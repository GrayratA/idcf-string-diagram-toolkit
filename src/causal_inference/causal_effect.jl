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
    require_full_support::Bool=true,
    reconstruction_atol::Float64=1e-8,
)::CausalEffectResult
    try
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
