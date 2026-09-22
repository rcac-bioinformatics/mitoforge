//
// FINALIZE: the one step every sample goes through, whatever assembled it.
//
// MitoHiFi in contigs mode (-c) picks the best mitochondrial contig, checks it for
// circularity, trims the overlap, rotates it to start at tRNA-Phe and annotates it.
// Running it on HiFi and Illumina assemblies alike is what makes the output
// directories identical across platforms.
//
// MitoHiFi cannot read gzipped input in contigs mode, so assemblies must arrive
// uncompressed.
//

include { MITOHIFI_MITOHIFI as MITOHIFI_FINALIZE } from '../../../modules/nf-core/mitohifi/mitohifi/main'

workflow FINALIZE {

    take:
    ch_assembly // channel: [ meta, fasta ]

    main:

    def ch_input = ch_assembly.multiMap { meta, fasta ->
        contigs:   [ meta, fasta ]
        reference: [ meta, meta.ref_fa, meta.ref_gb ]
        code:      meta.genetic_code
    }

    MITOHIFI_FINALIZE ( ch_input.contigs, ch_input.reference, 'contigs', ch_input.code )

    emit:
    assembly = MITOHIFI_FINALIZE.out.fasta // channel: [ meta, final_mitogenome.fasta ]
    gb       = MITOHIFI_FINALIZE.out.gb    // channel: [ meta, final_mitogenome.gb ]
    gff      = MITOHIFI_FINALIZE.out.gff   // channel: [ meta, final_mitogenome.gff ]
    stats    = MITOHIFI_FINALIZE.out.stats // channel: [ meta, contigs_stats.tsv ]
}
