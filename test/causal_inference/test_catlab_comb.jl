@testset "Catlab comb-only interface" begin
    S = FiniteVariable(:S, [0, 1])
    T = FiniteVariable(:T, [0, 1])
    C = FiniteVariable(:C, [0, 1])

    probs = zeros(Float64, 2, 2, 2)
    probs[1, 1, 1] = 0.50
    probs[1, 1, 2] = 0.10
    probs[1, 2, 1] = 0.01
    probs[1, 2, 2] = 0.02
    probs[2, 1, 1] = 0.10
    probs[2, 1, 2] = 0.05
    probs[2, 2, 1] = 0.02
    probs[2, 2, 2] = 0.20
    state = JointState([S, T, C], probs)

    diagram = WiringDiagram(Any[:T], Any[:S, :T, :C])
    f_s = add_box!(diagram, Box(:f_S, Any[], Any[:S]))
    f_t = add_box!(diagram, Box(:f_T, Any[:S], Any[:T]))
    f_c = add_box!(diagram, Box(:f_C, Any[:S, :T], Any[:C]))
    add_wire!(diagram, Port(f_s, OutputPort, 1) => Port(f_t, InputPort, 1))
    add_wire!(diagram, Port(f_s, OutputPort, 1) => Port(f_c, InputPort, 1))
    add_wire!(diagram, Port(input_id(diagram), OutputPort, 1) => Port(f_c, InputPort, 2))
    add_wire!(diagram, Port(f_s, OutputPort, 1) => Port(output_id(diagram), InputPort, 1))
    add_wire!(diagram, Port(f_t, OutputPort, 1) => Port(output_id(diagram), InputPort, 2))
    add_wire!(diagram, Port(f_c, OutputPort, 1) => Port(output_id(diagram), InputPort, 3))
    witness = CombWitness(
        A=[:S],
        B=[:T],
        C=[:C],
        intervention=[:S],
    )
    auto_structure = CombStructure(
        A=[:S],
        B=[:T],
        C=[:C],
        intervention=[:S],
    )
    user_structure = CombStructure(
        context=Symbol[],
        intervention=[:S],
        bridge=[:T],
        outcome=[:C],
    )
    explicit_structure = CombStructure(
        A=[:S],
        B=[:T],
        C=[:C],
        intervention=[:S],
        g_boxes=[:f_T],
        f_boxes=[:f_S, :f_C],
        cover_all_boxes=true,
    )

    result = infer_causal_effect(diagram, state; witness=witness)
    problem = CausalInferenceProblem(
        diagram;
        variables=[S, T, C],
        probabilities=probs,
        comb_structure=auto_structure,
    )
    problem_result = infer_causal_effect(problem)
    user_problem = CausalInferenceProblem(
        diagram;
        variables=[S, T, C],
        probabilities=probs,
        comb_structure=user_structure,
    )
    user_problem_result = infer_causal_effect(user_problem)
    high_level_result = infer_causal_effect(
        diagram;
        variables=[S, T, C],
        probabilities=probs,
        intervention=[:S],
        bridge=[:T],
        outcome=[:C],
    )
    explicit_result = infer_causal_effect(
        diagram;
        variables=[S, T, C],
        probabilities=probs,
        comb_structure=explicit_structure,
    )

    @test result.computable
    @test problem_result.computable
    @test user_problem_result.computable
    @test high_level_result.computable
    @test explicit_result.computable
    @test problem_result.effect.probabilities ≈ result.effect.probabilities
    @test user_problem_result.effect.probabilities ≈ result.effect.probabilities
    @test high_level_result.effect.probabilities ≈ result.effect.probabilities
    @test explicit_result.effect.probabilities ≈ result.effect.probabilities
    @test explicit_result.subdiagram_proof.g_proof.g_boxes == [f_t]
    @test explicit_result.subdiagram_proof.f_proof.f_boxes == [f_s, f_c]
    @test result.failure_reason === nothing
    @test result.effect.probabilities[:, 1] ≈ [0.74652237, 0.25347763] atol=1e-8
    @test result.effect.probabilities[:, 2] ≈ [0.45770270, 0.54229730] atol=1e-8
    @test result.surgery_diagram !== nothing
    @test input_ports(result.surgery_diagram) == Any[:S]
    @test output_ports(result.surgery_diagram) == Any[:C]
    @test result.subdiagram_proof !== nothing
    @test result.subdiagram_proof.g_proof.g_boxes == [f_t]
    @test result.subdiagram_proof.f_proof.f_boxes == [f_s, f_c]

    bad_structure = CombStructure(
        A=[:S],
        B=[:T],
        C=[:C],
        intervention=[:S],
        g_boxes=[:f_C],
        f_boxes=[:f_S, :f_T],
    )
    bad_explicit = infer_causal_effect(
        diagram;
        variables=[S, T, C],
        probabilities=probs,
        comb_structure=bad_structure,
    )
    @test !bad_explicit.computable
    @test occursin("could not prove g subdiagram", bad_explicit.failure_reason)

    incomplete_structure = CombStructure(
        A=[:S],
        B=[:T],
        C=[:C],
        intervention=[:S],
        g_boxes=[:f_T],
        f_boxes=[:f_C],
        cover_all_boxes=true,
    )
    incomplete = infer_causal_effect(
        diagram;
        variables=[S, T, C],
        probabilities=probs,
        comb_structure=incomplete_structure,
    )
    @test !incomplete.computable
    @test occursin("expected boundary", incomplete.failure_reason)

    one_sided_structure = CombStructure(
        A=[:S],
        B=[:T],
        C=[:C],
        intervention=[:S],
        g_boxes=[:f_T],
    )
    one_sided = infer_causal_effect(
        diagram;
        variables=[S, T, C],
        probabilities=probs,
        comb_structure=one_sided_structure,
    )
    @test !one_sided.computable
    @test occursin("provide both g_boxes and f_boxes", one_sided.failure_reason)

    bad_diagram = WiringDiagram([], Any[:S, :C])
    failed = infer_causal_effect(bad_diagram, state; witness=witness)

    @test !failed.computable
    @test occursin("not found in diagram", failed.failure_reason)
    @test failed.surgery_diagram === nothing
