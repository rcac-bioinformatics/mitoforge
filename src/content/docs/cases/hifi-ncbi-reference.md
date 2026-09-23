---
title: "HiFi with an NCBI reference"
---

The simplest case: you have PacBio HiFi reads and you know what the animal is. mitoforge
asks NCBI for the closest mitogenome it can find and assembles against that.

## Samplesheet

```csv title="samplesheet.csv"
sample,platform,fastq_1,fastq_2,bam,species,ref_fa,ref_gb,genetic_code
ilDeiPorc1,hifi,/data/ilDeiPorc1.hifi.fastq.gz,,,Deilephila porcellus,,,5
ilDeiPorc2,hifi,/data/ilDeiPorc2.hifi.fastq.gz,,,Deilephila porcellus,,,5
```

`species` filled in, `ref_fa` and `ref_gb` empty. Genetic code 5 because a hawk-moth is
an invertebrate.

## Command

```bash
MITOFORGE_ACCOUNT=myaccount MITOFORGE_QUEUE=cpu \
    bin/run.sh samplesheet.csv negishi
```

## What happens

1. `findMitoReference.py` looks up `Deilephila porcellus` at NCBI, takes the nearest
   available mitogenome of at least `--min_ref_length` bases (14,000 by default), and
   downloads it as FASTA and GenBank. **This runs on the login node**, because compute
   nodes have no internet.
2. MitoHiFi maps the reads to that reference with minimap2, throws away anything longer
   than the reference — that is the NUMT filter — and assembles the rest with hifiasm.
3. The assembly goes through the finishing step: circularise, trim the overlap, rotate
   to tRNA-Phe, annotate.

## Expected output

```
results/mitogenomes/ilDeiPorc1.fasta      ~15-17 kb for a lepidopteran
results/mitogenomes/ilDeiPorc1.gb
results/samples/ilDeiPorc1/reference/     the mitogenome NCBI gave you
results/summary/mitoforge_summary.tsv
```

```
sample      platform  genetic_code  reference       length_bp  genes  circular  status
ilDeiPorc1  hifi      5             OQ694980.1.fasta  15316    36     True      pass
```

36 or 37 genes and `circular: True` is a good result.

## Things to know

:::caution[The reference you get today may not be the reference you get next year]
`findMitoReference.py` searches NCBI live. As more mitogenomes are deposited, the
nearest relative changes, and so does your reference. If you need a run you can
reproduce exactly, download the reference once and name it in `ref_fa` and `ref_gb`
instead — see [Short reads with your own reference](/mitoforge/cases/short-reads/) for the shape.
:::

:::tip[Check the reference before you trust the result]
`results/summary/mitoforge_summary.tsv` names the reference each sample used. If it
is something surprisingly distant, raise `--min_ref_length` or supply your own.
:::

:::danger[Some NCBI records make MitoHiFi fail at the last step]
MitoHiFi needs `/gene=` qualifiers on the reference's CDS features. Many records
only have `/product=`. If a sample fails right at the end, see
[Troubleshooting](/mitoforge/troubleshooting/#keyerror-gene).
:::
