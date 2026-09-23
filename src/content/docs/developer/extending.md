---
title: "Adding a stage"
---

Worked example: filling in the `ANNOTATE` stub with a real annotator.

The stub exists so that this is a small, contained change. It sits between `FINALIZE`
and `SUMMARY`, takes `[meta, fasta]`, and emits `[meta, fasta]`. Everything around it
already works; you are replacing the middle.

## What the stub looks like now

```groovy title="subworkflows/local/annotate/main.nf"
workflow ANNOTATE {

    take:
    ch_assembly    // channel: [ meta, fasta ]
    skip           // value:   params.skip_annotation

    main:

    if (!skip) {
        log.info("ANNOTATE is a stub in this version: ...")
    }

    emit:
    assembly = ch_assembly // channel: [ meta, fasta ]
}
```

Every sample is already annotated inside `FINALIZE`, because MitoHiFi calls MitoFinder.
A standalone stage is worth having when you want a _different_ annotator — MITOS2 for
invertebrates, MitoAnnotator for fish — or want to re-annotate without re-assembling.

## Step 1: get the module

Check nf-core first. Always.

```bash
nf-core modules list remote | grep -i mitos
```

If it is there:

```bash
nf-core modules install mitos/runmitos
```

If it is not, write a local one in `modules/local/<tool>/main.nf`. Copy the shape of
`modules/local/mitoforge_sample_stats/main.nf`: a `tag`, a resource `label`, a pinned
`container`, a `when:` guard, a `script:` block, a `stub:` block, and a `versions`
topic emission.

```groovy
process MYANNOTATOR {
    tag "${meta.id}"
    label 'process_medium'

    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/myannotator:1.2.3--py39_0'
        : 'quay.io/biocontainers/myannotator:1.2.3--py39_0'}"

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("${meta.id}.annotated.fasta"), emit: fasta
    tuple val(meta), path("${meta.id}.gff")            , emit: gff
    tuple val("${task.process}"), val('myannotator'), eval('myannotator --version'), topic: versions, emit: versions_myannotator

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    myannotator \\
        --genetic-code ${meta.genetic_code} \\
        ${args} \\
        --out ${prefix} \\
        ${fasta}
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.annotated.fasta
    touch ${prefix}.gff
    """
}
```

:::caution[Pin the container, and stage inputs carefully]
Never use a floating tag. And if your tool writes an output file with the same name
as one of its inputs, stage the input into a subdirectory — see the patch on
`modules/nf-core/mitohifi/mitohifi` for what happens otherwise.
:::

## Step 2: fill in the subworkflow

```groovy title="subworkflows/local/annotate/main.nf"
include { MYANNOTATOR } from '../../../modules/local/myannotator/main'

workflow ANNOTATE {

    take:
    ch_assembly // channel: [ meta, fasta ]
    skip        // value:   params.skip_annotation

    main:

    if (skip) {
        emit:
        assembly = ch_assembly
        return
    }

    MYANNOTATOR ( ch_assembly )

    emit:
    assembly = MYANNOTATOR.out.fasta  // [ meta, fasta ] - the contract
    gff      = MYANNOTATOR.out.gff    // extra outputs are fine
}
```

The important part is that `assembly` is still `[meta, fasta]`, with `meta` untouched.
`SUMMARY` and everything after it keep working unchanged.

:::tip[Skipping is not the same as doing nothing]
Keep the `skip` branch returning the input channel. It is what lets people turn your
stage off without editing code, and it keeps the existing tests passing.
:::

## Step 3: give it a meta.yml

```yaml title="subworkflows/local/annotate/meta.yml"
name: "annotate"
description: Annotate finished mitogenomes with MyAnnotator
keywords:
  - annotation
  - mitogenome
  - myannotator
components:
  - myannotator
input:
  - ch_assembly:
      type: file
      description: |
        The finished mitogenome.
        Structure: [ val(meta), path(fasta) ]
  - skip:
      type: boolean
      description: Skip this stage and pass assemblies through unchanged.
output:
  - assembly:
      type: file
      description: |
        The annotated mitogenome.
        Structure: [ val(meta), path(fasta) ]
authors:
  - "Your Name"
maintainers:
  - "Your Name"
```

`nf-core pipelines lint` warns if this is missing.

## Step 4: publish its output

```groovy title="conf/modules.config"
withName: 'MYANNOTATOR' {
    ext.args   = { params.myannotator_args ?: '' }
    publishDir = [
        path: { "${params.outdir}/samples/${meta.id}/annotation" },
        mode: params.publish_dir_mode
    ]
}
```

One map, not a list, if any closure in it mentions `meta`. See the
[two traps](/mitoforge/developer/#two-traps-worth-knowing-about).

## Step 5: make the parameter real

`--skip_annotation` already exists and defaults to `true`. Flip the default and describe
any new parameters in `nextflow_schema.json`:

```json
"skip_annotation": {
    "type": "boolean",
    "description": "Skip the ANNOTATE stage.",
    "fa_icon": "fas fa-forward"
},
"myannotator_args": {
    "type": "string",
    "description": "Extra arguments passed to MyAnnotator.",
    "fa_icon": "fas fa-cog"
}
```

Anything in `params` that is not in the schema produces an "unrecognised parameter"
warning on every run.

## Step 6: test it

Update the existing tests rather than deleting them — they encode the contract.

```groovy title="subworkflows/local/annotate/tests/main.nf.test"
test("annotates a mitogenome") {
    when {
        params { outdir = "$outputDir" }
        workflow {
            """
            input[0] = channel.of([
                [ id: 'ilDeiPorc1', platform: 'hifi', genetic_code: 5 ],
                file("\${projectDir}/testdata/hifi/ilDeiPorc1.final_mitogenome.fasta", checkIfExists: true)
            ])
            input[1] = false
            """
        }
    }
    then {
        assertAll(
            { assert workflow.success },
            { assert workflow.out.assembly.size() == 1 },
            { assert workflow.out.assembly[0][0].id == 'ilDeiPorc1' },
            { assert workflow.out.gff.size() == 1 }
        )
    }
}
```

Keep the "passes through unchanged when skipped" test. It is the contract.

```bash
nf-test test subworkflows/local/annotate
nextflow run . -profile test,docker --outdir results
nf-test test tests/default.nf.test --update-snapshot   # the output tree changed
nf-core pipelines lint
```

## Step 7: document it

- `docs/output.md` — the new files, and what they mean
- `docs/citations.md` — the tool you just added
- `CITATIONS.md` and `toolCitationText()`/`toolBibliographyText()` in
  `subworkflows/local/utils_nfcore_mitoforge_pipeline/main.nf`, which feed the MultiQC
  methods section
- `CHANGELOG.md`
- `CLAUDE.md` — the "Current state" section

## Adding a stage somewhere else

The same six steps. Pick where it goes in `workflows/mitoforge.nf` and hand it the
channel it needs:

```groovy
NEW_STAGE ( FINALIZE_HIFI.out.assembly.mix( FINALIZE_SHORT.out.assembly ) )
ANNOTATE  ( NEW_STAGE.out.assembly, params.skip_annotation )
```

If your stage can fail for one sample, it does not need anything special: the default
`errorStrategy` drops that sample and `SUMMARY` reports it. If it must never fail
silently — a run-level step, not a per-sample one — set `errorStrategy = 'finish'` for
it in `conf/modules.config`, the way `MITOFORGE_SUMMARY` does.

If it should also feed the run summary, add it to the progress channel in
`subworkflows/local/summary/main.nf` so a sample that dies there is reported at the
right stage.
