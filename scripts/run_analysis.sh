#!/usr/bin/env bash
#
# run_analysis.sh
# ----------------
# Week 5 reproducibility analysis: genome completeness assessment of
# Beauveria bassiana (single assembly).
#
# What this does, in order:
#   1. Downloads one named, versioned NCBI genome assembly (no "latest" pointers)
#   2. Computes basic assembly contiguity stats with seqkit (external program)
#   3. Runs BUSCO genome-mode completeness assessment (external program)
#   4. Summarizes both into one human-readable table: outputs/results_table.tsv
#   5. Writes CHECKSUMS.txt for every output + the input genome file
#
# Requirements: conda env built from environment.yml in this repo.
#   conda env create -f environment.yml
#   conda activate week5-busco
#
# Usage:
#   bash scripts/run_analysis.sh
#
# Everything below is pinned/explicit on purpose — a classmate's AI coding
# agent should be able to run this with zero guessing.

set -euo pipefail  # fail loudly on any error, unset var, or pipe failure

# ---- Config (pin everything that could silently drift) --------------------
ACCESSION="GCA_014607475.1"       # complete B. bassiana genome, NCBI Datasets
LINEAGE="hypocreales_odb10"        # pinned BUSCO lineage dataset
THREADS=4                          # affects BUSCO's internal gene-calling; record it
BUSCO_MODE="genome"
BUSCO_BACKEND="metaeuk"            # BUSCO default gene-calling backend; state explicitly

# ---- Paths ------------------------------------------------------------------
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_DIR="${ROOT_DIR}/data"
OUT_DIR="${ROOT_DIR}/outputs"

mkdir -p "${DATA_DIR}" "${OUT_DIR}"

# ---- Sanity-check tools are actually installed -----------------------------
for tool in datasets unzip seqkit busco sha256sum; do
  command -v "${tool}" >/dev/null 2>&1 || {
    echo "ERROR: required tool '${tool}' not found on PATH. Did you activate the conda env?" >&2
    exit 1
  }
done

echo "=== [1/5] Downloading genome ${ACCESSION} ==="
cd "${DATA_DIR}"
if [ ! -f "ncbi_dataset.zip" ]; then
  datasets download genome accession "${ACCESSION}" --include genome
fi
unzip -o ncbi_dataset.zip -d "${DATA_DIR}"

# Locate the downloaded FASTA (path is deterministic given the accession)
GENOME_FASTA=$(find "${DATA_DIR}/ncbi_dataset/data/${ACCESSION}" -name "*.fna" | head -n1)
if [ -z "${GENOME_FASTA}" ]; then
  echo "ERROR: could not locate downloaded genome FASTA." >&2
  exit 1
fi
echo "Genome FASTA: ${GENOME_FASTA}"

echo "=== [2/5] Assembly stats (seqkit) ==="
cd "${ROOT_DIR}"
seqkit stats -a -T "${GENOME_FASTA}" > "${OUT_DIR}/seqkit_stats.tsv"

echo "=== [3/5] BUSCO completeness assessment ==="
busco \
  -i "${GENOME_FASTA}" \
  -m "${BUSCO_MODE}" \
  -l "${LINEAGE}" \
  --cpu "${THREADS}" \
  -o busco_out \
  --out_path "${OUT_DIR}" \
  --force

BUSCO_RUN_DIR="${OUT_DIR}/busco_out/run_${LINEAGE}"
cp "${BUSCO_RUN_DIR}/full_table.tsv" "${OUT_DIR}/busco_full_table.tsv"
cp "${BUSCO_RUN_DIR}/missing_busco_list.tsv" "${OUT_DIR}/busco_missing_list.tsv"
cp "${OUT_DIR}"/busco_out/short_summary.*."${LINEAGE}".busco_out.txt \
   "${OUT_DIR}/busco_short_summary.txt"

echo "=== [4/5] Building final results table ==="
python3 "${ROOT_DIR}/scripts/summarize_table.py" \
  --seqkit-stats "${OUT_DIR}/seqkit_stats.tsv" \
  --busco-summary "${OUT_DIR}/busco_short_summary.txt" \
  --accession "${ACCESSION}" \
  --lineage "${LINEAGE}" \
  --threads "${THREADS}" \
  --backend "${BUSCO_BACKEND}" \
  --out "${OUT_DIR}/results_table.tsv"

echo "=== [5/5] Writing checksums ==="
cd "${ROOT_DIR}"
sha256sum "${GENOME_FASTA}" \
  "${OUT_DIR}/seqkit_stats.tsv" \
  "${OUT_DIR}/busco_full_table.tsv" \
  "${OUT_DIR}/busco_missing_list.tsv" \
  "${OUT_DIR}/busco_short_summary.txt" \
  "${OUT_DIR}/results_table.tsv" \
  > "${ROOT_DIR}/CHECKSUMS.txt"

echo "Done. Final table: ${OUT_DIR}/results_table.tsv"
echo "Checksums:         ${ROOT_DIR}/CHECKSUMS.txt"
