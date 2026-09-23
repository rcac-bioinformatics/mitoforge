---
title: "Troubleshooting"
---

The things that actually go wrong, and what to do about them.

If a single sample failed rather than the whole run, start with
[When a sample fails](/mitoforge/cases/failed-sample/) instead.

## Pulling containers

Three steps in mitoforge reach the internet:

- `MITOHIFI_FINDMITOREFERENCE`, looks up a reference at NCBI by species name
- `GETORGANELLE_CONFIG`, downloads GetOrganelle's seed and label databases
- pulling the container images themselves

Gautschi's compute nodes can reach the internet, so the first two look after themselves
inside a normal job. The images are the one thing worth doing up front, because every
task needs them and a cold pull of MitoHiFi is several gigabytes.

Do it on an **interactive node**, not a login node. Login nodes are shared and are not
the place to unpack multi-gigabyte images.

```bash
sinteractive -A <account> -N 1 -n 8 -p <partition> -t 2:00:00
```

or:

```bash
salloc --account=<account> --partition=<partition> --nodes=1 --ntasks=8 --time=02:00:00
```

`--partition` is required, on both forms.

### Pre-pulling containers

The easy way is to run the built-in test there. It exercises both the HiFi and the
short-read path, so it pulls everything except the samtools image:

```bash
export APPTAINER_CACHEDIR="$RCAC_SCRATCH/.apptainer/cache"
export NXF_APPTAINER_CACHEDIR="$RCAC_SCRATCH/.apptainer_cache"
bin/fetch_testdata.sh
nextflow run . -profile test,apptainer --outdir test_results
```

Afterwards:

```bash
ls -lh "$NXF_APPTAINER_CACHEDIR"
```

You should see a `.img` or `.sif` for each tool. The MitoHiFi one is around 7 GB.

To pull exactly what _your_ samplesheet needs instead, ask Nextflow which containers it
will use and pull them yourself:

```bash
nextflow inspect . -profile purdue_gautschi \
    --input samplesheet.csv --outdir results \
    --cluster_account myaccount \
    | grep '"container"' | cut -d'"' -f4 | sort -u \
    | while read -r img; do
          case "$img" in
              https://*) apptainer pull --dir "$NXF_APPTAINER_CACHEDIR" "$img" ;;
              *)         apptainer pull --dir "$NXF_APPTAINER_CACHEDIR" "docker://$img" ;;
          esac
      done
```

`nextflow inspect` resolves the workflow and prints every container without running a
single job. Note that `-preview` does **not** do this: it builds the graph but never
touches a registry.

Set `NXF_APPTAINER_CACHEDIR` in your `~/.bashrc` so every run uses the same cache. The
cluster profiles default to `$RCAC_SCRATCH/.apptainer_cache` if you do not set it.

### Symptoms of getting this wrong

```
Failed to pull singularity image
FATAL: Unable to get library client configuration: no authentication token
Error executing process > 'MITOHIFI_MITOHIFI (sampleA)'
```

means the image was not cached and the pull did not succeed from inside the job.
Pre-pull on an interactive node and rerun with `-resume`.

## Apptainer cache problems

**The cache is on a filesystem the compute nodes cannot see.** Put it on scratch, not in
`$HOME` if `$HOME` is not mounted on compute nodes, and never in `/tmp`.

**The cache fills your quota.** The images are several gigabytes together. `$RCAC_SCRATCH`
is the right place.

**`disk quota exceeded` while pulling, even though you set `NXF_APPTAINER_CACHEDIR`.**
There are two caches, and that variable only moves one of them. `NXF_APPTAINER_CACHEDIR`
tells Nextflow where to keep the finished `.img`. Apptainer separately unpacks the
docker layers into its _own_ cache, which defaults to `$HOME/.apptainer/cache`, and on
RCAC that quota is small. A failure ending in `close
/home/<you>/.apptainer/cache/oci-tmp/...: disk quota exceeded` is this. Set both, then
clear what the failed pull left behind:

