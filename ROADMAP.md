You are setting up a new Nextflow pipeline repository from scratch. Work autonomously through the phases below, committing after each phase with a clear message. Only stop to ask me if you hit a genuine blocker (missing credentials, a tool that cannot be installed here, or an ambiguity that changes the architecture). Report a short summary at the end of each phase and continue.

## Context
- Repo name: mitoforge. GitHub org: rcac-bioinformatics. MIT license. Author: Arun Seetharam, RCAC, Purdue University.
- Purpose: assemble, circularise, and annotate animal mitochondrial genomes from either PacBio HiFi reads or Illumina paired-end short reads, for many samples at once, on Purdue RCAC clusters (Negishi, Bell, Anvil) using SLURM and Apptainer. Must also run on a laptop with Docker for testing.
- Primary users are novices: graduate students and postdocs who have used a terminal but never written Nextflow. Every design choice should favour "copy one command, get results" over flexibility.
- First real use case: 23 HiFi samples (~35x, ~1 Gb genome, three congeneric species plus hybrids, one same-genus NCBI reference) and 78 Illumina samples that will use the HiFi-derived mitogenomes as references.
- Future extension: a gene prediction / annotation stage will be added later. Design for it now (see Architecture), do not implement it.

## Environment

I am on a laptop Linux x86_64, Intel Core Ultra 7 155H (16 cores / 22 threads), 96 GB RAM, Docker installed and running. There is no SLURM here. Develop and test everything locally with -profile test,docker. Cluster profiles (negishi, bell, anvil) are written from documentation and cannot be executed here; mark them "untested on cluster" in CLAUDE.md.

Setup you may do yourself: create a .venv (or use uv) for nf-core tools, pre-commit, and mkdocs; install Java 17+ and Nextflow >= 24.10 (SDKMAN or Homebrew); install nf-test via its official installer. Do not install bioinformatics tools natively; they run in pinned containers only. If a container is amd64-only and this machine is arm64, set the Docker platform explicitly and note the performance cost in the docs.

Test data: use MitoHiFi's shipped test reads (tests/ilDeiPorc1.reads.100.fa, Deilephila porcellus) for the HiFi path. For the short-read path, find a real, small, public Illumina paired-end dataset from ENA or SRA with a known mitogenome, subsample it to under 50 MB per file with seqtk, and record the accession and subsampling command in conf/test.config and docs. Keep total test data under 200 MB; fetch it in a setup script rather than committing large files. Never fabricate reads or references.

Cap test-profile resources at 4 CPUs and 8 GB per process so the test runs in minutes. Everything must be green under -profile test,docker before each phase commit.

