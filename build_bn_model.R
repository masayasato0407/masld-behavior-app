# =============================================================================
# build_bn_model.R
# Bayesian network construction for the MASLD Risk Simulator (app.R)
#
# This script encodes the MODEL-BUILDING PROCEDURE only:
#   (1) a fixed three-layer DAG (Age/Sex -> 6 behaviors -> MASLD),
#   (2) data-driven inter-behavior edges (Cramer's V screening + score-based
#       direction learning), and
#   (3) conditional probability tables estimated by Bayesian parameter
#       estimation.
# It produces bn_masld_model.RData, which app.R loads at runtime.
#
# DATA NOTICE
#   The underlying individual-level data are from the JMDC claims database and
#   are governed by a data use agreement. NO DATA, NO FITTED PARAMETERS, and
#   NO derived statistics are contained in this file. The fitted model file
#   (bn_masld_model.RData) is likewise NOT distributed in this repository.
#   To reproduce the model, supply your own JMDC-licensed data frame `dat`
#   with the columns described in section 1.
#
# Packages: bnlearn, gRain (pulls gRbase), dplyr; pROC for optional validation.
# =============================================================================

library(bnlearn)
library(gRain)
library(dplyr)

# -----------------------------------------------------------------------------
# 1. Input data (NOT included; supply under your own JMDC license)
# -----------------------------------------------------------------------------
# `dat`: one row per individual, all columns coded as character/factor:
#   Age                     : "young" (<=50 years) | "old" (>50 years)
#   Sex                     : "male" | "female"
#   Regular_exercise        : "0" (healthy) | "1" (unhealthy)
#   Daily_physical_activity : "0" | "1"
#   Walking_speed           : "0" | "1"
#   Eating_speed            : "0" | "1"
#   Late_night_eating       : "0" | "1"
#   Skipping_breakfast      : "0" | "1"
#   MASLD_outcome           : "MASLD" | "non_MASLD"
# Behavior coding: 0 = healthy, 1 = unhealthy (see manuscript Methods).
#
# Replace the next line with your own data-loading step.
# dat <- readRDS("path/to/jmdc_derived_dataset.rds")   # <-- supply your data

stopifnot(exists("dat"))

demog     <- c("Age", "Sex")
behaviors <- c("Regular_exercise", "Daily_physical_activity", "Walking_speed",
               "Eating_speed", "Late_night_eating", "Skipping_breakfast")
outcome   <- "MASLD_outcome"
all_nodes <- c(demog, behaviors, outcome)

dat <- dat %>%
  mutate(
    Age           = factor(Age,           levels = c("young", "old")),
    Sex           = factor(Sex,           levels = c("male", "female")),
    MASLD_outcome = factor(MASLD_outcome, levels = c("non_MASLD", "MASLD"))
  )
for (b in behaviors) dat[[b]] <- factor(dat[[b]], levels = c("0", "1"))
dat <- dat[, all_nodes]
dat <- dat[complete.cases(dat), ]

# -----------------------------------------------------------------------------
# 2. Fixed a priori three-layer structure
#    Layer 1 (roots): Age, Sex
#    Layer 2        : six lifestyle behaviors           (Age, Sex -> behavior)
#    Layer 3        : MASLD_outcome      (Age, Sex, each behavior -> outcome)
# -----------------------------------------------------------------------------
base_arcs <- rbind(
  expand.grid(from = demog,     to = behaviors, stringsAsFactors = FALSE),
  data.frame (from = demog,     to = outcome,   stringsAsFactors = FALSE),
  data.frame (from = behaviors, to = outcome,   stringsAsFactors = FALSE)
)

# -----------------------------------------------------------------------------
# 3. Data-driven inter-behavior edges
#    (a) Cramer's V screening, conditional on Age x Sex strata (max V >= 0.20)
#    (b) edge directions by BIC score-based search, restricted to screened
#        candidate pairs, with the three-layer structure fixed (whitelisted).
#        This is the score (maximize) phase of MMHC applied to candidates only.
# -----------------------------------------------------------------------------
cramers_v <- function(x, y) {
  tab <- table(x, y)
  if (any(dim(tab) < 2)) return(0)
  chi <- suppressWarnings(chisq.test(tab, correct = FALSE)$statistic)
  as.numeric(sqrt((chi / sum(tab)) / (min(dim(tab)) - 1)))
}
pair_key <- function(a, b) paste(sort(c(a, b)), collapse = "|")

V_THRESHOLD <- 0.20
strata   <- expand.grid(Age = c("young", "old"), Sex = c("male", "female"),
                        stringsAsFactors = FALSE)
pairs_bb <- t(combn(behaviors, 2))

cand_keys <- character(0)
for (i in seq_len(nrow(pairs_bb))) {
  b1 <- pairs_bb[i, 1]; b2 <- pairs_bb[i, 2]
  maxv <- 0
  for (s in seq_len(nrow(strata))) {
    sub <- dat[dat$Age == strata$Age[s] & dat$Sex == strata$Sex[s], ]
    if (nrow(sub) >= 2) maxv <- max(maxv, cramers_v(sub[[b1]], sub[[b2]]))
  }
  if (maxv >= V_THRESHOLD) cand_keys <- c(cand_keys, pair_key(b1, b2))
}

