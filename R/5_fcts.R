# ---------------------------------------------------------
# 4_SAE_Variable_Selection_and_Modeling.R
# ---------------------------------------------------------

# ---------------------------------------------------------
# 1. Source Libraries and Data Preparation
# ---------------------------------------------------------
library(here)
source(here("R", "1_load_libraries.R"))    # Load packages
source(here("R", "2_sweden_preprocess.R")) # Prepare combined_data, sweden_shape

# Prepare 'data_fh' for FH modeling
data_fh <- combined_data %>%
  dplyr::mutate(
    Percent   = as.numeric(Percent),
    var_est   = as.numeric(var_est)
  ) %>%
  as.data.frame()

# Define candidate covariates
cand_vars <- c(
  "Elevation_m", "LST_C", "NDVI_avg", "NO2_mol_m2",
  "Slope_deg", "SoilMoisture", "Urban_pct", "VIIRS_avg",
  "PopDensity", "Vacancy_New", "Northern"
)

# ---------------------------------------------------------
# 2. Numeric Covariate Screening
# ---------------------------------------------------------
# Identify numeric candidates
numeric_covs <- cand_vars[sapply(data_fh[cand_vars], is.numeric)]

if (length(numeric_covs) > 1) {
  # Compute |correlation| with direct estimates
  corr_df <- data_fh %>%
    dplyr::select(all_of(numeric_covs), Percent) %>%
    summarise(across(all_of(numeric_covs), ~ cor(.x, Percent, use = "complete.obs"))) %>%
    tidyr::pivot_longer(everything(), names_to = "variable", values_to = "corr") %>%
    dplyr::mutate(abs_corr = abs(corr)) %>%
    dplyr::arrange(dplyr::desc(abs_corr))

  print(corr_df)

  # Plot |correlation|
  ggplot2::ggplot(corr_df, aes(x = reorder(variable, abs_corr), y = abs_corr)) +
    ggplot2::geom_col() + ggplot2::coord_flip() +
    ggplot2::labs(
      title = "|Correlation| with Direct Unemployment Estimates",
      x     = "Covariate", y = "|Correlation|"
    ) +
    ggplot2::theme_minimal()
} else {
  message("Not enough numeric covariates for correlation screening.")
}

# ---------------------------------------------------------
# 3. Multicollinearity Check (full candidate set)
# ---------------------------------------------------------
# The correlation ranking above is descriptive only. Pre-selecting the
# top-k covariates by correlation with Percent and then fitting/stepwise-
# selecting on that same ~21-domain sample would be double dipping and
# would invalidate the resulting p-values/VIFs. The full candidate set is
# carried forward instead and left to emdi::step() alone (section 5).
# VIF depends only on the predictors' own correlation structure (not on
# Percent), so pruning by VIF is not data dredging the way the top-k
# correlation filter was. Iteratively drop the highest-VIF covariate
# until all remaining VIFs are <= 10.
repeat {
  vif_fit  <- lm(Percent ~ ., data = data_fh %>% dplyr::select(Percent, all_of(cand_vars)))
  vif_vals <- car::vif(vif_fit)
  # car::vif() reports GVIF^(1/(2*Df)) instead of VIF when any predictor
  # (e.g. the Northern factor) has more than 1 df; square it back to a
  # VIF-comparable scale before thresholding.
  vif_scalar <- if (is.matrix(vif_vals)) vif_vals[, "GVIF^(1/(2*Df))"]^2 else vif_vals
  worst <- names(which.max(vif_scalar))
  if (vif_scalar[worst] <= 10 || length(cand_vars) <= 2) break
  message("Dropping '", worst, "' for collinearity (VIF = ", round(vif_scalar[worst], 1), ")")
  cand_vars <- setdiff(cand_vars, worst)
}
print(round(vif_scalar, 2))
message("Covariates retained after VIF pruning: ", paste(cand_vars, collapse = ", "))

# ---------------------------------------------------------
# 3b. Standardize Numeric Covariates
# ---------------------------------------------------------
# Even with collinearity ruled out, raw covariate scales span many orders
# of magnitude (e.g. NO2_mol_m2 ~1e-5 vs Vacancy_New in the thousands),
# which leaves X'Vi^-1X numerically singular in floating point during
# emdi::fh()'s REML search. Standardizing avoids that; fitted values and
# predictions are unaffected, only coefficients become per-SD effects.
numeric_cand <- cand_vars[sapply(data_fh[cand_vars], is.numeric)]
data_fh[numeric_cand] <- scale(data_fh[numeric_cand])

