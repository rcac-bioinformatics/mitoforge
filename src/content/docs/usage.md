---
title: "rcac-bioinformatics/mitoforge: Usage"
---

The full documentation is a website: **<https://rcac-bioinformatics.github.io/mitoforge/>**

It is built from this directory, so everything is also here in the repository:

| Page                                         | File                                              |
| -------------------------------------------- | ------------------------------------------------- |
| Quick start: five commands, clone to results | [quick-start.md](/mitoforge/quick-start/)         |
| Samplesheet: every column explained          | [samplesheet.md](/mitoforge/samplesheet/)         |
| Cases: a worked example per kind of input    | [cases/index.md](/mitoforge/cases/)               |
| Output reference: every file, what it means  | [output.md](/mitoforge/output/)                   |
| Troubleshooting                              | [troubleshooting.md](/mitoforge/troubleshooting/) |
| Citations                                    | [citations.md](/mitoforge/citations/)             |
| Developer guide                              | [developer/index.md](/mitoforge/developer/)       |

## The short version

```bash
git clone https://github.com/rcac-bioinformatics/mitoforge.git
cd mitoforge
cp assets/samplesheet_example.csv samplesheet.csv    # then edit it
MITOFORGE_ACCOUNT=myaccount bin/run.sh samplesheet.csv purdue_gautschi
column -t -s$'\t' results/summary/mitoforge_summary.tsv
```

On a laptop with Docker:

```bash
bin/run.sh samplesheet.csv docker
```

## Parameters

Every parameter is documented in `nextflow_schema.json` and printed by:

```bash
nextflow run . --help
nextflow run . --help_full     # including the hidden ones
```

:::note
Pass pipeline parameters on the command line or with `-params-file`. A config file
given with `-c` can set anything _except_ parameters.
:::

## Reproducing a run

Two files in `results/pipeline_info/` are what you need:

- `params_*.json`, every parameter the run used
- `mitoforge_software_mqc_versions.yml`, every tool version

Keep both with your results. To rerun with the same settings:

```bash
nextflow run . -profile purdue_gautschi -params-file results/pipeline_info/params_2026-01-01_12-00-00.json
```

Pin the pipeline version too:

```bash
nextflow run rcac-bioinformatics/mitoforge -r v0.1.0 -profile purdue_gautschi ...
```
