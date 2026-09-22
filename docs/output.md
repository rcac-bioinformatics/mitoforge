# Output reference

Everything mitoforge writes, and what it means. This is the tree from a run with one
HiFi sample (`ilDeiPorc1`) and one Illumina sample (`SRR5201683`).

```
results/
├── mitogenomes/
│   ├── ilDeiPorc1.fasta
│   ├── ilDeiPorc1.gb
│   ├── SRR5201683.fasta
│   └── SRR5201683.gb
├── summary/
│   ├── mitoforge_summary.tsv
│   ├── all_contigs_stats.tsv
│   └── mitoforge_summary_mqc.tsv
├── samples/
│   ├── ilDeiPorc1/
│   │   ├── assembly/
│   │   └── final/
│   └── SRR5201683/
│       ├── trimming/
│       ├── assembly/
│       └── final/
│   (a sample whose row used `species` also has a reference/ directory here)
├── multiqc/
│   ├── multiqc_report.html
│   ├── multiqc_data/
│   └── multiqc_plots/
└── pipeline_info/
```

## `mitogenomes/` — the answer

This is what you came for. One set of files per sample, named after the sample.

| File             | What it is                                                                                          |
| ---------------- | --------------------------------------------------------------------------------------------------- |
| `<sample>.fasta` | The finished mitogenome: circularised where possible, overlap trimmed, rotated to start at tRNA-Phe |
| `<sample>.gb`    | Its annotation, in GenBank format. This is what you submit or load into a genome browser            |
| `<sample>.gff`   | The same annotation in GFF, when MitoHiFi produces one. Often absent                                |

!!! note "The FASTA header is not the sample name"
It is the contig name MitoHiFi gave it, something like
`>ptg000001l.rc.rotated_rotated`. Rename it yourself if you are about to build a
phylogeny from a hundred of these:

    ```bash
    for f in results/mitogenomes/*.fasta; do
        s=$(basename "$f" .fasta)
        sed "1s/.*/>$s/" "$f" > "renamed/$s.fasta"
    done
    ```

## `summary/` — how the run went

### `mitoforge_summary.tsv`

One row per samplesheet row, whether or not it finished. Read this first.

| Column         | Meaning                                                                                    |
| -------------- | ------------------------------------------------------------------------------------------ |
| `sample`       | From the samplesheet                                                                       |
| `platform`     | `hifi` or `illumina`                                                                       |
| `genetic_code` | The NCBI translation table used to annotate it                                             |
| `reference`    | Which reference it was compared against. A file name, `species:<name>`, or `hifi:<sample>` |
| `length_bp`    | Length of the finished mitogenome                                                          |
| `genes`        | How many genes were annotated. An animal mitogenome usually has 36–37                      |
| `circular`     | `True` if any step found and closed a circular overlap                                     |
| `frameshifts`  | Genes MitoHiFi flagged as having a frameshift, or `No frameshift found`                    |
| `status`       | `pass`, or `failed: <where it stopped>`                                                    |

```
sample      platform  genetic_code  reference         length_bp  genes  circular  frameshifts          status
SRR5201683  illumina  2             PZ790849.fasta    16353      36     True      No frameshift found  pass
ilDeiPorc1  hifi      5             MW539688.1.fasta  15316      36     True      COX1                 pass
```

The `status` values for a sample that did not finish are:

| Status                 | What happened                                                        |
| ---------------------- | -------------------------------------------------------------------- |
| `failed: no reference` | No reference could be found or fetched for it                        |
| `failed: assembly`     | The assembler produced nothing usable                                |
| `failed: finishing`    | It assembled, but MitoHiFi could not finish it                       |
| `failed: reporting`    | It finished, but the statistics step failed. The mitogenome is there |

[When a sample fails](cases/failed-sample.md) says what to do about each.

!!! info "`circular` is true if _any_ step found it"
MitoHiFi's reads mode trims the circular overlap, so by the time the finishing step
sees the sequence there is no overlap left and its own table says `False`. The
summary therefore reports circularity from the assembly step too, and from
GetOrganelle's `(circular)` marker.

### `all_contigs_stats.tsv`

MitoHiFi's own per-contig table for every sample, stacked, with `sample` and `stage`
columns in front.

| Column                                          | Meaning                                                          |
| ----------------------------------------------- | ---------------------------------------------------------------- |
| `sample`                                        | Which sample this row belongs to                                 |
| `stage`                                         | `assembly` (MitoHiFi reads mode) or `final` (the finishing step) |
| `contig_id`                                     | The contig. `final_mitogenome` is the one that was chosen        |
| `frameshifts_found`                             | Genes with a frameshift in this contig                           |
| `annotation_file`                               | The GenBank file the annotation went into                        |
| `length(bp)`, `number_of_genes`, `was_circular` | As reported by MitoHiFi for this contig                          |

The `assembly` rows are the interesting ones: they list the candidates that were
_not_ chosen, which is where NUMTs and heteroplasmic variants show up. See
[Heteroplasmy and NUMTs](cases/heteroplasmy-and-numts.md).

### `mitoforge_summary_mqc.tsv`

The same table with a header MultiQC understands. Not for you; it is what puts the
summary at the top of the MultiQC report.

