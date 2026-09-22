# Adding an assembler

`--long_assembler` and `--short_assembler` each accept exactly one value today. They
exist as parameters so that a second one can be added without changing the samplesheet
format.

This page adds a hypothetical short-read assembler called NOVOPlasty. A long-read one
is the same shape.

## Step 1: widen the parameter

```json title="nextflow_schema.json"
"short_assembler": {
    "type": "string",
    "default": "getorganelle",
    "enum": ["getorganelle", "novoplasty"],
    "description": "Assembler used for `platform: illumina` rows.",
    "fa_icon": "fas fa-cogs"
}
```

The `enum` is what gives a novice a useful error instead of a silent no-op:

```
* --short_assembler (nvoplasty): Value is not one of the accepted values: getorganelle, novoplasty
```

## Step 2: get the module

```bash
nf-core modules list remote | grep -i novoplasty
nf-core modules install novoplasty/novoplasty
```

If there is no nf-core module, write a local one — see
[Adding a stage](extending.md#step-1-get-the-module) for the shape.

## Step 3: branch inside the subworkflow

The choice belongs inside `ASSEMBLE_SHORT`, not in `workflows/mitoforge.nf`. The rest of
the pipeline should not know or care which assembler ran.

```groovy title="subworkflows/local/assemble_short/main.nf"
include { GETORGANELLE_CONFIG    } from '../../../modules/nf-core/getorganelle/config/main'
include { GETORGANELLE_FROMREADS } from '../../../modules/nf-core/getorganelle/fromreads/main'
include { NOVOPLASTY             } from '../../../modules/nf-core/novoplasty/novoplasty/main'
include { GUNZIP                 } from '../../../modules/nf-core/gunzip/main'

workflow ASSEMBLE_SHORT {

    take:
    ch_reads       // channel: [ meta, [ read_1, read_2 ] ]
    skip_trimming  // value:   params.skip_trimming
    assembler      // value:   params.short_assembler

    main:

    // ... trimming, unchanged ...

    def ch_assembly = channel.empty()

    if (assembler == 'getorganelle') {
        GETORGANELLE_CONFIG ( 'animal_mt' )
        def ch_input = ch_trimmed.multiMap { meta, reads ->
            reads: [ meta, reads ]
            seed:  meta.ref_fa
        }
        GETORGANELLE_FROMREADS ( ch_input.reads, GETORGANELLE_CONFIG.out.db, ch_input.seed )
        GUNZIP ( GETORGANELLE_FROMREADS.out.fasta )
        ch_assembly = GUNZIP.out.gunzip
    }
    else if (assembler == 'novoplasty') {
        NOVOPLASTY ( ch_trimmed )
        ch_assembly = NOVOPLASTY.out.fasta
    }

    emit:
    assembly   = ch_assembly
    fastp_json = ch_fastp_json
}
```

Then pass the parameter in:

```groovy title="workflows/mitoforge.nf"
ASSEMBLE_SHORT (
    ch_by_platform.illumina.mix( ch_short_from_hifi ),
    params.skip_trimming,
    params.short_assembler
)
```

## Step 4: match the output contract

`FINALIZE` is the rest of the pipeline, and it wants:

- `[meta, fasta]`, with `meta` unchanged
- **uncompressed** FASTA — MitoHiFi's contigs mode refuses gzip
- an assembly that is **at least 80% of the reference length** — MitoHiFi rejects
  anything shorter, so a fragmented assembly fails rather than producing a fragment

If your assembler writes gzip, put `GUNZIP` after it as GetOrganelle does. If it writes
multiple contigs, that is fine: the finishing step is what chooses between them.

## Step 5: resources and publishing

```groovy title="conf/modules.config"
withName: 'NOVOPLASTY' {
    ext.args   = { params.novoplasty_args ?: '' }
    publishDir = [
        path: { "${params.outdir}/samples/${meta.id}/assembly" },
        mode: params.publish_dir_mode,
        saveAs: { filename ->
            def name = filename.tokenize('/').last()
            name.endsWith('.fasta') || name.endsWith('.log') ? name : null
        }
    ]
}
```

Be selective. Assemblers leave large intermediates behind, and publishing a directory
wholesale can copy gigabytes per sample.

## Step 6: if it produces a contig table

`SUMMARY` takes an optional assembly-stage stats channel, in MitoHiFi's
`contigs_stats.tsv` format. GetOrganelle produces nothing of the sort, so it passes
nothing, and the summary falls back to the finishing step's numbers plus GetOrganelle's
`(circular)` marker.

If your assembler does produce a comparable table, emit it as `stats` and mix it in:

```groovy title="workflows/mitoforge.nf"
SUMMARY (
    INPUT_CHECK.out.samples,
    PREPARE_REFERENCE.out.reference,
    ch_assembled,
    ANNOTATE.out.assembly,
    ch_finished_stats,
    ASSEMBLE_HIFI.out.stats.mix( ASSEMBLE_SHORT.out.stats )
)
```

If it does not, and circularity matters, teach `MITOFORGE_SAMPLE_STATS` the marker your
assembler uses, the way it already knows GetOrganelle's `(circular)`.

## Step 7: test it

```bash
nf-test test subworkflows/local/assemble_short
nextflow run . -profile test,docker --outdir results -- --short_assembler novoplasty
nf-core pipelines lint
```

Keep the existing GetOrganelle test and add one for the new assembler. The default must
not change unless that is the point of the change.

## Step 8: document it

- `docs/samplesheet.md` — the platform-to-assembler table
- `docs/cases/` — a case page if the new assembler needs different inputs
- `docs/citations.md` and `CITATIONS.md`
- `docs/troubleshooting.md` — its characteristic failure modes
- `CHANGELOG.md` and `CLAUDE.md`

## Adding a platform, not just an assembler

A third `platform` value — Nanopore, say — is a bigger change:

1. Add it to the `enum` in `assets/schema_input.json`.
2. Teach `INPUT_CHECK` its read-layout rules (single-ended? paired?).
3. Add `subworkflows/local/assemble_<platform>/`.
4. Add a branch in `workflows/mitoforge.nf` and feed its output into `FINALIZE`.
5. Add real test data and a case page.

The finishing step, the summary, and the samplesheet contract do not change. That is the
point of the design.
