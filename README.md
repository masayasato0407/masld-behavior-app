# MASLD Risk Simulator

A Shiny web application that uses a Bayesian Network with the do-operator 
to estimate how lifestyle behavior changes could affect an individual's 
MASLD (Metabolic dysfunction-Associated Steatotic Liver Disease) probability.

**Live app:** https://liver-prediction.shinyapps.io/masld_behavior_app/

## Overview

This app implements causal inference via the do-operator (Pearl 2009) on a 
Bayesian Network trained on the JMDC (Japan Medical Data Center) claims 
database (approximately 5.2 million adults):

- **Layer 1**: Demographics (Age, Sex)
- **Layer 2**: 6 lifestyle behaviors from the Japanese Specific Health 
  Checkup questionnaire, with data-driven inter-behavior edges learned 
  from the data
- **Layer 3**: MASLD outcome

Interventional probabilities are computed by graph mutilation (removing all 
incoming edges to the intervened variable) followed by exact inference via 
the junction tree algorithm (gRain package).

## Usage

1. **Step 1**: Set your demographics and answer 6 lifestyle questions based 
   on your current habits.
2. **Step 2**: View your current MASLD probability and simulate the effect 
   of improving one specific behavior. Only one behavior can be toggled at 
   a time; turn it off to select another.

## Requirements

```r
install.packages(c("shiny", "bslib", "bnlearn", "gRain", "dplyr"))
```

## Files

- `app.R` — Shiny application (do-operator, single-intervention mode)

> **Note:** The trained Bayesian network model file (`bn_masld_model.RData`) 
> is not included in this repository due to data use agreement restrictions 
> with JMDC. The model architecture, training procedure, and validation 
> results are described in detail in the forthcoming publication. Users who 
> wish to interact with the trained model can use the live web application 
> linked above.

## Run locally

This application requires the trained Bayesian network model file, which 
is not distributed with this repository. To run locally, please refer to 
the live web application or contact the authors.

## Data source

Model trained on the JMDC (Japan Medical Data Center) claims database. 
Lifestyle questions are based on the Japanese Specific Health Checkup 
(Tokutei Kenshin) questionnaire. Detailed methodology is described in the 
forthcoming publication.

## Reference

Manuscript under review.