end

@testset "diagram-aware Markov validation in pipeline" begin
    S = FiniteVariable(:S, [0, 1])
    T = FiniteVariable(:T, [0, 1])
    C = FiniteVariable(:C, [0, 1])

    # This table violates S ⟂ C | T for the chain S -> T -> C.
    probs = zeros(Float64, 2, 2, 2)
    probs[1, 1, 1] = 0.50
    probs[1, 1, 2] = 0.10
    probs[1, 2, 1] = 0.01
    probs[1, 2, 2] = 0.02
    probs[2, 1, 1] = 0.10
    probs[2, 1, 2] = 0.05
    probs[2, 2, 1] = 0.02
    probs[2, 2, 2] = 0.20
    state = JointState([S, T, C], probs)

    diagram = WiringDiagram(Any[:T], Any[:S, :T, :C])
    f_s = add_box!(diagram, Box(:f_S, Any[], Any[:S]))
    f_t = add_box!(diagram, Box(:f_T, Any[:S], Any[:T]))
    f_c = add_box!(diagram, Box(:f_C, Any[:T], Any[:C]))
    add_wire!(diagram, Port(f_s, OutputPort, 1) => Port(f_t, InputPort, 1))
    add_wire!(diagram, Port(f_t, OutputPort, 1) => Port(f_c, InputPort, 1))
    add_wire!(diagram, Port(f_s, OutputPort, 1) => Port(output_id(diagram), InputPort, 1))
    add_wire!(diagram, Port(f_t, OutputPort, 1) => Port(output_id(diagram), InputPort, 2))
    add_wire!(diagram, Port(f_c, OutputPort, 1) => Port(output_id(diagram), InputPort, 3))

    result = infer_causal_effect(
        diagram,
        state;
        witness=CombWitness(A=[:S], B=[:T], C=[:C], intervention=[:S]),
    )

    @test !result.computable
    @test occursin("Markov validation failed", result.failure_reason)
end

