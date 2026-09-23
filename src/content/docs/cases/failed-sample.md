---
title: "When a sample fails"
---

One failed sample never stops the run. The others finish, and the failed one is named in
the summary and in the log:

```
WARN: 1 of 24 samples did not finish:
    sampleQ  failed: assembly

The rest finished; their mitogenomes are in results/mitogenomes/
Full table: results/summary/mitoforge_summary.tsv
```

## Step 1: read the status

```bash
awk -F'\t' '$9 != "pass"' results/summary/mitoforge_summary.tsv | column -t -s$'\t'
```

The `status` column says where the sample stopped. Each value points at a different
place to look.

## `failed: no reference`

No reference could be found for this sample.

**If the row used `species`:** the NCBI lookup failed or returned nothing long enough.

```bash
# What did it actually look for?
grep -r "findMitoReference" .nextflow.log | head
```

- Check the spelling of the scientific name. Synonyms and common names will not match.
- Lower `--min_ref_length` if the group only has partial mitogenomes deposited:
  `-- --min_ref_length 12000`
- If you see a network error rather than a "no reference found" one, NCBI was
  unreachable or rate-limiting. See
  [Troubleshooting](/mitoforge/troubleshooting/#pulling-containers).
- Most reliable fix: download a reference yourself and use `ref_fa` + `ref_gb`.

**If the row used `hifi:<sample>`:** the HiFi sample it depends on failed. Fix that
sample first; these will follow.

## `failed: assembly`

The assembler ran and produced nothing usable. This is the most common failure, and it
is almost always about the reads or the reference.

```bash
# HiFi
less results/samples/sampleQ/assembly/sampleQ.log
# Illumina
less results/samples/sampleQ/assembly/sampleQ.get_org.log.txt
```

**For HiFi**, look for how many reads mapped:

```
Total number of mapped reads: 0
```

Zero or very few means the reference is too distant, or the reads are not from the
species you think. Try a closer reference. If the only available relative really is
distant, loosen the filter:

```bash
bin/run.sh samplesheet.csv purdue_gautschi results -- --mitohifi_percent_id 30
```

**For Illumina**, look for the coverage estimate:

```
Estimated animal_mt-hitting base-coverage = 12.5
```

Below about 30 there is not enough mitochondrial sequence to assemble from. You need
more reads from that library, subsampling will not help.

Also look for:

```
Disentangling unsuccessful: 'Multiple isolated animal_mt components detected!'
Result status of animal_mt: 2 scaffold(s)
```

That is a fragmented assembly, and the finishing step rejects anything shorter than 80%
of the reference rather than handing you a fragment. More reads, or a closer seed
reference, are the fixes.

If GetOrganelle's log shows it finished without ever reporting a coverage estimate, it
found nothing to extend. On a row whose `ref_fa` is `hifi:<sample>`, check how closely
related that HiFi sample actually is. The finished mitogenome is the bait, so pairing a
library with a sample from another order leaves nothing to catch and the assembler
exits without writing a thing. See
[Short reads using HiFi mitogenomes](/mitoforge/cases/short-reads-from-hifi/).

## `failed: finishing`

The assembly exists but MitoHiFi could not finish it. The assembly is still there:

```bash
ls results/samples/sampleQ/assembly/
less results/samples/sampleQ/final/sampleQ.log
```

Common causes:

- **`'parsed_blast.txt' files are empty`**: the assembly did not match the reference
  well enough, or is shorter than 80% of it. Check its length against the reference.
- **`KeyError: 'gene'`**: the reference GenBank file has no `/gene=` qualifiers. See
  [Troubleshooting](/mitoforge/troubleshooting/#keyerror-gene). This one is worth checking
  first, because it fails right at the end after everything else worked.

## `failed: reporting`

The mitogenome finished and is in `results/mitogenomes/`. Only the statistics step
failed, which is a bug, please
[open an issue](https://github.com/rcac-bioinformatics/mitoforge/issues) with the
sample's `final/contigs_stats.tsv` attached.

## Step 2: find the actual error

Every failure has a work directory with the exact command and its output:

```bash
grep -B2 -A20 "Error executing process.*sampleQ" .nextflow.log | head -40
```

That prints the work directory. Go and look:

```bash
cd work/ab/cdef12.../
cat .command.sh     # exactly what was run
cat .command.err    # what it said
cat .command.log    # everything it said
bash .command.run   # run it again by hand, interactively
```

## Step 3: fix and rerun

```bash
bin/run.sh samplesheet.csv purdue_gautschi
```

`bin/run.sh` always passes `-resume`. Everything that worked is cached; only the fixed
samples run again.

:::tip[Rerunning one sample on its own]
Put that one row in its own samplesheet and give it a different `--outdir`. It will
still reuse the cache, because the cache is keyed on the task, not the run.
:::

## When a run fails entirely

If the pipeline stops rather than dropping one sample, the failure is run-level, not
sample-level: a bad parameter, a samplesheet that does not validate, an unreachable
container registry, or the GetOrganelle database download failing three times. Those
are in [Troubleshooting](/mitoforge/troubleshooting/).
