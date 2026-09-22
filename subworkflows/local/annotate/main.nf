//
// ANNOTATE: a stub.
//
// Every sample is already annotated inside FINALIZE, because MitoHiFi calls
// MitoFinder (or MITOS2) on the finished mitogenome. This stage exists so that a
// standalone annotator can be dropped in later without touching anything around it:
// it takes [ meta, fasta ] and emits [ meta, fasta ].
//
// It is skipped by default (--skip_annotation, default true). Even when it is not
// skipped, v1 passes assemblies through unchanged.
//
// docs/developer/extending.md works through filling this in.
//

workflow ANNOTATE {

    take:
    ch_assembly    // channel: [ meta, fasta ]
    skip           // value:   params.skip_annotation

    main:

    if (!skip) {
        log.info("ANNOTATE is a stub in this version: assemblies pass through unchanged. " +
                 "Annotation for every sample comes from MitoHiFi inside FINALIZE.")
    }

    emit:
    assembly = ch_assembly // channel: [ meta, fasta ]
}
