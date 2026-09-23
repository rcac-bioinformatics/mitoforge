/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { INPUT_CHECK            } from '../subworkflows/local/input_check'
include { PREPARE_REFERENCE      } from '../subworkflows/local/prepare_reference'
include { ASSEMBLE_HIFI          } from '../subworkflows/local/assemble_hifi'
include { ASSEMBLE_SHORT         } from '../subworkflows/local/assemble_short'
include { FINALIZE as FINALIZE_HIFI  } from '../subworkflows/local/finalize'
include { FINALIZE as FINALIZE_SHORT } from '../subworkflows/local/finalize'
include { ANNOTATE               } from '../subworkflows/local/annotate'
include { SUMMARY                } from '../subworkflows/local/summary'
include { MULTIQC                } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_mitoforge_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow MITOFORGE {

    take:
    ch_samplesheet // channel: samplesheet read in from --input
    multiqc_config
    multiqc_logo
    multiqc_methods_description
    outdir

    main:

    def ch_versions = channel.empty()
    def ch_multiqc_files = channel.empty()

    //
    // SUBWORKFLOW: samplesheet rows -> meta maps
    //
    INPUT_CHECK ( ch_samplesheet, params.genetic_code )

    //
    // SUBWORKFLOW: give every sample a reference mitogenome
    //
    PREPARE_REFERENCE ( INPUT_CHECK.out.samples )

    //
    // Put the resolved reference back onto each sample. The reference channel carries
    // the enriched meta (ref_fa and ref_gb are now files), so join on the sample id
    // and keep that copy of meta.
    //
    def ch_with_reference = PREPARE_REFERENCE.out.reference
        .map { meta, _ref_fa, _ref_gb -> [ meta.id, meta ] }
        .join( INPUT_CHECK.out.samples.map { meta, files -> [ meta.id, files ] } )
        .map { _id, meta, files -> [ meta, files ] }

    def ch_by_platform = ch_with_reference.branch { meta, _files ->
        hifi_bam:   meta.platform == 'hifi' && meta.input_type == 'bam'
        hifi_reads: meta.platform == 'hifi'
        illumina:   meta.platform == 'illumina'
    }

    //
    // SUBWORKFLOW: assemble the HiFi samples
    //
    ASSEMBLE_HIFI ( ch_by_platform.hifi_reads, ch_by_platform.hifi_bam )

    //
    // SUBWORKFLOW: finish the HiFi assemblies
    //
    FINALIZE_HIFI ( ASSEMBLE_HIFI.out.assembly )

    //
    // Resolve 'ref_fa: hifi:<sample>'. Those rows waited for the sample they name to
    // be assembled and finished; now that it has been, hand them its mitogenome and
    // its annotation. combine() rather than join(), because many short-read samples
    // may share one HiFi reference.
    //
    // This is also why the finishing step is invoked twice rather than once on the
    // mixture: the short-read assemblies depend on the finished HiFi ones, and a
    // single invocation would be a cycle. Both invocations are the same subworkflow
    // with the same settings, so every sample is still finished identically.
    //
    def ch_hifi_references = FINALIZE_HIFI.out.assembly
        .join( FINALIZE_HIFI.out.gb )
        .map { meta, fasta, gb -> [ meta.id, fasta, gb ] }

    def ch_short_from_hifi = PREPARE_REFERENCE.out.needs_hifi
        .map { meta, files -> [ meta.ref_fa.substring('hifi:'.length()), meta, files ] }
        .combine( ch_hifi_references, by: 0 )
        .map { _target, meta, files, ref_fa, ref_gb ->
            [ meta + [ ref_fa: ref_fa, ref_gb: ref_gb ], files ]
        }

    //
    // Every sample that ended up with a reference, whichever of the three routes gave
    // it one. PREPARE_REFERENCE cannot emit the 'hifi:<sample>' rows, because theirs
    // does not exist until the HiFi sample it names has been finished, so they are
    // added here. SUMMARY uses this to decide how far a sample got: without them, a
    // 'hifi:<sample>' row that failed at assembly was reported as 'failed: no
    // reference', which pointed at the wrong stage entirely.
    //
    def ch_resolved_references = PREPARE_REFERENCE.out.reference
        .mix( ch_short_from_hifi.map { meta, _files -> [ meta, meta.ref_fa, meta.ref_gb ] } )

    //
    // SUBWORKFLOW: assemble the Illumina samples
    //
    ASSEMBLE_SHORT (
        ch_by_platform.illumina.mix( ch_short_from_hifi ),
        params.skip_trimming
    )

    //
    // SUBWORKFLOW: finish the short-read assemblies, the same way
    //
    FINALIZE_SHORT ( ASSEMBLE_SHORT.out.assembly )

    def ch_assembled      = ASSEMBLE_HIFI.out.assembly.mix( ASSEMBLE_SHORT.out.assembly )
    def ch_finished       = FINALIZE_HIFI.out.assembly.mix( FINALIZE_SHORT.out.assembly )
    def ch_finished_stats = FINALIZE_HIFI.out.stats.mix( FINALIZE_SHORT.out.stats )

    //
    // SUBWORKFLOW: stub, see subworkflows/local/annotate
    //
    ANNOTATE ( ch_finished, params.skip_annotation )

    //
    // SUBWORKFLOW: gather everything into one report.
    //
    // A sample that fails is dropped rather than killing the run, so it stops
    // appearing in the channels downstream of wherever it failed. SUMMARY is given
    // the samplesheet and each stage's output so it can say which samples are
    // missing and where they stopped.
    //
    SUMMARY (
        INPUT_CHECK.out.samples,
        ch_resolved_references,
        ch_assembled,
        ANNOTATE.out.assembly,
        ch_finished_stats,
        ASSEMBLE_HIFI.out.stats
    )

    ch_multiqc_files = ch_multiqc_files.mix( SUMMARY.out.multiqc )
    ch_multiqc_files = ch_multiqc_files.mix( ASSEMBLE_SHORT.out.fastp_json.map { _meta, json -> json } )

    //
    // Collate and save software versions
    //
    def topic_versions = channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    def ch_collated_versions = softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${outdir}/pipeline_info",
            name:  'mitoforge_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        )

    //
    // MODULE: MultiQC
    //
    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    def ch_summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    def ch_workflow_summary = channel.value(paramsSummaryMultiqc(ch_summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    def ch_multiqc_custom_methods_description = multiqc_methods_description
        ? file(multiqc_methods_description, checkIfExists: true)
        : file("${projectDir}/assets/methods_description_template.yml", checkIfExists: true)
    def ch_methods_description = channel.value(methodsDescriptionText(ch_multiqc_custom_methods_description))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml', sort: true))
    MULTIQC(
        ch_multiqc_files.flatten().collect().map { files ->
            [
                [id: 'mitoforge'],
                files,
                multiqc_config
                    ? file(multiqc_config, checkIfExists: true)
                    : file("${projectDir}/assets/multiqc_config.yml", checkIfExists: true),
                multiqc_logo ? file(multiqc_logo, checkIfExists: true) : [],
                [],
                [],
            ]
        }
    )

    emit:
    multiqc_report = MULTIQC.out.report.map { _meta, report -> [report] }.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
