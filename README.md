# MASLD Risk Simulator

A Shiny web application that uses a Bayesian Network to estimate how lifestyle behavior changes could affect an individual's MASLD (Metabolic dysfunction-Associated Steatotic Liver Disease) probability.

## Overview

This app implements exact inference via the junction tree algorithm on a 3-layer Bayesian Network:
- **Layer 1**: Demographics (Age, Sex)
- **Layer 2**: 6 Lifestyle behaviors from the Japanese Specific Health Checkup questionnaire
- **Layer 3**: MASLD outcome

## Usage

1. **Step 1**: Set your demographics and answer 6 lifestyle questions
2. **Step 2**: View your MASLD probability and simulate the effect of behavior changes

## Requirements

```r
install.packages(c("shiny", "bslib", "bnlearn", "gRain", "dplyr"))

# For DAG visualization in About tab (optional)
if (!requireNamespace("BiocManager", quietly = TRUE))
  install.packages("BiocManager")
BiocManager::install(c("Rgraphviz", "graph"))
```

## Files

- `app.R` — Shiny application
- `bn_masld_model.RData` — Trained Bayesian Network model (DAG + CPTs)

## Run locally

```r
shiny::runApp("masld_app")
```

## Deploy to shinyapps.io

```r
library(rsconnect)
rsconnect::deployApp("masld_app")
```

## Data source

Model trained on the JMDC (Japan Medical Data Center) claims database. Lifestyle questions are based on the Japanese Specific Health Checkup (Tokutei Kenshin) questionnaire.
