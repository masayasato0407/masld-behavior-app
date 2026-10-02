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
#
# It produces bn_masld_model.RData, which app.R loads at runtime.
#
# DATA NOTICE
#   The underlying individual-level data are from JMDC claims and health
#   checkup data and are governed by a data use agreement.
#   NO DATA, NO FITTED PARAMETERS, and NO derived statistics are contained
#   in this file. The fitted model file (bn_masld_model.RData) is likewise
#   NOT distributed in this repository.
#
#   To reproduce the model, supply your own JMDC-licensed data frame `dat`
#   with the columns described in Section 1.
#
#   The input dataset should correspond to the revised analytic cohort in
#   which MASLD is defined by the presence of steatotic liver disease (SLD),
#   at least one of the five cardiometabolic risk factors (CMRFs), and
#   MASLD-compatible alcohol consumption, as described in the manuscript.
#
# Packages:
#   bnlearn, gRain (pulls gRbase), dplyr
#   pROC for optional validation
# =============================================================================


library(bnlearn)
library(gRain)
library(dplyr)


# -----------------------------------------------------------------------------
# 1. Input data
#    NOT included; supply under your own JMDC license.
# -----------------------------------------------------------------------------
#
# `dat`: one row per individual, all columns coded as character/factor:
#
#   Age                     : "young" (<=50 years) | "old" (>50 years)
#   Sex                     : "male" | "female"
#   Regular_exercise        : "0" (healthy) | "1" (unhealthy)
#   Daily_physical_activity : "0" | "1"
#   Walking_speed           : "0" | "1"
#   Eating_speed            : "0" | "1"
#   Late_night_eating       : "0" | "1"
#   Skipping_breakfast      : "0" | "1"
#   MASLD_outcome           : "Control" | "MASLD"
#
# Behavior coding:
#   0 = healthy
#   1 = unhealthy
#
# See manuscript Methods for variable definitions.
#
# Replace the next line with your own data-loading step.
#
# dat <- readRDS("path/to/jmdc_derived_dataset.rds")


stopifnot(
  exists("dat")
)


# -----------------------------------------------------------------------------
# 1a. Define model variables
# -----------------------------------------------------------------------------

demog <- c(
  "Age",
  "Sex"
)


behaviors <- c(
  "Regular_exercise",
  "Daily_physical_activity",
  "Walking_speed",
  "Eating_speed",
  "Late_night_eating",
  "Skipping_breakfast"
)


outcome <- "MASLD_outcome"


all_nodes <- c(
  demog,
  behaviors,
  outcome
)


# -----------------------------------------------------------------------------
# 1b. Standardize factor levels
# -----------------------------------------------------------------------------

dat <- dat %>%
  mutate(

    Age = factor(
      Age,
      levels = c(
        "young",
        "old"
      )
    ),

    Sex = factor(
      Sex,
      levels = c(
        "male",
        "female"
      )
    ),

    MASLD_outcome = factor(
      MASLD_outcome,
      levels = c(
        "Control",
        "MASLD"
      )
    )
  )


for (b in behaviors) {

  dat[[b]] <- factor(
    dat[[b]],
    levels = c(
      "0",
      "1"
    )
  )
}


dat <- dat[
  ,
  all_nodes
]


dat <- dat[
  complete.cases(dat),
]


# -----------------------------------------------------------------------------
# 2. Fixed a priori three-layer structure
#
#    Layer 1 (roots):
#      Age, Sex
#
#    Layer 2:
#      Six lifestyle behaviors
#      Age, Sex -> each behavior
#
#    Layer 3:
#      MASLD_outcome
#      Age, Sex, each behavior -> MASLD_outcome
# -----------------------------------------------------------------------------

base_arcs <- rbind(

  expand.grid(
    from = demog,
    to = behaviors,
    stringsAsFactors = FALSE
  ),

  data.frame(
    from = demog,
    to = outcome,
    stringsAsFactors = FALSE
  ),

  data.frame(
    from = behaviors,
    to = outcome,
    stringsAsFactors = FALSE
  )
)


# -----------------------------------------------------------------------------
# 3. Data-driven inter-behavior edges
#
#    (a) Cramer's V screening conditional on Age x Sex strata.
#        Candidate threshold:
#          maximum V >= 0.20
#
#    (b) Edge directions determined by BIC score-based search, restricted
#        to screened candidate behavior pairs, while the a priori
#        three-layer structure is fixed by whitelisting.
#
#    The final manuscript model contains the following inter-behavior edges:
#
#      Regular_exercise
#          -> Daily_physical_activity
#
#      Daily_physical_activity
#          -> Walking_speed
#
#    A verification step below stops execution if the learned
#    inter-behavior structure differs from the final manuscript model.
# -----------------------------------------------------------------------------


# -----------------------------------------------------------------------------
# 3a. Cramer's V function
# -----------------------------------------------------------------------------

