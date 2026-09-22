process MITOFORGE_SAMPLE_STATS {
    tag "${meta.id}"
    label 'process_single'

    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/ubuntu:20.04'
        : 'nf-core/ubuntu:20.04'}"

    input:
    // Both tables are called contigs_stats.tsv where they come from, so they are
    // staged under distinct names.
    tuple val(meta), path(fasta), path(final_stats, stageAs: 'stats/final_contigs_stats.tsv'), path(assembly_stats, stageAs: 'stats/assembly_contigs_stats.tsv')

    output:
    tuple val(meta), path("${meta.id}.summary.tsv")      , emit: summary
    tuple val(meta), path("${meta.id}.contigs_stats.tsv"), emit: contigs_stats
    tuple val("${task.process}"), val('mitoforge'), val("${workflow.manifest.version}"), topic: versions, emit: versions_mitoforge

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix       = task.ext.prefix ?: "${meta.id}"
    def reference    = meta.ref_fa ? file(meta.ref_fa).name : 'NA'
    def has_assembly = assembly_stats ? true : false
    """
    # MitoHiFi's contigs_stats.tsv opens with a '#' comment about the reference, then
    # a header row, then one row per contig. Columns are looked up by name so a
    # reordering upstream does not silently shift the values.

    # 1. Size and gene count come from the finished mitogenome's row.
    awk '
        BEGIN { FS = OFS = "\\t"; length_bp = "NA"; genes = "NA"; frameshifts = "NA" }
        /^#/ { next }
        !seen_header { for (i = 1; i <= NF; i++) { col[\$i] = i } seen_header = 1; next }
        ("contig_id" in col) && \$(col["contig_id"]) == "final_mitogenome" {
            if ("length(bp)" in col)        { length_bp   = \$(col["length(bp)"]) }
            if ("number_of_genes" in col)   { genes       = \$(col["number_of_genes"]) }
            if ("frameshifts_found" in col) { frameshifts = \$(col["frameshifts_found"]) }
        }
        END { print length_bp, genes, frameshifts }
    ' ${final_stats} > measured.tsv

    IFS=\$'\\t' read -r length_bp genes frameshifts < measured.tsv

    # 2. Circularity is reported by whichever step actually found and trimmed the
    #    overlap. For a HiFi sample that is the assembly step, and by the time
    #    FINALIZE sees the sequence the overlap is gone, so FINALIZE says False. For a
    #    short-read sample there is no assembly-stage table and FINALIZE is where it
    #    happens. Answering "was this mitogenome circularised at any point" means
    #    looking at every table there is.
    circular=False
    for stats_file in ${final_stats}${has_assembly ? " ${assembly_stats}" : ''}; do
        if awk '
            BEGIN { FS = "\\t" }
            /^#/ { next }
            !seen_header { for (i = 1; i <= NF; i++) { col[\$i] = i } seen_header = 1; next }
            ("was_circular" in col) && \$(col["was_circular"]) ~ /^[Tt]rue\$/ { found = 1 }
            END { exit !found }
        ' "\${stats_file}"; then
            circular=True
        fi
    done

    # 3. If MitoHiFi wrote no 'final_mitogenome' row, measure the FASTA instead so the
    #    summary still says how big the assembly is.
    if [ "\${length_bp}" = "NA" ]; then
        length_bp=\$(awk '/^>/ { next } { gsub(/[^A-Za-z]/, ""); n += length(\$0) } END { print n + 0 }' ${fasta})
    fi

    printf '%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n' \\
        '${meta.id}' '${meta.platform}' '${meta.genetic_code}' '${reference}' \\
        "\${length_bp}" "\${genes}" "\${circular}" "\${frameshifts}" 'pass' \\
        > ${prefix}.summary.tsv

    # 4. Stack this sample's per-contig tables, tagged with the sample and the step
    #    they came from. The assembly-step table is the one that lists the rejected
    #    candidates, which is where NUMTs show up.
    print_stats() {
        awk -v sample='${meta.id}' -v stage="\$1" -v with_header="\$2" '
            BEGIN { FS = OFS = "\\t" }
            /^#/ { next }
            !seen_header {
                if (with_header == "yes") { print "sample", "stage", \$0 }
                seen_header = 1
                next
            }
            { print sample, stage, \$0 }
        ' "\$3"
    }

    print_stats final yes ${final_stats} > ${prefix}.contigs_stats.tsv
    ${has_assembly ? "print_stats assembly no ${assembly_stats} >> ${prefix}.contigs_stats.tsv" : ''}
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    printf '%s\\t%s\\t%s\\tNA\\t0\\t0\\tNA\\tNA\\tpass\\n' '${meta.id}' '${meta.platform}' '${meta.genetic_code}' > ${prefix}.summary.tsv
    printf 'sample\\tstage\\tcontig_id\\n%s\\tfinal\\tfinal_mitogenome\\n' '${meta.id}' > ${prefix}.contigs_stats.tsv
    """
}
