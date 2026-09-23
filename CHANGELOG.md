# rcac-bioinformatics/mitoforge: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### `Changed`

- **Cluster profiles now come from nf-core/configs.** The hand-written `negishi`,
  `bell` and `anvil` profiles are gone, replaced by `-profile purdue_gautschi`, which
  is maintained at
  [nf-core/configs](https://github.com/nf-core/configs/blob/master/conf/purdue_gautschi.config)
  by the people who run the cluster. It routes each task to `cpu` or `highmem` from its
  memory request, so `--cluster_queue` no longer exists; `--cluster_account` is still
  required.
- Documentation moved from MkDocs to Astro Starlight, with syntax highlighting on every
  code block and an explicit internal link check in CI.

### `Fixed`

- All 33 admonitions had been rendering as empty title-only boxes since v0.1.0, with
  their body text spilled out underneath. Prettier stripped the four-space indentation
  that MkDocs Material requires. They render correctly under Starlight.

### `Notes`

- Compute nodes on Gautschi reach the internet, checked against every host the pipeline
  contacts: `eutils.ncbi.nlm.nih.gov`, `gitlab.com`, `quay.io`, `ghcr.io` and
  `depot.galaxyproject.org`. The v0.1.0 profiles assumed otherwise and pinned two steps
  to the login node. `purdue_gautschi` does not, so a run launched from inside a batch
  job works.

## v0.1.0 - 2026-09-22

First release. Assembles, circularises and annotates animal mitochondrial genomes from
PacBio HiFi or Illumina paired-end reads, many samples at a time.

### `Added`

- **HiFi path.** MitoHiFi in reads mode, with unaligned PacBio BAM input converted first.
- **Short-read path.** fastp trimming, then GetOrganelle seeded with the sample's own
  reference mitogenome.
- **One finishing step for every sample**, whatever assembled it: MitoHiFi in contigs
  mode circularises, trims the overlap, rotates to tRNA-Phe and annotates. That is what
  makes the output identical across platforms.
- **Reference handling.** Per sample, from files in the samplesheet, from a species name
  looked up at NCBI, or - written as `ref_fa: hifi:<sample>` - from another sample's
  finished mitogenome. The pipeline works out the order itself.
- **Samplesheet validation** that checks the whole sheet in one pass, before any job is
  submitted, naming the row and the column for every problem it finds.
- **Run summary.** `summary/mitoforge_summary.tsv` has one row per samplesheet row
  whether or not it finished; `summary/all_contigs_stats.tsv` stacks every candidate
  contig from every sample, from both the assembly and the finishing step. Both are also
  in the MultiQC report.
- **One failed sample never kills the run.** Out-of-memory and out-of-time failures are
  retried with more of everything; anything else drops that sample and carries on. The
  summary and the end of the log say which samples did not finish and where they
  stopped.
- **`ANNOTATE` stub**, skipped by default, so a standalone annotator can be dropped in
  without touching anything around it.
- **Profiles** for Negishi, Bell and Anvil (SLURM and Apptainer), plus Docker,
  Singularity, Podman and Apptainer on their own. The NCBI lookup and the GetOrganelle
  database download are pinned to the login node, because RCAC compute nodes have no
  internet.
- **`bin/run.sh`**, a one-line way to run the pipeline, and **`bin/fetch_testdata.sh`**,
  which fetches the real public data the test profile uses.
- **Test profile** covering both platforms with real published data: MitoHiFi's
  _Deilephila porcellus_ HiFi reads, and the first 250,000 read pairs of SRA run
  SRR5201683 (_Myodes glareolus_).
- **29 nf-test cases**, including real assemblies for both platforms, eight samplesheet
  validation cases, the `hifi:<sample>` dependency, and a case that proves one failing
  sample does not take the run with it.
- **Documentation site** at <https://rcac-bioinformatics.github.io/mitoforge/>.

### `Fixed`

Two bugs in the wrapped tooling, worked around here and
[written up for reporting upstream](https://rcac-bioinformatics.github.io/mitoforge/developer/roadmap/#worth-reporting-upstream):

- The nf-core `mitohifi/mitohifi` module staged its inputs flat, next to where MitoHiFi
  writes `final_mitogenome.fasta`. When contigs mode is handed reads mode's output, or
  one sample's mitogenome is another's reference, MitoHiFi wrote straight through the
  staged symlink and corrupted the upstream task's work directory. mitoforge patches the
  module to stage into `input/` and `reference/`.
- `modules/nf-core/getorganelle/fromreads` has no way to stage a seed file. mitoforge
  patches it to take an optional `seed` input so GetOrganelle can be given `-s`.

### `Known issues`

- The `negishi`, `bell` and `anvil` profiles are **untested on cluster**. They were
  written from documentation on a machine with no SLURM.
- MitoHiFi fails on its last step if the reference GenBank file has no `/gene=`
  qualifiers on its CDS features, which many real submissions do not. Check with
  `grep -c '/gene=' reference.gb` before committing to a reference. See the
  [troubleshooting page](https://rcac-bioinformatics.github.io/mitoforge/troubleshooting/#keyerror-gene).
- MitoHiFi's contigs mode rejects any assembly shorter than 80% of the reference, so a
  fragmented short-read assembly fails rather than producing a partial mitogenome.
- The finished mitogenome keeps the contig name MitoHiFi gave it in its FASTA header,
  not the sample name.
- `nextflow run` prints `WARN: Unrecognized config option 'validation.monochromeLogs'`.
  nf-schema understands the option; Nextflow 26's config checker does not know about it
  yet. Cosmetic.

### `Dependencies`

| Tool         | Version   |
| ------------ | --------- |
| Nextflow     | >=25.10.4 |
| MitoHiFi     | 3.2.3     |
| GetOrganelle | 1.7.7.1   |
| fastp        | 1.3.6     |
| SAMtools     | 1.24      |
| MultiQC      | 1.35      |

Every run writes the exact versions it used to
`results/pipeline_info/mitoforge_software_mqc_versions.yml`.