cramers_v <- function(
  x,
  y
) {

  tab <- table(
    x,
    y
  )


  if (any(dim(tab) < 2)) {

    return(
      0
    )
  }


  chi <- suppressWarnings(
    chisq.test(
      tab,
      correct = FALSE
    )$statistic
  )


  as.numeric(
    sqrt(
      (chi / sum(tab)) /
        (min(dim(tab)) - 1)
    )
  )
}


# -----------------------------------------------------------------------------
# 3b. Helper for unordered behavior-pair identifiers
# -----------------------------------------------------------------------------

pair_key <- function(
  a,
  b
) {

  paste(
    sort(
      c(
        a,
        b
      )
    ),
    collapse = "|"
  )
}


# -----------------------------------------------------------------------------
# 3c. Candidate-pair screening
# -----------------------------------------------------------------------------

V_THRESHOLD <- 0.20


strata <- expand.grid(

  Age = c(
    "young",
    "old"
  ),

  Sex = c(
    "male",
    "female"
  ),

  stringsAsFactors = FALSE
)


pairs_bb <- t(
  combn(
    behaviors,
    2
  )
)


cand_keys <- character(
  0
)


for (i in seq_len(nrow(pairs_bb))) {

  b1 <- pairs_bb[i, 1]

  b2 <- pairs_bb[i, 2]

  maxv <- 0


  for (s in seq_len(nrow(strata))) {

    sub <- dat[
      dat$Age == strata$Age[s] &
        dat$Sex == strata$Sex[s],
    ]


    if (nrow(sub) >= 2) {

      maxv <- max(
        maxv,
        cramers_v(
          sub[[b1]],
          sub[[b2]]
        )
      )
    }
  }


  if (maxv >= V_THRESHOLD) {

    cand_keys <- c(
      cand_keys,
      pair_key(
        b1,
        b2
      )
    )
  }
}


cand_keys <- unique(
  cand_keys
)


# -----------------------------------------------------------------------------
# 3d. Direction learning for screened candidate pairs
# -----------------------------------------------------------------------------

inter_arcs <- data.frame(

  from = character(
    0
  ),

  to = character(
    0
  ),

  stringsAsFactors = FALSE
)


if (length(cand_keys) > 0) {

  ordered_bb <- expand.grid(

    from = behaviors,

    to = behaviors,

    stringsAsFactors = FALSE
  )


  ordered_bb <- ordered_bb[
    ordered_bb$from != ordered_bb$to,
  ]


  ordered_bb$k <- mapply(
    pair_key,
    ordered_bb$from,
    ordered_bb$to
  )


  # Block all behavior-to-behavior arcs that were not selected
  # by Cramer's V screening.
  blacklist_bb <- as.matrix(
    ordered_bb[
      !(ordered_bb$k %in% cand_keys),
      c(
        "from",
        "to"
      )
    ]
  )


  # Keep the a priori demographic / behavior / outcome structure fixed.
  whitelist_fixed <- as.matrix(
    base_arcs[
      ,
      c(
        "from",
        "to"
      )
    ]
  )


  learned <- hc(
    dat,
    whitelist = whitelist_fixed,
    blacklist = blacklist_bb,
    score = "bic"
  )


  larcs <- as.data.frame(
    learned$arcs,
    stringsAsFactors = FALSE
  )


  if (nrow(larcs) > 0) {

    larcs$k <- mapply(
      pair_key,
      larcs$from,
      larcs$to
    )


    keep <-
      larcs$from %in% behaviors &
      larcs$to %in% behaviors &
      larcs$k %in% cand_keys


    inter_arcs <- larcs[
      keep,
      c(
        "from",
        "to"
      )
    ]
  }
}


# -----------------------------------------------------------------------------
# 3e. Verify final inter-behavior structure
#
# Expected final manuscript model:
#
#   Regular_exercise
#       -> Daily_physical_activity
#
#   Daily_physical_activity
#       -> Walking_speed
# -----------------------------------------------------------------------------

expected_inter_arcs <- data.frame(

  from = c(
    "Regular_exercise",
    "Daily_physical_activity"
  ),

  to = c(
    "Daily_physical_activity",
    "Walking_speed"
  ),

  stringsAsFactors = FALSE
)


normalize_arcs <- function(
  x
) {

  if (nrow(x) == 0) {

    return(
      data.frame(
        from = character(0),
        to = character(0),
        stringsAsFactors = FALSE
      )
    )
  }


  x <- x[
    order(
      x$from,
      x$to
    ),
    c(
      "from",
      "to"
    )
  ]


  rownames(x) <- NULL


  x
}


if (
  !identical(
    normalize_arcs(
      inter_arcs
    ),
    normalize_arcs(
      expected_inter_arcs
    )
  )
) {

  cat(
    "\nLearned inter-behavior edges:\n"
  )

  print(
    inter_arcs
  )


  cat(
    "\nExpected inter-behavior edges:\n"
  )

  print(
    expected_inter_arcs
  )


  stop(
    paste0(
      "Learned inter-behavior edges do not match ",
      "the final manuscript model."
    )
  )
}


cat(
  "\nInter-behavior edge verification passed.\n"
)


print(
  inter_arcs
)


