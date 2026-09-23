---
title: "Heteroplasmy and NUMTs"
---

mitoforge gives you one mitogenome per sample. Sometimes that is a simplification: the
assembler saw more than one candidate and had to choose. This page is about looking at
what it chose between.

Two things cause extra candidates:

- **NUMTs**: nuclear copies of mitochondrial sequence. Real DNA, wrong compartment.
- **Heteroplasmy**: genuinely different mitochondrial haplotypes in the same
  individual.

## Where to look

### 1. The stacked contig table

```bash
column -t -s$'\t' results/summary/all_contigs_stats.tsv
```

The rows with `stage: assembly` are the candidates the assembler found. The rows with
`stage: final` are what survived the finishing step. A sample with several `assembly`
rows had a choice to make:

```
sample      stage     contig_id         length(bp)  number_of_genes  was_circular
sampleA     assembly  final_mitogenome  15316       36               True
sampleA     assembly  ptg000001l        15316       36               True
sampleA     assembly  ptg000014l         8800       19               False
sampleA     final     final_mitogenome  15316       36               False
```

`ptg000014l` there, short, half the genes, not circular, is what a NUMT looks like.

### 2. `final_mitogenome_choice/`

```bash
ls results/samples/sampleA/final/final_mitogenome_choice/
# all_mitogenomes.rotated.fa          every candidate, rotated to the same start
# all_mitogenomes.rotated.aligned.aln the MAFFT alignment of them
# cdhit.out                           the clustering
# cdhit.out.clstr                     which candidate represents which cluster
```

This is MitoHiFi's working: it rotates every candidate to a common start, aligns them,
clusters them with CD-HIT, and takes the representative of the largest cluster.

```bash
# How many candidates were there?
grep -c '^>' results/samples/sampleA/final/final_mitogenome_choice/all_mitogenomes.rotated.fa

# How were they clustered?
cat results/samples/sampleA/final/final_mitogenome_choice/cdhit.out.clstr
```

**More than one cluster is the signal worth chasing.** Two clusters that are each
full-length, circular and fully annotated are a heteroplasmy candidate. A second cluster
that is short and partly annotated is a NUMT that got through.

### 3. `all_potential_contigs.fa`

```bash
grep '^>' results/samples/sampleA/assembly/all_potential_contigs.fa
```

Every contig MitoHiFi thought might be mitochondrial, before filtering. The widest net.

### 4. The coverage plots

```
results/samples/sampleA/assembly/coverage_plot.png
results/samples/sampleA/assembly/final_mitogenome.coverage.png
```

A true mitogenome has high, even coverage, often hundreds of times the nuclear depth. A
NUMT sits at roughly nuclear depth. A heteroplasmic variant sits somewhere in between,
consistently across its whole length. A coverage plot with a step change in the middle
usually means two things have been joined that should not have been.

## Telling them apart

|                                       | NUMT                                                      | Heteroplasmy                                             |
| ------------------------------------- | --------------------------------------------------------- | -------------------------------------------------------- |
| Length                                | Usually partial                                           | Usually full-length                                      |
| Coverage                              | Around nuclear depth                                      | Between nuclear and mitochondrial, even along its length |
| Circular                              | No                                                        | Often yes                                                |
| Gene content                          | Fragmentary, often with frameshifts                       | Complete, 36–37 genes                                    |
| Divergence from the chosen mitogenome | Can be several percent: NUMTs stop evolving once inserted | Usually well under one percent                           |

## Making MitoHiFi stricter

If NUMTs keep getting through, raise the fraction of a contig that must match the
reference:

```bash
bin/run.sh samplesheet.csv purdue_gautschi results -- --mitohifi_percent_id 70
```

This is MitoHiFi's `-p`. The default is 50. See
[Troubleshooting](/mitoforge/troubleshooting/#mitohifi-p-tuning).

## What mitoforge does not do

It does not quantify heteroplasmy. There is no variant caller and no allele-frequency
table. What it gives you is the evidence, the candidates, the alignment, the coverage ,
so you can decide whether the question is worth a dedicated tool. This is
[noted in the roadmap](/mitoforge/developer/roadmap/) as a possible future addition.
