---
title: "HiFi from a PacBio BAM"
---

PacBio instruments hand you an unaligned BAM, not FASTQ. mitoforge takes it as-is.

## Samplesheet

```csv title="samplesheet.csv"
sample,platform,fastq_1,fastq_2,bam,species,ref_fa,ref_gb,genetic_code
ilDeiPorc1,hifi,,,/data/m64094_230101_120000.hifi_reads.bam,,/refs/MW539688.1.fasta,/refs/MW539688.1.gb,5
```

`bam` filled in, `fastq_1` and `fastq_2` empty. It is an error to fill in both `bam` and
`fastq_1`.

## Command

```bash
MITOFORGE_ACCOUNT=myaccount bin/run.sh samplesheet.csv purdue_gautschi
```

## What happens

`samtools fastq` converts the BAM first, then everything proceeds exactly as for FASTQ
input. The conversion is an intermediate step and is not published.

:::note[Why this is less obvious than it looks]
Records in an unaligned PacBio BAM carry flag 4 and neither the READ1 nor the READ2
flag. `samtools fastq` sends exactly those records to the file given to `-0`, not to
the `-1`/`-2` files you would expect. mitoforge takes its reads from there. There is
a regression test pinning this down, because if samtools ever changes it, MitoHiFi
would silently be handed an empty read set.
:::

## Expected output

Identical to [HiFi with an NCBI reference](/mitoforge/cases/hifi-ncbi-reference/). There is no trace of
the BAM in `results/`; the sample looks the same as one given as FASTQ.

## Things to know

:::caution[It must be an unaligned BAM]
The BAM your instrument produced, or a `ccs`/`extracthifi` output. An aligned BAM
will mostly work, because `samtools fastq` still extracts the sequences, but any
secondary or supplementary alignments will come through as duplicate reads.
:::

:::tip[Several BAMs for one sample]
Merge them first with `samtools merge`, or convert them yourself and point
`fastq_1` at a single FASTQ. The samplesheet takes one file per row.
:::
