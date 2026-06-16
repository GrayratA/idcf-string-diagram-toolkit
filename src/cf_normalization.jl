struct CFEvent
    var::Symbol
    value::Union{Symbol,Nothing}
    context::Dict{Symbol,Symbol}
    role::Symbol
end

struct NormalizedCFQuery
    gamma::Vector{CFEvent}
    delta::Vector{CFEvent}
    queries::Vector{CounterfactualQuery}
    contradictions::Vector{String}
end

_cf_ctx_key(ctx::Dict{Symbol,Symbol}) =
    isempty(ctx) ? "" : join(["$(k)=$(v)" for (k, v) in sort(collect(ctx); by=x -> string(x[1]))], "|")

_cf_event_key(e::CFEvent) = (
    e.role == :target ? 1 : e.role == :evidence ? 2 : 3,
    string(e.var),
    _cf_ctx_key(e.context),
    e.value === nothing ? "" : string(e.value),
)

function _cf_directed_edges(model_or_base)
    if model_or_base isa ADMGModel || model_or_base isa ConfoundedModel
        return model_or_base.directed
    end
    return Pair{Symbol,Symbol}[]
end

function _cf_ancestors(edges::Vector{Pair{Symbol,Symbol}}, var::Symbol)
    parents = Dict{Symbol,Vector{Symbol}}()
    for e in edges
        push!(get!(parents, e.second, Symbol[]), e.first)
    end

    seen = Set{Symbol}()
    stack = copy(get(parents, var, Symbol[]))
    while !isempty(stack)
        v = pop!(stack)
        v in seen && continue
        push!(seen, v)
        append!(stack, get(parents, v, Symbol[]))
    end
    return seen
end

function _cf_events_from_queries(queries::Vector{CounterfactualQuery})
    gamma = CFEvent[]
    delta = CFEvent[]

    for q in queries
        ctx = Dict(q.interventions)

        for out in q.outputs
            push!(gamma, CFEvent(out, nothing, Dict(ctx), :target))
        end

        for (var, val) in q.observations
            # Observations are conditioning/event constraints even when they are
            # attached to a target world.
            push!(delta, CFEvent(var, val, Dict(ctx), :evidence))
        end
    end

    return gamma, delta
end

function _cf_factual_observations(delta::Vector{CFEvent})
    factual = Dict{Symbol,Symbol}()
    contradictions = String[]

    for e in delta
        isempty(e.context) || continue
        e.value === nothing && continue
        if haskey(factual, e.var) && factual[e.var] != e.value
            push!(contradictions, "Conflicting factual observations for $(e.var): $(factual[e.var]) and $(e.value)")
        else
            factual[e.var] = e.value
        end
    end

    return factual, contradictions
end

function _cf_normalize_event(
    e::CFEvent,
    factual::Dict{Symbol,Symbol},
    directed_edges::Vector{Pair{Symbol,Symbol}};
    apply_consistency::Bool=false,
    reduce_interventions::Bool=true,
)
    contradictions = String[]
    ctx = Dict(e.context)

    # Self-intervention consistency: X_x=x is tautological, X_x=x' is
    # contradictory when the event value is known.
    if apply_consistency && haskey(ctx, e.var) && e.value !== nothing
        if ctx[e.var] != e.value
            push!(contradictions, "Contradiction: $(e.var)_{$(ctx[e.var])} = $(e.value)")
        else
            delete!(ctx, e.var)
        end
    end

    # If the conditioning event fixes an intervention variable to the same
    # value, consistency lets us remove that intervention from the event context.
    if apply_consistency
        for (var, val) in collect(ctx)
            if haskey(factual, var) && factual[var] == val
                delete!(ctx, var)
            end
        end
    end

    # Intervention reduction: interventions on non-ancestors cannot affect the
    # counterfactual variable in a directed causal graph. For non-graph inputs we
    # skip this safely by passing an empty edge list.
    if reduce_interventions && !isempty(directed_edges)
        anc = _cf_ancestors(directed_edges, e.var)
        for var in collect(keys(ctx))
            var in anc || delete!(ctx, var)
        end
    end

    return CFEvent(e.var, e.value, ctx, e.role), contradictions
end

