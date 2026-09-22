# mitoforge

Assemble, circularise and annotate animal mitochondrial genomes from PacBio HiFi or
Illumina paired-end reads, for many samples at once.

You write one samplesheet. You get one finished mitogenome per sample, annotated,
circularised and rotated to start at tRNA-Phe, plus a table telling you how each sample
went.

## What it does

```
samplesheet.csv
      │
      ├── HiFi samples ─────── MitoHiFi -r ────┐
      │                                        │
      └── Illumina samples ─── GetOrganelle ───┤
                                               │
                              MitoHiFi -c (the finishing step)
                                               │
                              results/mitogenomes/<sample>.fasta
                              results/summary/mitoforge_summary.tsv
```

Whichever route a sample took, it goes through the same finishing step, so every sample
ends up with the same files in the same places.

## Where to go next

<div class="grid cards" markdown>

- **[Quick start](quick-start.md)** — five commands, from clone to results.
- **[Samplesheet](samplesheet.md)** — every column, what it means, what is required.
- **[Cases](cases/index.md)** — a worked example for each kind of input, with the
  command to copy.
- **[Output reference](output.md)** — every file the pipeline writes, and what it means.
- **[Troubleshooting](troubleshooting.md)** — the things that actually go wrong.
- **[Citations](citations.md)** — the tools mitoforge wraps. Please cite them.

</div>

## What it is built on

mitoforge does not assemble anything itself. It wraps
[MitoHiFi](https://github.com/marcelauliano/MitoHiFi) and
[GetOrganelle](https://github.com/Kinggerm/GetOrganelle), and everything those two call
in turn, in a Nextflow pipeline built on the [nf-core](https://nf-co.re) template. All
of it runs in pinned containers, so a run on your laptop and a run on the cluster use
exactly the same software.

## Where it runs

| Where                              | Profile                    | Container engine |
| ---------------------------------- | -------------------------- | ---------------- |
| Negishi, Bell, Anvil (Purdue RCAC) | `negishi`, `bell`, `anvil` | Apptainer        |
| Your laptop                        | `docker`                   | Docker           |

!!! warning "The cluster profiles are untested on cluster"
They were written from documentation on a machine with no SLURM. They should work,
and the design is conservative, but you are the first person to run them. Please
[open an issue](https://github.com/rcac-bioinformatics/mitoforge/issues) with
anything that does not.

## Getting help

- Something went wrong: start with [Troubleshooting](troubleshooting.md) and
  [When a sample fails](cases/failed-sample.md).
- Something is missing or broken:
  [open an issue](https://github.com/rcac-bioinformatics/mitoforge/issues).
- You are at Purdue: mitoforge is maintained by Arun Seetharam at RCAC.
