# Small-Area Estimation (SAE) Workflow

[![R](https://img.shields.io/badge/R-276DC3?logo=R&logoColor=white)](https://cran.r-project.org/)
[![Python](https://img.shields.io/badge/Python-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![GeoJSON](https://img.shields.io/badge/GeoJSON-FFFB00?logo=geojson&logoColor=black)](https://geojson.org/)
[![Google Earth Engine](https://img.shields.io/badge/Google%20Earth%20Engine-34A853?logo=googleearthengine&logoColor=white)](https://earthengine.google.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Project Write-up

A detailed write-up for this project can be found in the following PDF:  
[Ms Thesis II.pdf](https://github.com/joseph-data/sae/blob/main/Msc%20Thesis%20II.pdf)

---

This repository provides a reproducible framework for small-area estimation (SAE) of county-level unemployment rates in Sweden, using the Fay–Herriot area-level model and its variants. The workflow integrates R for statistical modeling, Python for data acquisition from SCB, and Google Earth Engine (GEE) for geospatial data.

## Repository Structure

```
├── R/
│   ├── 1_load_libraries.R
│   ├── 2_sweden_preprocess.R
│   ├── 3_visualization.R
│   ├── test4.R
│   └── sae_model_report.R
├── outputs/
│   └── sae/
│       ├── fh_models.rds
│       ├── sae_model_report.csv
│       ├── correlation_matrix.png
│       ├── sae_map_*.png
│       └── compare_*.png
├── data/
│   ├── directEstimate.json        # JSON for direct unemployment estimates (from SCB API)
│   ├── popdensity.json            # Population density data (from SCB API)
│   ├── vacancies.csv              # Job vacancies (from arbetsformedlingen.se)
├── Python_pull/                   # Python helper scripts for data acquisition
│   ├── 1_SCBdirect_estimate.py    # Pulls direct unemployment estimates from SCB API
│   └── 2_SCBpopDensity.py         # Pulls population density from SCB API
├── gee.js                         # JavaScript for Google Earth Engine geospatial data extraction
├── Msc Thesis II.pdf              # Full project write-up
└── README.md
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

## Contact

For questions or suggestions, please open an issue or reach out via [GitHub profile](https://github.com/joseph-data).

---
