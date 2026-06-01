(
    name="party_two_world",
    queries=[
        CounterfactualQuery(
            :Real,
            Dict{Symbol, Symbol}(),
            Dict(:B => :bp),
            Symbol[],
        ),
        CounterfactualQuery(
            :CF,
            Dict(:B => :b),
            Dict{Symbol, Symbol}(),
            [:S],
        ),
    ],
    rules=(
        enabled=true,
        directed_edges=[("A", "B"), ("A", "C"), ("B", "S"), ("C", "S")],
    ),
    display=(
        symbols=Dict("A" => "a", "B" => "b", "C" => "c", "S" => "s"),
        value_rename=Dict("bp" => "b'"),
    ),
    data=(mode=:none, anchor_var="B"),
)
