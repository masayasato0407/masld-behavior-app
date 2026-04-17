# MASLD Risk Simulator

A Shiny web application that uses a Bayesian Network with the do-operator
to estimate how lifestyle behavior changes could affect an individual's 
MASLD (Metabolic dysfunction-Associated Steatotic Liver Disease) probability.

**Live app**: https://liver-prediction.shinyapps.io/masld_behavior_app/

## Overview

This app implements causal inference via the do-operator (Pearl 2009) 
on a Bayesian Network trained on the JMDC claims database 
(5.2 million adults):

- **Layer 1**: Demographics (Age, Sex)
- **Layer 2**: 6 lifestyle behaviors from the Japanese Specific 
  Health Checkup questionnaire, with 2 data-driven inter-behavior edges
  (regular exercise → daily physical activity; 
  daily physical activity → walking speed)
- **Layer 3**: MASLD outcome

Interventional probabilities are computed by graph mutilation 
(removing all incoming edges to the intervened variable) followed by 
exact inference via the junction tree algorithm (gRain package).

## Usage

1. **Step 1**: Set your demographics and answer 6 lifestyle questions 
   based on your current habits.
2. **Step 2**: View your current MASLD probability and simulate the 
   effect of improving one specific behavior. Only one behavior can 
   be toggled at a time; turn it off to select another.

## Requirements

```r
install.packages(c("shiny", "bslib", "bnlearn", "gRain", "dplyr"))
```

## Files

- `app.R` — Shiny application (do-operator, single-intervention mode)
- `bn_masld_model.RData` — Trained Bayesian Network model (DAG + CPTs)
- `www/dag_app.png` — DAG visualization displayed in About tab

## Run locally

```r
shiny::runApp("masld_behavior_app")
```

## Deploy to shinyapps.io

```r
library(rsconnect)
rsconnect::deployApp("masld_behavior_app")
```

## Data source

Model trained on the JMDC (Japan Medical Data Center) claims database 
(N = 5,235,113 adults). Lifestyle questions are based on the Japanese 
Specific Health Checkup (Tokutei Kenshin) questionnaire.

## Reference

Manuscript under review.
