# ---------------------------------------------------------
# 4_SAE.R 
# ---------------------------------------------------------

# ---------------------------------------------------------
# 1. Source Libraries and Preprocessing
# ---------------------------------------------------------
library(here)
source(here("R", "1_load_libraries.R"))    # Load packages
source(here("R", "2_sweden_preprocess.R")) # Prepare combined_data, sweden_shape

# ---------------------------------------------------------
# 2. Preliminaries and Spatial Correlation
# ---------------------------------------------------------
# Plot the distribution of direct estimates
plot(exp(na.omit(combined_data$Percent)), type = 'l')

# Arrange data by county for spatial weight consistency
direct_data <- combined_data %>% dplyr::arrange(County)

# Create spatial weight matrix based on adjacency of counties
nb_list <- spdep::poly2nb(sweden_shape, row.names = sweden_shape$NAME_1)
W_mat   <- spdep::nb2mat(nb_list, style = "W", zero.policy = TRUE)

# Test for spatial autocorrelation in direct estimates
valid_idx <- which(!is.na(direct_data$Percent))
spat_test <- emdi::spatialcor.tests(
  direct    = direct_data$Percent[valid_idx],
  corMatrix = W_mat[valid_idx, valid_idx]
)



# ---------------------------------------------------------
# 3. Prepare Data for SAE Modeling
# ---------------------------------------------------------
# Ensure correct types and conversion for the FH model
data_fh <- combined_data %>%
  dplyr::mutate(
    Percent   = as.numeric(Percent),
    var_est   = as.numeric(var_est)
  ) %>%
  as.data.frame()

# Define candidate covariates based on cleaned preprocess script
cand_vars <- c(
  "Elevation_m",     # Elevation (m)
  "LST_C",           # Land surface temperature (°C)
  "NDVI_avg",        # Vegetation index
  "NO2_mol_m2",      # NO2 density (mol/m²)
  "Slope_deg",       # Terrain slope (°)
  "SoilMoisture",    # Soil moisture (m³/m³)
  "Urban_pct",       # Urban cover (%)
  "VIIRS_avg",       # Night-time lights
  "PopDensity",      # Population density (per km²)
  "Vacancy_New",     # New vacancies (count)
  "Northern"         # Regional factor
)

# Check collinearity among numeric covariates
numeric_covs <- cand_vars[sapply(data_fh[cand_vars], is.numeric)]
if (length(numeric_covs) > 1) {
  cor_mat <- cor(data_fh[, numeric_covs], use = "pairwise.complete.obs")
  print(round(cor_mat, 2))
} else {
  message("Not enough numeric covariates for correlation check.")
}

# ---------------------------------------------------------
# 4. Initial Fay–Herriot Model
# ---------------------------------------------------------
initial_formula <- as.formula(
  paste0("Percent ~ ", paste(cand_vars, collapse = " + "))
)
fh_initial <- emdi::fh(
  fixed         = initial_formula,
  vardir        = "var_est",
  combined_data = data_fh,
  domains       = "County",
  method        = "reml",
  interval      = c(0, 100),
  B             = c(0, 50),
  MSE           = TRUE
)

# ---------------------------------------------------------
# 5. Stepwise Model Selection
# ---------------------------------------------------------
# Fit full model via ML for selection criteria
fh_std <- emdi::fh(
  fixed         = initial_formula,
  vardir        = "var_est",
  combined_data = data_fh,
  domains       = "County",
  method        = "ml",
  B             = c(0, 50)
)

# Backward stepwise (KICb2)
fh_step <- emdi::step(
  object    = fh_std,
  criteria  = "KICb2",
  direction = "backward",
  B         = 50,
  MSE       = TRUE
)
# Refit selected model via ML
step_formula <- fh_step$fixed
fh_step <- emdi::fh(
  fixed         = step_formula,
  vardir        = "var_est",
  combined_data = data_fh,
  domains       = "County",
  method        = "ml",
  B             = c(0, 50),
  MSE           = TRUE
)

# ---------------------------------------------------------
# 6. Transformed Models for Comparison
# ---------------------------------------------------------
# Stepwise transformed (arcsin-BC bootstrap)
fh_step_trans <- emdi::fh(
  fixed              = step_formula,
  vardir             = "var_est",
  combined_data      = data_fh,
  domains            = "County",
  method             = "reml",
  transformation     = "arcsin",
  backtransformation = "bc",
  eff_smpsize        = "eff_sample_size",
  MSE                = TRUE,
  mse_type           = "boot",
  interval           = c(0, 100)
)

