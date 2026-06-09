"""
interface for finite-discrete causal inference by comb disintegration.
"""

struct CausalEffectResult
    computable::Bool
    effect::Union{Nothing,StochChannel}
    comb::Union{Nothing,TwoComb}
    reconstructed::Union{Nothing,JointState}
    reconstruction_ok::Bool
    failure_reason::Union{Nothing,String}
end

"""
Infer the interventional channel C | do(A) from an observational joint P(A,B,C).

This implements the finite-discrete comb-disintegration pattern:

    P(A,B,C) -> f : B -> A ⊗ C, g : A -> B -> P(C | do(A))

`A`, `B`, and `C` are variable-name groups. They may each contain multiple
finite variables, but must be pairwise disjoint.
"""
function infer_causal_effect(
    state::JointState;
    A::Vector{Symbol},
    B::Vector{Symbol},
    C::Vector{Symbol},
    context::Vector{Symbol}=Symbol[],
    intervention::Union{Nothing,Vector{Symbol}}=nothing,
    require_full_support::Bool=true,
    reconstruction_atol::Float64=1e-8,
    validate_reconstruction::Bool=true,
)::CausalEffectResult
    try
        if !isempty(context) || intervention !== nothing
            X = intervention === nothing ? A : intervention
            all(x -> x in A, X) ||
                error("intervention variables must be contained in A")
            all(x -> x in A, context) ||
                error("context variables must be contained in A")
            Set(A) == union(Set(context), Set(X)) ||
                error("A must be exactly context union intervention for context-aware inference")

            effect = cut_comb_direct_context(
                state;
                context=context,
                intervention=X,
                B=B,
                C=C,
                require_full_support=require_full_support,
            )
            return CausalEffectResult(
                true,
                effect,
                nothing,
                nothing,
                true,
                nothing,
            )
        end

        if !validate_reconstruction
            effect = cut_comb_direct(
                state;
                A=A,
                B=B,
                C=C,
                require_full_support=require_full_support,
            )
            return CausalEffectResult(
                true,
                effect,
                nothing,
                nothing,
                true,
                nothing,
            )
        end

        comb = comb_disintegrate(
            state;
            A=A,
            B=B,
            C=C,
            require_full_support=require_full_support,
        )

        reconstructed = reconstruct_joint(comb)
        expected = marginal(state, vcat(A, B, C))
        reconstruction_ok = isapprox(
            reconstructed.probabilities,
            expected.probabilities;
            atol=reconstruction_atol,
        )

        if !reconstruction_ok
            return CausalEffectResult(
                false,
                nothing,
                comb,
                reconstructed,
                false,
                "comb reconstruction did not match the observational joint",
            )
        end

        effect = cut_comb(comb)
        return CausalEffectResult(
            true,
            effect,
            comb,
            reconstructed,
            true,
            nothing,
        )
    catch err
        return CausalEffectResult(
            false,
            nothing,
            nothing,
            nothing,
            false,
            sprint(showerror, err),
        )
    end
end
