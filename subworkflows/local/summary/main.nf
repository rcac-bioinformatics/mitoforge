//
// SUMMARY: one table for the whole run.
//
// Two files come out, both in results/summary/:
//   mitoforge_summary.tsv   one row per sample: platform, reference, size, genes,
//                           circularity, status
//   all_contigs_stats.tsv   MitoHiFi's per-contig tables for every sample, from both
//                           the assembly step and the finishing step, stacked with
//                           'sample' and 'stage' columns in front. The assembly-step
//                           rows are where rejected candidates and NUMTs show up.
//
// The summary is also handed to MultiQC as custom content so it appears at the top of
// the HTML report.
//

include { MITOFORGE_SAMPLE_STATS } from '../../../modules/local/mitoforge_sample_stats/main'
include { MITOFORGE_SUMMARY      } from '../../../modules/local/mitoforge_summary/main'

workflow SUMMARY {

    take:
    ch_assembly       // channel: [ meta, fasta ]              the finished mitogenome
    ch_final_stats    // channel: [ meta, contigs_stats.tsv ]  from FINALIZE
    ch_assembly_stats // channel: [ meta, contigs_stats.tsv ]  from the assembler, where it has one

    main:

    // Short-read assemblers do not produce a MitoHiFi-style contig table, so the
    // assembly-stage stats are optional: join with remainder and fill in [].
    def ch_per_sample = ch_assembly
        .join( ch_final_stats )
        .map { meta, fasta, stats -> [ meta.id, meta, fasta, stats ] }
        .join( ch_assembly_stats.map { meta, stats -> [ meta.id, stats ] }, remainder: true )
        .filter { row -> row[1] != null }
        .map { _id, meta, fasta, final_stats, assembly_stats ->
            [ meta, fasta, final_stats, assembly_stats ?: [] ]
        }

    MITOFORGE_SAMPLE_STATS ( ch_per_sample )

    MITOFORGE_SUMMARY (
        MITOFORGE_SAMPLE_STATS.out.summary.map { _meta, tsv -> tsv }.collect(),
        MITOFORGE_SAMPLE_STATS.out.contigs_stats.map { _meta, tsv -> tsv }.collect()
    )

    emit:
    summary           = MITOFORGE_SUMMARY.out.summary           // path: mitoforge_summary.tsv
    all_contigs_stats = MITOFORGE_SUMMARY.out.all_contigs_stats // path: all_contigs_stats.tsv
    multiqc           = MITOFORGE_SUMMARY.out.mqc               // path: mitoforge_summary_mqc.tsv
}
