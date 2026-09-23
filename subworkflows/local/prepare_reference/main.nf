//
// PREPARE_REFERENCE: give every sample a close-relative mitogenome to work against.
//
// Three ways in, one way out:
//   file     the user gave ref_fa + ref_gb in the samplesheet
//   species  the user gave a scientific name; findMitoReference.py asks NCBI
//   hifi     the user wrote 'hifi:<sample>'; that sample's finished mitogenome is
//            used. Only illumina rows may do this, so there is no cycle.
//
// On the way out, meta.ref_fa and meta.ref_gb are the resolved files rather than the
// strings the user typed, which is what the rest of the pipeline expects.
//

include { MITOHIFI_FINDMITOREFERENCE } from '../../../modules/nf-core/mitohifi/findmitoreference/main'

workflow PREPARE_REFERENCE {

    take:
    ch_samples   // channel: [ meta, [ reads ] ]

    main:

    def ch_by_source = ch_samples.branch { meta, _files ->
        from_file:    meta.ref_source == 'file'
        from_species: meta.ref_source == 'species'
        from_hifi:    meta.ref_source == 'hifi'
    }

    //
    // Reference files named in the samplesheet
    //
    def ch_from_file = ch_by_source.from_file.map { meta, _files ->
        [ meta, file(meta.ref_fa, checkIfExists: true), file(meta.ref_gb, checkIfExists: true) ]
    }

    //
    // Reference looked up at NCBI by species name. This reaches the internet, which
    // Gautschi's compute nodes can do, so it runs inside the job like any other step.
    //
    MITOHIFI_FINDMITOREFERENCE (
        ch_by_source.from_species.map { meta, _files -> [ meta, meta.species ] }
    )

    def ch_reference = ch_from_file
        .mix(MITOHIFI_FINDMITOREFERENCE.out.reference)
        .map { meta, ref_fa, ref_gb -> [ meta + [ ref_fa: ref_fa, ref_gb: ref_gb ], ref_fa, ref_gb ] }

    emit:
    reference   = ch_reference             // channel: [ meta, ref_fa, ref_gb ]
    needs_hifi  = ch_by_source.from_hifi   // channel: [ meta, [ reads ] ] - resolved later, once the hifi samples are finished
}