# -----------------------------------------------------------------------------
# 4. Assemble final DAG and estimate conditional probability tables
#
#    Conditional probability tables are estimated using Bayesian parameter
#    estimation with imaginary sample size (iss) = 10.
# -----------------------------------------------------------------------------

arcs_all <- unique(
  rbind(

    base_arcs[
      ,
      c(
        "from",
        "to"
      )
    ],

    inter_arcs
  )
)


dag <- empty.graph(
  all_nodes
)


arcs(
  dag
) <- as.matrix(
  arcs_all
)


stopifnot(
  acyclic(
    dag
  )
)


bn_fit <- bn.fit(
  dag,
  data = dat,
  method = "bayes",
  iss = 10
)


# -----------------------------------------------------------------------------
# 5. do-operator helper
#
#    Graph mutilation followed by exact inference via the junction tree.
#
#    This mirrors the model-based hypothetical behavioral modification query
#    used by app.R.
# -----------------------------------------------------------------------------

query_do <- function(
  fit,
  evidence_list,
  outcome_node = "MASLD_outcome",
  outcome_state = "MASLD"
) {

  mut <- mutilated(
    fit,
    evidence = evidence_list
  )


  g <- compile(
    as.grain(
      mut
    )
  )


  g <- setEvidence(
    g,
    nodes = names(
      evidence_list
    ),
    states = as.character(
      unlist(
        evidence_list
      )
    )
  )


  querygrain(
    g,
    nodes = outcome_node
  )[
    [
      outcome_node
    ]
  ][
    outcome_state
  ]
}


# -----------------------------------------------------------------------------
# 6. Optional optimism-corrected bootstrap validation
#
#    Outputs:
#      AUC
#      Brier score
#
#    Default:
#      B = 200 bootstrap samples
#
#    This routine may be computationally intensive for a large dataset.
#    Prediction uses likelihood weighting (method = "bayes-lw").
# -----------------------------------------------------------------------------

validate_bn <- function(
  dat,
  dag,
  B = 200,
  n_eval = 10000,
  seed = 1
) {

  if (
    !requireNamespace(
      "pROC",
      quietly = TRUE
    )
  ) {

    stop(
      "Package 'pROC' is required for validation."
    )
  }


  set.seed(
    seed
  )


  perf <- function(
    fit,
    d
  ) {

    pp <- predict(
      fit,
      node = "MASLD_outcome",
      data = d,
      method = "bayes-lw",
      prob = TRUE
    )


    p <- attr(
      pp,
      "prob"
    )[
      "MASLD",
    ]


    y <- as.integer(
      d$MASLD_outcome ==
        "MASLD"
    )


    c(

      auc = as.numeric(
        pROC::auc(
          y,
          p,
          quiet = TRUE
        )
      ),

      brier = mean(
        (
          p -
            y
        )^2
      )
    )
  }


  fit_app <- bn.fit(
    dag,
    dat,
    method = "bayes",
    iss = 10
  )


  apparent_sample <- sample(
    nrow(dat),
    min(
      n_eval,
      nrow(dat)
    )
  )


  apparent <- perf(
    fit_app,
    dat[
      apparent_sample,
    ]
  )


  optimism <- matrix(

    0,

    B,

    2,

    dimnames = list(
      NULL,
      c(
        "auc",
        "brier"
      )
    )
  )


  for (b in seq_len(B)) {

    bs <- sample(
      nrow(dat),
      replace = TRUE
    )


    fit_b <- bn.fit(
      dag,
      dat[
        bs,
      ],
      method = "bayes",
      iss = 10
    )


    boot_eval_index <- sample(
      length(bs),
      min(
        n_eval,
        length(bs)
      )
    )


    boot_eval <- dat[
      bs,
    ][
      boot_eval_index,
    ]


    orig_eval_index <- sample(
      nrow(dat),
      min(
        n_eval,
        nrow(dat)
      )
    )


    orig_eval <- dat[
      orig_eval_index,
    ]


    optimism[
      b,
    ] <-
      perf(
        fit_b,
        boot_eval
      ) -
      perf(
        fit_b,
        orig_eval
      )
  }


  apparent -
    colMeans(
      optimism
    )
}


# Uncomment to run:
#
# metrics <- validate_bn(
#   dat,
#   dag
# )
#
# print(
#   metrics
# )


# -----------------------------------------------------------------------------
# 7. Save fitted model for the Shiny app
#
#    app.R loads the object:
#
#      bn_fit
#
#    Only bn_fit is saved in bn_masld_model.RData.
#
#    The fitted RData file is not committed to this repository.
# -----------------------------------------------------------------------------

save(
  bn_fit,
  file = "bn_masld_model.RData"
)


# -----------------------------------------------------------------------------
# 8. Final confirmation
# -----------------------------------------------------------------------------

cat(
  "\nSaved bn_masld_model.RData\n"
)


cat(
  "\nNodes:\n"
)


print(
  names(
    bn_fit
  )
)


cat(
  "\nFinal inter-behavior edges:\n"
)


print(
  inter_arcs
)


cat(
  "\nModel building completed successfully.\n"
)