# Initial transformed for baseline comparison
fh_initial_trans <- emdi::fh(
  fixed              = initial_formula,
  vardir             = "var_est",
  combined_data      = data_fh,
  domains            = "County",
  method             = "reml",
  transformation     = "arcsin",
  backtransformation = "bc",
  eff_smpsize        = "eff_sample_size",
  MSE                = TRUE,
  mse_type           = "boot",
  interval           = c(0, 100)
)





# ---------------------------------------------------------
# 7. Mapping SAE Results
# ---------------------------------------------------------
models_to_map <- list(
  initial       = fh_initial,
  step          = fh_step,
  initial_trans = fh_initial_trans,
  step_trans    = fh_step_trans
)
output_dir <- here("outputs"); if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

for (nm in names(models_to_map)) {
  md <- emdi::map_plot(
    object     = models_to_map[[nm]],
    map_obj    = sweden_shape,
    map_dom_id = "NAME_1",
    indicator  = "FH",
    MSE        = TRUE,
    CV         = TRUE,
    return_data= TRUE
  ) %>%
    dplyr::rename(FH_est = FH)
  
  p <- ggplot2::ggplot(md) +
    ggplot2::geom_sf(aes(fill = FH_est), color = "grey20", alpha = 0.8) +
    ggplot2::scale_fill_viridis_c(option = "viridis") +
    ggplot2::theme_minimal() +
    ggplot2::labs(
      title = paste0("Small-Area Estimates: ", nm),
      fill  = "Estimate"
    )
  
  ggplot2::ggsave(
    filename = file.path(output_dir, paste0("sae_map_", nm, ".png")),
    plot     = p,
    width    = 8,
    height   = 6,
    dpi      = 300,
    units    = "in"
  )
}

# ---------------------------------------------------------
# 8. Diagnostics and Tables
# ---------------------------------------------------------
# Compare direct vs. FH and diagnostics
for (nm in names(models_to_map)) {
  obj <- models_to_map[[nm]]
  png(file.path(output_dir, paste0("fh_", nm, "_compare.png")), width = 800, height = 600)
  emdi::compare_plot(obj, CV = TRUE, MSE = TRUE)
  dev.off()
  png(file.path(output_dir, paste0("fh_", nm, "_plot.png")), width = 800, height = 600)
  plot(obj)
  dev.off()
}

# Extract model coefficients into tables
extract_fh <- function(x) {
  sm <- summary(x)
  m  <- as.matrix(sm$model$coefficients)
  df <- as.data.frame(m)
  df$term <- rownames(df)
  df %>%
    dplyr::rename(
      estimate  = coefficients,
      std.error = std.error,
      t.value   = t.value,
      p.value   = p.value
    ) %>%
    dplyr::select(term, estimate, std.error, t.value, p.value)
}

# Save coefficient tables
for (nm in names(models_to_map)) {
  df <- extract_fh(models_to_map[[nm]]) %>% dplyr::mutate(model = nm)
  save(
    df,
    file = file.path(output_dir, paste0("sae_table_", nm, ".RData"))
  )
}

# Side-by-side comparison tables (gt)
if (!requireNamespace("gt", quietly = TRUE)) install.packages("gt")
library(gt)

tab_initial <- purrr::imap_dfr(
  list(Untransformed = fh_initial, Transformed = fh_initial_trans),
  ~ extract_fh(.x) %>% dplyr::mutate(model = .y)
)

tab_stepwise <- purrr::imap_dfr(
  list(Untransformed = fh_step, Transformed = fh_step_trans),
  ~ extract_fh(.x) %>% dplyr::mutate(model = .y)
)

gt_initial <- tab_initial %>%
  gt(groupname_col = "model", rowname_col = "term") %>%
  tab_header(
    title    = md("**Initial Model Comparison**"),
    subtitle = "Untransformed vs. Arcsin-BC"
  ) %>%
  fmt_number(columns = c(estimate, std.error, p.value), decimals = 3)

gt_stepwise <- tab_stepwise %>%
  gt(groupname_col = "model", rowname_col = "term") %>%
  tab_header(
    title    = md("**Stepwise Model Comparison**"),
    subtitle = "Untransformed vs. Arcsin-BC"
  ) %>%
  fmt_number(columns = c(estimate, std.error, p.value), decimals = 3)

# Save grouped tables
save(
  gt_initial,
  gt_stepwise,
  file = file.path(output_dir, "sae_tables_grouped.RData")
)
saveRDS(spat_test, "spat_test.rds")
message("SAE script updated to use renamed variables and cleaned covariate list.")

