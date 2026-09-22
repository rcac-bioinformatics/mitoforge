process MITOFORGE_SUMMARY {
    tag "${workflow.runName}"
    label 'process_single'

    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/ubuntu:20.04'
        : 'nf-core/ubuntu:20.04'}"

    input:
    path manifest
    path progress
    path per_sample, stageAs: 'per_sample/*'
    path contig_stats, stageAs: 'contig_stats/*'

    output:
    path "mitoforge_summary.tsv"    , emit: summary
    path "all_contigs_stats.tsv"    , emit: all_contigs_stats
    path "mitoforge_summary_mqc.tsv", emit: mqc
    tuple val("${task.process}"), val('mitoforge'), val("${workflow.manifest.version}"), topic: versions, emit: versions_mitoforge

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    # A sample that failed produced no files at all, so the globs below can match
    # nothing and must not expand to a literal pattern.
    shopt -s nullglob

    # How far did each sample get? ${progress} holds one line per sample per stage it
    # reached; the furthest one is what the summary reports.
    awk '
        BEGIN {
            FS = OFS = "\\t"
            rank["input"] = 1; rank["reference"] = 2; rank["assembly"] = 3; rank["final"] = 4
        }
        (\$2 in rank) && rank[\$2] > best[\$1] { best[\$1] = rank[\$2] }
        END { for (sample in best) { print sample, best[sample] } }
    ' ${progress} > stage.tsv

    # The rows written for samples that made it all the way through.
    : > passed.tsv
    for f in per_sample/*.summary.tsv; do
        cat "\${f}" >> passed.tsv
    done

    # One row per sample in the samplesheet, whether or not it finished. A sample that
    # dropped out says where it stopped instead of quietly disappearing.
    awk '
        BEGIN {
            FS = OFS = "\\t"
            label[1] = "failed: no reference"
            label[2] = "failed: assembly"
            label[3] = "failed: finishing"
            label[4] = "failed: reporting"
        }
        FILENAME == "stage.tsv"  { stage[\$1] = \$2; next }
        FILENAME == "passed.tsv" { row[\$1] = \$0; next }
        {
            if (\$1 in row) { print row[\$1]; next }
            reached = (\$1 in stage) ? stage[\$1] : 1
            print \$1, \$2, \$3, \$4, "NA", "NA", "NA", "NA", label[reached]
        }
    ' stage.tsv passed.tsv ${manifest} | sort -k1,1 > body.tsv

    {
        printf 'sample\\tplatform\\tgenetic_code\\treference\\tlength_bp\\tgenes\\tcircular\\tframeshifts\\tstatus\\n'
        cat body.tsv
    } > mitoforge_summary.tsv

    # MitoHiFi's per-contig tables from every sample, stacked under one header.
    stats_files=(contig_stats/*.contigs_stats.tsv)
    if [ \${#stats_files[@]} -gt 0 ]; then
        head -n 1 "\${stats_files[0]}" > all_contigs_stats.tsv
        for f in "\${stats_files[@]}"; do
            tail -n +2 "\${f}"
        done | sort -k1,1 >> all_contigs_stats.tsv
    else
        printf 'sample\\tstage\\tcontig_id\\n' > all_contigs_stats.tsv
    fi

    # The same summary again, with the header MultiQC needs to render it as a table.
    {
        printf '# id: "rcac-bioinformatics-mitoforge-summary"\\n'
        printf '# section_name: "mitoforge summary"\\n'
        printf '# description: "One row per sample: how it was assembled, which reference it was compared against, the size of the finished mitogenome, and whether it finished at all."\\n'
        printf '# format: "tsv"\\n'
        printf '# plot_type: "table"\\n'
        printf '# pconfig:\\n'
        printf '#     id: "mitoforge_summary_table"\\n'
        printf '#     namespace: "mitoforge"\\n'
        cat mitoforge_summary.tsv
    } > mitoforge_summary_mqc.tsv
    """

    stub:
    // The stub still stacks the per-sample rows, because that is what stub-mode
    // pipeline tests look at to check which samples ran and how they were wired.
    """
    shopt -s nullglob
    {
        printf 'sample\\tplatform\\tgenetic_code\\treference\\tlength_bp\\tgenes\\tcircular\\tframeshifts\\tstatus\\n'
        for f in per_sample/*.summary.tsv; do
            cat "\${f}"
        done | sort -k1,1
    } > mitoforge_summary.tsv
    printf 'sample\\tstage\\tcontig_id\\n' > all_contigs_stats.tsv
    cp mitoforge_summary.tsv mitoforge_summary_mqc.tsv
    """
}
