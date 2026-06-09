"""
Finite-discrete probability primitives for comb-disintegration causal inference.

The convention for `StochChannel.probabilities` is:

    probabilities[output assignment..., input assignment...]

so a channel with no inputs is a state.
"""

struct FiniteVariable
    name::Symbol
    values::Vector{Any}

    function FiniteVariable(name::Symbol, values::AbstractVector)
        isempty(values) && error("variable $(name) must have at least one value")
        length(unique(values)) == length(values) ||
            error("variable $(name) has duplicate values")
        new(name, collect(Any, values))
    end
end

Base.:(==)(x::FiniteVariable, y::FiniteVariable) =
    x.name == y.name && x.values == y.values

Base.hash(x::FiniteVariable, h::UInt) = hash((x.name, x.values), h)

struct JointState
    variables::Vector{FiniteVariable}
    probabilities::Array{Float64}

    function JointState(variables::Vector{FiniteVariable}, probabilities::AbstractArray{<:Real})
        length(unique(v.name for v in variables)) == length(variables) ||
            error("JointState variable names must be unique")
        expected_dims = Tuple(length(v.values) for v in variables)
        size(probabilities) == expected_dims ||
            error("JointState probability dimensions $(size(probabilities)) do not match $(expected_dims)")
        probs = Array{Float64}(probabilities)
        any(probs .< -1e-12) && error("JointState probabilities must be non-negative")
        isapprox(sum(probs), 1.0; atol=1e-9) ||
            error("JointState probabilities must sum to 1, got $(sum(probs))")
        new(variables, probs)
    end
end

struct StochChannel
    inputs::Vector{FiniteVariable}
    outputs::Vector{FiniteVariable}
    probabilities::Array{Float64}

    function StochChannel(
        inputs::Vector{FiniteVariable},
        outputs::Vector{FiniteVariable},
        probabilities::AbstractArray{<:Real};
        check_normalized::Bool=true,
    )
        all_vars = vcat(inputs, outputs)
        length(unique(v.name for v in all_vars)) == length(all_vars) ||
            error("StochChannel input/output variable names must be disjoint and unique")

        expected_dims = Tuple(vcat(length.(getfield.(outputs, :values)),
                                  length.(getfield.(inputs, :values))))
        size(probabilities) == expected_dims ||
            error("StochChannel dimensions $(size(probabilities)) do not match $(expected_dims)")

        probs = Array{Float64}(probabilities)
        any(probs .< -1e-12) && error("StochChannel probabilities must be non-negative")

        if check_normalized
            _check_channel_normalization(probs, length(outputs), length(inputs))
        end
        new(inputs, outputs, probs)
    end
end

variable_names(vars::Vector{FiniteVariable}) = [v.name for v in vars]

function _var_index(vars::Vector{FiniteVariable}, name::Symbol)::Int
    idx = findfirst(v -> v.name == name, vars)
    idx === nothing && error("variable $(name) not found")
    return idx
end

function _variables_by_name(vars::Vector{FiniteVariable}, names::Vector{Symbol})
    length(unique(names)) == length(names) || error("variable names must be unique")
    return [vars[_var_index(vars, name)] for name in names]
end

function _assignment_indices(vars::Vector{FiniteVariable})
    dims = Tuple(length(v.values) for v in vars)
    return CartesianIndices(dims)
end

function _tuple_or_empty(idx::CartesianIndex)
    return Tuple(idx)
end

function _check_channel_normalization(
    probabilities::Array{Float64},
    n_outputs::Int,
    n_inputs::Int,
)
    input_dims = size(probabilities)[(n_outputs + 1):(n_outputs + n_inputs)]
    input_indices = n_inputs == 0 ? [CartesianIndex()] : CartesianIndices(input_dims)

    for input_idx in input_indices
        total = 0.0
        if n_outputs == 0
            total = probabilities[Tuple(input_idx)...]
        else
            output_dims = size(probabilities)[1:n_outputs]
            for output_idx in CartesianIndices(output_dims)
                total += probabilities[Tuple(output_idx)..., Tuple(input_idx)...]
            end
        end
        isapprox(total, 1.0; atol=1e-9) ||
            error("channel column for input $(Tuple(input_idx)) sums to $(total), expected 1")
    end
