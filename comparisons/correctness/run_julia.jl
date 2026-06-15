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
#   * one "Real" world holding every evidence event with an empty do-context
#     (these are plain observations);
#   * one world per evidence event that carries a do-context;
#   * one world per target event, with the target variable placed in `outputs`.
#
# If the toolkit's verdict were sensitive to this grouping, that would itself be
# a defect worth surfacing -- which is exactly what the differential test does.
# --------------------------------------------------------------------------

function build_admg(case)
    directed = [Pair(a, b) for (a, b) in case.directed]
    bidirected = [Pair(a, b) for (a, b) in case.bidirected]
    return ADMGModel(directed, bidirected)
end

function build_queries(case)
    worlds = CounterfactualQuery[]

    # `ctx` is the intervention context (named `do` in the JSON/R corpus, but
    # `do` is a reserved keyword in Julia so the .jl literal uses `ctx`).
    real_obs = Dict{Symbol,Symbol}()
    for e in case.evidence
        if isempty(e.ctx)
            real_obs[e.var] = e.val
        end
    end
    if !isempty(real_obs)
        push!(worlds, CounterfactualQuery(:Real, Dict{Symbol,Symbol}(), real_obs, Symbol[]))
    end

    wcount = 0
    for e in case.evidence
        if !isempty(e.ctx)
            wcount += 1
            push!(worlds, CounterfactualQuery(Symbol("Ev", wcount),
                                              Dict(e.ctx), Dict(e.var => e.val), Symbol[]))
        end
    end

    tcount = 0
    for t in case.target
        tcount += 1
        push!(worlds, CounterfactualQuery(Symbol("T", tcount),
                                          Dict(t.ctx), Dict{Symbol,Symbol}(), [t.var]))
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