# ---------------------------------------------------------
# 4. Preliminary Fay–Herriot Model (full candidate set)
# ---------------------------------------------------------
prelim_formula <- as.formula(
  paste("Percent ~", paste(cand_vars, collapse = " + "))
)
fh_prelim <- emdi::fh(
  fixed         = prelim_formula,
  vardir        = "var_est",
  combined_data = data_fh,
  domains       = "County",
  method        = "reml",
  MSE           = TRUE
)
summary(fh_prelim)

# ---------------------------------------------------------
# 5. Stepwise Model Selection (KICb2)
# ---------------------------------------------------------
# Fit full model via ML
fh_full_ml <- emdi::fh(
  fixed         = prelim_formula,
  vardir        = "var_est",
  combined_data = data_fh,
  domains       = "County",
  method        = "ml",
  B             = c(0,50)
)
# Backward selection
fh_step <- emdi::step(
  object    = fh_full_ml,
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
  B             = c(0,50),
  MSE           = TRUE
)

# ---------------------------------------------------------
# 6. Transformed Models for Comparison
# ---------------------------------------------------------
# Arcsin-BC transformed
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
  interval           = c(0,100)
)
fh_prelim_trans <- emdi::fh(
  fixed              = prelim_formula,
  vardir             = "var_est",
  combined_data      = data_fh,
  domains            = "County",
  method             = "reml",
  transformation     = "arcsin",
  backtransformation = "bc",
  eff_smpsize        = "eff_sample_size",
  MSE                = TRUE,
  mse_type           = "boot",
  interval           = c(0,100)
)

# ---------------------------------------------------------
# 7. Mapping SAE Results
# ---------------------------------------------------------
models_list <- list(
  Prelim       = fh_prelim,
  Stepwise     = fh_step,
  PrelimTrans  = fh_prelim_trans,
  StepTrans    = fh_step_trans
)
output_dir <- here("outputs"); if (!dir.exists(output_dir)) dir.create(output_dir, recursive=TRUE)

for (nm in names(models_list)) {
  md <- emdi::map_plot(
    object     = models_list[[nm]],
    map_obj    = sweden_shape,
    map_dom_id = "NAME_1",
    indicator  = "FH",
    MSE        = TRUE,
    CV         = TRUE,
    return_data= TRUE
  ) %>% dplyr::rename(FH_est = FH)

  p <- ggplot2::ggplot(md) +
    ggplot2::geom_sf(aes(fill = FH_est), color="grey20", alpha=.8) +
    ggplot2::scale_fill_viridis_c() +
    ggplot2::theme_minimal() +
    ggplot2::labs(title = paste0("SAE Map: ", nm), fill = "Estimate")

  ggplot2::ggsave(
    file.path(output_dir, paste0("sae_map_", nm, ".png")),
    plot  = p, width=8, height=6, dpi=300, units="in"
  )
}

# ---------------------------------------------------------
# 8. Diagnostics and Table Outputs
# ---------------------------------------------------------
# Compare direct vs. SAE
for (nm in names(models_list)) {
  obj <- models_list[[nm]]
  png(file.path(output_dir, paste0("compare_", nm, ".png")), 800,600)
  emdi::compare_plot(obj, CV=TRUE, MSE=TRUE)
  dev.off()
  png(file.path(output_dir, paste0("diagn_", nm, ".png")), 800,600)
  plot(obj)
  dev.off()
}

# Extract coefficient tables
extract_coefs <- function(mod) {
  sm <- summary(mod)
  co <- as.data.frame(sm$model$coefficients)
  co$term <- rownames(co)
  dplyr::rename(co,
    estimate  = coefficients,
    std.error = std.error,
    t.value   = t.value,
    p.value   = p.value
  ) %>% dplyr::select(term, estimate, std.error, t.value, p.value)
}

# Save tables
tab_list <- lapply(models_list, extract_coefs)
sapply(names(tab_list), function(nm) {
  saveRDS(tab_list[[nm]], file=file.path(output_dir, paste0("coef_", nm, ".rds")))
})

message("Variable selection and full SAE modeling script complete.")
