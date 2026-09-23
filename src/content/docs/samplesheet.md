---
title: "Samplesheet"
---

One comma-separated file. One row per sample. This header, exactly:

```csv
sample,platform,fastq_1,fastq_2,bam,species,ref_fa,ref_gb,genetic_code
```

Every column must be present in the header. Most of them may be empty on any given row.

A copyable starting point is in [`assets/samplesheet_example.csv`](https://github.com/rcac-bioinformatics/mitoforge/blob/master/assets/samplesheet_example.csv).

## The columns

### `sample`

**Required.** The name you want your results filed under. No spaces. Must be unique
across the samplesheet.

It becomes the file name of your mitogenome (`results/mitogenomes/<sample>.fasta`) and
the name of its working directory (`results/samples/<sample>/`), so pick something you
will still recognise in six months.

### `platform`

**Required.** Exactly one of:

| Value      | Meaning                   | Assembler            |
| ---------- | ------------------------- | -------------------- |
| `hifi`     | PacBio HiFi reads         | MitoHiFi, reads mode |
| `illumina` | Illumina paired-end reads | GetOrganelle         |

Nothing else is accepted. A typo here fails immediately with a message naming the row.

### `fastq_1`, `fastq_2`

Paths to your reads. Use absolute paths.

- **`hifi`**: put the reads in `fastq_1` and leave `fastq_2` empty. HiFi reads are
  single-ended. FASTA and FASTQ both work, gzipped or not, because MitoHiFi feeds them
  straight to minimap2.
- **`illumina`**: fill in both. mitoforge needs paired-end reads.

Accepted extensions: `.fa`, `.fas`, `.fasta`, `.fna`, `.fq`, `.fastq`, optionally with
`.gz`.

### `bam`

An **unaligned** PacBio BAM, as the instrument produces it, instead of `fastq_1`. Only
for `hifi` rows. See [HiFi from a PacBio BAM](/mitoforge/cases/hifi-from-bam/).

:::note[Exactly one of `fastq_1` or `bam`]
Give the reads one way or the other. Both empty, or both filled in, is an error.
:::

### `species`

A scientific name, e.g. `Deilephila porcellus`. Used to look up a close-relative
mitogenome at NCBI with MitoHiFi's `findMitoReference.py`.

Fill this in **or** `ref_fa` + `ref_gb`. If you give both, the files win.

:::caution[This one reaches the internet]
On the cluster profiles the lookup is pinned to the login node, because compute
nodes have no route out. It still means your run depends on NCBI being up and on
what NCBI happens to hold today. If you want a run you can reproduce exactly, fetch
the reference once and use `ref_fa` + `ref_gb` instead.
:::

### `ref_fa`, `ref_gb`

A close-relative mitogenome, as a FASTA and the matching GenBank flat file. Both, or
neither. `ref_gb` is where the gene annotation comes from, so a FASTA on its own is not
enough.

Accepted extensions: `.fa`, `.fas`, `.fasta`, `.fna` (optionally `.gz`) for `ref_fa`;
`.gb`, `.gbk`, `.gbff`, `.genbank` for `ref_gb`.

`ref_fa` also accepts one special value:

```
hifi:<sample>
```

meaning "use the finished mitogenome of that sample in this samplesheet". The named
sample must be a `hifi` row, `ref_gb` must be empty (the GenBank file comes from that
sample too), and only `illumina` rows may use it. mitoforge works out the order for
you: the HiFi samples are assembled and finished first, and the short-read samples that
point at them wait. See
[Short reads using HiFi mitogenomes](/mitoforge/cases/short-reads-from-hifi/).

:::danger[Not every GenBank file works]
MitoHiFi reads the `/gene=` qualifier off every CDS in your `ref_gb`. Plenty of real
submissions annotate CDS features with `/product=` only, and MitoHiFi then fails on
its very last step. Check before you commit to a reference:

```bash
grep -c '/gene=' my_reference.gb    # must be greater than 0
```

:::

    See [Troubleshooting](/mitoforge/troubleshooting/#keyerror-gene).

### `genetic_code`

The NCBI translation table used to annotate this sample. Leave it empty to use
`--genetic_code`, which defaults to **2**.

| Code | Use it for                                                                     |
| ---- | ------------------------------------------------------------------------------ |
| 2    | Vertebrate mitochondrial: mammals, birds, fish, reptiles, amphibians           |
| 5    | Invertebrate mitochondrial: insects, molluscs, crustaceans, most invertebrates |
| 9    | Echinoderm and flatworm mitochondrial                                          |

Codes 1, 3, 4, 6, 10–14, 16, 21–25 are also accepted. Getting this wrong does not stop
the run; it gives you an annotation full of spurious stop codons.

## The rules, in one place

A row is rejected if:

- `sample` is missing, has a space in it, or repeats an earlier row
- `platform` is anything other than `hifi` or `illumina`
- neither `fastq_1` nor `bam` is filled in, or both are
- an `illumina` row has `bam` filled in, or has `fastq_1` without `fastq_2`
- a `hifi` row has `fastq_2` filled in
- neither `species` nor `ref_fa` is filled in
- `ref_fa` is given without `ref_gb` (except for `hifi:<sample>`)
- `ref_gb` is given without `ref_fa`
- a file named in any column does not exist
- `hifi:<sample>` names a sample that is not in the sheet, or is not a `hifi` row
- `hifi:<sample>` is used on a `hifi` row, or alongside a `ref_gb`

Every problem in the sheet is reported at once, before any job is submitted, and each
message names the row number and the column:

```
ERROR ~ Found 2 problems in the samplesheet:

  - row 3 (sample 'sampleB'): column 'fastq_2' is empty. mitoforge needs paired-end Illumina reads.
  - row 5 (sample 'sampleD'): column 'ref_fa': 'hifi:sampleZ' names sample 'sampleZ', which is not in this samplesheet.
```

## Worked examples

```csv title="HiFi, reference fetched from NCBI by species name"
sample,platform,fastq_1,fastq_2,bam,species,ref_fa,ref_gb,genetic_code
ilDeiPorc1,hifi,/data/ilDeiPorc1.hifi.fastq.gz,,,Deilephila porcellus,,,5
```

```csv title="HiFi, reference you downloaded yourself"
sample,platform,fastq_1,fastq_2,bam,species,ref_fa,ref_gb,genetic_code
ilDeiPorc1,hifi,/data/ilDeiPorc1.hifi.fastq.gz,,,,/refs/MW539688.1.fasta,/refs/MW539688.1.gb,5
```

```csv title="Illumina, and a second Illumina sample using the first HiFi sample's result"
sample,platform,fastq_1,fastq_2,bam,species,ref_fa,ref_gb,genetic_code
voleA,hifi,/data/voleA.hifi.fastq.gz,,,,/refs/PZ790849.fasta,/refs/PZ790849.gb,2
voleB,illumina,/data/voleB_R1.fastq.gz,/data/voleB_R2.fastq.gz,,,hifi:voleA,,2
voleC,illumina,/data/voleC_R1.fastq.gz,/data/voleC_R2.fastq.gz,,,hifi:voleA,,2
```

More in [Cases](/mitoforge/cases/).
