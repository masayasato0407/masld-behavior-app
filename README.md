# MASLD Risk Simulator

A Shiny web application that uses a Bayesian network with the do-operator to
estimate model-predicted changes in an individual's MASLD
(metabolic dysfunction-associated steatotic liver disease) probability under
hypothetical behavioral modifications.

**Live app:** https://liver-prediction.shinyapps.io/masld_behavior_app/

## Overview

This app implements model-based hypothetical simulations using the do-operator
(Pearl 2009) on a Bayesian network trained on JMDC (Japan Medical Data Center)
claims and health checkup data (approximately 5.2 million adults):

- **Layer 1:** Demographics (Age, Sex)
- **Layer 2:** Six lifestyle behaviors from the Japanese Specific Health
  Checkup questionnaire, with data-driven inter-behavior edges learned from
  the data
- **Layer 3:** MASLD outcome

Model-predicted probabilities under hypothetical behavioral modifications are
computed by graph mutilation (removing all incoming edges to the modified
variable) followed by exact inference via the junction tree algorithm
(gRain package).

## Repository contents

- `app.R`: Shiny application (do-operator, single-behavior simulation mode).
- `build_bn_model.R`: Bayesian network construction. Builds the three-layer
  DAG, learns data-driven inter-behavior edges (Cramér's V screening
  conditional on age and sex, followed by BIC score-based direction learning),
  and estimates conditional probability tables by Bayesian parameter
  estimation. Running it produces `bn_masld_model.RData`, which `app.R` loads
  at startup.

> **Data and model availability.** The individual-level JMDC data, and the
> fitted model file (`bn_masld_model.RData`) derived from them, are **not**
> included in this repository under the JMDC data use agreement.
> `build_bn_model.R` contains the model-building procedure only; no data and no
> fitted parameters are embedded. The model architecture, training procedure,
> and validation are described in the associated publication.

## Requirements

```r
install.packages(c("shiny", "bslib", "bnlearn", "gRain", "dplyr"))
# Optional, for the validation routine in build_bn_model.R:
install.packages("pROC")
```

## Usage

The deployed app at the link above requires no setup. To run locally, the
fitted model file `bn_masld_model.RData` must be present in the app directory
(it is not distributed; see above).

1. **Step 1:** Set your demographics and answer six lifestyle questions based
   on your current habits.
2. **Step 2:** View your current MASLD probability and simulate the
   model-predicted change associated with hypothetically modifying one
   behavior. Only one behavior can be toggled at a time; turn it off to select
   another.

## Reproducing the model

With a JMDC-licensed dataset formatted as described in the header of
`build_bn_model.R`:

```r
source("build_bn_model.R")   # writes bn_masld_model.RData, used by app.R
```

For inquiries about data or model access, please contact the authors (subject
to permission from JMDC).

## Data source

Model trained on JMDC (Japan Medical Data Center) claims and health checkup data.
Lifestyle questions are based on the Japanese Specific Health Checkup (Tokutei
Kenshin) questionnaire. Detailed methodology is described in the associated
publication.

## Reference

Manuscript under review.
