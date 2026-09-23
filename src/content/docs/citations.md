---
title: "Citations"
---

mitoforge does not assemble anything itself. Every result it gives you was produced by
one of the tools below, and those are the ones to cite.

The exact versions used in your run are in
`results/pipeline_info/mitoforge_software_mqc_versions.yml`. Take the numbers from there
rather than from this page.

## The pipeline

**mitoforge** — Arun Seetharam, Rosen Center for Advanced Computing, Purdue University.
<https://github.com/rcac-bioinformatics/mitoforge>

## The framework

**Nextflow**

> Di Tommaso P, Chatzou M, Floden EW, Barja PP, Palumbo E, Notredame C. Nextflow enables
> reproducible computational workflows. Nat Biotechnol. 2017 Apr 11;35(4):316-319.
> doi: [10.1038/nbt.3820](https://doi.org/10.1038/nbt.3820)

**nf-core** — mitoforge is built on the nf-core template and uses nf-core modules.

> Ewels PA, Peltzer A, Fillinger S, Patel H, Alneberg J, Wilm A, Garcia MU, Di Tommaso P,
> Nahnsen S. The nf-core framework for community-curated bioinformatics pipelines.
> Nat Biotechnol. 2020 Mar;38(3):276-278.
> doi: [10.1038/s41587-020-0439-x](https://doi.org/10.1038/s41587-020-0439-x)

## Assembly and finishing

**MitoHiFi** — assembles HiFi samples, and finishes every sample whatever assembled it.

> Uliano-Silva M, Ferreira JGRN, Krasheninnikova K, Darwin Tree of Life Consortium,
> Formenti G, Abueg L, Torrance J, Myers EW, Durbin R, Blaxter M, McCarthy SA. MitoHiFi:
> a python pipeline for mitochondrial genome assembly from PacBio high fidelity reads.
> BMC Bioinformatics. 2023 Jul 18;24(1):288.
> doi: [10.1186/s12859-023-05385-y](https://doi.org/10.1186/s12859-023-05385-y)

MitoHiFi calls four tools of its own. If you used mitoforge, you used all of them:

**hifiasm** — assembles the baited HiFi reads.

> Cheng H, Concepcion GT, Feng X, Zhang H, Li H. Haplotype-resolved de novo assembly
> using phased assembly graphs with hifiasm. Nat Methods. 2021 Feb;18(2):170-175.
> doi: [10.1038/s41592-020-01056-5](https://doi.org/10.1038/s41592-020-01056-5)

**minimap2** — maps reads to the reference mitogenome to find the mitochondrial ones.

> Li H. Minimap2: pairwise alignment for nucleotide sequences. Bioinformatics.
> 2018 Sep 15;34(18):3094-3100.
> doi: [10.1093/bioinformatics/bty191](https://doi.org/10.1093/bioinformatics/bty191)

**MitoFinder** — annotates the finished mitogenome.

> Allio R, Schomaker-Bastos A, Romiguier J, Prosdocimi F, Nabholz B, Delsuc F.
> MitoFinder: Efficient automated large-scale extraction of mitogenomic data in target
> enrichment phylogenomics. Mol Ecol Resour. 2020 Jul;20(4):892-905.
> doi: [10.1111/1755-0998.13160](https://doi.org/10.1111/1755-0998.13160)

**MAFFT** — aligns the candidate mitogenomes before choosing between them.

> Katoh K, Standley DM. MAFFT multiple sequence alignment software version 7:
> improvements in performance and usability. Mol Biol Evol. 2013 Apr;30(4):772-80.
> doi: [10.1093/molbev/mst010](https://doi.org/10.1093/molbev/mst010)

**CD-HIT** — clusters them.

> Fu L, Niu B, Zhu Z, Wu S, Li W. CD-HIT: accelerated for clustering the next-generation
> sequencing data. Bioinformatics. 2012 Dec 1;28(23):3150-2.
> doi: [10.1093/bioinformatics/bts565](https://doi.org/10.1093/bioinformatics/bts565)

## Short-read assembly

**GetOrganelle** — assembles Illumina samples.

> Jin JJ, Yu WB, Yang JB, Song Y, dePamphilis CW, Yi TS, Li DZ. GetOrganelle: a fast and
> versatile toolkit for accurate de novo assembly of organelle genomes. Genome Biol.
> 2020 Sep 10;21(1):241.
> doi: [10.1186/s13059-020-02154-5](https://doi.org/10.1186/s13059-020-02154-5)

GetOrganelle calls two tools of its own:

**SPAdes** — assembles the baited reads.

> Bankevich A, Nurk S, Antipov D, Gurevich AA, Dvorkin M, Kulikov AS, Lesin VM,
> Nikolenko SI, Pham S, Prjibelski AD, Pyshkin AV, Sirotkin AV, Vyahhi N, Tesler G,
> Alekseyev MA, Pevzner PA. SPAdes: a new genome assembly algorithm and its applications
> to single-cell sequencing. J Comput Biol. 2012 May;19(5):455-77.
> doi: [10.1089/cmb.2012.0021](https://doi.org/10.1089/cmb.2012.0021)

**Bowtie 2** — baits reads against the seed mitogenome.

> Langmead B, Salzberg SL. Fast gapped-read alignment with Bowtie 2. Nat Methods.
> 2012 Mar 4;9(4):357-9.
> doi: [10.1038/nmeth.1923](https://doi.org/10.1038/nmeth.1923)

## Read handling and reporting

**fastp** — trims Illumina adapters and low-quality ends.

> Chen S, Zhou Y, Chen Y, Gu J. fastp: an ultra-fast all-in-one FASTQ preprocessor.
> Bioinformatics. 2018 Sep 1;34(17):i884-i890.
> doi: [10.1093/bioinformatics/bty560](https://doi.org/10.1093/bioinformatics/bty560)

**SAMtools** — converts unaligned PacBio BAM to FASTQ.

> Danecek P, Bonfield JK, Liddle J, Marshall J, Ohan V, Pollard MO, Whitwham A, Keane T,
> McCarthy SA, Davies RM, Li H. Twelve years of SAMtools and BCFtools. Gigascience.
> 2021 Feb 16;10(2):giab008.
> doi: [10.1093/gigascience/giab008](https://doi.org/10.1093/gigascience/giab008)

**MultiQC** — builds the HTML report.

> Ewels P, Magnusson M, Lundin S, Käller M. MultiQC: summarize analysis results for
> multiple tools and samples in a single report. Bioinformatics. 2016 Oct 1;32(19):3047-8.
> doi: [10.1093/bioinformatics/btw354](https://doi.org/10.1093/bioinformatics/btw354)

## Packaging

**Bioconda**

> Grüning B, Dale R, Sjödin A, Chapman BA, Rowe J, Tomkins-Tinch CH, Valieris R,
> Köster J; Bioconda Team. Bioconda: sustainable and comprehensive software distribution
> for the life sciences. Nat Methods. 2018 Jul;15(7):475-476.
> doi: [10.1038/s41592-018-0046-7](https://doi.org/10.1038/s41592-018-0046-7)

**BioContainers**

> da Veiga Leprevost F, Grüning B, Aflitos SA, Röst HL, Uszkoreit J, Barsnes H, Vaudel M,
> Moreno P, Gatto L, Weber J, Bai M, Jimenez RC, Sachsenberg T, Pfeuffer J, Alvarez RV,
> Griss J, Nesvizhskii AI, Perez-Riverol Y. BioContainers: an open-source and
> community-driven framework for software standardization. Bioinformatics.
> 2017 Aug 15;33(16):2580-2582.
> doi: [10.1093/bioinformatics/btx192](https://doi.org/10.1093/bioinformatics/btx192)

**Apptainer / Singularity**

> Kurtzer GM, Sochat V, Bauer MW. Singularity: Scientific containers for mobility of
> compute. PLoS One. 2017 May 11;12(5):e0177459.
> doi: [10.1371/journal.pone.0177459](https://doi.org/10.1371/journal.pone.0177459)

**Docker**

> Merkel D. Docker: lightweight Linux containers for consistent development and
> deployment. Linux Journal. 2014;2014(239):2.

## Test data

The `-profile test` run uses real published data, not simulations:

- **PacBio HiFi** — 100 CCS reads from _Deilephila porcellus_, distributed with MitoHiFi
  as `tests/ilDeiPorc1.reads.100.fa`. Reference: GenBank
  [MW539688.1](https://www.ncbi.nlm.nih.gov/nuccore/MW539688.1), _Theretra latreillii
  lucasii_.
- **Illumina** — the first 250,000 read pairs of SRA run
  [SRR5201683](https://www.ncbi.nlm.nih.gov/sra/SRR5201683), _Myodes glareolus_. This
  reduced set is the one the GetOrganelle authors publish and document. Reference:
  GenBank [PZ790849](https://www.ncbi.nlm.nih.gov/nuccore/PZ790849), _Caryomys eva_.
- **Unaligned PacBio BAM** (unit tests only) — `alz.ccs.bam` from the
  [nf-core test-datasets](https://github.com/nf-core/test-datasets) collection.
