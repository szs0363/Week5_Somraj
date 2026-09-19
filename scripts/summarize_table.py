#!/usr/bin/env python3
"""
summarize_table.py
-------------------
Post-processing only: parses the raw text/TSV output already produced by
seqkit and BUSCO (the two external programs) and merges them into a single
tidy table (metric, value). This script performs no analysis of its own —
it only reformats what the external tools already computed, which is why
it doesn't count against the "use an external program" requirement.

Usage (called automatically by run_analysis.sh, but can be run standalone):
    python3 summarize_table.py \
        --seqkit-stats outputs/seqkit_stats.tsv \
        --busco-summary outputs/busco_short_summary.txt \
        --accession GCA_014607475.1 \
        --lineage hypocreales_odb10 \
        --threads 4 \
        --backend metaeuk \
        --out outputs/results_table.tsv
"""

import argparse
import csv
import re
import sys
from pathlib import Path


def parse_seqkit_stats(path: Path) -> dict:
    """seqkit stats -T produces a single header row + single data row (TSV)."""
    with open(path, newline="") as fh:
        reader = csv.DictReader(fh, delimiter="\t")
        row = next(reader, None)
    if row is None:
        raise ValueError(f"No data rows found in {path}")
    # Keep the fields most relevant to a genome-completeness project
    keys_of_interest = ["num_seqs", "sum_len", "min_len", "avg_len", "max_len", "N50", "GC(%)"]
    return {f"seqkit_{k}": row[k] for k in keys_of_interest if k in row}


def parse_busco_summary(path: Path) -> dict:
    """
    Extracts the C:xx.x%[S:xx.x%,D:xx.x%],F:xx.x%,M:xx.x%,n:NNNN line
    that BUSCO always prints in its short_summary file.
    """
    text = path.read_text()
    pattern = re.compile(
        r"C:(?P<C>[\d.]+)%\[S:(?P<S>[\d.]+)%,D:(?P<D>[\d.]+)%\],"
        r"F:(?P<F>[\d.]+)%,M:(?P<M>[\d.]+)%,n:(?P<n>\d+)"
    )
    match = pattern.search(text)
    if not match:
        raise ValueError(f"Could not find BUSCO summary line in {path}")
    g = match.groupdict()
    return {
        "busco_complete_pct": g["C"],
        "busco_single_copy_pct": g["S"],
        "busco_duplicated_pct": g["D"],
        "busco_fragmented_pct": g["F"],
        "busco_missing_pct": g["M"],
        "busco_total_groups_searched": g["n"],
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--seqkit-stats", required=True, type=Path)
    ap.add_argument("--busco-summary", required=True, type=Path)
    ap.add_argument("--accession", required=True)
    ap.add_argument("--lineage", required=True)
    ap.add_argument("--threads", required=True)
    ap.add_argument("--backend", required=True)
    ap.add_argument("--out", required=True, type=Path)
    args = ap.parse_args()

    row = {}
    row["genome_accession"] = args.accession
    row["busco_lineage_dataset"] = args.lineage
    row["busco_threads"] = args.threads
    row["busco_gene_caller_backend"] = args.backend
    row.update(parse_seqkit_stats(args.seqkit_stats))
    row.update(parse_busco_summary(args.busco_summary))

    args.out.parent.mkdir(parents=True, exist_ok=True)
    with open(args.out, "w", newline="") as fh:
        writer = csv.writer(fh, delimiter="\t")
        writer.writerow(["metric", "value"])
        for k, v in row.items():
            writer.writerow([k, v])

    print(f"Wrote {len(row)} metrics to {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
