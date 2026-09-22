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

### Phase 1 - HiFi path: done

Done:

- `INPUT_CHECK` validates the whole samplesheet in one pass and names the row and column for every problem. It covers what the JSON schema cannot: one of fastq_1/bam, platform-specific read layout, a reference or a species, and `hifi:<sample>` pointing at a real hifi row.
- `PREPARE_REFERENCE` resolves a reference from samplesheet files or from a species name via `findMitoReference.py`. `hifi:<sample>` rows come out on a separate `needs_hifi` channel and are wired up in Phase 2.
- `ASSEMBLE_HIFI` runs MitoHiFi `-r`, converting an unaligned PacBio BAM first when needed.
- `FINALIZE` runs MitoHiFi `-c` on every assembly. `ANNOTATE` is the documented pass-through stub.
- `SUMMARY` writes `summary/mitoforge_summary.tsv` and `summary/all_contigs_stats.tsv`, and feeds the summary to MultiQC as custom content. Two local modules: `MITOFORGE_SAMPLE_STATS`, `MITOFORGE_SUMMARY`.
- Outputs land in `results/mitogenomes/<sample>.{fasta,gb,gff}`, `results/samples/<sample>/{reference,assembly,final}/` and `results/summary/`.

Tested:

- `nextflow run . -profile test,docker --outdir results` - green, and the pipeline-level nf-test snapshot is reproducible across runs.
- `nf-test test modules/local subworkflows/local` - 24 tests, all green. Includes real MitoHiFi runs for ASSEMBLE_HIFI and FINALIZE, eight INPUT_CHECK validation cases, and a regression test pinning the samtools-fastq channel that PacBio BAM reads come out of.
- `nf-core pipelines lint` - 0 failures.

Things worth knowing:

- **BAM input.** Records in an unaligned PacBio BAM carry flag 4 and neither READ1 nor READ2, so `samtools fastq` routes every read to the file given to `-0`, which the nf-core module publishes on `other`, not `fastq`. Verified against a real PacBio CCS BAM and pinned by `subworkflows/local/assemble_hifi/tests/samtools_fastq_routing.nf.test`.
- **Circularity.** MitoHiFi `-r` trims the circular overlap, so the later `-c` pass reports `was_circular False` for a mitogenome that really is circular. The summary therefore reports circularity as true if any stage found it.
- **publishDir.** The MitoHiFi module emits `path("*")`, which also matches staged input reads. Every MitoHiFi publishDir names what it wants. `potential_contigs/` is not published because MitoFinder leaves a symlink in it pointing at a path that only existed inside the container; `reads_mapping_and_assembly/` is not published because it is large.
- **Process selectors** in `conf/modules.config` are written `'.*STAGE:PROCESS'` with no leading colon, so they also match when a subworkflow is run on its own under nf-test.
- The finished mitogenome keeps MitoHiFi's contig name in its FASTA header, not the sample name. Noted in docs/developer/roadmap.md.
- The `hifi:<sample>` reference is still unresolved: it validates, and PREPARE_REFERENCE routes it aside, but nothing consumes `needs_hifi` until Phase 2.

### Phase 2 - short-read path: done

Done:

- `ASSEMBLE_SHORT`: optional fastp trimming (`--skip_trimming`), `GETORGANELLE_CONFIG` once per run, `GETORGANELLE_FROMREADS` seeded with the sample's reference, then `GUNZIP` because MitoHiFi cannot read gzipped input in contigs mode.
- `ref_fa: hifi:<sample>` is resolved: those rows wait for the named HiFi sample to be finished, then take its `final_mitogenome.fasta` and `.gb`. `combine(by: 0)`, not `join`, so many short-read samples can share one HiFi reference.
- FINALIZE is invoked twice, as `FINALIZE_HIFI` and `FINALIZE_SHORT`. One invocation over the mixture would be a cycle, because the short-read assemblies depend on the finished HiFi ones. Both are the same subworkflow with the same settings, so every sample is still finished identically.
- Test profile now covers both platforms in one run.

Test data (all real, all fetched by `bin/fetch_testdata.sh`, 50 MB total):

- HiFi: MitoHiFi's shipped _Deilephila porcellus_ reads against MW539688.1, code 5.
- Illumina: the first 250,000 read pairs of SRA run **SRR5201683** (_Myodes glareolus_, bank vole), the reduced set the GetOrganelle authors publish and document, md5-checked against the values in their wiki. Reference **PZ790849** (_Caryomys eva_, same tribe), code 2.
- Why not the bank vole's own RefSeq record NC_024538: it annotates no `/gene=` qualifiers, and MitoHiFi needs them (see below).

Tested:

- `nextflow run . -profile test,docker --outdir results` - green, both platforms.
- `nf-test test` - 27 tests, all green; the pipeline snapshot is reproducible across runs.
- `nf-core pipelines lint` - 0 failures.

Two real bugs found and worked around (both written up in docs/developer/roadmap.md for reporting upstream):

