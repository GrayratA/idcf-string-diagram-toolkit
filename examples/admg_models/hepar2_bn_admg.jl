hepar2 = read_bn_structure(joinpath(@__DIR__, "..", "..", "net", "hepar2.net"))

(
    name="hepar2_bn_admg",
    input=hepar2.model,
)
