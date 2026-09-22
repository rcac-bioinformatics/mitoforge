/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { INPUT_CHECK            } from '../subworkflows/local/input_check'
include { PREPARE_REFERENCE      } from '../subworkflows/local/prepare_reference'
include { ASSEMBLE_HIFI          } from '../subworkflows/local/assemble_hifi'
include { FINALIZE               } from '../subworkflows/local/finalize'
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
    // SUBWORKFLOW: one finishing step for every assembly, whatever made it
    //
    FINALIZE ( ASSEMBLE_HIFI.out.assembly )

    //
    // SUBWORKFLOW: stub, see subworkflows/local/annotate
    //
    ANNOTATE ( FINALIZE.out.assembly, params.skip_annotation )

    //
    // SUBWORKFLOW: gather everything into one report
    //
    SUMMARY ( ANNOTATE.out.assembly, FINALIZE.out.stats, ASSEMBLE_HIFI.out.stats )

    ch_multiqc_files = ch_multiqc_files.mix( SUMMARY.out.multiqc )

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