```bash
export APPTAINER_CACHEDIR="$RCAC_SCRATCH/.apptainer/cache"
export NXF_APPTAINER_CACHEDIR="$RCAC_SCRATCH/.apptainer_cache"
mkdir -p "$APPTAINER_CACHEDIR" "$NXF_APPTAINER_CACHEDIR"

apptainer cache clean --force
rm -rf ~/.apptainer/cache
```

Put both exports in your `~/.bashrc` so this cannot come back. The MitoHiFi image is the
one that usually triggers it: it ships MitoFinder, infernal and tRNAscan-SE.

**Two runs pulling at once corrupt an image.** Apptainer does not lock the cache. If you
see a truncated or unreadable `.sif`, delete it and pull again:

```bash
rm "$NXF_APPTAINER_CACHEDIR/<the-broken-image>"
nextflow run . -profile purdue_gautschi ... -preview
```

**Nothing is being cached at all.** Check the variable is exported, not just set:

```bash
echo "$APPTAINER_CACHEDIR"
echo "$NXF_APPTAINER_CACHEDIR"
```

## Out of memory, out of time

A task killed for memory or time is retried automatically, twice, with every request
multiplied by the attempt number. So a step asking for 64 GB gets 128 GB and then
192 GB before it is given up on.

If a sample still fails after that, raise the ceiling rather than the request. Find out
what it actually used first:

```bash
# open in a browser: per-task peak memory and runtime
results/pipeline_info/execution_report_*.html

# or as text
column -t results/pipeline_info/execution_trace_*.txt
```

Then override the label the process uses:

```bash title="more_memory.config"
process {
    withLabel: process_high {
        memory = { 128.GB * task.attempt }
        time   = { 48.h   * task.attempt }
    }
}
```

```bash
nextflow run . -profile purdue_gautschi -c more_memory.config \
    --input samplesheet.csv --outdir results \
    --cluster_account myaccount -resume
```

Or target one process:

```groovy
process {
    withName: 'MITOHIFI_MITOHIFI' { memory = { 200.GB * task.attempt } }
}
```

The labels are in `conf/base.config`: `process_single`, `process_low`, `process_medium`,
`process_high`. `MITOHIFI_MITOHIFI` and `GETORGANELLE_FROMREADS` are the heavy ones.

:::caution[Asking for more than a node has]
If your partition's nodes are smaller than the request, the job will never schedule
and will sit in the queue forever. Cap it instead:

```groovy
process.resourceLimits = [ cpus: 64, memory: '240.GB', time: '48.h' ]
```

:::

## Gzipped input problems

Different steps have different tolerances, and the errors are not obvious.

**"MitoHiFi requires all inputs to either be uncompressed or compressed!"**

You gave one sample a mix of gzipped and plain read files. Make them consistent.

**"Running Mitohifi in contigs mode requires uncompressed input!"**

