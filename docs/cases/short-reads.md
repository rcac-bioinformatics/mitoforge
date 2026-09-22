# Short reads with your own reference

Illumina paired-end reads, and a close-relative mitogenome you have already downloaded.
This is the most reproducible way to run mitoforge: nothing about the run depends on
what NCBI holds today.

## Getting a reference

Find one on NCBI and download both formats. For a bank vole, a good choice is a
mitogenome from the same tribe:

```bash
mkdir -p refs
ACC=PZ790849
curl -s "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nuccore&id=${ACC}&rettype=fasta&retmode=text" -o refs/${ACC}.fasta
curl -s "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nuccore&id=${ACC}&rettype=gb&retmode=text"    -o refs/${ACC}.gb

# Check it will work with MitoHiFi: this must print a number greater than zero
grep -c '/gene=' refs/${ACC}.gb
```

If that count is `0`, pick a different record. See
[Troubleshooting](../troubleshooting.md#keyerror-gene).

## Samplesheet

```csv title="samplesheet.csv"
sample,platform,fastq_1,fastq_2,bam,species,ref_fa,ref_gb,genetic_code
voleA,illumina,/data/voleA_R1.fastq.gz,/data/voleA_R2.fastq.gz,,,/refs/PZ790849.fasta,/refs/PZ790849.gb,2
voleB,illumina,/data/voleB_R1.fastq.gz,/data/voleB_R2.fastq.gz,,,/refs/PZ790849.fasta,/refs/PZ790849.gb,2
```

Genetic code 2 because a vole is a vertebrate. Both read files are required.

## Command

```bash
MITOFORGE_ACCOUNT=myaccount MITOFORGE_QUEUE=cpu \
    bin/run.sh samplesheet.csv negishi
```

To skip adapter trimming because your reads are already clean:

```bash
MITOFORGE_ACCOUNT=myaccount MITOFORGE_QUEUE=cpu \
    bin/run.sh samplesheet.csv negishi results -- --skip_trimming
```

## What happens

1. fastp trims adapters and low-quality ends, unless you passed `--skip_trimming`.
2. GetOrganelle downloads its `animal_mt` seed and label databases once for the whole
   run. **This runs on the login node**; compute nodes have no internet.
3. GetOrganelle baits mitochondrial reads out of the library using both its own seed
   database and your reference, extends them, and assembles with SPAdes.
4. The assembly is uncompressed and goes through the same finishing step as the HiFi
   samples.

## Expected output

```
results/mitogenomes/voleA.fasta                          ~16 kb for a rodent
results/mitogenomes/voleA.gb
results/samples/voleA/trimming/voleA.fastp.html
results/samples/voleA/assembly/voleA.animal_mt.fasta.gz
results/samples/voleA/assembly/voleA.get_org.log.txt
results/samples/voleA/final/
```

```
sample  platform  genetic_code  reference       length_bp  genes  circular  status
voleA   illumina  2             PZ790849.fasta  16353      36     True      pass
```

Look for `(circular)` in the name inside `voleA.animal_mt.fasta.gz`: that is
GetOrganelle telling you it closed the circle.

```bash
zcat results/samples/voleA/assembly/voleA.animal_mt.fasta.gz | head -1
# >604-(circular)
```

## Things to know

!!! warning "Short-read assemblies are all-or-nothing"
The finishing step rejects any assembly shorter than 80% of the reference. A
fragmented GetOrganelle result therefore fails outright rather than giving you a
partial mitogenome. If that happens you need more reads, or more mitochondrial
reads — see [When a sample fails](failed-sample.md).

!!! tip "How much data do you need?"
GetOrganelle needs enough mitochondrial reads to reach roughly 50x over 16 kb. In a
whole-genome library that is usually 1–5% of the reads, so a few hundred megabases
of a typical library is often plenty. The `Estimated animal_mt-hitting
    base-coverage` line in `<sample>.get_org.log.txt` tells you what it actually had.
