#!/usr/bin/env bash
#
# run.sh -- the short way to run mitoforge.
#
# It picks the right container engine for the machine you are on, turns on
# -resume so an interrupted run picks up where it stopped, and writes the
# Nextflow log somewhere you can find it again.
#
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage:
    bin/run.sh <samplesheet.csv> <profile> [outdir]

Arguments:
    samplesheet.csv   Your samples. See
                      https://rcac-bioinformatics.github.io/mitoforge/samplesheet/
    profile           One of: purdue_gautschi, docker, apptainer, test
    outdir            Where results go. Default: results

The purdue_gautschi profile also needs a SLURM account. Give it on the command
line or in the environment:

    MITOFORGE_ACCOUNT=myaccount bin/run.sh samples.csv purdue_gautschi

The partition is chosen from each task's memory request, so there is none to set.

Anything after `--` is passed straight to Nextflow, for example:

    bin/run.sh samples.csv docker results -- --genetic_code 5 -with-report

Examples:
    bin/run.sh samples.csv purdue_gautschi
    bin/run.sh samples.csv docker my_results
USAGE
}

if [[ $# -lt 1 ]] || [[ "${1}" == "-h" ]] || [[ "${1}" == "--help" ]]; then
    usage
    exit 0
fi
if [[ $# -lt 2 ]]; then
    echo "ERROR: need both a samplesheet and a profile." >&2
    echo >&2
    usage
    exit 1
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SAMPLESHEET="$1"; shift
PROFILE="$1"; shift
OUTDIR="results"
if [[ $# -gt 0 && "$1" != "--" ]]; then
    OUTDIR="$1"; shift
fi
if [[ ${1:-} == "--" ]]; then
    shift
fi
EXTRA=("$@")

if [[ ! -f "${SAMPLESHEET}" ]]; then
    echo "ERROR: samplesheet not found: ${SAMPLESHEET}" >&2
    exit 1
fi
SAMPLESHEET="$(cd "$(dirname "${SAMPLESHEET}")" && pwd)/$(basename "${SAMPLESHEET}")"

# Pick a container engine to pair with the chosen profile.
case "${PROFILE}" in
    purdue_gautschi)
        # The nf-core institutional config already turns Apptainer on.
        PROFILES="${PROFILE}"
        ;;
    docker|apptainer|singularity|podman)
        PROFILES="${PROFILE}"
        ;;
    test)
        if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
            PROFILES="test,docker"
        elif command -v apptainer >/dev/null 2>&1; then
            PROFILES="test,apptainer"
        else
            echo "ERROR: -profile test needs either Docker or Apptainer, and neither was found." >&2
            exit 1
        fi
        ;;
    *)
        echo "ERROR: unknown profile '${PROFILE}'." >&2
        echo "       Use one of: purdue_gautschi, docker, apptainer, test" >&2
        exit 1
        ;;
esac

ARGS=(run "${PROJECT_DIR}" -profile "${PROFILES}" --input "${SAMPLESHEET}" --outdir "${OUTDIR}" -resume)

case "${PROFILE}" in
    purdue_gautschi)
        if [[ -n "${MITOFORGE_ACCOUNT:-}" ]]; then
            ARGS+=(--cluster_account "${MITOFORGE_ACCOUNT}")
        fi
        ;;
esac

if [[ ${#EXTRA[@]} -gt 0 ]]; then
    ARGS+=("${EXTRA[@]}")
fi

mkdir -p "${OUTDIR}/pipeline_info"
export NXF_LOG_FILE="${OUTDIR}/pipeline_info/nextflow.log"

echo "+ nextflow ${ARGS[*]}"
exec nextflow "${ARGS[@]}"
