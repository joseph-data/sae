# Small-Area Estimation (SAE) — Sweden

[![R](https://img.shields.io/badge/R-276DC3?logo=R&logoColor=white)](https://cran.r-project.org/)
[![Python](https://img.shields.io/badge/Python-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![Google Earth Engine](https://img.shields.io/badge/Google%20Earth%20Engine-34A853?logo=googleearthengine&logoColor=white)](https://earthengine.google.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Reproducible workflow for county-level unemployment small-area estimation in Sweden using Fay–Herriot area-level models (R), with optional Python notebooks for pulling SCB inputs and a Google Earth Engine script for geospatial covariates.

## Project write-up

- Thesis PDF: [`documentation/Msc Thesis II.pdf`](documentation/Msc%20Thesis%20II.pdf)

## Repository layout

```
.
├── R/                      # R scripts (preprocess, visualization, SAE models)
├── Python_pull/            # Python notebooks to pull SCB inputs (PXWeb)
├── data/                   # Inputs (SCB, GEE), shapefiles, and intermediate .RData
├── outputs/                # Generated figures/maps/reports (gitignored)
├── renv.lock, renv/        # R dependency lock + bootstrap
├── pyproject.toml, uv.lock # Python project metadata + lock (minimal)
└── qmarkdown/              # Thesis supporting document (Quarto)
```

## Quick start (R)

1. Restore R dependencies (recommended):

    ```r
    install.packages("renv")
    renv::restore()
    ```

2. Preprocess data + generate direct-estimate maps:

    ```r
    source("R/3_visualization.R")
    ```

3. Fit Fay–Herriot models + write model outputs:

    ```r
    source("R/test4.R")
    ```

4. Build the model summary table:

    ```r
    source("R/report.R")
    ```

## Inputs and outputs

**Key inputs used by `R/2_sweden_preprocess.R`:**

- `data/SWE_adm/SWE_adm1.shp` (county boundaries)
- `data/UnempDirect.csv` (direct unemployment estimates, from `Python_pull/notebooks/02_UnempDirect.ipynb`)
- `data/geodata.csv` (GEE-derived covariates)
- `data/Pop_density.csv` (population density, from `Python_pull/notebooks/01_Population_Density.ipynb`)
- `data/vacancies.csv` (job vacancies)

**Common outputs:**

- `data/processed_sweden.RData` (processed data objects)
- `outputs/html/sweden_direct_map.html` (interactive map)
- `outputs/img/sweden_direct_map_*.png` (static maps)
- `outputs/sae/` (SAE model artifacts, e.g. `fh_models.rds`, plots, tables)

`outputs/` is generated and ignored by git.

## Optional: refresh SCB inputs (Python)

See [`Python_pull/README.md`](Python_pull/README.md) and run the notebooks in `Python_pull/notebooks/`. They write `data/Pop_density.csv` and `data/UnempDirect.csv` directly, which `R/2_sweden_preprocess.R` reads as-is — no renaming or column changes needed.

## Contact

For questions or suggestions, please open an issue or reach out via https://github.com/joseph-data
