# Quick start

From nothing to finished mitogenomes on **Negishi**, in five commands. Bell and Anvil
are the same with a different profile name.

## Before you start

You need Nextflow 25.10.4 or newer on your PATH. RCAC provides it as a module; find the
right name with:

```bash
module spider nextflow
```

You also need to know two things about your allocation:

```bash
slist        # which accounts you belong to  -> --cluster_account
sinfo -s     # which partitions you can use  -> --cluster_queue
```

## The five commands

```bash
# 1. Get the pipeline
git clone https://github.com/rcac-bioinformatics/mitoforge.git
cd mitoforge

# 2. On the LOGIN NODE, run the built-in test. This pulls every container into a
#    shared cache and proves the install works. Compute nodes have no internet.
export NXF_APPTAINER_CACHEDIR="$RCAC_SCRATCH/.apptainer_cache"
bin/fetch_testdata.sh
nextflow run . -profile test,apptainer --outdir test_results

# 3. Write your samplesheet
cp assets/samplesheet_example.csv samplesheet.csv
nano samplesheet.csv

# 4. Run it
MITOFORGE_ACCOUNT=myaccount MITOFORGE_QUEUE=cpu bin/run.sh samplesheet.csv negishi

# 5. Read the summary
column -t -s$'\t' results/summary/mitoforge_summary.tsv
```

!!! tip "Step 2 in plain words"
Compute nodes at RCAC cannot reach the internet, so the container images have to be
in the cache before any job is submitted. The test profile exercises both the HiFi
and the short-read path, so running it on the login node pulls everything you need
and tells you the installation is sound. It downloads about 50 MB of real public
data and takes a few minutes. See
[Troubleshooting](troubleshooting.md#no-internet-on-compute-nodes).

    The one container the test does not pull is samtools, which is only used for BAM
    input. If your samplesheet has a `bam` column filled in, add:

    ```bash
    apptainer pull --dir "$NXF_APPTAINER_CACHEDIR" \
        docker://community.wave.seqera.io/library/htslib_samtools:1.24--d697cfb9dce007cd
    ```

## What step 4 actually runs

`bin/run.sh` is a thin wrapper. It picks `apptainer` to go with a cluster profile,
turns on `-resume`, and puts the Nextflow log somewhere you can find it. The long form
is:

```bash
nextflow run . \
    -profile negishi,apptainer \
    --input samplesheet.csv \
    --outdir results \
    --cluster_account myaccount \
    --cluster_queue cpu \
    -resume
```

Use the long form when you want to add parameters; `bin/run.sh` passes anything after
`--` straight through:

```bash
bin/run.sh samplesheet.csv negishi results -- --genetic_code 5 --skip_trimming
```

## What you get

```
results/
├── mitogenomes/                 one finished mitogenome per sample
│   ├── sampleA.fasta
│   ├── sampleA.gb
│   └── ...
├── summary/
│   ├── mitoforge_summary.tsv    one row per sample: size, genes, circular, status
│   └── all_contigs_stats.tsv    every candidate contig, every sample
├── samples/<sample>/            the working output for each sample
├── multiqc/multiqc_report.html  the summary as a web page
└── pipeline_info/               run reports, timings, software versions
```

Every file is explained in the [output reference](output.md).

## What step 2 actually checks

The test profile assembles a moth mitogenome from PacBio HiFi reads and a bank vole
mitogenome from Illumina reads, both from real published data. When it finishes:

```bash
column -t -s$'\t' test_results/summary/mitoforge_summary.tsv
```

```
sample      platform  genetic_code  reference         length_bp  genes  circular  status
SRR5201683  illumina  2             PZ790849.fasta    16353      36     True      pass
ilDeiPorc1  hifi      5             MW539688.1.fasta  15316      36     True      pass
```

Two `pass` rows means the pipeline is installed correctly, and anything that goes wrong
afterwards is about your data or your settings. On a laptop the same test runs with
`-profile test,docker`.

## Next

- [Write your samplesheet](samplesheet.md)
- [Find the case that matches your data](cases/index.md)
