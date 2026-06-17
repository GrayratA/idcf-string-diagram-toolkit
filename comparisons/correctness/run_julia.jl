# run_julia.jl -- run the toolkit on every corpus case and emit an ID/FAIL verdict.
#
# Reads a Julia-literal corpus (corpus.jl, produced by gen_corpus.py) and, for
# each case, drives the toolkit's top-level entry point `identify_counterfactual`.
# The only thing we read off is the IDENTIFIABILITY VERDICT -- not the formula --
# because that is what we can compare against the cfid reference implementation.
#
# Output: a TSV with one line per case:
#     <id> \t <verdict> \t <failure_stage> \t <error-one-line>
# where <verdict> is one of:
#     ID    -- toolkit reports the query is identifiable
#     FAIL  -- toolkit reports the query is NOT identifiable (Step 4 raised a FAIL)
#     ERROR -- the toolkit crashed for a non-verdict reason (build/simplify bug,
#              or a Step 4 error whose message is not a recognised FAIL).
# ERROR rows are NOT counterexamples; they are flagged for human review.
#
# Usage (from anywhere; pass absolute or relative paths):
#     julia --project=<repo-root> run_julia.jl corpus.jl verdicts_julia.tsv

using Catlab
using Catlab.WiringDiagrams
using Catlab.CategoricalAlgebra
using Catlab.Theories

const HERE = @__DIR__
const ROOT = normpath(joinpath(HERE, "..", ".."))

include(joinpath(ROOT, "src", "utils.jl"))
include(joinpath(ROOT, "src", "admg_compile.jl"))
include(joinpath(ROOT, "src", "bn_import.jl"))
include(joinpath(ROOT, "src", "simplify_cf.jl"))
include(joinpath(ROOT, "src", "id_cf.jl"))

# --------------------------------------------------------------------------
# Translate one corpus case into the toolkit's ADMGModel + CounterfactualQuery list.
#
# Identifiability is a property of (graph, target events, evidence events,
# data-type) and does NOT depend on how events are grouped into "worlds". We use
# a simple, mechanical grouping that matches the hand-written drug/party examples:
#
#   * one world per distinct intervention context;
#   * all evidence events with that same context are placed in that world's
#     observation dictionary;
#   * all target events with that same context are placed in that world's
#     `outputs`.
#
# This matches the usual counterfactual notation: events with the same subscript
# belong to the same counterfactual world.
# --------------------------------------------------------------------------

function build_admg(case)
    directed = [Pair(a, b) for (a, b) in case.directed]
    bidirected = [Pair(a, b) for (a, b) in case.bidirected]
    return ADMGModel(directed, bidirected)
end

function build_queries(case)
    ctx_key(ctx) = Tuple(sort!(collect(ctx); by = p -> string(p.first)))

    groups = Dict{Any,NamedTuple}()
    order = Any[]

    function group_for!(ctx)
        key = ctx_key(ctx)
        if !haskey(groups, key)
            groups[key] = (
                ctx = Dict{Symbol,Symbol}(ctx),
                obs = Dict{Symbol,Symbol}(),
                outputs = Symbol[],
            )
            push!(order, key)
        end
        return groups[key]
    end

    # `ctx` is the intervention context (named `do` in the JSON/R corpus, but
    # `do` is a reserved keyword in Julia so the .jl literal uses `ctx`).
    for e in case.evidence
        group_for!(e.ctx).obs[e.var] = e.val
    end

    for t in case.target
        push!(group_for!(t.ctx).outputs, t.var)
    end

    worlds = CounterfactualQuery[]
    wcount = 0
    for key in order
        g = groups[key]
        name = if isempty(g.ctx)
            :Real
        else
            wcount += 1
            Symbol("W", wcount)
        end
        push!(worlds, CounterfactualQuery(
            name,
            Dict{Symbol,Symbol}(g.ctx),
            Dict{Symbol,Symbol}(g.obs),
            unique(g.outputs),
        ))
    end
    return worlds
end

# Classify the result of identify_counterfactual into a comparable verdict.
function verdict_of(case)
    admg = build_admg(case)
    queries = build_queries(case)
    output_vars = String[string(t.var) for t in case.target]

    res = try
        identify_counterfactual(admg, queries; output_vars=output_vars)
    catch err
        return ("ERROR", "exception", oneline(sprint(showerror, err)))
    end

    if res.identifiable
        return ("ID", "-", "-")
    end

    stage = res.failure_stage === nothing ? "-" : string(res.failure_stage)
    msg = res.error === nothing ? "" : res.error
    # A Step-4 failure whose message announces a FAIL is a genuine
    # non-identifiability verdict; anything else is a tool error to review.
    if res.failure_stage === :step4 && occursin("FAIL", msg)
        return ("FAIL", stage, oneline(msg))
    else
        return ("ERROR", stage, oneline(msg))
    end
end

oneline(s) = replace(replace(strip(s), '\t' => ' '), r"\s*\n\s*" => " ⏎ ")

# --------------------------------------------------------------------------

function main()
    length(ARGS) >= 2 || error("usage: julia run_julia.jl <corpus.jl> <out.tsv>")
    corpus_path = ARGS[1]
    out_path = ARGS[2]

    include(abspath(corpus_path))   # defines const CORPUS

    open(out_path, "w") do io
        for case in CORPUS
            verdict, stage, msg = verdict_of(case)
            println(io, join((case.id, verdict, stage, msg), '\t'))
            println(stderr, "[julia] $(case.id): $(verdict)")
        end
    end
    println("[julia] wrote $(length(CORPUS)) verdicts to $(out_path)")
end

main()
