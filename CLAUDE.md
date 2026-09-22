# CLAUDE.md

## What this repo is

mitoforge: a Nextflow DSL2 pipeline that assembles, circularises, and annotates animal mitochondrial genomes from PacBio HiFi or Illumina paired-end reads, for many samples at once, on Purdue RCAC clusters (SLURM + Apptainer) and on laptops (Docker). Built on the nf-core template. Maintainer: Arun Seetharam, RCAC. Users are novices; favour "one command, get results" over flexibility.

## Non-negotiable rules

- Wrap existing tools, never reimplement. v1 assemblers: MitoHiFi (HiFi, `-r`) and GetOrganelle (short reads). Every assembly goes through FINALIZE (MitoHiFi `-c`) so all samples get identical outputs.
  - Pinned versions come from the nf-core modules: MitoHiFi **3.2.3** (`ghcr.io/marcelauliano/mitohifi:3.2.3`), GetOrganelle **1.7.7.1**. The original plan said MitoHiFi 3.2.2; the nf-core module pins 3.2.3, and using the nf-core module wins.
- Use nf-core/modules where one exists; write local modules only when none does. Pin every container by tag or digest.
- Channel contract between subworkflows: `tuple val(meta), path(fasta)`. meta has at least `id, platform, ref_fa, ref_gb, genetic_code`. New stages consume and emit this tuple.
- Compute nodes have no internet. Anything that fetches (findMitoReference, container pulls) runs with `executor = 'local'` or is a documented login-node pre-step.
- One failed sample never kills the run. Failed samples are reported in the summary.
- Nothing fabricated: no invented test data, URLs, versions, or accessions. If unsure, say so and stop.
- Do not add features outside the current phase. Put ideas in docs/developer/roadmap.md.

## Layout

- workflows/mitoforge.nf: INPUT_CHECK -> PREPARE_REFERENCE -> ASSEMBLE_HIFI | ASSEMBLE_SHORT -> FINALIZE -> ANNOTATE (stub) -> SUMMARY
- subworkflows/local/: one directory per stage above
- modules/local/: only tools with no nf-core module
- conf/: base.config, test.config, profiles negishi/bell/anvil/docker/apptainer
- bin/run.sh: novice entry point
- docs/: MkDocs Material, deployed to GitHub Pages
- tests/: nf-test

## Commands

- Test: `nextflow run . -profile test,docker` (or `test,apptainer` on a login node). Must be green before any commit.
- Lint: `nf-core pipelines lint`; pre-commit runs prettier and lint.
- Module tests: `nf-test test modules/ subworkflows/`

## Style

- Nextflow >= 25.10.4. The nf-core 4.1.0 template requires it (`outputDir`, `workflow.output.mode`, topic channels), so the original ">= 24.10" is not achievable without gutting the template. Developed against 26.04.6.
- nf-core conventions for module structure, meta maps, versions.yml, and `publishDir` via modules.config.
- Resource requests via labels in conf/base.config, sized for ~35 Gb HiFi per sample and ~1 Gb nuclear genome.
- Docs pages are copy-paste first: every case page opens with a runnable command.
- Commit per phase with a message that names the phase.

## Current state

Update this section at the end of each phase: what is done, what is tested, what is known broken.

### Phase 0 - scaffold: done

Done:

- nf-core 4.1.0 template, `is_nfcore: false`, org `rcac-bioinformatics`. Pruned: igenomes, fastqc, nf-core configs, rocrate, email, codespaces, vscode, seqera platform, github badges, `conf/test_full.config`, the generated `conf/containers_*.config`, and the nf-core-org-only GitHub workflows.
- `nextflow_schema.json` with all mitoforge params; `assets/schema_input.json` with the nine samplesheet columns.
- `conf/base.config` resource labels; `conf/test.config` capped at 4 CPU / 8 GB; profiles `docker`, `apptainer`, `singularity`, `podman`, `emulate_amd64`, `negishi`, `bell`, `anvil`, `test`.
- `bin/fetch_testdata.sh` downloads the real public test data (~1 MB) that `-profile test` needs. `bin/run.sh` is the novice entry point.
- Pre-commit: prettier, whitespace fixers, seqera nextflow-lint, `nf-core pipelines lint`, and the template's outdir guard. All pass.

Tested on this laptop (x86_64, Docker 26.1.5, Nextflow 26.04.6, nf-core 4.1.0, nf-test 0.9.5):

- `nextflow run . -profile test,docker --outdir results` - green (MultiQC only; the science stages land in Phase 1).
- `nextflow run . --help` - green.
- `nextflow config -profile <negishi|bell|anvil|apptainer>` - all parse.
- `nf-core pipelines lint` - 0 failures.

Known broken / deferred:

- `negishi`, `bell`, `anvil` profiles are **untested on cluster**. No SLURM on this machine. They require `--cluster_account` and `--cluster_queue`; neither partition names nor node sizes are hard-coded, so nothing is guessed.
- `WARN: Unrecognized config option 'validation.monochromeLogs'` on every run. The option is real and honoured by nf-schema 2.5.1; Nextflow 26.04's config-schema validator just does not know about it. Cosmetic.
- `workflows/mitoforge.nf` is still the template body (MultiQC only).
- Lint warnings that stay until later phases: TODOs in `docs/usage.md`, `docs/output.md` (Phase 4) and `CHANGELOG.md` (Phase 5).