## Non-negotiable design rules
1. Nextflow DSL2, Nextflow >= 24.10. Use the nf-core pipeline template (`nf-core pipelines create`) and prune what is not needed. Use nf-core/modules where they exist (mitohifi/mitohifi, mitohifi/findmitoreference, getorganelle/*, samtools/fastq, seqkit/*); write local modules only where no nf-core module exists. Pin every container by tag or digest.
2. Wrap existing tools, never reimplement them. v1 assemblers: MitoHiFi v3.2.2 for HiFi (`-r` mode), GetOrganelle for short reads (`-F animal_mt`, seeded with a user-supplied or HiFi-derived reference). No other assemblers in v1; expose `--short_assembler` and `--long_assembler` params with a single allowed value each so more can be added later.
3. Every assembly, regardless of platform, passes through one FINALIZE step (MitoHiFi `-c` mode) so all samples get identical circularisation, rotation to tRNA-Phe, annotation, and stats.
4. Channel contract between subworkflows is always `tuple val(meta), path(fasta)` where meta contains at least `id`, `platform` (hifi|illumina), `ref_fa`, `ref_gb`, `genetic_code`. New stages must be addable by consuming this tuple.
5. Parameter validation with nf-schema: a bad samplesheet or missing param must fail fast with a human-readable message naming the row and column. `nextflow run . --help` must work.
6. Compute nodes have no internet. Reference fetching (findMitoReference.py) and container pulls run on the login node: the reference fetch process is tagged with `executor = 'local'` in the cluster profiles, and docs show pre-pulling containers to a cache.
7. One failed sample never kills the run (`errorStrategy 'ignore'` with a retry on memory/time failures first). Failed samples are listed in the final summary.
8. Nothing fabricated: no invented test data, no placeholder URLs, no fake tool versions. If a public test dataset is needed, find a real one, cite its accession, and subsample it.

## Architecture
```
workflows/mitoforge.nf                 # top level: INPUT_CHECK -> PREPARE_REFERENCE -> ASSEMBLE_HIFI | ASSEMBLE_SHORT -> FINALIZE -> [ANNOTATE stub] -> SUMMARY
subworkflows/local/input_check          # samplesheet -> meta map
subworkflows/local/prepare_reference    # per-sample ref: user FASTA+GB, or findMitoReference by species, or another sample's finalised mitogenome (for the short-read-uses-HiFi-reference case)
subworkflows/local/assemble_hifi        # optional BAM->FASTQ, MitoHiFi -r
subworkflows/local/assemble_short       # optional trimming (fastp), GetOrganelle
subworkflows/local/finalize             # MitoHiFi -c on every assembly
subworkflows/local/annotate             # STUB: takes [meta, fasta], emits it unchanged, gated by --skip_annotation (default true). Document in docs/developer/extending.md how to fill it in.
subworkflows/local/summary              # all_contigs_stats.tsv across samples, per-sample pass/fail, MultiQC-style HTML report if cheap, otherwise a clean markdown/TSV summary
```
Samplesheet columns: `sample,platform,fastq_1,fastq_2,bam,species,ref_fa,ref_gb,genetic_code`. Exactly one of (fastq_1 | bam) is required per row; `ref_fa`+`ref_gb` OR `species` is required; `ref_fa` may also be the string `hifi:<sample_id>` meaning "use that sample's finalised mitogenome", which creates a dependency the workflow must honour. Default genetic_code 2.

## Phases
Phase 0. Scaffold. Create the repo from the nf-core template, prune unused template parts, set up nextflow_schema.json, conf/base.config, conf/test.config, profiles: docker, apptainer, negishi, bell, anvil (SLURM; account and queue as params with clear errors if unset), test. Add `bin/run.sh` that takes a samplesheet and a profile name and runs the pipeline with sensible defaults. Pre-commit with nf-core lint and prettier. Commit.

Phase 1. HiFi path. INPUT_CHECK, PREPARE_REFERENCE, ASSEMBLE_HIFI, FINALIZE, SUMMARY. Must pass `-profile test,docker` (or test,apptainer if Docker is unavailable here) using MitoHiFi's shipped test reads. Add nf-test for each module and the subworkflow. Commit.

Phase 2. Short-read path. ASSEMBLE_SHORT with GetOrganelle, including the `hifi:<sample>` reference dependency. Add a real, small public paired-end test dataset (state the accession in conf/test.config). Test profile now covers both platforms in one run. Commit.

Phase 3. Robustness. Retry logic, resource labels sized for ~35 Gb HiFi per sample and ~1 Gb genome, per-sample failure reporting, `-resume` verified, trace/report/timeline on by default. Commit.

Phase 4. Docs. MkDocs Material site in docs/, deployable to GitHub Pages via Actions:
- Quick start (five commands, from clone to results, for Negishi)
- Samplesheet reference with every column explained
- Cases, each with a full copy-paste command and expected outputs: (a) HiFi only with NCBI reference, (b) HiFi from PacBio BAM, (c) short reads only with user reference, (d) mixed: short reads using HiFi-derived references, (e) multiple species with per-sample references, (f) inspecting heteroplasmy and NUMT contigs in final_mitogenome_choice/, (g) running on a laptop with Docker, (h) what to do when a sample fails
- Output reference (every file, what it means)
- Troubleshooting (no internet on compute nodes, Apptainer cache, memory failures, gz input issues, MitoHiFi -p tuning for vertebrates)
- Developer guide: adding a stage (worked example: filling in the ANNOTATE stub), adding an assembler, adding a cluster profile
- Citation page listing every wrapped tool
Commit.

Phase 5. CI and release. GitHub Actions: nf-core lint, nf-test on test profile with Docker, docs deploy. CHANGELOG.md, CITATION.cff, release v0.1.0 tag. Commit.

## Working rules
- Before writing any module, check nf-core/modules for an existing one and use it.
- Run the test profile after every phase; do not proceed on a red test.
- Keep README.md short: what it does, one command to run, link to docs.
- Do not add features I did not list. Note ideas in docs/developer/roadmap.md instead.
