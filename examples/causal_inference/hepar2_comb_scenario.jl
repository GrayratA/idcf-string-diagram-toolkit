include(joinpath(@__DIR__, "..", "..", "src", "admg_compile.jl"))
include(joinpath(@__DIR__, "..", "..", "src", "bn_import.jl"))
include(joinpath(@__DIR__, "..", "..", "src", "causal_inference.jl"))

# HEPAR2 comb-disintegration demo.
#
# This example uses the full HEPAR2 Bayesian-network structure from
# net/hepar2.net and selects a comb-shaped causal-inference query inside it:
#
#   A = {hospital, surgery, choledocholithotomy}
#   B = {injections, transfusion}
#   C = {ChHepatitis}
#
# Structurally, HEPAR2 contains:
#
#   hospital, surgery, choledocholithotomy -> injections
#   hospital, surgery, choledocholithotomy -> transfusion
#   injections, transfusion -> ChHepatitis
#
# The full graph also contains many other clinical variables; they remain in
# the string diagram and are assigned to the f-region if the comb boundary check
# succeeds.
#
# The probability table below is a synthetic joint table over the selected
# variables. It is used only to demonstrate the comb-disintegration interface;
# it is not the original HEPAR2 CPT parameterization.

hepar2 = read_bn_structure(joinpath(@__DIR__, "..", "..", "net", "hepar2.net"))
display_vars = Set([
    :hospital,
    :surgery,
    :choledocholithotomy,
    :injections,
    :transfusion,
    :ChHepatitis,
])
hepar2_diagram = graph_b_to_scm(hepar2.model; outputs=display_vars)

variables = [
    :hospital => ["outpatient", "inpatient"],
    :surgery => ["no_surgery", "surgery"],
    :choledocholithotomy => ["none", "past", "recent"],
    :injections => ["no_injections", "injections"],
    :transfusion => ["no_transfusion", "transfusion"],
    :ChHepatitis => ["none", "mild", "chronic"],
]

# probabilities[hospital, surgery, choledocholithotomy, injections, transfusion, ChHepatitis]
probs = zeros(Float64, 2, 2, 3, 2, 2, 3)
p_hospital = [0.70, 0.30]
p_surgery = [0.62, 0.38]
p_chole = [0.58, 0.27, 0.15]

for idx in CartesianIndices(probs)
    hospital, surgery, chole, injections, transfusion, hepatitis = Tuple(idx) .- 1

    p_injections = 0.08 + 0.30hospital + 0.22surgery + 0.12chole
    p_injections = clamp(p_injections, 0.02, 0.92)

    p_transfusion = 0.05 + 0.35hospital + 0.28surgery + 0.10chole
    p_transfusion = clamp(p_transfusion, 0.02, 0.94)

    hepatitis_raw = [
        4.0 - 0.35injections - 0.50transfusion,
        0.9 + 0.25injections + 0.25transfusion,
        0.25 + 0.65injections + 0.80transfusion,
    ]
    hepatitis_dist = hepatitis_raw ./ sum(hepatitis_raw)

    probs[idx] = p_hospital[hospital + 1] *
                 p_surgery[surgery + 1] *
                 p_chole[chole + 1] *
                 (injections == 1 ? p_injections : 1.0 - p_injections) *
                 (transfusion == 1 ? p_transfusion : 1.0 - p_transfusion) *
                 hepatitis_dist[hepatitis + 1]
end
probs ./= sum(probs)

result = infer_causal_effect(
    hepar2_diagram;
    variables=variables,
    probabilities=probs,
    comb_structure=CombStructure(
        context=Symbol[],
        intervention=[:hospital, :surgery, :choledocholithotomy],
        bridge=[:injections, :transfusion],
        outcome=[:ChHepatitis],
    ),
)

println("== HEPAR2 comb-disintegration demo ==")
println("HEPAR2 variables        = ", length(hepar2.nodes))
println("HEPAR2 directed edges   = ", length(hepar2.model.directed))
println("diagram internal boxes  = ", count(b -> b > 0, box_ids(hepar2_diagram)))
println("diagram outputs         = ", output_ports(hepar2_diagram))
println()

println("== Comb witness selected from HEPAR2 ==")
witness = result.witness
println("context      = ", witness.context)
println("intervention = ", witness.intervention)
println("bridge       = ", witness.B)
println("outcome      = ", witness.C)
println()

println("== Automatic subdiagram proof ==")
println("computable = ", result.computable)
println("failure    = ", result.failure_reason)
if result.subdiagram_proof !== nothing
    g_labels = box_labels(hepar2_diagram, result.subdiagram_proof.g_proof.g_boxes)
    f_count = length(result.subdiagram_proof.f_proof.f_boxes)
    println("g boxes    = ", g_labels)
    println("f box count= ", f_count)
end
println()

if result.computable
    effect = result.effect
    println("== Causal effect P(ChHepatitis | do(hospital, surgery, choledocholithotomy)) ==")
    for hospital_idx in eachindex(effect.inputs[1].values)
        hospital_value = effect.inputs[1].values[hospital_idx]
        for surgery_idx in eachindex(effect.inputs[2].values)
            surgery_value = effect.inputs[2].values[surgery_idx]
            for chole_idx in eachindex(effect.inputs[3].values)
                chole_value = effect.inputs[3].values[chole_idx]
                println(
                    "do(hospital = ", hospital_value,
                    ", surgery = ", surgery_value,
                    ", choledocholithotomy = ", chole_value,
                    ")",
                )
                for c_idx in eachindex(effect.outputs[1].values)
                    c_value = effect.outputs[1].values[c_idx]
                    p = effect.probabilities[c_idx, hospital_idx, surgery_idx, chole_idx]
                    println("  P(ChHepatitis = ", c_value, ") = ", round(p; digits=6))
                end
            end
        end
    end
end
