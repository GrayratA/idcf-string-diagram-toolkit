(
    name="drug_admg",
    input=ADMGModel(
        [
            :X => :W,
            :W => :Y,
            :D => :Z,
            :Z => :Y,
        ],
        [
            :X => :Y,
        ],
    ),
    display_syms=[:D, :Z, :X, :W, :Y],
    output_vars=["Y"],
)
