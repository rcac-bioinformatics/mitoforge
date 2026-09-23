---
title: "Adding a cluster profile"
---

mitoforge does not carry its own cluster profiles. It enables
[nf-core/configs](https://github.com/nf-core/configs), so every institutional profile
published there is available by name:

```groovy title="nextflow.config"
includeConfig !System.getenv('NXF_OFFLINE') && params.custom_config_base
    ? "${params.custom_config_base}/nfcore_custom.config"
    : "/dev/null"
```

That is how `-profile purdue_gautschi` works. The config itself lives at
[`conf/purdue_gautschi.config`](https://github.com/nf-core/configs/blob/master/conf/purdue_gautschi.config)
in nf-core/configs, not in this repository.

The advantage is that the cluster's details are maintained in one place by the people
who run it, and every nf-core pipeline gets the same behaviour. The cost is that adding
a cluster means a pull request to another repository.

## Using a cluster that already has a profile

Nothing to do. Check the
[list of institutional profiles](https://nf-co.re/configs) and use the name:

```bash
nextflow run rcac-bioinformatics/mitoforge \
    -profile <institution> \
    --input samplesheet.csv \
    --outdir results
```

Most profiles need something passed in, usually an account. Read the profile's page on
nf-co.re for what it expects.

## Adding a cluster that has no profile

Follow the
[nf-core/configs contributing guide](https://github.com/nf-core/configs/blob/master/README.md).
In outline:

1. Fork nf-core/configs.
2. Write `conf/<institution>.config`. `purdue_gautschi.config` is a reasonable model:
   it sets the executor, derives the partition from each task's memory request, caps
   requests with `process.resourceLimits`, and turns on Apptainer with a cache on
   scratch.
3. Add the profile to `nfcore_custom.config`.
4. Add `docs/<institution>.md`.
5. Open the pull request.

Once it is merged, `-profile <institution>` works in mitoforge with no change here,
because the configs are fetched at launch rather than pinned.

:::note[Testing before it is merged]
Point `custom_config_base` at your fork while you iterate:

```bash
nextflow run . -profile <institution> \
    --custom_config_base https://raw.githubusercontent.com/<you>/configs/<branch> \
    --input samplesheet.csv --outdir results
```

:::

## A local config instead

For a cluster that will never be shared, or for a one-off override, a plain `-c` file
is simpler than a profile and needs no pull request:

```groovy title="mycluster.config"
process {
    executor       = 'slurm'
    queue          = 'compute'
    clusterOptions = { "--account=${params.cluster_account}" }
    resourceLimits = [ cpus: 64, memory: '240.GB', time: '48.h' ]
}

apptainer {
    enabled    = true
    autoMounts = true
    cacheDir   = "${System.getenv('SCRATCH')}/.apptainer/cache"
}
```

```bash
nextflow run . -c mycluster.config --input samplesheet.csv --outdir results
```

`-c` can set anything except pipeline parameters. Those go on the command line or in a
`-params-file`.

## What mitoforge itself still decides

Two things stay here rather than in a cluster profile, because they are about the
pipeline rather than the machine:

- **Resource requests**, as the labels in `conf/base.config`. A cluster profile caps
  them with `resourceLimits`; it does not set them.
- **What each process does**, in `conf/modules.config`: arguments, published outputs,
  and the retry behaviour that lets one failed sample drop out without taking the run
  with it.

## If a step needs the internet

Compute nodes on Gautschi can reach the internet, verified by checking HTTPS to each
host the pipeline actually contacts. Two steps need it:

| Step                         | Contacts                  |
| ---------------------------- | ------------------------- |
| `MITOHIFI_FINDMITOREFERENCE` | `eutils.ncbi.nlm.nih.gov` |
| `GETORGANELLE_CONFIG`        | `gitlab.com`, `gitee.com` |

If you add a cluster whose compute nodes are walled off, pin those two to the login
node in your config:

```groovy
process {
    withName: 'MITOHIFI_FINDMITOREFERENCE' { executor = 'local' }
    withName: 'GETORGANELLE_CONFIG'        { executor = 'local' }
}
```

That only works when Nextflow itself is launched from a login node. A new stage that
reaches the network has to be added to that list as well, which is easy to forget.