This should not happen, the pipeline uncompresses assemblies before the finishing step.
If you see it, please
[open an issue](https://github.com/rcac-bioinformatics/mitoforge/issues).

**Your `.gz` file is not actually gzip.** A file that was decompressed and renamed, or
truncated mid-download:

```bash
gzip -t reads_R1.fastq.gz && echo "fine" || echo "broken"
```

**bgzip versus gzip.** Both work everywhere in this pipeline; if a tool refuses one,
convert:

```bash
zcat reads.fastq.gz | gzip > reads.plain.fastq.gz
```

## `KeyError: 'gene'`

```
File "/opt/MitoHiFi/src/getGenesList.py", line 25, in get_genes_list
    genes.append(feat.qualifiers['gene'][0])
KeyError: 'gene'
```

MitoHiFi reads the `/gene=` qualifier off every CDS feature in your reference GenBank
file. Many real submissions annotate CDS features with `/product=` only, and MitoHiFi
does not fall back to it. It fails on its very last step, after it has already written
the finished mitogenome, so the sample shows up as `failed: finishing` even though the
result is sitting in the work directory.

**Check any reference before you commit to it:**

```bash
grep -c '/gene=' my_reference.gb
```

Greater than zero: fine. Zero: pick a different record.

Two real examples, both _Myodes glareolus_:

```bash
# NC_024538 - RefSeq, no /gene= anywhere. MitoHiFi will fail on it.
# PZ790849  - Caryomys eva, same tribe, 26 /gene= qualifiers. Works.
```

This is a MitoHiFi limitation, not a mitoforge one; it is
[written up for reporting upstream](/mitoforge/developer/roadmap/#worth-reporting-upstream).

## MitoHiFi `-p` tuning

MitoHiFi's `-p` is the percentage of a candidate contig that must match the reference
mitogenome for the contig to be kept. The default is 50. mitoforge exposes it as
`--mitohifi_percent_id`.

```bash
bin/run.sh samplesheet.csv purdue_gautschi results -- --mitohifi_percent_id 70
```

**Raise it** when NUMTs are getting through, extra candidates in
`all_contigs_stats.tsv` that are short, not circular, and missing genes. 70 is a
reasonable first try. This is common in vertebrates, which carry far more nuclear
mitochondrial insertions than insects do; a vertebrate sample that assembles several
"mitogenomes" is usually collecting NUMTs.

**Lower it** when the only reference available is distant and nothing passes the filter
at all, `'parsed_blast.txt' and 'parsed_blast_all.txt' files are empty`. Try 30. Then
check the result carefully: a loose filter is exactly how a NUMT gets chosen as the
answer.

The setting applies to both the assembly and the finishing step.

See [Heteroplasmy and NUMTs](/mitoforge/cases/heteroplasmy-and-numts/) for how to tell whether a
candidate is a NUMT before you start tuning.

## The samplesheet will not validate

Every problem is reported at once, before anything is submitted, with the row number and
the column:

```
ERROR ~ Found 2 problems in the samplesheet:

  - row 3 (sample 'sampleB'): column 'fastq_2' is empty. mitoforge needs paired-end Illumina reads.
  - row 5 (sample 'sampleD'): column 'ref_fa': file not found: /refs/typo.fasta
```

The full rules are in the [samplesheet reference](/mitoforge/samplesheet/#the-rules-in-one-place).

Two that catch people out:

- **`Must be a file path, not a directory`** or **file not found** on a path that looks
  right: check for a trailing space in the cell, and use absolute paths.
- **Windows line endings.** A samplesheet saved from Excel on Windows has `\r` at the
  end of every line, which becomes part of the last column's value.
  ```bash
  sed -i 's/\r$//' samplesheet.csv
  ```

## The cluster profile will not start

```
ERROR ~ The 'purdue_gautschi' profile submits jobs to SLURM and needs an account:

    --cluster_account <allocation>
```

Exactly what it says. Run `slist` on Gautschi to see the accounts you
belong to:

```bash
slist
```

Or set it in the environment and let `bin/run.sh` pass it along:

```bash
export MITOFORGE_ACCOUNT=myaccount
bin/run.sh samplesheet.csv purdue_gautschi
```

## `-resume` is rerunning everything

- **The work directory is gone.** `-resume` needs `work/`. If you deleted it, the cache
  is gone with it.
- **You are running from a different directory.** The cache lives in `work/` relative to
  where you launch Nextflow. Launch from the same place.
- **A file changed.** Nextflow hashes the input files. Touching, re-copying or
  re-downloading a read file invalidates every task that used it.
- **You changed a parameter.** Anything that changes a command line invalidates that
  task and everything after it.

:::note[MultiQC always reruns, and that is normal]
The parameter summary MultiQC embeds contains the run timestamp, so it differs every
time. Everything else caches.
:::

## Warnings you can ignore

```
WARN: Unrecognized config option 'validation.monochromeLogs'
```

nf-schema understands this option; Nextflow 26's config checker does not know about it
yet. Cosmetic.

```
Warning: representative contig wasn't circularized
```

MitoHiFi saying the finishing step found no circular overlap. If the assembly step
already closed and trimmed the circle, there is nothing left for the finishing step to
find. Check the `circular` column in the summary, which takes both steps into account.

## Still stuck

[Open an issue](https://github.com/rcac-bioinformatics/mitoforge/issues) with:

- the command you ran
- `results/summary/mitoforge_summary.tsv`
- `results/pipeline_info/mitoforge_software_mqc_versions.yml`
- the failing task's `.command.sh` and `.command.err`
