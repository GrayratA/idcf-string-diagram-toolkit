#!/usr/bin/env bash
# run_all.sh -- generate a corpus, run both implementations, compare verdicts.
#
# Produces report.md and exits non-zero if the toolkit ever disagrees with cfid
# on a comparable case (so it can be used as a CI gate).
#
# Usage:
#     ./run_all.sh [N_RANDOM_CASES] [SEED]
# e.g.
#     ./run_all.sh 60 1

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
N="${1:-60}"
SEED="${2:-1}"

cd "$HERE"

echo "==> [1/4] generating corpus (N=$N, seed=$SEED)"
python3 gen_corpus.py --n "$N" --seed "$SEED" --out .

echo "==> [2/4] running toolkit (Julia)"
if command -v julia >/dev/null 2>&1; then
  julia --project="$ROOT" run_julia.jl corpus.jl verdicts_julia.tsv
else
  echo "ERROR: 'julia' not found on PATH. Install Julia and the project deps:" >&2
  echo "  julia --project=$ROOT -e 'using Pkg; Pkg.instantiate()'" >&2
  exit 127
fi

echo "==> [3/4] running cfid reference (R)"
if command -v Rscript >/dev/null 2>&1; then
  Rscript run_cfid.R corpus.R verdicts_cfid.tsv
else
  echo "ERROR: 'Rscript' not found on PATH. Install R and the cfid package:" >&2
  echo "  install.packages('cfid')" >&2
  exit 127
fi

echo "==> [4/4] comparing verdicts"
python3 compare.py corpus.json verdicts_julia.tsv verdicts_cfid.tsv report.md
