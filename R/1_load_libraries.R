# 1_load_libraries.R
# ---------------------------------------------------------
# 1. Library Loader
# ---------------------------------------------------------

# ---------------------------------------------------------
# 2. Required Packages
# ---------------------------------------------------------
# Vector of packages needed for this project
# Include all libraries used across preprocessing, visualization, and SAE scripts
target_pkgs <- c(
  "sf",         # spatial data handling
  "tidyverse",  # data manipulation & visualization
  "emdi",       # small area estimation
  "tmap",       # thematic mapping
  "glmnet",     # regularized regression
  "here",       # project-relative file paths
  "conflicted", # manage function conflicts
  "spdep",      # spatial dependence matrices and tests
  "corrplot"    # correlation plots
)

# ---------------------------------------------------------
# 3. Install Missing Packages
# ---------------------------------------------------------
toinstall <- setdiff(target_pkgs, rownames(installed.packages()))
if (length(toinstall) > 0) {
  message("Installing missing packages: ", paste(toinstall, collapse = ", "))
  install.packages(toinstall)
}

# ---------------------------------------------------------
# 4. Load Packages
# ---------------------------------------------------------
for (pkg in target_pkgs) {
  message("Loading package: ", pkg)
  library(pkg, character.only = TRUE)
}

# ---------------------------------------------------------
# 5. Resolve Name Conflicts
# ---------------------------------------------------------
# Ensure dplyr's filter and lag take precedence
conflict_prefer("filter", "dplyr")
conflict_prefer("lag",    "dplyr")
message("Function conflicts resolved: filter and lag from dplyr preferred.")

# ---------------------------------------------------------
# 6. Set Seed
# ---------------------------------------------------------
# For reproducibility of random operations
set.seed(2)
message("Random seed set to 2.")

# ---------------------------------------------------------
# 7. Data Path Helper
# ---------------------------------------------------------
# Usage: data_path("raw", "myfile.csv") -> <project_root>/data/raw/myfile.csv
data_path <- function(...) {
  here::here("data", ...)
}
message("Helper 'data_path()' defined for project-relative data paths.")

