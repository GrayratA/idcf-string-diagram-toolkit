@testset "Markov property validation" begin
    vars = [
        FiniteVariable(:X, [0, 1]),
        FiniteVariable(:Y, [0, 1]),
        FiniteVariable(:Z, [0, 1]),
    ]

    function chain_joint(; z_depends_on_x::Bool=false)
        probs = zeros(Float64, 2, 2, 2)
        p_x = [0.4, 0.6]
        p_y_given_x = [
            0.8 0.3
            0.2 0.7
        ]
        p_z_given_y = [
            0.9 0.25
            0.1 0.75
        ]
        p_z_given_xy = [
            0.9 0.25 0.55 0.1
            0.1 0.75 0.45 0.9
        ]

        for x in 1:2, y in 1:2, z in 1:2
            z_prob = if z_depends_on_x
                p_z_given_xy[z, (x - 1) * 2 + y]
            else
                p_z_given_y[z, y]
            end
            probs[x, y, z] = p_x[x] * p_y_given_x[y, x] * z_prob
        end
        return JointState(vars, probs)
    end

    dag = ADMGModel([:X => :Y, :Y => :Z], Pair{Symbol,Symbol}[])

    valid = validate_markov_property(dag, chain_joint())
    @test valid.passed
    @test valid.is_dag
    @test isempty(valid.failures)
    @test valid.error === nothing

    invalid = validate_markov_property(dag, chain_joint(z_depends_on_x=true))
    @test !invalid.passed
    @test invalid.is_dag
    @test length(invalid.failures) == 1
    @test invalid.failures[1].variable == :Z
    @test invalid.failures[1].independent_of == [:X]
    @test invalid.failures[1].given == [:Y]
    @test invalid.failures[1].max_abs_diff > 0.0

    cyclic = ADMGModel([:X => :Y, :Y => :X], Pair{Symbol,Symbol}[])
    cyclic_result = validate_markov_property(cyclic, chain_joint())
    @test !cyclic_result.passed
    @test !cyclic_result.is_dag
    @test occursin("cycle", cyclic_result.error)

    admg = ADMGModel([:X => :Y], [:X => :Z])
    admg_result = validate_markov_property(admg, chain_joint())
    @test !admg_result.passed
    @test !admg_result.is_dag
    @test occursin("DAGs only", admg_result.error)

    @testset "diagram exogenous wires come from source boxes" begin
        X = FiniteVariable(:X, [0, 1])
        Y = FiniteVariable(:Y, [0, 1])
        state = JointState([X, Y], fill(0.25, 2, 2))

        scm = WiringDiagram(Any[], Any[:X, :Y])
        pu_x = add_box!(scm, Box(:PU_X, Any[], Any[:UX]))
        f_x = add_box!(scm, Box(:f_X, Any[:UX], Any[:X]))
        f_y = add_box!(scm, Box(:f_Y, Any[:X], Any[:Y]))
        add_wire!(scm, Port(pu_x, OutputPort, 1) => Port(f_x, InputPort, 1))
        add_wire!(scm, Port(f_x, OutputPort, 1) => Port(f_y, InputPort, 1))
        add_wire!(scm, Port(f_x, OutputPort, 1) => Port(output_id(scm), InputPort, 1))
        add_wire!(scm, Port(f_y, OutputPort, 1) => Port(output_id(scm), InputPort, 2))

        @test validate_markov_property(scm, state).passed

        hand_written = WiringDiagram(Any[], Any[:X])
        u_box = add_box!(hand_written, Box(:Uhidden_source, Any[], Any[:Uhidden]))
        f_x2 = add_box!(hand_written, Box(:f_X, Any[:Uhidden], Any[:X]))
        add_wire!(hand_written, Port(u_box, OutputPort, 1) => Port(f_x2, InputPort, 1))
        add_wire!(hand_written, Port(f_x2, OutputPort, 1) => Port(output_id(hand_written), InputPort, 1))

        # Uhidden is produced by a no-input source box, so it is treated as an
        # omitted exogenous/source variable for diagram-level Markov checking.
        @test validate_markov_property(hand_written, JointState([X], [0.4, 0.6])).passed

        not_source = WiringDiagram(Any[], Any[:X])
        root = add_box!(not_source, Box(:root, Any[], Any[:R]))
        u_from_r = add_box!(not_source, Box(:Uhidden_from_R, Any[:R], Any[:Uhidden]))
        f_x3 = add_box!(not_source, Box(:f_X, Any[:Uhidden], Any[:X]))
        add_wire!(not_source, Port(root, OutputPort, 1) => Port(u_from_r, InputPort, 1))
        add_wire!(not_source, Port(u_from_r, OutputPort, 1) => Port(f_x3, InputPort, 1))
        add_wire!(not_source, Port(f_x3, OutputPort, 1) => Port(output_id(not_source), InputPort, 1))

        # Uhidden starts with "U", but it is produced by a box with an input,
        # so the implementation does not classify it as exogenous by name.
        @test validate_markov_property(not_source, JointState([X], [0.4, 0.6])).passed

        shared_source = WiringDiagram(Any[], Any[:X, :Y])
        h = add_box!(shared_source, Box(:h, Any[], Any[:H]))
        f_x_shared = add_box!(shared_source, Box(:f_X, Any[:H], Any[:X]))
        f_y_shared = add_box!(shared_source, Box(:f_Y, Any[:H], Any[:Y]))
        add_wire!(shared_source, Port(h, OutputPort, 1) => Port(f_x_shared, InputPort, 1))
        add_wire!(shared_source, Port(h, OutputPort, 1) => Port(f_y_shared, InputPort, 1))
        add_wire!(shared_source, Port(f_x_shared, OutputPort, 1) => Port(output_id(shared_source), InputPort, 1))
        add_wire!(shared_source, Port(f_y_shared, OutputPort, 1) => Port(output_id(shared_source), InputPort, 2))

        # H is an omitted common source, so the observed marginal over X,Y
        # should not be rejected using ordinary DAG Markov constraints.
        @test validate_markov_property(shared_source, state).passed
    end
end
