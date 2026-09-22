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
GETORGANELLE_GALLERY="https://raw.githubusercontent.com/Kinggerm/GetOrganelleGallery/master/Test/reads"
NCBI_EFETCH="https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nuccore&retmode=text"

mkdir -p "${OUTDIR}/hifi" "${OUTDIR}/contigs" "${OUTDIR}/bam" "${OUTDIR}/illumina"

fetch() {
    local url="$1" dest="$2" want_md5="${3:-}"
    if [[ -s "${dest}" ]]; then
        echo "  [skip] $(basename "${dest}") already present"
        return
    fi
    echo "  [get ] $(basename "${dest}")"
    curl -fsSL "${url}" -o "${dest}.part"
    if [[ -n "${want_md5}" ]]; then
        local got_md5
        got_md5=$(md5sum "${dest}.part" | cut -d" " -f1)
        if [[ "${got_md5}" != "${want_md5}" ]]; then
            rm -f "${dest}.part"
            echo "  ERROR: checksum mismatch for $(basename "${dest}")" >&2
            echo "         expected ${want_md5}, got ${got_md5}" >&2
            exit 1
        fi
    fi
    mv "${dest}.part" "${dest}"
}

# Pull a single record from NCBI nucleotide in both FASTA and GenBank form.
fetch_ncbi() {
    local accession="$1" dir="$2"
    fetch "${NCBI_EFETCH}&id=${accession}&rettype=fasta" "${dir}/${accession}.fasta"
    fetch "${NCBI_EFETCH}&id=${accession}&rettype=gb"    "${dir}/${accession}.gb"
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
echo "==> Illumina test data"
# The first 250,000 read pairs of SRA run SRR5201683, a whole-genome shotgun library
# from Myodes glareolus (bank vole). This reduced set is the one the GetOrganelle
# authors publish and document as their animal mitogenome example; they made it with
#
#     fastq-dump --origfmt --split-files -X 250000 --gzip SRR5201683
#
# The checksums below are the ones published in the GetOrganelle wiki. About 50 Mb of
# bases in total, which is enough for a complete circular mitogenome.
fetch "${GETORGANELLE_GALLERY}/SRR5201683_1.fastq.gz" "${OUTDIR}/illumina/SRR5201683_1.fastq.gz" 287765e5ef6131f15aaabd2eb227485d
fetch "${GETORGANELLE_GALLERY}/SRR5201683_2.fastq.gz" "${OUTDIR}/illumina/SRR5201683_2.fastq.gz" e45bf7f244ce59da9d79b206ca08ff6b
# Close relative reference: GenBank PZ790849, Caryomys eva, the same tribe (Myodini)
# as the bank vole. Chosen over the bank vole's own RefSeq record NC_024538 because
# that one annotates no /gene= qualifiers and MitoHiFi needs them.
fetch_ncbi PZ790849 "${OUTDIR}/illumina"

echo
echo "==> Writing test samplesheet"
cat > "${OUTDIR}/samplesheet_test.csv" <<EOF
sample,platform,fastq_1,fastq_2,bam,species,ref_fa,ref_gb,genetic_code
ilDeiPorc1,hifi,${OUTDIR}/hifi/ilDeiPorc1.reads.100.fa,,,,${OUTDIR}/hifi/MW539688.1.fasta,${OUTDIR}/hifi/MW539688.1.gb,5
SRR5201683,illumina,${OUTDIR}/illumina/SRR5201683_1.fastq.gz,${OUTDIR}/illumina/SRR5201683_2.fastq.gz,,,${OUTDIR}/illumina/PZ790849.fasta,${OUTDIR}/illumina/PZ790849.gb,2
EOF
echo "  ${OUTDIR}/samplesheet_test.csv"

# A second samplesheet for the stub-mode test of the 'ref_fa: hifi:<sample>'
# dependency. The reads are the same real files; only the wiring is under test, and
# -stub means no assembler actually runs, so the cross-species pairing is harmless.
cat > "${OUTDIR}/samplesheet_hifi_reference.csv" <<EOF
sample,platform,fastq_1,fastq_2,bam,species,ref_fa,ref_gb,genetic_code
ilDeiPorc1,hifi,${OUTDIR}/hifi/ilDeiPorc1.reads.100.fa,,,,${OUTDIR}/hifi/MW539688.1.fasta,${OUTDIR}/hifi/MW539688.1.gb,5
shortA,illumina,${OUTDIR}/illumina/SRR5201683_1.fastq.gz,${OUTDIR}/illumina/SRR5201683_2.fastq.gz,,,hifi:ilDeiPorc1,,5
shortB,illumina,${OUTDIR}/illumina/SRR5201683_1.fastq.gz,${OUTDIR}/illumina/SRR5201683_2.fastq.gz,,,hifi:ilDeiPorc1,,5
EOF
echo "  ${OUTDIR}/samplesheet_hifi_reference.csv"

echo
echo "Total size:"
du -sh "${OUTDIR}"
echo
echo "Done. Now run:"
echo "  nextflow run . -profile test,docker --outdir results"