end

"""
Return the marginal distribution over `keep`, in exactly that variable order.
"""
function marginal(state::JointState, keep::Vector{Symbol})::JointState
    keep == variable_names(state.variables) && return state

    keep_vars = _variables_by_name(state.variables, keep)
    keep_axes = [_var_index(state.variables, name) for name in keep]
    out_dims = Tuple(length(v.values) for v in keep_vars)
    out = zeros(Float64, out_dims)

    for idx in CartesianIndices(state.probabilities)
        in_tuple = Tuple(idx)
        out_tuple = Tuple(in_tuple[axis] for axis in keep_axes)
        out[out_tuple...] += state.probabilities[idx]
    end

    return JointState(keep_vars, out)
end

"""
Return the conditional channel P(outputs | given).

The output tensor order is `outputs..., given...`.
"""
function conditional(
    state::JointState,
    outputs::Vector{Symbol},
    given::Vector{Symbol};
    atol::Float64=1e-12,
)::StochChannel
    isempty(intersect(outputs, given)) ||
        error("outputs and given variables must be disjoint")

    output_vars = _variables_by_name(state.variables, outputs)
    input_vars = _variables_by_name(state.variables, given)

    joint = marginal(state, vcat(outputs, given))
    given_state = marginal(state, given)

    output_dims = Tuple(length(v.values) for v in output_vars)
    input_dims = Tuple(length(v.values) for v in input_vars)
    probs = zeros(Float64, output_dims..., input_dims...)

    output_indices = isempty(output_vars) ? [CartesianIndex()] : CartesianIndices(output_dims)
    input_indices = isempty(input_vars) ? [CartesianIndex()] : CartesianIndices(input_dims)

    for input_idx in input_indices
        denom = given_state.probabilities[Tuple(input_idx)...]
        denom > atol || error("conditioning event $(Tuple(input_idx)) has probability $(denom)")
        for output_idx in output_indices
            probs[Tuple(output_idx)..., Tuple(input_idx)...] =
                joint.probabilities[Tuple(output_idx)..., Tuple(input_idx)...] / denom
        end
    end

    return StochChannel(input_vars, output_vars, probs)
end

"""
Compose channels as `second ∘ first`.

If `first : A -> B` and `second : B -> C`, the result is `A -> C`.
"""
function compose_channels(first::StochChannel, second::StochChannel)::StochChannel
    first.outputs == second.inputs ||
        error("channel mismatch: first outputs $(variable_names(first.outputs)) != second inputs $(variable_names(second.inputs))")

    a_vars = first.inputs
    b_vars = first.outputs
    c_vars = second.outputs

    a_dims = Tuple(length(v.values) for v in a_vars)
    b_dims = Tuple(length(v.values) for v in b_vars)
    c_dims = Tuple(length(v.values) for v in c_vars)

    out = zeros(Float64, c_dims..., a_dims...)
    a_indices = isempty(a_vars) ? [CartesianIndex()] : CartesianIndices(a_dims)
    b_indices = isempty(b_vars) ? [CartesianIndex()] : CartesianIndices(b_dims)
    c_indices = isempty(c_vars) ? [CartesianIndex()] : CartesianIndices(c_dims)

    for a_idx in a_indices
        for c_idx in c_indices
            total = 0.0
            for b_idx in b_indices
                p_b_given_a = first.probabilities[Tuple(b_idx)..., Tuple(a_idx)...]
                p_c_given_b = second.probabilities[Tuple(c_idx)..., Tuple(b_idx)...]
                total += p_c_given_b * p_b_given_a
            end
            out[Tuple(c_idx)..., Tuple(a_idx)...] = total
        end
    end

    return StochChannel(a_vars, c_vars, out)
end

function as_state(channel::StochChannel)::JointState
    isempty(channel.inputs) || error("channel has inputs and cannot be converted to a JointState")
    return JointState(channel.outputs, channel.probabilities)
end
