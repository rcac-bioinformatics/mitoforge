//
// SUMMARY: one table for the whole run, including the samples that did not make it.
//
// Two files come out, both in results/summary/:
//   mitoforge_summary.tsv   one row per samplesheet row: platform, reference, size,
//                           genes, circularity, and a status that says where a failed
//                           sample stopped
//   all_contigs_stats.tsv   MitoHiFi's per-contig tables for every sample, from both
//                           the assembly step and the finishing step, stacked with
//                           'sample' and 'stage' columns in front. The assembly-step
//                           rows are where rejected candidates and NUMTs show up.
//
// Because a failed sample is dropped rather than killing the run, it simply stops
// appearing in the channels downstream of wherever it failed. Its progress is
// therefore reconstructed by recording which stages it did reach.
//
// The summary is also handed to MultiQC as custom content so it appears at the top of
// the HTML report.
//

include { MITOFORGE_SAMPLE_STATS } from '../../../modules/local/mitoforge_sample_stats/main'
include { MITOFORGE_SUMMARY      } from '../../../modules/local/mitoforge_summary/main'

workflow SUMMARY {

    take:
    ch_samples        // channel: [ meta, [ reads ] ]         every row in the samplesheet
    ch_reference      // channel: [ meta, ref_fa, ref_gb ]    samples that got a reference
    ch_assembled      // channel: [ meta, fasta ]             samples an assembler produced something for
    ch_finished       // channel: [ meta, fasta ]             samples that came out of FINALIZE
    ch_final_stats    // channel: [ meta, contigs_stats.tsv ] from FINALIZE
    ch_assembly_stats // channel: [ meta, contigs_stats.tsv ] from the assembler, where it has one

    main:

    //
    // What the samplesheet asked for. Known before anything runs, so it is the list
    // every sample is checked against at the end.
    //
    def ch_manifest = ch_samples
        .map { meta, _files ->
            [ meta.id, meta.platform, meta.genetic_code, requestedReference(meta) ].join('\t')
        }
        .collectFile(name: 'samples.tsv', newLine: true, sort: true)

    //
    // How far each sample actually got.
    //
    def ch_progress = ch_samples.map { meta, _files -> "${meta.id}\tinput" }
        .mix( ch_reference.map { meta, _fa, _gb -> "${meta.id}\treference" } )
        .mix( ch_assembled.map { meta, _fasta -> "${meta.id}\tassembly" } )
        .mix( ch_finished.map { meta, _fasta -> "${meta.id}\tfinal" } )
        .collectFile(name: 'progress.tsv', newLine: true, sort: true)

    //
    // Per-sample numbers, for the samples that have any. Short-read assemblers do not
    // produce a MitoHiFi-style contig table, so the assembly-stage stats are optional.
    //
    def ch_per_sample = ch_finished
        .join( ch_final_stats )
        .map { meta, fasta, stats -> [ meta.id, meta, fasta, stats ] }
        .join( ch_assembly_stats.map { meta, stats -> [ meta.id, stats ] }, remainder: true )
        .filter { row -> row[1] != null }
        .map { _id, meta, fasta, final_stats, assembly_stats ->
            [ meta, fasta, final_stats, assembly_stats ?: [] ]
        }

    MITOFORGE_SAMPLE_STATS ( ch_per_sample )

    MITOFORGE_SUMMARY (
        ch_manifest,
        ch_progress,
        MITOFORGE_SAMPLE_STATS.out.summary.map { _meta, tsv -> tsv }.collect().ifEmpty( [] ),
        MITOFORGE_SAMPLE_STATS.out.contigs_stats.map { _meta, tsv -> tsv }.collect().ifEmpty( [] )
    )

    emit:
    summary           = MITOFORGE_SUMMARY.out.summary           // path: mitoforge_summary.tsv
    all_contigs_stats = MITOFORGE_SUMMARY.out.all_contigs_stats // path: all_contigs_stats.tsv
    multiqc           = MITOFORGE_SUMMARY.out.mqc               // path: mitoforge_summary_mqc.tsv
}

//
// What the user asked for in the reference columns, in a form that fits one cell.
//
def requestedReference(meta) {
    if (meta.ref_source == 'hifi') {
        return meta.ref_fa
    }
    if (meta.ref_source == 'species') {
        return "species:${meta.species}"
    }
    return meta.ref_fa ? file(meta.ref_fa).name : 'NA'
}
