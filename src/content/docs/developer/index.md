---
title: "Developer guide"
---

How mitoforge is put together, and how to change it without breaking it.

## The shape of it

```
main.nf                                  entry point, initialisation and completion
workflows/mitoforge.nf                   the whole pipeline, wired together
subworkflows/local/
    input_check/                         samplesheet rows -> meta maps
    prepare_reference/                   every sample gets a reference mitogenome
    assemble_hifi/                       MitoHiFi -r  (with BAM -> FASTQ first)
    assemble_short/                      fastp -> GetOrganelle -> gunzip
    finalize/                            MitoHiFi -c, the one finishing step
    annotate/                            a stub, see Adding a stage
    summary/                             the run summary, including failures
modules/local/                           only tools with no nf-core module
modules/nf-core/                         everything else, installed with nf-core tools
conf/                                    base, modules, test, and one per cluster
```

```
INPUT_CHECK
     │
PREPARE_REFERENCE ──────────────┐ (rows saying ref_fa: hifi:<sample> wait here)
     │                          │
     ├── hifi ── ASSEMBLE_HIFI ─┴─ FINALIZE_HIFI ──┐
     │                                             │
     └── illumina ── ASSEMBLE_SHORT ── FINALIZE_SHORT
                            ▲                      │
                            └──────────────────────┘
                                                   │
                                    ANNOTATE (stub) ── SUMMARY ── MULTIQC
```

## The channel contract

Between subworkflows, an assembly travels as:

```groovy
tuple val(meta), path(fasta)
```

`meta` always carries at least:

| Key            | Type    | Meaning                                                                |
| -------------- | ------- | ---------------------------------------------------------------------- |
| `id`           | String  | The sample name                                                        |
| `platform`     | String  | `hifi` or `illumina`                                                   |
| `genetic_code` | Integer | NCBI translation table                                                 |
| `ref_fa`       | Path    | The reference FASTA. A String before `PREPARE_REFERENCE`, a file after |
| `ref_gb`       | Path    | The matching GenBank file, same story                                  |
| `ref_source`   | String  | `file`, `species` or `hifi`                                            |
| `single_end`   | Boolean | True for `hifi`                                                        |
| `input_type`   | String  | `fastq` or `bam`                                                       |

A new stage consumes `[meta, fasta]` and emits `[meta, fasta]`. That is the whole
contract, and it is what makes stages droppable in and out.

## Rules this pipeline is built on

These are not style preferences. Breaking one will bite someone.

1. **Wrap tools, never reimplement them.** If a tool is wrong, fix it upstream or swap
   it out.
2. **Use an nf-core module if one exists.** Write a local module only when none does.
   Pin every container by tag or digest.
3. **Every assembly goes through the same finishing step**, whatever assembled it. That
   is what makes the output directories identical across platforms.
4. **Compute nodes have no internet.** Anything that fetches runs with
   `executor = 'local'` in the cluster profiles, or is a documented login-node
   pre-step.
5. **One failed sample never kills the run**, and it is named in the summary.
6. **Nothing fabricated.** No invented test data, URLs, versions or accessions.

## Working on it

```bash
# toolchain
python -m venv .venv && .venv/bin/pip install nf-core pre-commit
curl -s https://get.nextflow.io | bash
curl -fsSL https://code.askimed.com/install/nf-test | bash

# the documentation site (Astro 7 needs Node >= 22.12)
npm install

# hooks: prettier, whitespace, nextflow-lint, nf-core lint
pre-commit install

# test data (real, public, about 50 MB)
bin/fetch_testdata.sh
```

Before every commit:

```bash
nextflow run . -profile test,docker --outdir results   # must be green
nf-test test                                            # must be green
nf-core pipelines lint                                  # zero failures
```

### Two traps worth knowing about

:::caution[`publishDir` must be a single map wherever a closure mentions `meta`]
Nextflow 26 cannot render a _list_ of publishDir maps to JSON when one of them
closes over `meta`. `nextflow config -o json` then fails, and `nf-core pipelines
    lint` aborts on it. Use one map whose `saveAs` routes each file instead. See
`MITOHIFI_FINALIZE` in `conf/modules.config`.
:::

:::caution[Process selectors have no leading colon]
Write `withName: 'MITOHIFI_MITOHIFI'`, not `withName: '.*:ASSEMBLE_HIFI:MITOHIFI_MITOHIFI'`.
The qualified form does not match when a subworkflow is run on its own under
nf-test, and the config silently stops applying.
:::

## Where to go next

- [Adding a stage](/mitoforge/developer/extending/) — worked example: filling in the ANNOTATE stub
- [Adding an assembler](/mitoforge/developer/adding-an-assembler/)
- [Adding a cluster profile](/mitoforge/developer/adding-a-cluster-profile/)
- [Roadmap](/mitoforge/developer/roadmap/) — what is deliberately not here yet
- [Contributing](/mitoforge/contributing/)
