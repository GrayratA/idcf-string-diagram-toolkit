#!/usr/bin/env python3
"""Generate a corpus of ADMGs + counterfactual queries for differential testing.

The corpus is the single source of truth shared by every runner. To avoid
forcing a JSON parser on each language, the same corpus is emitted three ways:

  * corpus.json  -- canonical record, read by compare.py (Python stdlib json)
  * corpus.jl    -- a Julia literal `const CORPUS = [...]`, `include`d by run_julia.jl
  * corpus.R     -- an R literal `corpus <- list(...)`, `source`d by run_cfid.R

Each case is a counterfactual identification problem:

  {
    "id":         "case_0001",
    "directed":   [["X","W"], ["W","Y"], ...],   # directed edges src -> tgt
    "bidirected": [["X","Y"], ...],              # bidirected (latent confounding) edges
    "data":       "interventions" | "observations",
    "target":     [ {"var":"Y","val":"y","do":{"X":"x"}} ],   # gamma: target counterfactual events
    "evidence":   [ {"var":"W","val":"w","do":{}}, ... ]      # delta: evidence counterfactual events
  }

A "counterfactual event" is a potential outcome: variable `var` takes value `val`
in the world where the variables in `do` are intervened to the given values.
This maps faithfully to cfid's `cf(var, obs, sub)` and to the toolkit's
`CounterfactualQuery` worlds (see run_cfid.R / run_julia.jl).

The corpus mixes:
  * structured cases  -- drug, party, and the four synthetic scaling DAG families
                         (chain, fanin, dense, chain_bi) used by the efficiency
                         benchmarks, so those DAGs finally get correctness coverage too;
  * random cases      -- reproducibly sampled ADMGs of varying size/density.

Usage:
    python3 gen_corpus.py --n 60 --seed 1 --out .
"""

import argparse
import json
import os
import random
from collections import OrderedDict


# --------------------------------------------------------------------------
# Graph helpers
# --------------------------------------------------------------------------

def ordered_nodes(directed, bidirected):
    """All node names, in first-seen order."""
    seen = OrderedDict()
    for a, b in directed:
        seen.setdefault(a, None)
        seen.setdefault(b, None)
    for a, b in bidirected:
        seen.setdefault(a, None)
        seen.setdefault(b, None)
    return list(seen.keys())


def descendants(directed, start):
    """Set of nodes reachable from `start` along directed edges (excluding start)."""
    adj = {}
    for a, b in directed:
        adj.setdefault(a, []).append(b)
    seen, stack = set(), list(adj.get(start, []))
    while stack:
        v = stack.pop()
        if v in seen:
            continue
        seen.add(v)
        stack.extend(adj.get(v, []))
    return seen


def parents(directed, node):
    return [a for a, b in directed if b == node]


def lc(name):
    """A lowercase value-symbol for a variable (e.g. 'Y' -> 'y', 'V3' -> 'v3')."""
    return name.lower()


# --------------------------------------------------------------------------
# Query construction
# --------------------------------------------------------------------------

def natural_query(directed, bidirected, data, rng, max_evidence=2):
    """Build a 'natural' single-target counterfactual query over a graph.

    Picks a root-ish treatment X, a downstream sink-ish outcome Y, forms the
    target event Y | do(X = x), and observes up to `max_evidence` of the
    remaining variables (some plainly, some under an intervention on a parent).
    Returns None if the graph has no usable X->Y pair.
    """
    nodes = ordered_nodes(directed, bidirected)
    if len(nodes) < 2:
        return None

    # Treatment: prefer a parentless node; outcome: a descendant that is a sink.
    roots = [v for v in nodes if not parents(directed, v)]
    candidates_x = roots if roots else nodes
    x = None
    y = None
    for cand in candidates_x:
        desc = descendants(directed, cand)
        sinks = [d for d in desc if not any(a == d for a, _ in directed)]
        downstream = sinks if sinks else list(desc)
        if downstream:
            x = cand
            # pick the farthest-looking downstream node deterministically via rng
            y = rng.choice(sorted(downstream))
            break
    if x is None or y is None or x == y:
        return None

    target = [{"var": y, "val": lc(y), "do": {x: lc(x)}}]

    # Evidence: variables other than X and Y.
    pool = [v for v in nodes if v not in (x, y)]
    rng.shuffle(pool)
    evidence = []
    for v in pool[:max_evidence]:
        ps = [p for p in parents(directed, v) if p != x]
        if ps and rng.random() < 0.4:
            p = rng.choice(sorted(ps))
            evidence.append({"var": v, "val": lc(v), "do": {p: lc(p)}})
        else:
            evidence.append({"var": v, "val": lc(v), "do": {}})

    # cfid/ID-CF works on conditional queries; keep evidence non-empty.
    if not evidence:
        # fall back to observing a parent of Y (never X)
        ps = [p for p in parents(directed, y) if p != x]
        if not ps:
            return None
        v = sorted(ps)[0]
        evidence.append({"var": v, "val": lc(v), "do": {}})

    return {
        "directed": [list(e) for e in directed],
        "bidirected": [list(e) for e in bidirected],
        "data": data,
        "target": target,
        "evidence": evidence,
    }


