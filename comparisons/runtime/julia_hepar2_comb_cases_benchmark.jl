using Statistics

using Catlab
using Catlab.WiringDiagrams

include(joinpath(@__DIR__, "..", "..", "src", "admg_compile.jl"))
include(joinpath(@__DIR__, "..", "..", "src", "bn_import.jl"))
include(joinpath(@__DIR__, "..", "..", "src", "causal_inference.jl"))

const CASES = [
    (
        name="hospital_exposure",
        context=Symbol[],
        intervention=[:hospital, :surgery, :choledocholithotomy],
        bridge=[:injections, :transfusion],
        outcome=[:ChHepatitis],
    ),
    (
        name="hospital_exposure_context",
        context=[:hospital],
        intervention=[:surgery, :choledocholithotomy],
        bridge=[:injections, :transfusion],
        outcome=[:ChHepatitis],
    ),
    (
        name="pbc_bilirubin",
        context=Symbol[],
        intervention=[:age, :sex],
        bridge=[:PBC, :Hyperbilirubinemia],
        outcome=[:bilirubin],
    ),
    (
        name="pbc_bilirubin_context",
        context=[:age],
        intervention=[:sex],
        bridge=[:PBC, :Hyperbilirubinemia],
        outcome=[:bilirubin],
    ),
    (
        name="toxic_hepatitis_fatigue",
        context=Symbol[],
        intervention=[:hepatotoxic, :alcoholism],
        bridge=[:THepatitis],
        outcome=[:fatigue],
    ),
    (
        name="toxic_hepatitis_fatigue_context",
        context=[:alcoholism],
        intervention=[:hepatotoxic],
        bridge=[:THepatitis],
        outcome=[:fatigue],
    ),
    (
        name="diabetes_steatosis",
        context=Symbol[],
        intervention=[:diabetes],
        bridge=[:obesity],
        outcome=[:Steatosis],
    ),
    (
        name="gallstone_injection",
        context=Symbol[],
        intervention=[:gallstones],
        bridge=[:choledocholithotomy],
        outcome=[:injections],
    ),
    (
        name="steatosis_cirrhosis",
        context=Symbol[],
        intervention=[:alcoholism, :obesity],
        bridge=[:Steatosis],
        outcome=[:Cirrhosis],
    ),
    (
        name="hospital_hbsag",
        context=Symbol[],
        intervention=[:hospital, :surgery, :choledocholithotomy],
        bridge=[:injections, :transfusion],
        outcome=[:hbsag],
    ),
    (
        name="hospital_hbsag_context",
        context=[:hospital],
        intervention=[:surgery, :choledocholithotomy],
        bridge=[:injections, :transfusion],
        outcome=[:hbsag],
    ),
    (
        name="viral_hbsag",
        context=Symbol[],
        intervention=[:injections, :transfusion, :vh_amn],
        bridge=[:ChHepatitis],
        outcome=[:hbsag],
    ),
    (
        name="viral_hbsag_context",
        context=[:vh_amn],
        intervention=[:injections, :transfusion],
        bridge=[:ChHepatitis],
        outcome=[:hbsag],
    ),
    (
        name="pbc_pressure_ruq",
        context=Symbol[],
        intervention=[:age, :sex],
        bridge=[:PBC, :Hyperbilirubinemia],
        outcome=[:pressure_ruq],
    ),
    (
        name="pbc_inr",
        context=Symbol[],
        intervention=[:age, :sex],
        bridge=[:PBC, :Hyperbilirubinemia],
        outcome=[:inr],
    ),
    (
        name="toxic_hepatitis_two_bridge",
        context=Symbol[],
        intervention=[:hepatotoxic, :alcoholism],
        bridge=[:THepatitis, :RHepatitis],
        outcome=[:fatigue],
    ),
    (
        name="liver_injury_alt",
        context=Symbol[],
        intervention=[:alcoholism, :obesity, :hepatotoxic],
        bridge=[:Steatosis, :THepatitis, :RHepatitis],
        outcome=[:alt],
    ),
    (
        name="liver_injury_alt_context",
        context=[:alcoholism],
        intervention=[:obesity, :hepatotoxic],
        bridge=[:Steatosis, :THepatitis, :RHepatitis],
        outcome=[:alt],
    ),
    (
        name="liver_injury_ggtp",
        context=Symbol[],
        intervention=[:alcoholism, :obesity, :hepatotoxic],
        bridge=[:Steatosis, :THepatitis, :RHepatitis],
        outcome=[:ggtp],
    ),
]

const STAGE_KEYS = (:setup_ms, :proof_ms, :compute_ms, :total_ms)

stage_summary(xs::Vector{Float64}) = (
    min_ms = minimum(xs),
    median_ms = median(xs),
    mean_ms = mean(xs),
    max_ms = maximum(xs),
)

function values_for(var::Symbol)
    var == :choledocholithotomy && return ["none", "past", "recent"]
    var == :ChHepatitis && return ["none", "mild", "chronic"]
    var == :bilirubin && return ["low", "normal", "high"]
    var == :age && return ["young", "old"]
    return ["$(var)_0", "$(var)_1"]
end

function finite_variables(case)
    return [FiniteVariable(v, values_for(v)) for v in vcat(case.context, case.intervention, case.bridge, case.outcome)]
end

