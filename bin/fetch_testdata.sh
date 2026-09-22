#!/usr/bin/env bash
#
# fetch_testdata.sh -- download the public test data used by `-profile test`.
#
# Everything downloaded here is real, published data. Nothing is generated or
# simulated. The files are small (< 1 MB in total for the HiFi path) but they
# are not committed to the repository, so run this script once after cloning.
#
# Usage:  bin/fetch_testdata.sh [outdir]
#
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTDIR="${1:-${PROJECT_DIR}/testdata}"

MITOHIFI_TESTS="https://raw.githubusercontent.com/marcelauliano/MitoHiFi/master/tests"
NFCORE_TESTS="https://raw.githubusercontent.com/nf-core/test-datasets/modules/data"

mkdir -p "${OUTDIR}/hifi" "${OUTDIR}/contigs" "${OUTDIR}/bam"

fetch() {
    local url="$1" dest="$2"
    if [[ -s "${dest}" ]]; then
        echo "  [skip] $(basename "${dest}") already present"
        return
    fi
    echo "  [get ] $(basename "${dest}")"
    curl -fsSL "${url}" -o "${dest}.part"
    mv "${dest}.part" "${dest}"
}

echo "==> HiFi test data (MitoHiFi shipped test set)"
# 100 PacBio HiFi CCS reads from Deilephila porcellus (elephant hawk-moth),
# distributed with MitoHiFi at tests/ilDeiPorc1.reads.100.fa
fetch "${MITOHIFI_TESTS}/ilDeiPorc1.reads.100.fa" "${OUTDIR}/hifi/ilDeiPorc1.reads.100.fa"
# Close relative reference mitogenome: Theretra latreillii lucasii (Sphingidae),
# GenBank MW539688.1, distributed with MitoHiFi at tests/MW539688.1.{fasta,gb}
fetch "${MITOHIFI_TESTS}/MW539688.1.fasta" "${OUTDIR}/hifi/MW539688.1.fasta"
fetch "${MITOHIFI_TESTS}/MW539688.1.gb" "${OUTDIR}/hifi/MW539688.1.gb"
# The mitogenome MitoHiFi assembles from those reads, shipped alongside them. Used as
# a ready-made input by the unit tests that do not need to run an assembler.
fetch "${MITOHIFI_TESTS}/ilDeiPorc1.final_mitogenome.fasta" "${OUTDIR}/hifi/ilDeiPorc1.final_mitogenome.fasta"

echo
echo "==> Contigs-mode test data (used by the FINALIZE nf-test)"
# The contig and reference pair from MitoHiFi's own documented contigs-mode example:
# Phalera bucephala contig, with Phalera flavescens (NC_016067.1) as the reference.
fetch "${MITOHIFI_TESTS}/ilPhaBuce1_contig.fa" "${OUTDIR}/contigs/ilPhaBuce1_contig.fa"
fetch "${MITOHIFI_TESTS}/NC_016067.1.fasta" "${OUTDIR}/contigs/NC_016067.1.fasta"
fetch "${MITOHIFI_TESTS}/NC_016067.1.gb" "${OUTDIR}/contigs/NC_016067.1.gb"

echo
echo "==> Unaligned PacBio BAM (used by the BAM-to-FASTQ nf-test)"
# A real PacBio CCS unaligned BAM from the nf-core test-datasets collection. It is
# human Iso-Seq, so it is only used to check that reads come out of the right
# samtools channel, never to assemble a mitogenome.
fetch "${NFCORE_TESTS}/genomics/homo_sapiens/pacbio/bam/alz.ccs.bam" "${OUTDIR}/bam/alz.ccs.bam"

echo
echo "==> Writing test samplesheet"
cat > "${OUTDIR}/samplesheet_test.csv" <<EOF
sample,platform,fastq_1,fastq_2,bam,species,ref_fa,ref_gb,genetic_code
ilDeiPorc1,hifi,${OUTDIR}/hifi/ilDeiPorc1.reads.100.fa,,,,${OUTDIR}/hifi/MW539688.1.fasta,${OUTDIR}/hifi/MW539688.1.gb,5
EOF
echo "  ${OUTDIR}/samplesheet_test.csv"

echo
echo "Total size:"
du -sh "${OUTDIR}"
echo
echo "Done. Now run:"
echo "  nextflow run . -profile test,docker --outdir results"