# --------------------------------------------------------------------------
# Structured cases (known graphs + the four synthetic efficiency DAGs)
# --------------------------------------------------------------------------

def v(i):
    return "V%d" % i


def model_chain(n):
    return [[v(i), v(i + 1)] for i in range(1, n)], []


def model_fanin(n):
    directed = []
    for i in range(2, n):
        directed.append([v(1), v(i)])
        directed.append([v(i), v(n)])
    directed.append([v(1), v(n)])
    return directed, []


def model_chain_bi(n):
    directed = [[v(i), v(i + 1)] for i in range(1, n)]
    bidirected = [[v(i), v(i + 1)] for i in range(1, n)]
    return directed, bidirected


def model_dense(n):
    directed = []
    for i in range(1, n):
        for j in range(i + 1, n + 1):
            if (i * 37 + j * 17) % 10 < 3:
                directed.append([v(i), v(j)])
    return directed, []


def structured_cases(rng):
    """Hand-known graphs plus the four synthetic scaling families at small n.

    The drug and party cases are the classic ID-CF examples (drug is identifiable
    from interventions; party is identifiable from observations). The synthetic
    families are the ones used in the efficiency benchmarks -- here they finally
    get a correctness verdict against the cfid reference.
    """
    cases = []

    # Drug: X -> W -> Y <- Z <- D ; X <-> Y  (identifiable counterfactual)
    cases.append(("drug", {
        "directed": [["X", "W"], ["W", "Y"], ["D", "Z"], ["Z", "Y"]],
        "bidirected": [["X", "Y"]],
        "data": "interventions",
        "target": [{"var": "Y", "val": "y", "do": {"X": "x"}}],
        "evidence": [
            {"var": "X", "val": "xt", "do": {}},
            {"var": "D", "val": "d", "do": {}},
            {"var": "Z", "val": "z", "do": {"D": "d"}},
        ],
    }))

    # Party: A -> B; A -> C; B -> S; C -> S
    cases.append(("party", {
        "directed": [["A", "B"], ["A", "C"], ["B", "S"], ["C", "S"]],
        "bidirected": [],
        "data": "observations",
        "target": [{"var": "S", "val": "s", "do": {"B": "b"}}],
        "evidence": [{"var": "B", "val": "bp", "do": {}}],
    }))

    # The four synthetic scaling families, small n, with a natural query each.
    families = [
        ("chain", model_chain),
        ("fanin", model_fanin),
        ("chain_bi", model_chain_bi),
        ("dense", model_dense),
    ]
    for n in (4, 6):
        for fam_name, fam in families:
            directed, bidirected = fam(n)
            if not directed:
                continue
            # chain_bi has confounding on every edge -> good FAIL coverage;
            # interventions are the data setting these were benchmarked under.
            data = "interventions" if bidirected else "observations"
            q = natural_query(directed, bidirected, data, rng)
            if q is None:
                continue
            cases.append(("%s%d" % (fam_name, n), q))

    return cases


# --------------------------------------------------------------------------
# Random cases
# --------------------------------------------------------------------------

def random_admg(rng, n, p_dir=0.45, p_bi=0.12):
    """Random ADMG on n nodes V1..Vn: directed edges respect i<j (acyclic)."""
    nodes = [v(i) for i in range(1, n + 1)]
    directed = []
    for i in range(n):
        for j in range(i + 1, n):
            if rng.random() < p_dir:
                directed.append([nodes[i], nodes[j]])
    bidirected = []
    for i in range(n):
        for j in range(i + 1, n):
            if rng.random() < p_bi:
                bidirected.append([nodes[i], nodes[j]])
    return directed, bidirected