@testset "subdiagram boundary checker" begin
    wd = WiringDiagram(Any[:S, :Z], Any[:C])

    f_t = add_box!(wd, Box(:f_T, Any[:S, :Z], Any[:T]))
    f_c = add_box!(wd, Box(:f_C, Any[:T], Any[:C]))

    add_wire!(wd, Port(input_id(wd), OutputPort, 1) => Port(f_t, InputPort, 1))
    add_wire!(wd, Port(input_id(wd), OutputPort, 2) => Port(f_t, InputPort, 2))
    add_wire!(wd, Port(f_t, OutputPort, 1) => Port(f_c, InputPort, 1))
    add_wire!(wd, Port(f_c, OutputPort, 1) => Port(output_id(wd), InputPort, 1))

    b_t = subdiagram_boundary(wd, [f_t])
    @test Set(b_t.input_vars) == Set([:S, :Z])
    @test b_t.output_vars == [:T]
    @test length(b_t.input_wires) == 2
    @test length(b_t.output_wires) == 1
    @test isempty(b_t.internal_wires)
    @test boundary_matches(b_t; inputs=[:S, :Z], outputs=[:T])
    @test !boundary_matches(b_t; inputs=[:S], outputs=[:T])

    b_c = subdiagram_boundary(wd, [f_c])
    @test b_c.input_vars == [:T]
    @test b_c.output_vars == [:C]
    @test boundary_matches(b_c; inputs=[:T], outputs=[:C])

    b_all = subdiagram_boundary(wd, [f_t, f_c])
    @test Set(b_all.input_vars) == Set([:S, :Z])
    @test b_all.output_vars == [:C]
    @test length(b_all.internal_wires) == 1
    @test boundary_matches(b_all; inputs=[:S, :Z], outputs=[:C])
end

@testset "g subdiagram proof" begin
    S = FiniteVariable(:S, [0, 1])
    T = FiniteVariable(:T, [0, 1])
    C = FiniteVariable(:C, [0, 1])
    state = JointState([S, T, C], fill(1.0 / 8.0, 2, 2, 2))

    wd = WiringDiagram(Any[:S], Any[:C])
    f_t = add_box!(wd, Box(:f_T, Any[:S], Any[:T]))
    f_c = add_box!(wd, Box(:f_C, Any[:T], Any[:C]))
    add_wire!(wd, Port(input_id(wd), OutputPort, 1) => Port(f_t, InputPort, 1))
    add_wire!(wd, Port(f_t, OutputPort, 1) => Port(f_c, InputPort, 1))
    add_wire!(wd, Port(f_c, OutputPort, 1) => Port(output_id(wd), InputPort, 1))

    witness = CombWitness(A=[:S], B=[:T], C=[:C], intervention=[:S])
    proof = prove_g_subdiagram(wd, state, witness)

    @test proof.witness == witness
    @test proof.g_boxes == [f_t]
    @test proof.g_boundary.input_vars == [:S]
    @test proof.g_boundary.output_vars == [:T]

    Z = FiniteVariable(:Z, [0, 1])
    bad_state = JointState([S, Z, T, C], fill(1.0 / 16.0, 2, 2, 2, 2))
    bad_wd = WiringDiagram(Any[:S, :Z], Any[:C])
    bad_f_t = add_box!(bad_wd, Box(:f_T, Any[:S, :Z], Any[:T]))
    bad_f_c = add_box!(bad_wd, Box(:f_C, Any[:T], Any[:C]))
    add_wire!(bad_wd, Port(input_id(bad_wd), OutputPort, 1) => Port(bad_f_t, InputPort, 1))
    add_wire!(bad_wd, Port(input_id(bad_wd), OutputPort, 2) => Port(bad_f_t, InputPort, 2))
    add_wire!(bad_wd, Port(bad_f_t, OutputPort, 1) => Port(bad_f_c, InputPort, 1))
    add_wire!(bad_wd, Port(bad_f_c, OutputPort, 1) => Port(output_id(bad_wd), InputPort, 1))

    @test_throws ErrorException prove_g_subdiagram(bad_wd, bad_state, witness)
end

