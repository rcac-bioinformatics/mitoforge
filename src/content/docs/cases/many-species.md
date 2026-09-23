---
title: "Many species at once"
---

Nothing in mitoforge assumes your samples are the same species. Reference and genetic
code are per row, so a single samplesheet can mix moths, voles and sea urchins.

## Samplesheet

```csv title="samplesheet.csv"
sample,platform,fastq_1,fastq_2,bam,species,ref_fa,ref_gb,genetic_code
moth01,hifi,/data/moth01.hifi.fastq.gz,,,,/refs/MW539688.1.fasta,/refs/MW539688.1.gb,5
moth02,hifi,/data/moth02.hifi.fastq.gz,,,,/refs/MW539688.1.fasta,/refs/MW539688.1.gb,5
vole01,hifi,/data/vole01.hifi.fastq.gz,,,,/refs/PZ790849.fasta,/refs/PZ790849.gb,2
urchin01,illumina,/data/urchin01_R1.fastq.gz,/data/urchin01_R2.fastq.gz,,Strongylocentrotus purpuratus,,,9
hybrid01,hifi,/data/hybrid01.hifi.fastq.gz,,,,/refs/MW539688.1.fasta,/refs/MW539688.1.gb,5
```

Four species, three genetic codes, two platforms, two ways of naming a reference. All in
one run.

## Command

```bash
MITOFORGE_ACCOUNT=myaccount MITOFORGE_QUEUE=cpu \
    bin/run.sh samplesheet.csv negishi
```

## Getting the genetic code right

This is the one thing that is easy to get wrong and quiet about it. A wrong translation
table does not fail; it gives you an annotation full of internal stop codons.

| Code | Groups                                                                  |
| ---- | ----------------------------------------------------------------------- |
| 2    | Vertebrates: mammals, birds, fish, reptiles, amphibians                 |
| 5    | Most invertebrates: insects, molluscs, crustaceans, annelids, nematodes |
| 9    | Echinoderms and flatworms                                               |

If you are unsure, look the species up in
[NCBI Taxonomy](https://www.ncbi.nlm.nih.gov/taxonomy) — each entry states its
mitochondrial genetic code.

You can set a default for the whole run and only override the exceptions:

```bash
bin/run.sh samplesheet.csv negishi results -- --genetic_code 5
```

Any row with a value in the `genetic_code` column still wins.

## Congeners and hybrids

For the real case this pipeline was built for — three congeneric species plus hybrids,
with one same-genus reference available — point every row at the same reference:

```csv
sample,platform,fastq_1,fastq_2,bam,species,ref_fa,ref_gb,genetic_code
sp1_01,hifi,/data/sp1_01.hifi.fastq.gz,,,,/refs/congener.fasta,/refs/congener.gb,5
sp2_01,hifi,/data/sp2_01.hifi.fastq.gz,,,,/refs/congener.fasta,/refs/congener.gb,5
hyb_01,hifi,/data/hyb_01.hifi.fastq.gz,,,,/refs/congener.fasta,/refs/congener.gb,5
```

A same-genus reference is comfortably close enough for MitoHiFi's bait-and-filter step.
A hybrid's mitogenome is maternally inherited, so it will assemble cleanly against the
maternal species' relative; nothing special is needed.

## Expected output

One row per sample in `results/summary/mitoforge_summary.tsv`, with the `reference` and
`genetic_code` columns showing what each sample actually used. Check those columns
before you trust a hundred annotations:

```bash
cut -f1,3,4,6 results/summary/mitoforge_summary.tsv | column -t
```

## Things to know

:::tip[Sort the summary by gene count to find the odd ones out]
`bash
    sort -t$'\t' -k6,6n results/summary/mitoforge_summary.tsv | column -t -s$'\t'
    `
An animal mitogenome has 36–37 genes. Anything much below that is worth looking at.
:::

:::caution[One reference per row, not per species]
There is no "species group" concept. If twenty samples share a reference, that path
appears twenty times. Generate the samplesheet with a script rather than by hand.
:::