def random_cases(rng, count):
    cases = []
    made = 0
    attempts = 0
    while made < count and attempts < count * 20:
        attempts += 1
        n = rng.randint(4, 7)
        directed, bidirected = random_admg(rng, n)
        if not directed:
            continue
        data = rng.choice(["interventions", "observations"])
        q = natural_query(directed, bidirected, data, rng)
        if q is None:
            continue
        cases.append(("rand%04d" % (made + 1), q))
        made += 1
    return cases


# --------------------------------------------------------------------------
# Emitters
# --------------------------------------------------------------------------

def emit_json(cases, path):
    out = []
    for cid, c in cases:
        rec = {"id": cid}
        rec.update(c)
        out.append(rec)
    with open(path, "w") as f:
        json.dump(out, f, indent=2)
        f.write("\n")


def _jl_do(do):
    if not do:
        return "Dict{Symbol,Symbol}()"
    items = ", ".join(":%s => :%s" % (k, val) for k, val in do.items())
    return "Dict(%s)" % items


def _jl_events(events):
    parts = []
    for e in events:
        # `do` is a reserved keyword in Julia, so the intervention context is
        # named `ctx` in the Julia literal (run_julia.jl reads e.ctx / t.ctx).
        parts.append("(var=:%s, val=:%s, ctx=%s)" % (e["var"], e["val"], _jl_do(e["do"])))
    return "[" + ", ".join(parts) + "]"


def emit_julia(cases, path):
    lines = ["# Auto-generated by gen_corpus.py -- do not edit by hand.",
             "const CORPUS = ["]
    for cid, c in cases:
        directed = ", ".join("(:%s,:%s)" % (a, b) for a, b in c["directed"])
        bidir = ", ".join("(:%s,:%s)" % (a, b) for a, b in c["bidirected"])
        lines.append("  (")
        lines.append('    id = "%s",' % cid)
        lines.append("    directed = Tuple{Symbol,Symbol}[%s]," % directed)
        lines.append("    bidirected = Tuple{Symbol,Symbol}[%s]," % bidir)
        lines.append('    data = "%s",' % c["data"])
        lines.append("    target = %s," % _jl_events(c["target"]))
        lines.append("    evidence = %s," % _jl_events(c["evidence"]))
        lines.append("  ),")
    lines.append("]")
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")


def _r_do(do):
    if not do:
        return "list()"
    items = ", ".join('%s = "%s"' % (k, val) for k, val in do.items())
    return "list(%s)" % items


def _r_events(events):
    parts = []
    for e in events:
        parts.append('list(var = "%s", val = "%s", do = %s)'
                     % (e["var"], e["val"], _r_do(e["do"])))
    return "list(" + ", ".join(parts) + ")"


def emit_r(cases, path):
    lines = ["# Auto-generated by gen_corpus.py -- do not edit by hand.",
             "corpus <- list("]
    blocks = []
    for cid, c in cases:
        directed = ", ".join('c("%s","%s")' % (a, b) for a, b in c["directed"])
        bidir = ", ".join('c("%s","%s")' % (a, b) for a, b in c["bidirected"])
        block = []
        block.append("  list(")
        block.append('    id = "%s",' % cid)
        block.append("    directed = list(%s)," % directed)
        block.append("    bidirected = list(%s)," % bidir)
        block.append('    data = "%s",' % c["data"])
        block.append("    target = %s," % _r_events(c["target"]))
        block.append("    evidence = %s" % _r_events(c["evidence"]))
        block.append("  )")
        blocks.append("\n".join(block))
    lines.append(",\n".join(blocks))
    lines.append(")")
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")


# --------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--n", type=int, default=60, help="number of random cases")
    ap.add_argument("--seed", type=int, default=1, help="RNG seed (reproducible corpus)")
    ap.add_argument("--out", default=".", help="output directory")
    args = ap.parse_args()

    rng = random.Random(args.seed)
    cases = structured_cases(rng) + random_cases(rng, args.n)

    os.makedirs(args.out, exist_ok=True)
    emit_json(cases, os.path.join(args.out, "corpus.json"))
    emit_julia(cases, os.path.join(args.out, "corpus.jl"))
    emit_r(cases, os.path.join(args.out, "corpus.R"))

    print("Generated %d cases (seed=%d):" % (len(cases), args.seed))
    print("  %d structured + %d random" % (len(cases) - args.n, args.n)
          if len(cases) >= args.n else "  %d total" % len(cases))
    print("Wrote corpus.json, corpus.jl, corpus.R to %s" % os.path.abspath(args.out))


if __name__ == "__main__":
    main()
