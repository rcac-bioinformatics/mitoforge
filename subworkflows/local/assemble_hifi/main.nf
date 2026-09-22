//
// ASSEMBLE_HIFI: PacBio HiFi reads in, one candidate mitogenome out.
//
// MitoHiFi in reads mode (-r) maps the reads to the reference mitogenome with
// minimap2, throws away anything longer than the reference (NUMTs), and assembles
// what is left with hifiasm.
//
// Reads may arrive as FASTA/FASTQ or inside an unaligned PacBio BAM. minimap2 reads
// either, so a BAM is just converted first.
//

include { SAMTOOLS_FASTQ    } from '../../../modules/nf-core/samtools/fastq/main'
include { MITOHIFI_MITOHIFI } from '../../../modules/nf-core/mitohifi/mitohifi/main'

workflow ASSEMBLE_HIFI {

    take:
    ch_reads // channel: [ meta, [ reads ] ]  reads already in FASTA/FASTQ
    ch_bam   // channel: [ meta, [ bam ] ]    unaligned PacBio BAM

    main:

    //
    // BAM -> FASTQ.
    //
    // Records in an unaligned PacBio BAM carry flag 4 and neither READ1 nor READ2,
    // so `samtools fastq` routes all of them to the file given to -0, which this
    // module publishes on its `other` channel. The `fastq` and `singleton` channels
    // come back empty. This is verified by the nf-test case for this subworkflow.
    //
    SAMTOOLS_FASTQ ( ch_bam, false )

    def ch_all_reads = ch_reads.mix( SAMTOOLS_FASTQ.out.other )

    //
    // MitoHiFi needs the reads, the reference pair and the genetic code to line up
    // sample by sample. multiMap splits one channel into three, so the order holds.
    //
    def ch_input = ch_all_reads.multiMap { meta, reads ->
        reads:     [ meta, reads ]
        reference: [ meta, meta.ref_fa, meta.ref_gb ]
        code:      meta.genetic_code
    }

    MITOHIFI_MITOHIFI ( ch_input.reads, ch_input.reference, 'reads', ch_input.code )

    emit:
    assembly = MITOHIFI_MITOHIFI.out.fasta // channel: [ meta, fasta ]
    stats    = MITOHIFI_MITOHIFI.out.stats // channel: [ meta, contigs_stats.tsv ]
}
