# MASLD Probability Simulator

A Shiny web application that uses a Bayesian network (BN) with the do-operator
to generate profile-specific, model-based hypothetical simulations of MASLD
(metabolic dysfunction-associated steatotic liver disease) probability under
alternative lifestyle-behavior scenarios.

**Live app:** https://liver-prediction.shinyapps.io/masld_behavior_app/

## Overview

This app implements model-based hypothetical simulations using the do-operator
(Pearl 2009) on a Bayesian network trained on JMDC (Japan Medical Data Center)
claims and health checkup data from approximately 5.2 million adults:

- **Layer 1:** Demographics (Age, Sex)
- **Layer 2:** Six lifestyle behaviors from the Japanese Specific Health
  Checkup questionnaire, with data-driven inter-behavior edges learned from
  the data
- **Layer 3:** MASLD outcome

The six lifestyle behaviors are regular exercise, daily physical activity,
walking speed, eating speed, late-night eating, and skipping breakfast.

Model-predicted probabilities under hypothetical behavioral scenarios are
computed by graph mutilation (removing all incoming edges to the modified
variable) followed by exact inference via the junction tree algorithm
(`gRain` package).

All six lifestyle behaviors are retained when estimating the current
profile-specific MASLD probability. However, **skipping breakfast is not
available as a hypothetical scenario option in the simulation panel**. Its
BN-derived modeled effect was directionally inconsistent with the positive
associations observed in the regression analyses and was therefore not
considered sufficiently robust for behavioral prioritization. Skipping
breakfast remains part of the current profile because it is one of the six
variables in the fitted BN.

## Web application interface

The current interface is designed to present the BN outputs as model-based
hypothetical scenarios rather than as clinical recommendations or causal
effects.

- **Step 1:** Enter demographics and answer the six lifestyle questions.
- Select **“View Model-Predicted Probability & Explore Scenarios”** to proceed.
- **Step 2:** View the **Model-Predicted MASLD Probability** for the current
  profile.
- Select one eligible unhealthy behavior under
  **“Select One Behavior to Set to Healthy.”**
- The app displays the probability under the **Hypothetical Scenario** and the
  **Simulated Change in Model-Predicted Probability**.
- The **Scenario Comparison** panel summarizes the selected behavioral
  scenario.
- Only one behavior can be set to healthy at a time; turn it off before
  selecting another.

The results screen displays the following disclaimer:

> **For research and illustrative purposes. Results represent model-predicted
> probabilities under hypothetical behavioral scenarios and are not standalone
> diagnostic or treatment recommendations.**

## Interpretation

The app is intended for hypothesis-generating, model-based comparison of
behavioral scenarios. The displayed probabilities and simulated changes should
**not** be interpreted as causal effects of actual lifestyle modification,
precise individual-level risk predictions, or standalone diagnostic or
treatment recommendations.

The underlying analyses and BN simulations are based on observational data and
remain subject to residual or unmeasured confounding and uncertainty regarding
the assumed network structure.

## Repository contents

- `app.R`: Shiny application. Uses all six lifestyle behaviors to estimate the
  current profile-specific MASLD probability and allows single-behavior
  hypothetical scenarios for five behaviors. Skipping breakfast is excluded
  from the simulation options as described above.
- `build_bn_model.R`: Bayesian network construction. Builds the three-layer
  DAG, learns data-driven inter-behavior edges (Cramér's V screening
  conditional on age and sex, followed by BIC score-based direction learning),
  and estimates conditional probability tables by Bayesian parameter
  estimation. Running it produces `bn_masld_model.RData`, which `app.R` loads
  at startup.
- `www/dag_app.png`: Network structure figure displayed in the **About** tab.

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

1. **Step 1:** Set demographics and answer six lifestyle questions based on
   current habits. All six responses contribute to the model-predicted MASLD
   probability for the current profile.
2. **Step 2:** View the current model-predicted MASLD probability and explore
   the model-predicted probability after one eligible behavior is
   hypothetically set to healthy. Only one behavior can be toggled at a time;
   turn it off to select another. Skipping breakfast is not offered as a
   hypothetical scenario option because its modeled effect was not considered
   sufficiently robust for behavioral prioritization.

## Reproducing the model

With a JMDC-licensed dataset formatted as described in the header of
`build_bn_model.R`:

```r
source("build_bn_model.R")   # writes bn_masld_model.RData, used by app.R
```

For inquiries about data or model access, please contact the authors (subject
to permission from JMDC).

## Data source

Model trained on JMDC (Japan Medical Data Center) claims and health checkup
data. Lifestyle questions are based on the Japanese Specific Health Checkup
(Tokutei Kenshin) questionnaire. Detailed methodology is described in the
associated publication.

## Reference

Manuscript under review.
