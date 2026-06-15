# run_cfid.R -- run the cfid reference implementation on every corpus case.
#
# cfid (Tikka, "Identifying Counterfactual Queries with the R Package cfid") is the
# reference implementation of the ID* / IDC* counterfactual identification
# algorithms on ADMGs -- the same problem the toolkit solves. We use it as an
# INDEPENDENT ORACLE: for each case we ask cfid whether the query is identifiable
# and compare its yes/no against the toolkit's.
#
# Reads an R-literal corpus (corpus.R, produced by gen_corpus.py) and writes a TSV:
#     <id> \t <verdict> \t <formula-or-note>
# where <verdict> is ID, FAIL, or ERROR (cfid raised for a non-verdict reason).
#
# The concrete observed values do not affect identifiability (it is a structural
# property), so every event is encoded at integer level 0; only the variable and
# its intervention context matter.
#
# Usage:
#     Rscript run_cfid.R corpus.R verdicts_cfid.tsv

suppressMessages(library(cfid))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) stop("usage: Rscript run_cfid.R <corpus.R> <out.tsv>")
corpus_path <- args[[1]]
out_path <- args[[2]]

source(corpus_path)   # defines `corpus`

# Build a cfid DAG string from directed + bidirected edge lists.
build_dag <- function(case) {
  edges <- character()
  for (e in case$directed) {
    edges <- c(edges, sprintf("%s -> %s", e[[1]], e[[2]]))
  }
  for (e in case$bidirected) {
    edges <- c(edges, sprintf("%s <-> %s", e[[1]], e[[2]]))
  }
  dag(paste(edges, collapse = "; "))
}

# Build one cfid counterfactual event `cf(var, obs, sub)` from an event record.
build_cf <- function(ev) {
  if (length(ev$do) == 0) {
    cf(var = ev$var, obs = 0L)
  } else {
    sub <- setNames(rep(0L, length(ev$do)), names(ev$do))
    cf(var = ev$var, obs = 0L, sub = sub)
  }
}

build_conj <- function(events) {
  do.call(conj, lapply(events, build_cf))
}

run_case <- function(case) {
  res <- tryCatch({
    g <- build_dag(case)
    gamma <- build_conj(case$target)
    delta <- build_conj(case$evidence)
    identifiable(g, gamma, delta, data = case$data)
  }, error = function(e) e)

  if (inherits(res, "error")) {
    msg <- gsub("[\t\r\n]+", " ", conditionMessage(res))
    return(c("ERROR", msg))
  }
  if (isTRUE(res$id)) {
    formula <- tryCatch(format(res$formula, use_do = TRUE),
                        error = function(e) "ID")
    formula <- gsub("[\t\r\n]+", " ", formula)
    return(c("ID", formula))
  }
  c("FAIL", "-")
}

con <- file(out_path, "w")
on.exit(close(con))
for (case in corpus) {
  out <- run_case(case)
  cat(sprintf("%s\t%s\t%s\n", case$id, out[[1]], out[[2]]), file = con)
  cat(sprintf("[cfid] %s: %s\n", case$id, out[[1]]), file = stderr())
}
cat(sprintf("[cfid] wrote %d verdicts to %s\n", length(corpus), out_path))
