#!/usr/bin/env python3
"""Compare toolkit verdicts against the cfid reference and report disagreements.

Inputs:
  corpus.json          -- the case definitions (for context in the report)
  verdicts_julia.tsv   -- <id> \t <verdict> \t <stage> \t <msg>   (from run_julia.jl)
  verdicts_cfid.tsv    -- <id> \t <verdict> \t <formula>          (from run_cfid.R)

Each verdict is ID, FAIL, or ERROR.

Outcome per case:
  AGREE        -- both tools returned a verdict (ID/FAIL) and they match
  DISAGREE     -- both returned a verdict but they differ   <-- the bug signal
  NOT-COMPARABLE -- at least one tool returned ERROR (crash / unsupported case)

Writes a Markdown report and prints a summary. Exit code is non-zero if there is
any DISAGREE case, so the harness can gate CI.

Usage:
    python3 compare.py corpus.json verdicts_julia.tsv verdicts_cfid.tsv report.md
"""

import json
import sys


def load_tsv(path):
    rows = {}
    with open(path) as f:
        for line in f:
            line = line.rstrip("\n")
            if not line:
                continue
            parts = line.split("\t")
            cid = parts[0]
            verdict = parts[1] if len(parts) > 1 else "ERROR"
            rest = parts[2:] if len(parts) > 2 else []
            rows[cid] = (verdict, rest)
    return rows


def describe(case):
    """One-line human description of a case's query."""
    def ev(e):
        if e["do"]:
            ctx = ",".join("do(%s=%s)" % (k, v) for k, v in e["do"].items())
            return "%s=%s | %s" % (e["var"], e["val"], ctx)
        return "%s=%s" % (e["var"], e["val"])
    tgt = " ∧ ".join(ev(e) for e in case["target"])
    evd = " ∧ ".join(ev(e) for e in case["evidence"])
    nd = len(case["directed"])
    nb = len(case["bidirected"])
    desc = "P(%s | %s) [%s; %d→, %d↔]" % (tgt, evd, case["data"], nd, nb)
    # '|' is the Markdown table cell delimiter; use the divides glyph instead.
    return desc.replace("|", "∣")


def main():
    if len(sys.argv) < 5:
        sys.exit("usage: compare.py corpus.json verdicts_julia.tsv "
                 "verdicts_cfid.tsv report.md")
    corpus_path, julia_path, cfid_path, report_path = sys.argv[1:5]

    with open(corpus_path) as f:
        corpus = json.load(f)
    cases = {c["id"]: c for c in corpus}
    julia = load_tsv(julia_path)
    cfid = load_tsv(cfid_path)

    agree, disagree, ncomp = [], [], []
    for cid in [c["id"] for c in corpus]:
        jv = julia.get(cid, ("MISSING", []))[0]
        cv = cfid.get(cid, ("MISSING", []))[0]
        if jv in ("ID", "FAIL") and cv in ("ID", "FAIL"):
            (agree if jv == cv else disagree).append((cid, jv, cv))
        else:
            ncomp.append((cid, jv, cv))

    total = len(corpus)
    comparable = len(agree) + len(disagree)
    rate = (100.0 * len(agree) / comparable) if comparable else float("nan")

    # ---- report ----
    lines = []
    lines.append("# Correctness differential test: toolkit vs cfid\n")
    lines.append("Each case is a counterfactual identification problem. The "
                 "toolkit's ID/FAIL verdict is compared against the cfid "
                 "reference implementation.\n")
    lines.append("## Summary\n")
    lines.append("| metric | value |")
    lines.append("| --- | --- |")
    lines.append("| total cases | %d |" % total)
    lines.append("| comparable (both gave a verdict) | %d |" % comparable)
    lines.append("| **agree** | **%d** |" % len(agree))
    lines.append("| **disagree** | **%d** |" % len(disagree))
    lines.append("| not comparable (≥1 ERROR) | %d |" % len(ncomp))
    lines.append("| agreement rate | %.1f%% |" % rate)
    lines.append("")

    if disagree:
        lines.append("## ❌ Disagreements (investigate these)\n")
        lines.append("| case | toolkit | cfid | query |")
        lines.append("| --- | --- | --- | --- |")
        for cid, jv, cv in disagree:
            lines.append("| %s | %s | %s | %s |"
                         % (cid, jv, cv, describe(cases[cid])))
        lines.append("")

    if ncomp:
        lines.append("## ⚠️ Not comparable (errors — review separately)\n")
        lines.append("| case | toolkit | cfid | toolkit-note | query |")
        lines.append("| --- | --- | --- | --- | --- |")
        for cid, jv, cv in ncomp:
            note = ""
            jrow = julia.get(cid)
            if jrow and jrow[1]:
                note = " ".join(jrow[1])[:80]
            lines.append("| %s | %s | %s | %s | %s |"
                         % (cid, jv, cv, note, describe(cases[cid])))
        lines.append("")

    lines.append("## ✓ Agreements\n")
    lines.append("| case | verdict | query |")
    lines.append("| --- | --- | --- |")
    for cid, jv, _ in agree:
        lines.append("| %s | %s | %s |" % (cid, jv, describe(cases[cid])))
    lines.append("")

    with open(report_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")

    # ---- console summary ----
    print("=" * 60)
    print("Correctness differential test: toolkit vs cfid")
    print("=" * 60)
    print("  total cases       : %d" % total)
    print("  comparable        : %d" % comparable)
    print("  agree             : %d" % len(agree))
    print("  disagree          : %d" % len(disagree))
    print("  not comparable    : %d" % len(ncomp))
    print("  agreement rate    : %.1f%%" % rate)
    print("  report            : %s" % report_path)
    if disagree:
        print("\n  DISAGREEMENTS:")
        for cid, jv, cv in disagree:
            print("    %-12s toolkit=%-4s cfid=%-4s" % (cid, jv, cv))
    print("=" * 60)

    sys.exit(1 if disagree else 0)


if __name__ == "__main__":
    main()
