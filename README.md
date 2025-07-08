# Small-Area Estimation (SAE) Workflow

[![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/joseph-data/sae/main.yml?branch=main)](https://github.com/joseph-data/sae/actions)
[![GitHub stars](https://img.shields.io/github/stars/joseph-data/sae.svg)](https://github.com/joseph-data/sae/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/joseph-data/sae.svg)](https://github.com/joseph-data/sae/network)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Project Write-up

A detailed write-up for this project can be found in the following PDF:  
[Ms Thesis II.pdf](https://github.com/joseph-data/sae/blob/main/Msc%20Thesis%20II.pdf)

---

This repository provides a reproducible framework for small-area estimation (SAE) of county-level unemployment rates in Sweden, using the **Fay–Herriot** area-level model and its variants. The analysis is organized for clarity and reproducibility.

## Repository Structure

```
├── R/                           # R scripts for each workflow step
│   ├── 1_load_libraries.R       # Load required packages
│   ├── 2_sweden_preprocess.R    # Data import and preprocessing (combined_data, fh_data)
│   ├── 3_visualization.R        # Map and plot functions (map_plot, compare_plot)
│   ├── test4.R                  # Main SAE modeling script
│   └── sae_model_report.R       # Generates coefficient/statistics report (sae_model_report.csv)
├── outputs/
│   └── sae/                     # Results: model objects, CSV tables, and plots
│       ├── fh_models.rds        # Saved FH model list
│       ├── sae_model_report.csv # Final wide-format table of coefficients & stats
│       ├── correlation_matrix.png
│       ├── sae_map_*.png        # Maps by model
│       └── compare_*.png        # Compare plots by model
├── data/                        # Raw input files: direct_estimates.csv, geodata.csv, etc.
├── Msc Thesis II.pdf            # Full project write-up
└── README.md                    # This file
```

## Getting Started

1. **Clone the repository**

    ```bash
    git clone https://github.com/joseph-data/sae.git
    cd sae
    ```

2. **Install dependencies**

    ```r
    # In R
    install.packages(c("here", "dplyr", "ggplot2", "emdi", "spdep", "corrplot", "purrr", "tibble", "tidyr"))
    ```

3. **Run the main script**

    ```r
    # In R or RStudio, source the main SAE script
    source("R/test4.R")
    ```

    This will:
    * Fit various FH models (initial, log, arcsin, logit; full vs. reduced)
    * Perform spatial diagnostics (Moran’s I)
    * Generate correlation matrix and maps
    * Save model objects under `outputs/sae/fh_models.rds`

4. **Generate the report table**

    ```r
    source("R/sae_model_report.R")
    ```

    This creates `outputs/sae/sae_model_report.csv`, which summarizes coefficients (with p-values) and fit statistics (AIC, BIC, R², Adj. R²).

## Scripts Overview

* **1_load_libraries.R**: Loads libraries and sets project-wide options.
* **2_sweden_preprocess.R**: Reads raw survey and auxiliary data, constructs `combined_data`, and calculates sampling variances (`var_est`).
* **3_visualization.R**: Provides `map_plot()` and `compare_plot()` functions to create SAE maps and compare EBLUP vs. direct estimates.
* **test4.R**: Orchestrates the full modeling pipeline:
    1. Spatial diagnostics
    2. Covariate transformation and correlation analysis
    3. FH model fitting (initial and transformed)
    4. Reduced model selection (BIC-driven stepwise)
    5. Mapping and diagnostics
    6. Save outputs
* **sae_model_report.R**: Reads `fh_models.rds`, extracts coefficients (with p-values) and statistics, formats a publication-ready table, and writes to CSV.

## Outputs

* **Correlation Matrix**: `outputs/sae/correlation_matrix.png`
* **SAE Maps**: `outputs/sae/sae_map_<ModelName>.png`
* **Comparison Plots**: `outputs/sae/compare_<ModelName>.png`
* **Model Objects**: `outputs/sae/fh_models.rds`
* **Report Table**: `outputs/sae/sae_model_report.csv`

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

Feel free to raise issues or contribute via pull requests!