@testset "f subdiagram proof" begin
    S = FiniteVariable(:S, [0, 1])
    T = FiniteVariable(:T, [0, 1])
    C = FiniteVariable(:C, [0, 1])
    state = JointState([S, T, C], fill(1.0 / 8.0, 2, 2, 2))

    wd = WiringDiagram(Any[:T], Any[:S, :T, :C])
    f_s = add_box!(wd, Box(:f_S, Any[], Any[:S]))
    f_t = add_box!(wd, Box(:f_T, Any[:S], Any[:T]))
    f_c = add_box!(wd, Box(:f_C, Any[:S, :T], Any[:C]))
    add_wire!(wd, Port(f_s, OutputPort, 1) => Port(f_t, InputPort, 1))
    add_wire!(wd, Port(f_s, OutputPort, 1) => Port(f_c, InputPort, 1))
    add_wire!(wd, Port(input_id(wd), OutputPort, 1) => Port(f_c, InputPort, 2))
    add_wire!(wd, Port(f_s, OutputPort, 1) => Port(output_id(wd), InputPort, 1))
    add_wire!(wd, Port(f_t, OutputPort, 1) => Port(output_id(wd), InputPort, 2))
    add_wire!(wd, Port(f_c, OutputPort, 1) => Port(output_id(wd), InputPort, 3))

    witness = CombWitness(A=[:S], B=[:T], C=[:C], intervention=[:S])
    g_proof = CombSubdiagramProof(
        witness,
        [f_t],
        subdiagram_boundary(wd, [f_t]),
    )
    f_proof = prove_f_subdiagram(wd, state, witness, g_proof)
    cut_proof = prove_cut_comb_subdiagrams(wd, state, witness)

    @test f_proof.witness == witness
    @test f_proof.f_boxes == [f_s, f_c]
    @test f_proof.f_boundary.input_vars == [:T]
    @test Set(f_proof.f_boundary.output_vars) == Set([:S, :C])
    @test cut_proof.g_proof.g_boxes == [f_t]
    @test cut_proof.f_proof.f_boxes == [f_s, f_c]

    Z = FiniteVariable(:Z, [0, 1])
    bad_state = JointState([S, T, Z, C], fill(1.0 / 16.0, 2, 2, 2, 2))
    bad_wd = WiringDiagram(Any[:T, :Z], Any[:S, :C])
    bad_f_s = add_box!(bad_wd, Box(:f_S, Any[], Any[:S]))
    bad_f_t = add_box!(bad_wd, Box(:f_T, Any[:S], Any[:T]))
    bad_f_c = add_box!(bad_wd, Box(:f_C, Any[:S, :T, :Z], Any[:C]))
    add_wire!(bad_wd, Port(bad_f_s, OutputPort, 1) => Port(bad_f_t, InputPort, 1))
    add_wire!(bad_wd, Port(bad_f_s, OutputPort, 1) => Port(bad_f_c, InputPort, 1))
    add_wire!(bad_wd, Port(input_id(bad_wd), OutputPort, 1) => Port(bad_f_c, InputPort, 2))
    add_wire!(bad_wd, Port(input_id(bad_wd), OutputPort, 2) => Port(bad_f_c, InputPort, 3))
    add_wire!(bad_wd, Port(bad_f_s, OutputPort, 1) => Port(output_id(bad_wd), InputPort, 1))
    add_wire!(bad_wd, Port(bad_f_c, OutputPort, 1) => Port(output_id(bad_wd), InputPort, 2))

    bad_g_proof = CombSubdiagramProof(
        witness,
        [bad_f_t],
        subdiagram_boundary(bad_wd, [bad_f_t]),
    )
    @test_throws ErrorException prove_f_subdiagram(bad_wd, bad_state, witness, bad_g_proof)
end

