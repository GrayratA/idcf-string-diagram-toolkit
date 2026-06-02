"""
Minimal y0 counterfactual-identification demo for the commute scenario.

Run:
  python comparisons/python_y0/commute_example.py

Notes:
- y0's ID*/IDC* counterfactual API uses binary-style events (+/-).
- This script maps the commute query to that style:
    P(Y_{do(T=+)}=+ | W=+, T=-, M_{do(W=+)}=+)
"""

from __future__ import annotations

from y0.dsl import Variable
from y0.graph import NxMixedGraph

try:
    # y0 stable/dev both expose this path
    from y0.algorithm.identify.idc_star import idc_star
    from y0.algorithm.identify.utils import Unidentifiable
except ImportError:  # pragma: no cover
    raise RuntimeError(
        "Cannot import y0 IDC* APIs. Install y0 first: pip install y0"
    )


def build_commute_graph() -> NxMixedGraph:
    """Build the ADMG:
    W->T, W->M, T->L, M->L, L->Y, and latent confounding T<->Y.
    """
    W = Variable("W")
    T = Variable("T")
    M = Variable("M")
    L = Variable("L")
    Y = Variable("Y")

    return NxMixedGraph.from_edges(
        directed=[
            (W, T),
            (W, M),
            (T, L),
            (M, L),
            (L, Y),
        ],
        undirected=[
            (T, Y),  # bidirected confounding arc T <-> Y in ADMG notation
        ],
    )


def run_commute_idc_star() -> None:
    graph = build_commute_graph()

    W = Variable("W")
    T = Variable("T")
    M = Variable("M")
    Y = Variable("Y")

    # Binary mapping for the commute counterfactual query:
    # P(Y_{do(T=+)}=+ | W=+, T=-, M_{do(W=+)}=+)
    outcomes = {
        (Y @ +T): +Y,
    }
    conditions = {
        W: +W,
        T: -T,
        (M @ +W): +M,
    }

    print("== y0 commute IDC* demo ==")
    print("directed edges :", list(graph.directed.edges()))
    print("bidirected arcs:", list(graph.undirected.edges()))
    print("query outcomes :", outcomes)
    print("query conditions:", conditions)

    try:
        expr = idc_star(graph, outcomes=outcomes, conditions=conditions)
        print("\nidentifiable = True")
        print("estimand (text):", expr.to_text())
        print("estimand (y0)  :", expr.to_y0())
        print("estimand (latex):", expr.to_latex())
    except Unidentifiable as e:
        print("\nidentifiable = False")
        print("error:", repr(e))
    except ValueError as e:
        # y0 uses ValueError for certain inconsistencies (e.g., line-1 IDC* check)
        print("\nidentifiable = False")
        print("error:", repr(e))


if __name__ == "__main__":
    run_commute_idc_star()