function synthetic_joint(case)
    variables = finite_variables(case)
    dims = Tuple(length(v.values) for v in variables)
    probs = zeros(Float64, dims)

    nA = length(case.context) + length(case.intervention)
    nB = length(case.bridge)
    a_dims = dims[1:nA]
    b_dims = dims[(nA + 1):(nA + nB)]
    c_dims = dims[(nA + nB + 1):end]

    for idx in CartesianIndices(probs)
        vals = Tuple(idx) .- 1
        a_vals = vals[1:nA]
        b_vals = vals[(nA + 1):(nA + nB)]
        c_vals = vals[(nA + nB + 1):end]

        p_a = 1.0
        for (i, a) in enumerate(a_vals)
            dim = a_dims[i]
            weights = [1.0 + 0.25i + 0.17k for k in 0:(dim - 1)]
            p_a *= weights[a + 1] / sum(weights)
        end

        p_b = 1.0
        a_score = sum(i * a_vals[i] for i in 1:nA)
        for (j, b) in enumerate(b_vals)
            dim = b_dims[j]
            weights = [1.0 + 0.20j + 0.11a_score + 0.31k for k in 0:(dim - 1)]
            p_b *= weights[b + 1] / sum(weights)
        end

        b_score = sum((j + 1) * b_vals[j] for j in 1:nB)
        p_c = 1.0
        for (k, c_val) in enumerate(c_vals)
            dim = c_dims[k]
            c_weights = [1.0 + 0.13a_score + 0.29b_score + 0.19k + 0.37v for v in 0:(dim - 1)]
            p_c *= c_weights[c_val + 1] / sum(c_weights)
        end

        probs[idx] = p_a * p_b * p_c
    end

    probs ./= sum(probs)
    return probs
end

function benchmark_stages(f::Function; repeats::Int=30, warmups::Int=5)
    for _ in 1:warmups
        f()
    end

    cold = f()
    warm = Dict{Symbol, Vector{Float64}}(k => Float64[] for k in STAGE_KEYS)
    last = cold

    for _ in 1:repeats
        cur = f()
        for k in STAGE_KEYS
            push!(warm[k], cur[k])
        end
        last = cur
    end

    return (
        cold=cold,
        warm=Dict(k => stage_summary(warm[k]) for k in STAGE_KEYS),
        result=last.result,
    )
end

function run_case(hepar2, case)
    total_t0 = time_ns()

    setup_t0 = time_ns()
    A = vcat(case.context, case.intervention)
    display_vars = Set(vcat(A, case.bridge, case.outcome))
    wd = graph_b_to_scm(hepar2.model; outputs=display_vars)
    variables = finite_variables(case)
    probabilities = synthetic_joint(case)
    state = JointState(variables, probabilities)
    witness = CombWitness(A=A, B=case.bridge, C=case.outcome, intervention=case.intervention, context=case.context)
    setup_ms = (time_ns() - setup_t0) / 1e6

    proof_t0 = time_ns()
    proof = prove_cut_comb_subdiagrams(wd, state, witness)
    proof_ms = (time_ns() - proof_t0) / 1e6

    compute_t0 = time_ns()
    result = infer_causal_effect(
        state;
        A=A,
        B=case.bridge,
        C=case.outcome,
        context=case.context,
        intervention=case.intervention,
        validate_reconstruction=false,
    )
    compute_ms = (time_ns() - compute_t0) / 1e6

    total_ms = (time_ns() - total_t0) / 1e6
    return (
        setup_ms=setup_ms,
        proof_ms=proof_ms,
        compute_ms=compute_ms,
        total_ms=total_ms,
        result=(proof=proof, effect=result.effect),
    )
end

function print_summary(case, stats)
    w = stats.warm
    effect = stats.result.effect
    proof = stats.result.proof
    effect_values = join((string(round(x, digits=12)) for x in vec(effect.probabilities)), ",")
    println(
        "impl=julia_causal example=$(case.name) " *
        "warm_total_median_ms=$(round(w[:total_ms].median_ms, digits=3)) " *
        "warm_setup_median_ms=$(round(w[:setup_ms].median_ms, digits=3)) " *
        "warm_proof_median_ms=$(round(w[:proof_ms].median_ms, digits=3)) " *
        "warm_compute_median_ms=$(round(w[:compute_ms].median_ms, digits=3)) " *
        "context_count=$(length(case.context)) " *
        "intervention_count=$(length(case.intervention)) " *
        "bridge_count=$(length(case.bridge)) " *
        "outcome_count=$(length(case.outcome)) " *
        "g_box_count=$(length(proof.g_proof.g_boxes)) " *
        "f_box_count=$(length(proof.f_proof.f_boxes)) " *
        "effect_checksum=$(round(sum(effect.probabilities), digits=6)) " *
        "first_effect=$(round(first(effect.probabilities), digits=6)) " *
        "effect_values=$(effect_values)"
    )
end

repeats = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 30
warmups = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 5
case_filter = length(ARGS) >= 3 ? Set(split(ARGS[3], ",")) : nothing

hepar2 = read_bn_structure(joinpath(@__DIR__, "..", "..", "net", "hepar2.net"))

println("impl=julia_causal benchmark_config repeats=$(repeats) warmups=$(warmups) timer=time_ns")
for case in CASES
    case_filter === nothing || string(case.name) in case_filter || continue
    print_summary(case, benchmark_stages(() -> run_case(hepar2, case); repeats=repeats, warmups=warmups))
end