@testset "Catlab comb-only convenience call" begin
    S = FiniteVariable(:S, [0, 1])
    T = FiniteVariable(:T, [0, 1])
    C = FiniteVariable(:C, [0, 1])

    probs = fill(1.0 / 8.0, 2, 2, 2)
    state = JointState([S, T, C], probs)
    diagram = WiringDiagram(Any[:T], Any[:S, :T, :C])
    f_s = add_box!(diagram, Box(:f_S, Any[], Any[:S]))
    f_t = add_box!(diagram, Box(:f_T, Any[:S], Any[:T]))
    f_c = add_box!(diagram, Box(:f_C, Any[:S, :T], Any[:C]))
    add_wire!(diagram, Port(f_s, OutputPort, 1) => Port(f_t, InputPort, 1))
    add_wire!(diagram, Port(f_s, OutputPort, 1) => Port(f_c, InputPort, 1))
    add_wire!(diagram, Port(input_id(diagram), OutputPort, 1) => Port(f_c, InputPort, 2))
    add_wire!(diagram, Port(f_s, OutputPort, 1) => Port(output_id(diagram), InputPort, 1))
    add_wire!(diagram, Port(f_t, OutputPort, 1) => Port(output_id(diagram), InputPort, 2))
    add_wire!(diagram, Port(f_c, OutputPort, 1) => Port(output_id(diagram), InputPort, 3))

    result = infer_causal_effect(
        diagram,
        state;
        intervention=[:S],
        bridge=[:T],
        outcome=[:C],
    )

    @test result.computable
    @test result.witness.A == [:S]
    @test result.witness.B == [:T]
    @test result.witness.C == [:C]
    @test result.witness.intervention == [:S]
    @test result.surgery_diagram !== nothing
    @test result.subdiagram_proof !== nothing
end

@testset "complete comb partition search" begin
    S = FiniteVariable(:S, [0, 1])
    T = FiniteVariable(:T, [0, 1])
    C = FiniteVariable(:C, [0, 1])

    probs = fill(1.0 / 8.0, 2, 2, 2)
    state = JointState([S, T, C], probs)

    # The valid g-region is S -> Z -> T. Z is an internal diagram-only wire
    # and is not present in the observational joint table. This forces the
    # recognizer to find a multi-box g-region rather than only the final T box.
    diagram = WiringDiagram(Any[:T], Any[:S, :T, :C])
    f_s = add_box!(diagram, Box(:f_S, Any[], Any[:S]))
    g_z = add_box!(diagram, Box(:g_Z, Any[:S], Any[:Z]))
    g_t = add_box!(diagram, Box(:g_T, Any[:Z], Any[:T]))
    f_c = add_box!(diagram, Box(:f_C, Any[:S, :T], Any[:C]))
    add_wire!(diagram, Port(f_s, OutputPort, 1) => Port(g_z, InputPort, 1))
    add_wire!(diagram, Port(g_z, OutputPort, 1) => Port(g_t, InputPort, 1))
    add_wire!(diagram, Port(f_s, OutputPort, 1) => Port(f_c, InputPort, 1))
    add_wire!(diagram, Port(input_id(diagram), OutputPort, 1) => Port(f_c, InputPort, 2))
    add_wire!(diagram, Port(f_s, OutputPort, 1) => Port(output_id(diagram), InputPort, 1))
    add_wire!(diagram, Port(g_t, OutputPort, 1) => Port(output_id(diagram), InputPort, 2))
    add_wire!(diagram, Port(f_c, OutputPort, 1) => Port(output_id(diagram), InputPort, 3))

    result = infer_causal_effect(
        diagram,
        state;
        witness=CombWitness(A=[:S], B=[:T], C=[:C], intervention=[:S]),
    )

    @test result.computable
    @test result.subdiagram_proof !== nothing
    @test Set(result.subdiagram_proof.g_proof.g_boxes) == Set([g_z, g_t])
    @test Set(result.subdiagram_proof.f_proof.f_boxes) == Set([f_s, f_c])
end

