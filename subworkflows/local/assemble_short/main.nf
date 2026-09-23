//
// ASSEMBLE_SHORT: Illumina paired-end reads in, one candidate mitogenome out.
//
// GetOrganelle baits mitochondrial reads out of a whole-genome library using its
// animal_mt seed database, extends them, and assembles what it finds. Seeding it with
// the sample's own reference mitogenome as well makes the bait step much more
// specific, which matters when the reference is a congener or another sample's
// finished mitogenome.
//
// GetOrganelle writes its result gzipped, and MitoHiFi cannot read gzipped input in
// contigs mode, so the assembly is uncompressed on the way out.
//

include { FASTP                  } from '../../../modules/nf-core/fastp/main'
include { GETORGANELLE_CONFIG    } from '../../../modules/nf-core/getorganelle/config/main'
include { GETORGANELLE_FROMREADS } from '../../../modules/nf-core/getorganelle/fromreads/main'
include { GUNZIP                 } from '../../../modules/nf-core/gunzip/main'

workflow ASSEMBLE_SHORT {

    take:
    ch_reads      // channel: [ meta, [ read_1, read_2 ] ]
    skip_trimming // value:   params.skip_trimming

    main:

    //
    // Adapter and quality trimming. Optional, because reads that arrive already
    // trimmed do not need it and the step is not free on 78 samples.
    //
    def ch_trimmed = ch_reads
    def ch_fastp_json = channel.empty()

    if (!skip_trimming) {
        FASTP ( ch_reads.map { meta, reads -> [ meta, reads, [] ] }, false, false, false )
        ch_trimmed = FASTP.out.reads
        ch_fastp_json = FASTP.out.json
    }

    //
    // GetOrganelle's seed and label databases. Downloaded once per run, and it reaches
    // the internet, which Gautschi's compute nodes can do.
    //
    GETORGANELLE_CONFIG ( 'animal_mt' )

    //
    // The seed is a plain path input rather than part of the meta tuple, so it has to
    // stay in step with the reads. multiMap splits one channel, which keeps the order.
    //
    def ch_input = ch_trimmed.multiMap { meta, reads ->
        reads: [ meta, reads ]
        seed:  meta.ref_fa
    }

    GETORGANELLE_FROMREADS (
        ch_input.reads,
        GETORGANELLE_CONFIG.out.db,
        ch_input.seed
    )

    GUNZIP ( GETORGANELLE_FROMREADS.out.fasta )

    emit:
    assembly   = GUNZIP.out.gunzip     // channel: [ meta, fasta ]
    fastp_json = ch_fastp_json         // channel: [ meta, json ] - for MultiQC
}
