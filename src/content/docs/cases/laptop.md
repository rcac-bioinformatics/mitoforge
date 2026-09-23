---
title: "On a laptop with Docker"
---

Everything mitoforge does runs in containers, so a laptop works exactly like the
cluster. The only differences are the profile name and how much patience you need.

## What you need

- **Docker**, running. `docker info` should print without an error.
- **Java 17 or newer** and **Nextflow 25.10.4 or newer**.
- **Disk.** The MitoHiFi container alone is about 7 GB, and the work directory holds
  every intermediate. Budget 30 GB, more for real samples.
- **Memory.** `conf/base.config` asks for up to 64 GB for the heavy steps. On a smaller
  machine, cap it, see below.

## Install Nextflow

```bash
curl -s https://get.nextflow.io | bash
sudo mv nextflow /usr/local/bin/      # or anywhere on your PATH
nextflow -version
```

## Run the built-in test first

```bash
git clone https://github.com/rcac-bioinformatics/mitoforge.git
cd mitoforge
bin/fetch_testdata.sh
nextflow run . -profile test,docker --outdir test_results
```

About 50 MB of real public data is downloaded, and the run takes a few minutes once the
containers are pulled. It assembles a moth mitogenome from PacBio HiFi reads and a bank
vole mitogenome from Illumina reads. When it finishes:

```bash
column -t -s$'\t' test_results/summary/mitoforge_summary.tsv
```

```
sample      platform  genetic_code  reference         length_bp  genes  circular  status
SRR5201683  illumina  2             PZ790849.fasta    16353      36     True      pass
ilDeiPorc1  hifi      5             MW539688.1.fasta  15316      36     True      pass
```

## Your own data

```bash
bin/run.sh samplesheet.csv docker
```

or the long form:

```bash
nextflow run . -profile docker --input samplesheet.csv --outdir results -resume
```

## Capping resources on a small machine

`conf/base.config` is sized for a cluster node. On a laptop, put a ceiling on it:

```bash title="laptop.config"
process {
    resourceLimits = [
        cpus:   8,
        memory: '24.GB',
        time:   '12.h'
    ]
}
```

```bash
nextflow run . -profile docker -c laptop.config \
    --input samplesheet.csv --outdir results -resume
```

`resourceLimits` caps requests without changing them, so a process asking for 64 GB gets
24 GB instead of failing to schedule.

## Things to know

:::caution[A real HiFi sample is not a laptop job]
The test data is 100 reads. A real sample is ~35 Gb of HiFi, and MitoHiFi maps all
of it against the reference before assembling. That is hours on a laptop and days
for a batch. Use a laptop to check your samplesheet and your references; use the
cluster for the run.
:::

:::tip[File ownership]
The `docker` profile runs containers as your own user (`-u $(id -u):$(id -g)`), so
output files belong to you and not to root.
:::

:::note[Apple Silicon and other arm64 machines]
The MitoHiFi container is published for amd64 only. On arm64 it has to run under
emulation:

    ```bash
    nextflow run . -profile docker,emulate_amd64 --input samplesheet.csv --outdir results
    ```

:::

    Emulated, MitoHiFi runs several times slower than native. It is fine for the test
    profile and for checking a samplesheet; it is not a way to process real samples.

:::tip[Reclaiming disk]
The work directory is where everything goes. Once you have your results:

    ```bash
    nextflow clean -f -before $(nextflow log -q | tail -1)   # keep only the last run
    rm -rf work                                              # or just delete it
    ```

:::

    Deleting `work/` means the next run cannot use `-resume`.