## `samples/<sample>/` — the working output

### `trimming/` (Illumina only)

fastp's reports. Absent if you ran with `--skip_trimming`.

| File                  | What it is                                            |
| --------------------- | ----------------------------------------------------- |
| `<sample>.fastp.html` | Read quality before and after trimming, as a web page |
| `<sample>.fastp.json` | The same numbers as data. Also fed to MultiQC         |
| `<sample>.fastp.log`  | fastp's console output                                |

The trimmed reads themselves are not published. They are large and nothing downstream
needs them again; they are in the Nextflow work directory if you want them.

### `reference/` (only when the row used `species`)

The mitogenome `findMitoReference.py` fetched from NCBI for this sample, as
`<accession>.fasta` and `<accession>.gb`. Keep these: they are what makes the run
reproducible, because a lookup repeated next year may return a different record.

Rows that named `ref_fa` and `ref_gb` themselves have no `reference/` directory — you
already have those files.

### `assembly/` — what the assembler produced

For a **HiFi** sample, this is MitoHiFi's reads-mode output:

| File                                                 | What it is                                                                                      |
| ---------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `final_mitogenome.fasta`, `.gb`                      | MitoHiFi's answer **before** the finishing step. Not the same file as the one in `mitogenomes/` |
| `all_potential_contigs.fa`                           | Every contig that looked mitochondrial. Where NUMTs live                                        |
| `contigs_stats.tsv`                                  | Per-contig statistics                                                                           |
| `shared_genes.tsv`                                   | Which genes this assembly shares with the reference                                             |
| `contigs_annotations.png`                            | The annotated candidates, drawn                                                                 |
| `final_mitogenome.annotation.png`                    | The chosen mitogenome, drawn                                                                    |
| `coverage_plot.png`, `final_mitogenome.coverage.png` | Read depth along the contigs                                                                    |
| `final_mitogenome_choice/`                           | The alignment and clustering used to pick between candidates                                    |
| `contigs_circularization/`                           | The circularisation check, per contig                                                           |
| `contigs_filtering/`                                 | The BLAST output used to decide what was mitochondrial                                          |
| `coverage_mapping/`                                  | Working files for the coverage plots                                                            |
| `<sample>.log`                                       | MitoHiFi's full log. Start here when a sample fails                                             |

For an **Illumina** sample, this is GetOrganelle's output:

| File                                       | What it is                                                                                                  |
| ------------------------------------------ | ----------------------------------------------------------------------------------------------------------- |
| `<sample>.animal_mt.fasta.gz`              | The assembled mitogenome, gzipped. A name containing `(circular)` means GetOrganelle closed the circle      |
| `<sample>.animal_mt.K*.selected_graph.gfa` | The assembly graph, for opening in [Bandage](https://rrwick.github.io/Bandage/) when the result looks wrong |
| `<sample>.get_org.log.txt`                 | GetOrganelle's full log                                                                                     |

GetOrganelle's extended read files are not published; they are large and are in the work
directory.

### `final/` — the finishing step

MitoHiFi contigs mode, run on whatever the assembler produced. Same files as the HiFi
`assembly/` directory above, minus the mitogenome itself — that lives in
`mitogenomes/<sample>.fasta` instead of being written twice.

| File                                                                  | What it is                                  |
| --------------------------------------------------------------------- | ------------------------------------------- |
| `contigs_stats.tsv`                                                   | Statistics for the finished mitogenome      |
| `shared_genes.tsv`                                                    | Gene content compared against the reference |
| `final_mitogenome_choice/`                                            | Which candidate was chosen, and why         |
| `contigs_circularization/`, `contigs_filtering/`, `coverage_mapping/` | Working files                               |
| `*.png`                                                               | Annotation drawings                         |
| `<sample>.log`                                                        | MitoHiFi's log for the finishing step       |

!!! info "Two directories MitoHiFi writes that are not published"
`potential_contigs/` holds MitoFinder's per-contig working directories, one of which
contains a symlink into a path that only existed inside the container - nothing can
copy it out. `reads_mapping_and_assembly/` holds hifiasm intermediates and is large
on a real sample. Both are in the Nextflow work directory if you need them.

## `multiqc/`

| File                  | What it is                                                                                     |
| --------------------- | ---------------------------------------------------------------------------------------------- |
| `multiqc_report.html` | The run as a web page: the mitoforge summary table, fastp read quality, and every tool version |
| `multiqc_data/`       | The numbers behind the report, as text                                                         |
| `multiqc_plots/`      | Each plot as PNG, PDF and SVG                                                                  |

## `pipeline_info/`

| File                                  | What it is                                                                 |
| ------------------------------------- | -------------------------------------------------------------------------- |
| `execution_report_*.html`             | Per-task CPU, memory, and time. Read this before asking for more resources |
| `execution_timeline_*.html`           | What ran when, and for how long                                            |
| `execution_trace_*.txt`               | The same as a table, one row per task                                      |
| `pipeline_dag_*.html`                 | The workflow graph                                                         |
| `mitoforge_software_mqc_versions.yml` | Every tool version used. Put this in your methods section                  |
| `params_*.json`                       | Every parameter the run used. Keep it with your results                    |
