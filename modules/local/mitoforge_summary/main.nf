process MITOFORGE_SUMMARY {
    tag "${workflow.runName}"
    label 'process_single'

    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/ubuntu:20.04'
        : 'nf-core/ubuntu:20.04'}"

    input:
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
    # One row per sample, sorted so the table is stable between runs.
    {
        printf 'sample\\tplatform\\tgenetic_code\\treference\\tlength_bp\\tgenes\\tcircular\\tframeshifts\\tstatus\\n'
        cat per_sample/*.summary.tsv | sort -k1,1
    } > mitoforge_summary.tsv

    # MitoHiFi's per-contig tables from every sample, stacked under one header.
    first_stats=\$(ls contig_stats/*.contigs_stats.tsv | head -n 1)
    head -n 1 "\${first_stats}" > all_contigs_stats.tsv
    for f in contig_stats/*.contigs_stats.tsv; do
        tail -n +2 "\${f}"
    done | sort -k1,1 >> all_contigs_stats.tsv

    # The same summary again, with the header MultiQC needs to render it as a table.
    {
        printf '# id: "rcac-bioinformatics-mitoforge-summary"\\n'
        printf '# section_name: "mitoforge summary"\\n'
        printf '# description: "One row per sample: how it was assembled, which reference it was compared against, and the size of the finished mitogenome."\\n'
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
    {
        printf 'sample\\tplatform\\tgenetic_code\\treference\\tlength_bp\\tgenes\\tcircular\\tframeshifts\\tstatus\\n'
        cat per_sample/*.summary.tsv | sort -k1,1
    } > mitoforge_summary.tsv
    printf 'sample\\tstage\\tcontig_id\\n' > all_contigs_stats.tsv
    cp mitoforge_summary.tsv mitoforge_summary_mqc.tsv
    """
}
