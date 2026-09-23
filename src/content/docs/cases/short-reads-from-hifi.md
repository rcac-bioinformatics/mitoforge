---
title: "Short reads using HiFi mitogenomes"
---

You have a handful of HiFi samples and a lot of Illumina ones, from the same species or
close relatives. The best reference for the Illumina samples is not something from NCBI
, it is the mitogenome you are about to assemble from your own HiFi data.

Write `hifi:<sample>` in `ref_fa` and mitoforge works out the order for you.

## Samplesheet

```csv title="samplesheet.csv"
sample,platform,fastq_1,fastq_2,bam,species,ref_fa,ref_gb,genetic_code
speciesA_hifi,hifi,/data/A.hifi.fastq.gz,,,,/refs/PZ790849.fasta,/refs/PZ790849.gb,2
speciesB_hifi,hifi,/data/B.hifi.fastq.gz,,,,/refs/PZ790849.fasta,/refs/PZ790849.gb,2
A_short_01,illumina,/data/A01_R1.fastq.gz,/data/A01_R2.fastq.gz,,,hifi:speciesA_hifi,,2
A_short_02,illumina,/data/A02_R1.fastq.gz,/data/A02_R2.fastq.gz,,,hifi:speciesA_hifi,,2
B_short_01,illumina,/data/B01_R1.fastq.gz,/data/B01_R2.fastq.gz,,,hifi:speciesB_hifi,,2
```

The rules for `hifi:<sample>`:

- It may only be used on an `illumina` row.
- The sample it names must be a `hifi` row in the same samplesheet.
- `ref_gb` must be empty. The GenBank file comes from that sample's own finished
  mitogenome.
- Many short-read samples may point at the same HiFi sample.

Any of those broken is caught before a single job is submitted, with the row number in
the message.

## Command

```bash
MITOFORGE_ACCOUNT=myaccount bin/run.sh samplesheet.csv purdue_gautschi
```

One command. There is no first pass and second pass to run by hand.

## What happens

```
speciesA_hifi ── MitoHiFi -r ── finishing ──┬── A_short_01 ── GetOrganelle ── finishing
                                            └── A_short_02 ── GetOrganelle ── finishing
speciesB_hifi ── MitoHiFi -r ── finishing ───── B_short_01 ── GetOrganelle ── finishing
```

The Illumina samples wait for the HiFi sample they name to be assembled _and_ finished,
then take its `final_mitogenome.fasta` as their GetOrganelle seed and its
`final_mitogenome.gb` as their annotation reference.

## Expected output

```
sample         platform  genetic_code  reference                length_bp  genes  circular  status
A_short_01     illumina  2             final_mitogenome.fasta   16353      36     True      pass
A_short_02     illumina  2             final_mitogenome.fasta   16353      36     True      pass
B_short_01     illumina  2             final_mitogenome.fasta   16341      36     True      pass
speciesA_hifi  hifi      2             PZ790849.fasta           16353      37     True      pass
speciesB_hifi  hifi      2             PZ790849.fasta           16341      37     True      pass
```

`reference: final_mitogenome.fasta` in the summary is how you can tell a sample used a
HiFi-derived reference rather than a file from the samplesheet.

## Things to know

:::caution[A failed HiFi sample takes its dependants with it]
If `speciesA_hifi` does not finish, `A_short_01` and `A_short_02` have no reference
and never start. They appear in the summary as `failed: no reference`. Fix the HiFi
sample and rerun with `-resume`; everything that already worked is cached.
:::

:::tip[Keep the HiFi samples first in the file]
It makes no difference to the pipeline, the dependency is resolved from the names,
not the order, but it makes the samplesheet much easier for a human to read.
:::

:::note[Why the finishing step runs twice]
Internally the finishing step is invoked once for the HiFi assemblies and once for
the short-read ones, because the short-read assemblies depend on the finished HiFi
ones and a single invocation would be a cycle. Both use the same settings, so every
sample is still finished identically.
:::