@testset "Catlab comb witness discovery" begin
    S = FiniteVariable(:S, [0, 1])
    T = FiniteVariable(:T, [0, 1])
    C = FiniteVariable(:C, [0, 1])

    probs = zeros(Float64, 2, 2, 2)
    probs[1, 1, 1] = 0.50
    probs[1, 1, 2] = 0.10
    probs[1, 2, 1] = 0.01
    probs[1, 2, 2] = 0.02
    probs[2, 1, 1] = 0.10
    probs[2, 1, 2] = 0.05
    probs[2, 2, 1] = 0.02
    probs[2, 2, 2] = 0.20
    state = JointState([S, T, C], probs)

    diagram = WiringDiagram(Any[:S], Any[:C])
    f_t = add_box!(diagram, Box(:f_T, Any[:S], Any[:T]))
    f_c = add_box!(diagram, Box(:f_C, Any[:T], Any[:C]))
    add_wire!(diagram, Port(input_id(diagram), OutputPort, 1) => Port(f_t, InputPort, 1))
    add_wire!(diagram, Port(f_t, OutputPort, 1) => Port(f_c, InputPort, 1))
    add_wire!(diagram, Port(f_c, OutputPort, 1) => Port(output_id(diagram), InputPort, 1))

    witness = discover_comb_witness(
        diagram,
        state;
        intervention=[:S],
        outcome=[:C],
    )
    @test witness.A == [:S]
    @test witness.B == [:T]
    @test witness.C == [:C]

    disconnected = WiringDiagram(Any[:S], Any[:C])
    f_t_disconnected = add_box!(disconnected, Box(:f_T, Any[:S], Any[:T]))
    add_wire!(disconnected, Port(input_id(disconnected), OutputPort, 1) => Port(f_t_disconnected, InputPort, 1))
    failed = infer_causal_effect(
        disconnected,
        state;
        intervention=[:S],
        outcome=[:C],
    )

    @test !failed.computable
    @test occursin("not reachable", failed.failure_reason)

    bypass = WiringDiagram(Any[:S], Any[:C, :C])
    f_t_bypass = add_box!(bypass, Box(:f_T, Any[:S], Any[:T]))
    f_c_bypass = add_box!(bypass, Box(:f_C, Any[:T], Any[:C]))
    direct_c = add_box!(bypass, Box(:direct_C, Any[:S], Any[:C]))
    add_wire!(bypass, Port(input_id(bypass), OutputPort, 1) => Port(f_t_bypass, InputPort, 1))
    add_wire!(bypass, Port(f_t_bypass, OutputPort, 1) => Port(f_c_bypass, InputPort, 1))
    add_wire!(bypass, Port(f_c_bypass, OutputPort, 1) => Port(output_id(bypass), InputPort, 1))
    add_wire!(bypass, Port(input_id(bypass), OutputPort, 1) => Port(direct_c, InputPort, 1))
    add_wire!(bypass, Port(direct_c, OutputPort, 1) => Port(output_id(bypass), InputPort, 2))

    bypass_failed = infer_causal_effect(
        bypass,
        state;
        intervention=[:S],
        outcome=[:C],
    )

    @test !bypass_failed.computable
    @test occursin("bypasses bridge", bypass_failed.failure_reason)
end

@testset "Catlab comb-only generic grouped variables" begin
    X = FiniteVariable(:X, [0, 1, 2])
    Z = FiniteVariable(:Z, [:low, :high])
    M = FiniteVariable(:M, [false, true])
    Y = FiniteVariable(:Y, [:bad, :ok, :good])

    probs = zeros(Float64, 3, 2, 2, 3)
    p_x = [0.2, 0.35, 0.45]
    p_z = [0.55, 0.45]
    for idx in CartesianIndices(probs)
        x, z, m, y = Tuple(idx) .- 1
        p_m = clamp(0.2 + 0.15x + 0.25z, 0.05, 0.95)
        y_weights = [
            1.0 + 0.1x + 0.2z + 0.1m,
            1.2 + 0.2x + 0.1z + 0.3m,
            1.4 + 0.3x + 0.2z + 0.4m,
        ]
        y_dist = y_weights ./ sum(y_weights)
        probs[idx] = p_x[x + 1] *
                     p_z[z + 1] *
                     (m == 1 ? p_m : 1.0 - p_m) *
                     y_dist[y + 1]
    end
    probs ./= sum(probs)

    state = JointState([X, Z, M, Y], probs)
    diagram = WiringDiagram(Any[:M], Any[:X, :Z, :M, :Y])
    f_x = add_box!(diagram, Box(:f_X, Any[], Any[:X]))
    f_z = add_box!(diagram, Box(:f_Z, Any[], Any[:Z]))
    f_m = add_box!(diagram, Box(:f_M, Any[:X, :Z], Any[:M]))
    f_y = add_box!(diagram, Box(:f_Y, Any[:X, :Z, :M], Any[:Y]))
    add_wire!(diagram, Port(f_x, OutputPort, 1) => Port(f_m, InputPort, 1))
    add_wire!(diagram, Port(f_z, OutputPort, 1) => Port(f_m, InputPort, 2))
    add_wire!(diagram, Port(f_x, OutputPort, 1) => Port(f_y, InputPort, 1))
    add_wire!(diagram, Port(f_z, OutputPort, 1) => Port(f_y, InputPort, 2))
    add_wire!(diagram, Port(input_id(diagram), OutputPort, 1) => Port(f_y, InputPort, 3))
    add_wire!(diagram, Port(f_x, OutputPort, 1) => Port(output_id(diagram), InputPort, 1))
    add_wire!(diagram, Port(f_z, OutputPort, 1) => Port(output_id(diagram), InputPort, 2))
    add_wire!(diagram, Port(f_m, OutputPort, 1) => Port(output_id(diagram), InputPort, 3))
    add_wire!(diagram, Port(f_y, OutputPort, 1) => Port(output_id(diagram), InputPort, 4))
    witness = CombWitness(
        A=[:X, :Z],
        B=[:M],
        C=[:Y],
        intervention=[:X, :Z],
    )

    result = infer_causal_effect(diagram, state; witness=witness)

    @test result.computable
    @test result.reconstruction_ok
    @test result.effect.inputs == [X, Z]
    @test result.effect.outputs == [Y]
    @test size(result.effect.probabilities) == (3, 3, 2)
    @test all(sum(result.effect.probabilities; dims=1) .≈ 1.0)
    @test input_ports(result.surgery_diagram) == Any[:X, :Z]
    @test output_ports(result.surgery_diagram) == Any[:Y]
    @test result.subdiagram_proof !== nothing
