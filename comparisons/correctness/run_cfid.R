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
# Counterfactual values must be preserved. In cfid, `obs` and intervention
# values in `sub` are integer levels, so distinct value tokens such as `x` and
# `xt` must be mapped to distinct levels for the same variable. Otherwise
# consistency can incorrectly collapse queries such as P(Y_x | X=x') into
# P(Y_x | X=x).
#
# Usage:
#     Rscript run_cfid.R corpus.R verdicts_cfid.tsv

suppressMessages(library(cfid))

if (packageVersion("cfid") < "0.1.9") {
  stop("cfid >= 0.1.9 is required for this correctness harness")
}

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

# Build a per-variable value-token map for one case.
#
# The corpus stores symbolic values (`x`, `xt`, `v2`, ...). cfid expects integer
# levels. The mapping is local to each variable: the same token for the same
# variable gets the same level, while distinct tokens for that variable get
# distinct levels.
build_value_levels <- function(case) {
  levels <- list()

  add_value <- function(var, val) {
    if (is.null(levels[[var]])) {
      levels[[var]] <<- list()
    }
    key <- as.character(val)
    if (is.null(levels[[var]][[key]])) {
      levels[[var]][[key]] <<- length(levels[[var]])
    }
  }

  for (ev in c(case$target, case$evidence)) {
    add_value(ev$var, ev$val)
    if (length(ev$do) > 0) {
      for (v in names(ev$do)) {
        add_value(v, ev$do[[v]])
      }
    }
  }

  levels
}

level_of <- function(levels, var, val) {
  key <- as.character(val)
  if (is.null(levels[[var]]) || is.null(levels[[var]][[key]])) {
    stop(sprintf("no cfid level for %s=%s", var, key))
  }
  as.integer(levels[[var]][[key]])
}

# Build one cfid counterfactual event `cf(var, obs, sub)` from an event record.
build_cf <- function(ev, levels) {
  obs <- level_of(levels, ev$var, ev$val)
  if (length(ev$do) == 0) {
    cf(var = ev$var, obs = obs)
  } else {
    sub <- setNames(
      vapply(names(ev$do), function(v) level_of(levels, v, ev$do[[v]]), integer(1)),
      names(ev$do)
    )
    cf(var = ev$var, obs = obs, sub = sub)
  }
}

build_conj <- function(events, levels, case) {
  do.call(conj, lapply(events, build_cf, levels = levels))
}

run_case <- function(case) {
  res <- tryCatch({
    g <- build_dag(case)
    levels <- build_value_levels(case)
    gamma <- build_conj(case$target, levels, case)
    delta <- build_conj(case$evidence, levels, case)
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
