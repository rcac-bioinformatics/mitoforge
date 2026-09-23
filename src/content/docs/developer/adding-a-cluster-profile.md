---
title: "Adding a cluster profile"
---

`conf/negishi.config`, `conf/bell.config` and `conf/anvil.config` are the same file with
a different name. Adding a fourth cluster is copying one and changing what is actually
different.

## Step 1: copy one

```bash
cp conf/negishi.config conf/gilbreth.config
```

## Step 2: edit the header

```groovy
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Gilbreth (Purdue RCAC) profile
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Cluster documentation: https://www.rcac.purdue.edu/knowledge/gilbreth

    STATUS: tested on cluster 2026-05-01 by <name>.
...
*/
```

Say honestly whether it has been run there. "Untested on cluster" is useful information;
a profile that claims to work and does not is worse than no profile.

## Step 3: what actually differs

Most of the file does not change. These are the parts that might:

**The scheduler.** If it is not SLURM:

```groovy
executor {
    name            = 'pbspro'   // or 'lsf', 'sge', ...
    queueSize       = 50
    submitRateLimit = '10 sec'
}

process {
    executor       = 'pbspro'
    queue          = { params.cluster_queue }
    clusterOptions = { "-A ${params.cluster_account}" }
}
```

`clusterOptions` is scheduler-specific. `-A` is SLURM's account flag.

**The container cache.** The default chases `$RCAC_SCRATCH`, then `$SCRATCH`, then
`$HOME`. If your cluster names it something else:

```groovy
apptainer.cacheDir = System.getenv('NXF_APPTAINER_CACHEDIR')
    ?: (System.getenv('MY_SCRATCH') ?: System.getenv('HOME')) + '/.apptainer_cache'
```

It must be on a filesystem the compute nodes can see.

**Node size.** `conf/base.config` asks for up to 16 CPUs and 64 GB, which fits inside a
256 GB node. If your partition is smaller, cap it — do not edit `base.config`:

```groovy
process.resourceLimits = [ cpus: 32, memory: '120.GB', time: '24.h' ]
```

`resourceLimits` clamps requests rather than changing them, so a retry that doubles a
request still schedules.

**Queue limits.** If the scheduler will not take 50 jobs at once, lower `queueSize`.

## Step 4: keep the internet steps local

This part must survive the copy. Compute nodes at RCAC have no route out:

```groovy
process {
    withName: 'MITOHIFI_FINDMITOREFERENCE' {
        executor       = 'local'
        clusterOptions = null
        queue          = null
    }
    withName: 'GETORGANELLE_CONFIG' {
        executor       = 'local'
        clusterOptions = null
        queue          = null
    }
}
```

If your cluster's compute nodes _can_ reach the internet, you may drop this — but
leaving it costs nothing, and both processes are small.

If a future stage needs the network, it has to be added here too. That is the one thing
easy to forget when adding a stage.

## Step 5: register the profile

```groovy title="nextflow.config"
profiles {
    // ...
    negishi   { includeConfig 'conf/negishi.config'   }
    bell      { includeConfig 'conf/bell.config'      }
    anvil     { includeConfig 'conf/anvil.config'     }
    gilbreth  { includeConfig 'conf/gilbreth.config'  }
    test      { includeConfig 'conf/test.config'      }
}
```

And in `validateClusterParams()`, so it demands an account and a partition:

```groovy title="subworkflows/local/utils_nfcore_mitoforge_pipeline/main.nf"
def cluster_profiles = ['negishi', 'bell', 'anvil', 'gilbreth']
```

And in `bin/run.sh`, so the wrapper pairs it with Apptainer:

```bash
case "${PROFILE}" in
    negishi|bell|anvil|gilbreth)
        PROFILES="${PROFILE},apptainer"
        ;;
```

## Step 6: check it parses, then run it

```bash
nextflow config -profile gilbreth .        # does it parse?
nextflow config -o json .                  # can the tooling read it?

# on the login node, pull containers
export NXF_APPTAINER_CACHEDIR="$MY_SCRATCH/.apptainer_cache"
bin/fetch_testdata.sh
nextflow run . -profile test,gilbreth,apptainer --outdir test_results \
    --cluster_account myaccount --cluster_queue standard
```

The test profile is small enough to run on a cluster without wasting an allocation, and
it exercises both the HiFi and the short-read path.

## Step 7: document it

- `docs/quick-start.md` and `docs/index.md` — the table of where it runs
- `docs/troubleshooting.md` — anything cluster-specific, particularly about the cache
- `README.md` if the profile list is in it
- `CLAUDE.md` — whether it has been tested on the cluster

## A GPU cluster

Nothing in mitoforge uses a GPU. MitoHiFi, GetOrganelle and everything they call are
CPU-only. A GPU partition will run it, and waste the GPUs.