- **The nf-core mitohifi module corrupted upstream work directories.** It staged inputs flat, and MitoHiFi writes `final_mitogenome.fasta` into its working directory. When contigs mode is handed reads mode's output - or when one sample's finished mitogenome is another's reference - the staged symlink has that exact name, and MitoHiFi writes straight through it into the upstream task's work directory. The symptom was a contig name growing an extra `.rotated` on every run. Patched (`modules/nf-core/mitohifi/mitohifi/mitohifi-mitohifi.diff`) to stage into `input/` and `reference/`.
- **MitoHiFi needs `/gene=` on the reference's CDS features.** `getGenesList.py` raises `KeyError: 'gene'` otherwise, on the very last step, after the finished mitogenome has already been written. Many real submissions annotate `/product=` only.

Other things worth knowing:

- `modules/nf-core/getorganelle/fromreads` is patched to take an optional `seed` input, so GetOrganelle can be given `-s <reference>`. The unpatched module has no way to stage a seed file.
- MitoHiFi's contigs mode rejects any assembly shorter than 80% of the reference. A partial short-read assembly therefore fails FINALIZE rather than producing a fragment.
- `nf-test.config` ignores `.venv/**`: the nf-core tools package ships a copy of the pipeline template, complete with its own nf-tests, and nf-test will happily run those from inside a virtualenv in the repo.
- Circularity in the summary is true if any stage reported it: a stats table saying `was_circular True`, or GetOrganelle's `(circular)` marker in the sequence name. Neither finishing pass sees an overlap that the assembler already trimmed.

### Phase 3 - robustness: done

Done:

- **One failed sample never kills the run.** `conf/base.config` retries twice on the exit codes that mean out-of-memory or out-of-time (`task.attempt` scales every request), and otherwise drops the sample and carries on. Run-level processes - `MITOFORGE_SUMMARY`, `MULTIQC` - are set back to `finish`, and `GETORGANELLE_CONFIG` retries then finishes, because every short-read sample depends on that one download.
- **Failed samples are named.** A dropped sample simply stops appearing in the channels downstream of where it failed, so SUMMARY is given the samplesheet plus each stage's output and reconstructs how far each sample got: `failed: no reference`, `failed: assembly`, `failed: finishing`, `failed: reporting`. Every samplesheet row appears in `summary/mitoforge_summary.tsv` whether or not it finished, and `PIPELINE_COMPLETION` prints the failures at the end of the log.
- **Resource labels.** Sized for ~35 Gb HiFi per sample; `MITOHIFI_FINALIZE` is pulled down from `process_high` to 4 CPU / 16 GB because contigs mode only ever handles a finished 16 kb assembly.
- trace, report, timeline and DAG were already on by default.

Output layout changed: the finished mitogenome, GenBank and GFF live only in `results/mitogenomes/<sample>.{fasta,gb,gff}`; `results/samples/<sample>/final/` keeps the working output (stats, plots, `final_mitogenome_choice/`, log). They used to be in both.

Tested:

- `nf-test test` - 29 tests green, including `tests/failed_sample.nf.test`, which gives one sample a moth contig as its HiFi reads and a vole mitogenome as its reference, and checks that the other sample still finishes and the bad one is reported.
- `-resume` verified: a second run caches 10 of 11 tasks. Only MULTIQC re-runs, because the parameter summary it embeds contains `trace_report_suffix`, which is the run timestamp. That is nf-core template behaviour.
- `nf-core pipelines lint` - 0 failures.

Things worth knowing:

- **`publishDir` must be a single map, not a list, wherever a closure mentions `meta`.** Nextflow 26 cannot render a list of publishDir maps to JSON when one of them closes over `meta`, so `nextflow config -o json` fails and `nf-core pipelines lint` aborts on it. `MITOHIFI_FINALIZE` therefore uses one publishDir rooted at `params.outdir` whose `saveAs` routes each file, rather than two entries.
- `errorStrategy` closures and `meta` inside a single publishDir map are both fine.

### Phase 4 - docs: done

Done:

- MkDocs Material site in `docs/`, `mkdocs.yml` in the repo root, deployed to GitHub Pages by `.github/workflows/docs.yml`. The build runs with `--strict` on pull requests too, so a broken internal link or a page missing from the nav fails before merge.
- Pages: quick start (five commands for Negishi), samplesheet reference (every column, every rule), eight case pages, output reference (every file), troubleshooting, citations, and a four-page developer guide.
- `assets/samplesheet_example.csv` is a real, copyable starting point covering all five ways of specifying a row.
- `docs/usage.md` and `docs/README.md` are kept because nf-core lint wants them; `usage.md` is now an index into the site, and `README.md` is excluded from the built site (it would collide with `index.md`).

Corrected while writing the docs:

- **`-preview` does not pull containers.** It builds the DAG and stops. The pre-pull advice is therefore to run `-profile test,apptainer` on the login node, which exercises both paths and pulls everything except the samtools image, or to use `nextflow inspect` and `apptainer pull` for exactly what a given samplesheet needs.
- `assets/samplesheet_example.csv` cannot be used as a real `--input`: its paths are placeholders and nf-schema checks that files exist.

Tested:

- `mkdocs build --strict` with anchor and link validation on - clean.
- `nf-core pipelines lint` - 0 failures, warnings down to 10.
- `nextflow run . -profile test,docker` - still green.
