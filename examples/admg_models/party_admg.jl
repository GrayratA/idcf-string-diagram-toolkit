(
    name="party_admg",
    input=ADMGModel(
        [
            :A => :B,
            :A => :C,
            :B => :S,
            :C => :S,
        ],
        Pair{Symbol, Symbol}[],
    ),
    display_syms=[:B, :S],
    output_vars=["S"],
)
