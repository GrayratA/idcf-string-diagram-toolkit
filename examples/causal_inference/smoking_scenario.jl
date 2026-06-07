using Catlab
using Catlab.Theories
using Catlab.Programs
using Catlab.WiringDiagrams

include(joinpath(@__DIR__, "..", "..", "src", "causal_inference.jl"))

# Smoking example for causal inference by comb disintegration.
#
# Variables:
#   S = smoking
#   T = tar
#   C = cancer
#
# Query:
#   P(C | do(S))
#
# The string diagram below decomposes the joint state
# omega : I -> S x T x C. Box t is the g-region. Boxes h, s, and c form the
# f-region after the T wire is cut.

@present SmokingInferenceExample(FreeCartesianCategory) begin
    (S, T, C, H)::Ob

    # h is an internal latent source.
    h::Hom(munit(), H)

    # s produces the factual smoking value S.
    s::Hom(H, S)

    # t is the bridge channel g : S -> T.
    t::Hom(S, T)

    # c produces the cancer outcome C from T and the latent H.
    c::Hom(T ⊗ H, C)
end

# This is omega : I -> S x T x C. It has no external inputs.
smoking_diagram = @program SmokingInferenceExample () begin
    h_val = h()
    s_val = s(h_val)
    t_val = t(s_val)
    c_val = c(t_val, h_val)

    return s_val, t_val, c_val
end

# probabilities[s, t, c] follows the variable order [S, T, C].
probs = zeros(Float64, 2, 2, 2)
probs[1, 1, 1] = 0.50
probs[1, 1, 2] = 0.10
probs[1, 2, 1] = 0.01
probs[1, 2, 2] = 0.02
probs[2, 1, 1] = 0.10
probs[2, 1, 2] = 0.05
probs[2, 2, 1] = 0.02
probs[2, 2, 2] = 0.20

result = infer_causal_effect(
    smoking_diagram;
    variables=[
        :S => ["no_smoke", "smoke"],
        :T => ["low_tar", "high_tar"],
        :C => ["no_cancer", "cancer"],
    ],
    probabilities=probs,
    intervention=[:S],
    outcome=[:C],
)

println("== Smoking string diagram input ==")
println("diagram inputs  = ", input_ports(smoking_diagram))
println("diagram outputs = ", output_ports(smoking_diagram))
println()

println("== Comb witness ==")
witness = result.witness
println("A = ", witness.A, "  # intervention variable")
println("B = ", witness.B, "  # bridge variable")
println("C = ", witness.C, "  # outcome variable")
println()

println("== Subdiagram proof ==")
println("computable = ", result.computable)
println("failure    = ", result.failure_reason)
println("g boxes    = ", result.subdiagram_proof === nothing ? nothing : box_labels(smoking_diagram, result.subdiagram_proof.g_proof.g_boxes))
println("f boxes    = ", result.subdiagram_proof === nothing ? nothing : box_labels(smoking_diagram, result.subdiagram_proof.f_proof.f_boxes))
println()

println("== Causal effect P(C | do(S)) ==")
if result.computable
    effect = result.effect
    for (s_idx, s_value) in enumerate(effect.inputs[1].values)
        println("do(S = ", s_value, ")")
        for (c_idx, c_value) in enumerate(effect.outputs[1].values)
            p = effect.probabilities[c_idx, s_idx]
            println("  P(C = ", c_value, " | do(S = ", s_value, ")) = ", round(p; digits=6))
        end
    end
end