end

@testset "Catlab context-aware comb interface" begin
    A = FiniteVariable(:A, [0, 1])
    X = FiniteVariable(:X, [0, 1])
    B = FiniteVariable(:B, [0, 1])
    C = FiniteVariable(:C, [0, 1])

    probs = zeros(Float64, 2, 2, 2, 2)
    for idx in CartesianIndices(probs)
        a, x, b, c = Tuple(idx) .- 1
        probs[idx] = 1.0 + 0.7a + 0.5x + 0.3b + 0.2c + 0.4a * b + 0.6x * c
    end
    probs ./= sum(probs)
    state = JointState([A, X, B, C], probs)

    diagram = WiringDiagram(Any[:B], Any[:A, :X, :B, :C])
    f_a = add_box!(diagram, Box(:f_A, Any[], Any[:A]))
    f_x = add_box!(diagram, Box(:f_X, Any[:A], Any[:X]))
    g_b = add_box!(diagram, Box(:g_B, Any[:A, :X], Any[:B]))
    f_c = add_box!(diagram, Box(:f_C, Any[:A, :X, :B], Any[:C]))
    add_wire!(diagram, Port(f_a, OutputPort, 1) => Port(f_x, InputPort, 1))
    add_wire!(diagram, Port(f_a, OutputPort, 1) => Port(g_b, InputPort, 1))
    add_wire!(diagram, Port(f_x, OutputPort, 1) => Port(g_b, InputPort, 2))
    add_wire!(diagram, Port(f_a, OutputPort, 1) => Port(f_c, InputPort, 1))
    add_wire!(diagram, Port(f_x, OutputPort, 1) => Port(f_c, InputPort, 2))
    add_wire!(diagram, Port(input_id(diagram), OutputPort, 1) => Port(f_c, InputPort, 3))
    add_wire!(diagram, Port(f_a, OutputPort, 1) => Port(output_id(diagram), InputPort, 1))
    add_wire!(diagram, Port(f_x, OutputPort, 1) => Port(output_id(diagram), InputPort, 2))
    add_wire!(diagram, Port(g_b, OutputPort, 1) => Port(output_id(diagram), InputPort, 3))
    add_wire!(diagram, Port(f_c, OutputPort, 1) => Port(output_id(diagram), InputPort, 4))

    result = infer_causal_effect(
        diagram,
        state;
        intervention=[:X],
        context=[:A],
        bridge=[:B],
        outcome=[:C],
    )

    @test result.computable
    @test result.witness.A == [:A, :X]
    @test result.witness.context == [:A]
    @test result.witness.intervention == [:X]
    @test result.effect.inputs == [A, X]
    @test result.effect.outputs == [C]
    @test input_ports(result.surgery_diagram) == Any[:A, :X]
    @test result.subdiagram_proof.g_proof.g_boxes == [g_b]
end