function _cf_merge_events(events::Vector{CFEvent})
    merged = Dict{Tuple{Symbol,Symbol,String},CFEvent}()
    contradictions = String[]

    for e in events
        key = (e.role, e.var, _cf_ctx_key(e.context))
        if haskey(merged, key)
            old = merged[key]
            if old.value !== nothing && e.value !== nothing && old.value != e.value
                push!(contradictions, "Conflicting values for $(e.var) in context $(_cf_ctx_key(e.context)): $(old.value) and $(e.value)")
            elseif old.value === nothing && e.value !== nothing
                merged[key] = e
            end
        else
            merged[key] = e
        end
    end

    out = collect(values(merged))
    sort!(out; by=_cf_event_key)
    return out, contradictions
end

function _cf_queries_from_events(gamma::Vector{CFEvent}, delta::Vector{CFEvent})
    target_groups = Dict{String,NamedTuple{(:context, :outputs),Tuple{Dict{Symbol,Symbol},Vector{Symbol}}}}()
    evidence_groups = Dict{String,NamedTuple{(:context, :observations),Tuple{Dict{Symbol,Symbol},Dict{Symbol,Symbol}}}}()

    for e in gamma
        key = _cf_ctx_key(e.context)
        group = get!(target_groups, key) do
            (context=Dict(e.context), outputs=Symbol[])
        end
        e.var in group.outputs || push!(group.outputs, e.var)
    end

    for e in delta
        e.value === nothing && continue
        key = _cf_ctx_key(e.context)
        group = get!(evidence_groups, key) do
            (context=Dict(e.context), observations=Dict{Symbol,Symbol}())
        end
        group.observations[e.var] = e.value
    end

    queries = CounterfactualQuery[]

    target_values = sort(collect(values(target_groups)); by=g -> (_cf_ctx_key(g.context), join(string.(sort(g.outputs)), "|")))
    for (i, group) in enumerate(target_values)
        push!(queries, CounterfactualQuery(Symbol("T", i), group.context, Dict{Symbol,Symbol}(), sort(group.outputs)))
    end

    if haskey(evidence_groups, "")
        group = evidence_groups[""]
        push!(queries, CounterfactualQuery(:Real, Dict{Symbol,Symbol}(), group.observations, Symbol[]))
        delete!(evidence_groups, "")
    end

    cf_values = sort(collect(values(evidence_groups)); by=g -> (_cf_ctx_key(g.context), _cf_ctx_key(g.observations)))
    for (i, group) in enumerate(cf_values)
        push!(queries, CounterfactualQuery(Symbol("Ev", i), group.context, group.observations, Symbol[]))
    end

    return queries
end

function normalize_counterfactual_query(
    model_or_base,
    queries::Vector{CounterfactualQuery};
    apply_consistency::Bool=false,
    reduce_interventions::Bool=true,
)
    gamma, delta = _cf_events_from_queries(queries)
    factual, contradictions = _cf_factual_observations(delta)
    directed_edges = _cf_directed_edges(model_or_base)

    norm_gamma = CFEvent[]
    norm_delta = CFEvent[]

    for e in gamma
        ne, errs = _cf_normalize_event(
            e,
            factual,
            directed_edges;
            apply_consistency=apply_consistency,
            reduce_interventions=reduce_interventions,
        )
        append!(contradictions, errs)
        push!(norm_gamma, ne)
    end
    for e in delta
        ne, errs = _cf_normalize_event(
            e,
            factual,
            directed_edges;
            apply_consistency=apply_consistency,
            reduce_interventions=reduce_interventions,
        )
        append!(contradictions, errs)
        push!(norm_delta, ne)
    end

    norm_gamma, errs = _cf_merge_events(norm_gamma)
    append!(contradictions, errs)
    norm_delta, errs = _cf_merge_events(norm_delta)
    append!(contradictions, errs)

    return NormalizedCFQuery(
        norm_gamma,
        norm_delta,
        _cf_queries_from_events(norm_gamma, norm_delta),
        contradictions,
    )
end

normalize_counterfactual_query(queries::Vector{CounterfactualQuery}; kwargs...) =
    normalize_counterfactual_query(nothing, queries; kwargs...)
