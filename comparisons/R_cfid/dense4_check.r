library(cfid)

# Dense4 minimal check.
#
# ADMG:
#   V1 -> V2 -> V4
#
# Counterfactual query:
#   P(V4_{do(V1 = v1)} = v4 | V2 = v2)
#
# Under shared-exogenous-variable counterfactual semantics, this query should
# not be treated as an ordinary causal effect. The factual observation V2 = v2
# carries information about the exogenous noise of the V2 mechanism, and that
# same noise is shared with the counterfactual world.

g <- dag("V1 -> V2; V2 -> V4")

v1 <- 0L
v2 <- 0L
v4 <- 0L

gamma <- conj(cf("V4", obs = v4, sub = c(V1 = v1)))
delta <- conj(cf("V2", obs = v2))

cat("== dense4 cfid check ==\n")
cat("Graph: V1 -> V2 -> V4\n")
cat("Query: P(V4_{v1} = v4 | V2 = v2)\n\n")

for (mode in c("observations", "interventions")) {
  res <- identifiable(g, gamma, delta, data = mode)
  cat("data =", mode, "\n")
  cat("identifiable =", isTRUE(res$id), "\n")
  if (isTRUE(res$id)) {
    cat("formula =", format(res$formula, use_do = TRUE), "\n")
  }
  cat("undefined =", isTRUE(res$undefined), "\n\n")
}
