# Beauveria bassiana genome completeness assessment

Single-genome reproducibility exercise for Week 5. Downloads one named,
version-pinned *Beauveria bassiana* assembly, runs two external
bioinformatics programs against it (`seqkit`, `BUSCO`), and produces one
final table summarizing genome contiguity and gene-set completeness.

## What this run does
- Downloads **GCA_014607475.1** (complete *B. bassiana* genome, NCBI)
- Computes assembly contiguity stats with `seqkit stats`
- Runs `BUSCO` in genome mode against the `hypocreales_odb10` lineage dataset
- Merges both into `outputs/results_table.tsv`
- Writes `CHECKSUMS.txt` (sha256 of the genome file + every output)

## Setup
```bash
conda env create -f environment.yml
conda activate week5-busco
```

## Run
```bash
bash scripts/run_analysis.sh
```
Expect this to take roughly 15–35 minutes on a laptop (4 cores), mostly
spent inside BUSCO's internal gene-calling step. The genome download itself
is small (tens of MB).

## What should come out
```
data/                          # downloaded genome (NOT committed — see .gitignore)
outputs/
  seqkit_stats.tsv             # raw contiguity stats
  busco_full_table.tsv         # per-BUSCO-gene hit table
  busco_missing_list.tsv       # BUSCOs not found
  busco_short_summary.txt      # raw BUSCO summary text
  results_table.tsv            # <-- final merged table, the deliverable
CHECKSUMS.txt                  # sha256 of genome file + every output above
```

`results_table.tsv` looks like:

| metric | value |
|---|---|
| genome_accession | GCA_014607475.1 |
| busco_lineage_dataset | hypocreales_odb10 |
| busco_threads | 4 |
| busco_gene_caller_backend | metaeuk |
| seqkit_num_seqs | ... |
| seqkit_N50 | ... |
| seqkit_GC(%) | ... |
| busco_complete_pct | ... |
| busco_single_copy_pct | ... |
| busco_duplicated_pct | ... |
| busco_fragmented_pct | ... |
| busco_missing_pct | ... |
| busco_total_groups_searched | ... |

## Reproducibility notes (read before re-running or replicating)
These are the specific places this pipeline can silently diverge between
runs or machines — call these out explicitly if you're the one replicating
someone else's version of this project:

- **Genome accession is pinned**, not "latest assembly for *B. bassiana*" —
  NCBI's "latest" pointer for a species can change over time.
- **BUSCO lineage dataset version** is pinned via `hypocreales_odb10`, but
  BUSCO itself may auto-update the underlying dataset files on first
  download. Record the dataset date it actually pulls (printed to stdout).
- **Thread count (`--cpu`)** can affect tie-breaking in BUSCO's internal
  gene calls in some backend/version combinations. We use 4; if you change
  it, note that in your run log.
- **Gene-calling backend**: BUSCO defaults to `metaeuk` for genome mode in
  this version; older BUSCO versions defaulted to `augustus`. This is
  recorded explicitly in `results_table.tsv`.
- **Tool versions** are pinned in `environment.yml`. Do not `conda update`
  before running unless you intend to test cross-version drift.

## Data
Raw genome FASTA is downloaded fresh by the script and is **not** committed
to this repo (see `.gitignore`). Only the checksums are committed, so
anyone re-running this can verify they fetched the identical file.