inter_arcs <- data.frame(from = character(0), to = character(0),
                         stringsAsFactors = FALSE)
if (length(cand_keys) > 0) {
  ordered_bb <- expand.grid(from = behaviors, to = behaviors,
                            stringsAsFactors = FALSE)
  ordered_bb <- ordered_bb[ordered_bb$from != ordered_bb$to, ]
  ordered_bb$k <- mapply(pair_key, ordered_bb$from, ordered_bb$to)
  blacklist_bb    <- as.matrix(ordered_bb[!(ordered_bb$k %in% cand_keys),
                                          c("from", "to")])
  whitelist_fixed <- as.matrix(base_arcs[, c("from", "to")])

  learned <- hc(dat, whitelist = whitelist_fixed,
                blacklist = blacklist_bb, score = "bic")
  larcs <- as.data.frame(learned$arcs, stringsAsFactors = FALSE)
  if (nrow(larcs) > 0) {
    larcs$k <- mapply(pair_key, larcs$from, larcs$to)
    keep <- larcs$from %in% behaviors & larcs$to %in% behaviors &
            larcs$k %in% cand_keys
    inter_arcs <- larcs[keep, c("from", "to")]
  }
}

# -----------------------------------------------------------------------------
# 4. Assemble DAG and estimate CPTs (Bayesian parameter estimation)
# -----------------------------------------------------------------------------
arcs_all <- unique(rbind(base_arcs[, c("from", "to")], inter_arcs))
dag <- empty.graph(all_nodes)
arcs(dag) <- as.matrix(arcs_all)
stopifnot(acyclic(dag))

bn_fit <- bn.fit(dag, data = dat, method = "bayes", iss = 1)

# -----------------------------------------------------------------------------
# 5. do-operator helper (graph mutilation + exact inference via junction tree)
#    Mirrors the interventional query used by app.R.
# -----------------------------------------------------------------------------
query_do <- function(fit, evidence_list,
                     outcome_node = "MASLD_outcome", outcome_state = "MASLD") {
  mut <- mutilated(fit, evidence = evidence_list)
  g   <- compile(as.grain(mut))
  g   <- setEvidence(g, nodes = names(evidence_list),
                     states = as.character(unlist(evidence_list)))
  querygrain(g, nodes = outcome_node)[[outcome_node]][outcome_state]
}

# -----------------------------------------------------------------------------
# 6. (Optional) Optimism-corrected bootstrap validation (AUC, Brier)
#    Reproduces Supplementary Figure 2 metrics. May be slow on large data.
#    Uses likelihood-weighting prediction (method = "bayes-lw").
# -----------------------------------------------------------------------------
validate_bn <- function(dat, dag, B = 200, n_eval = 10000, seed = 1) {
  if (!requireNamespace("pROC", quietly = TRUE))
    stop("Package 'pROC' is required for validation.")
  set.seed(seed)
  perf <- function(fit, d) {
    pp <- predict(fit, node = "MASLD_outcome", data = d,
                  method = "bayes-lw", prob = TRUE)
    p  <- attr(pp, "prob")["MASLD", ]
    y  <- as.integer(d$MASLD_outcome == "MASLD")
    c(auc   = as.numeric(pROC::auc(y, p, quiet = TRUE)),
      brier = mean((p - y)^2))
  }
  fit_app  <- bn.fit(dag, dat, method = "bayes", iss = 1)
  apparent <- perf(fit_app, dat[sample(nrow(dat), min(n_eval, nrow(dat))), ])

  optimism <- matrix(0, B, 2, dimnames = list(NULL, c("auc", "brier")))
  for (b in seq_len(B)) {
    bs    <- sample(nrow(dat), replace = TRUE)
    fit_b <- bn.fit(dag, dat[bs, ], method = "bayes", iss = 1)
    boot_eval <- dat[bs, ][sample(length(bs), min(n_eval, length(bs))), ]
    orig_eval <- dat[sample(nrow(dat), min(n_eval, nrow(dat))), ]
    optimism[b, ] <- perf(fit_b, boot_eval) - perf(fit_b, orig_eval)
  }
  apparent - colMeans(optimism)   # optimism-corrected AUC and Brier
}
# metrics <- validate_bn(dat, dag)   # uncomment to run

# -----------------------------------------------------------------------------
# 7. Save fitted model for the Shiny app (app.R loads `bn_fit`)
#    NOTE: bn_masld_model.RData is NOT committed to this repository (JMDC DUA).
# -----------------------------------------------------------------------------
save(bn_fit, dag, query_do, file = "bn_masld_model.RData")

cat("Saved bn_masld_model.RData\n")
cat("Nodes:", paste(nodes(bn_fit), collapse = ", "), "\n")
cat("Inter-behavior edges learned:\n"); print(inter_arcs)
