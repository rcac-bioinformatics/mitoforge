---
title: "Cases"
---

Each page is a worked example: a samplesheet, a command you can copy, and what you
should see when it works. Find the one that matches your data.

| Your data                                                            | Page                                                                          |
| -------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| HiFi reads, and you want the reference fetched for you               | [HiFi with an NCBI reference](/mitoforge/cases/hifi-ncbi-reference/)          |
| HiFi reads still in the instrument's BAM                             | [HiFi from a PacBio BAM](/mitoforge/cases/hifi-from-bam/)                     |
| Illumina paired-end reads, and a reference you already have          | [Short reads with your own reference](/mitoforge/cases/short-reads/)          |
| Illumina reads from the same species as HiFi samples in the same run | [Short reads using HiFi mitogenomes](/mitoforge/cases/short-reads-from-hifi/) |
| Several species in one run, each with its own reference              | [Many species at once](/mitoforge/cases/many-species/)                        |
| A result you do not trust, or a NUMT you suspect                     | [Heteroplasmy and NUMTs](/mitoforge/cases/heteroplasmy-and-numts/)            |
| No cluster, just your laptop                                         | [On a laptop with Docker](/mitoforge/cases/laptop/)                           |
| A sample that did not finish                                         | [When a sample fails](/mitoforge/cases/failed-sample/)                        |

Every command on these pages assumes you are in the cloned `mitoforge` directory and
that Nextflow is on your PATH. Cluster commands also assume you know your account and
partition; see the [quick start](/mitoforge/quick-start/).
