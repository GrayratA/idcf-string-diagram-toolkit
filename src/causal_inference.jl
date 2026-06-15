include(joinpath(@__DIR__, "causal_inference", "finite_stoch.jl"))
include(joinpath(@__DIR__, "causal_inference", "comb_disintegration.jl"))
include(joinpath(@__DIR__, "causal_inference", "causal_effect.jl"))
include(joinpath(@__DIR__, "causal_inference", "catlab_comb.jl"))
include(joinpath(@__DIR__, "causal_inference", "markov_validation.jl"))

"""
Complete input object for the current comb-disintegration causal inference
pipeline.

This is the public API boundary. The implementation files under
`src/causal_inference/` are internal layers; users should construct this object
or call the keyword `infer_causal_effect(diagram; ...)` interface below.
"""
struct CausalInferenceProblem
    diagram::WiringDiagram
    variables::Vector{FiniteVariable}
    probabilities::Array{Float64}
    comb_structure::Union{Nothing,CombStructure}
    intervention::Union{Nothing,Vector{Symbol}}
    context::Union{Nothing,Vector{Symbol}}
    bridge::Union{Nothing,Vector{Symbol}}
    outcome::Union{Nothing,Vector{Symbol}}
    witness::Union{Nothing,CombWitness}

    function CausalInferenceProblem(
        diagram::WiringDiagram,
        variables::Vector{FiniteVariable},
        probabilities::AbstractArray{<:Real};
        comb_structure::Union{Nothing,CombStructure}=nothing,
        intervention::Union{Nothing,Vector{Symbol}}=nothing,
        context::Union{Nothing,Vector{Symbol}}=nothing,
        bridge::Union{Nothing,Vector{Symbol}}=nothing,
        outcome::Union{Nothing,Vector{Symbol}}=nothing,
        witness::Union{Nothing,CombWitness}=nothing,
    )
        if comb_structure !== nothing
            (witness !== nothing || intervention !== nothing || bridge !== nothing || outcome !== nothing) &&
                error("provide either comb_structure or witness/intervention/bridge/outcome, not both")
        else
            witness === nothing && intervention === nothing &&
                error("provide either comb_structure, witness, or intervention/outcome")
            witness === nothing && outcome === nothing &&
                error("provide either comb_structure, witness, or intervention/outcome")
        end
        probs = Array{Float64}(probabilities)
        return new(diagram, variables, probs, comb_structure, intervention, context, bridge, outcome, witness)
    end
end

function _finite_variable_from_spec(spec)
    if spec isa FiniteVariable
        return spec
    elseif spec isa Pair
        values = spec.second
        values isa AbstractVector ||
            error("variable specification $(spec) must map to a vector of values")
        return FiniteVariable(Symbol(spec.first), values)
    elseif spec isa Tuple && length(spec) == 2
        values = spec[2]
        values isa AbstractVector ||
            error("variable specification $(spec) must contain a vector of values")
        return FiniteVariable(Symbol(spec[1]), values)
    else
        error("unsupported variable specification $(spec); use FiniteVariable or :X => values")
    end
end

_finite_variables_from_specs(specs) =
    [_finite_variable_from_spec(spec) for spec in specs]

function CausalInferenceProblem(
    diagram::WiringDiagram;
    variables,
    probabilities::AbstractArray{<:Real},
    comb_structure::Union{Nothing,CombStructure}=nothing,
    intervention::Union{Nothing,Vector{Symbol}}=nothing,
    context::Union{Nothing,Vector{Symbol}}=nothing,
    bridge::Union{Nothing,Vector{Symbol}}=nothing,
    outcome::Union{Nothing,Vector{Symbol}}=nothing,
    witness::Union{Nothing,CombWitness}=nothing,
)
    return CausalInferenceProblem(
        diagram,
        _finite_variables_from_specs(variables),
        probabilities;
        comb_structure=comb_structure,
        intervention=intervention,
        context=context,
        bridge=bridge,
        outcome=outcome,
        witness=witness,
    )
end

"""
Run the current causal inference pipeline.

The pipeline does all currently supported inference work:

1. Build the finite observational joint distribution.
2. Construct or discover the comb witness.
3. Validate the Catlab string diagram.
4. Prove the `g : A -> B` and `f : B -> A ⊗ C` subdiagram boundaries.
5. Apply comb disintegration and compute `P(C | do(A))`.

Returns a `CombOnlyCausalEffectResult`.
"""
function infer_causal_effect(
    problem::CausalInferenceProblem;
    require_full_support::Bool=true,
    reconstruction_atol::Float64=1e-8,
    validate_reconstruction::Bool=true,
)::CombOnlyCausalEffectResult
    observational_joint = JointState(problem.variables, problem.probabilities)

    return infer_causal_effect(
        problem.diagram,
        observational_joint;
        comb_structure=problem.comb_structure,
        witness=problem.witness,
        intervention=problem.intervention,
        context=problem.context,
        bridge=problem.bridge,
        outcome=problem.outcome,
        require_full_support=require_full_support,
        reconstruction_atol=reconstruction_atol,
        validate_reconstruction=validate_reconstruction,
    )
end

function infer_causal_effect(
    diagram::WiringDiagram;
    variables,
    probabilities::AbstractArray{<:Real},
    comb_structure::Union{Nothing,CombStructure}=nothing,
    intervention::Union{Nothing,Vector{Symbol}}=nothing,
    context::Union{Nothing,Vector{Symbol}}=nothing,
    bridge::Union{Nothing,Vector{Symbol}}=nothing,
    outcome::Union{Nothing,Vector{Symbol}}=nothing,
    witness::Union{Nothing,CombWitness}=nothing,
    require_full_support::Bool=true,
    reconstruction_atol::Float64=1e-8,
    validate_reconstruction::Bool=true,
)::CombOnlyCausalEffectResult
    problem = CausalInferenceProblem(
        diagram;
        variables=variables,
        probabilities=probabilities,
        comb_structure=comb_structure,
        intervention=intervention,
        context=context,
        bridge=bridge,
        outcome=outcome,
        witness=witness,
    )

    return infer_causal_effect(
        problem;
        require_full_support=require_full_support,
        reconstruction_atol=reconstruction_atol,
        validate_reconstruction=validate_reconstruction,
    )
end

"""
Return user-readable labels for Catlab box ids.

Subdiagram proofs store box ids because Catlab wiring diagrams are indexed
internally. Examples and reports should usually display these labels instead.
"""
function box_labels(diagram::WiringDiagram, ids::AbstractVector{<:Integer})
    return [box(diagram, id).value for id in ids]
end
