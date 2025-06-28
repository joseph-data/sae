# ---------------------------------------------------------
# SAE Modeling
# ---------------------------------------------------------

# ---------------------------------------------------------
# 1. Load Libraries and Preprocessing
# ---------------------------------------------------------
library(here)

# Source shared scripts
source(here("R", "1_load_libraries.R"))    # common packages
source(here("R", "2_sweden_preprocess.R")) # defines data

#  Setup Output Directory
out_dir <- file.path(here("outputs"), "sae")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# ---------------------------------------------------------
# 2. Spatial Diagnostics
# ---------------------------------------------------------
# Ensure fh_data ordered by domain
fh_data <- combined_data %>% arrange(County)
# Build spatial weights
nb  <- poly2nb(sweden_shape, row.names = sweden_shape$NAME_1)
W   <- nb2mat(nb, style = "W", zero.policy = TRUE)
idx <- which(!is.na(fh_data$Percent))
# Moran's I test
spatialcor.tests(
  direct    = fh_data$Percent[idx],
  corMatrix = W[idx, idx]
)

# ---------------------------------------------------------
# 3. Data Transformation
# ---------------------------------------------------------
# Convert and log-transform skewed covariates
fh_data <- combined_data %>%
  mutate(
    Percent         = as.numeric(Percent),
    var_est         = as.numeric(var_est),
    Elevation_log   = log(Elevation_m),
    LST_log         = log(LST_C),
    SoilMoist_log   = log(SoilMoisture),
    PopDensity_log  = log(PopDensity),
    Vacancy_log     = log(Vacancy_New)
  )
# Covariate names (use log-transformed variables where applied)
covariates <- c(
  "Elevation_log",    # log(Elevation_m)
  "LST_log",          # log(LST_C)
  "SoilMoist_log",    # log(SoilMoisture)
  "PopDensity_log",   # log(PopDensity)
  "Vacancy_log",      # log(Vacancy_New)
  "NDVI_avg",         # Vegetation index
  "NO2_mol_m2",       # NO2 density (mol/m²)
  "Slope_deg",        # Terrain slope (°)
  "Urban_pct",        # Urban cover (%)
  "VIIRS_avg",        # Night-time lights
  "Northern"          # Regional factor
)

# ---------------------------------------------------------
# 4. Correlation Matrix
# ---------------------------------------------------------
# 4.1 Prepare data and rename for readable labels
corr_vars <- c("Percent", covariates[covariates != "Northern"])
corr_data <- fh_data %>%
  select(all_of(corr_vars)) %>%
  rename(
    `Unemp. Rate`       = Percent,
    `Elevation (log)`   = Elevation_log,
    `LST (log)`         = LST_log,
    `NDVI`              = NDVI_avg,
    `NO2`               = NO2_mol_m2,
    `Slope`             = Slope_deg,
    `Soil Moist. (log)` = SoilMoist_log,
    `Urban (%)`         = Urban_pct,
    `Night Lights`      = VIIRS_avg,
    `Pop Density (log)` = PopDensity_log,
    `Vacancy (log)`     = Vacancy_log
  )

# 4.2 Compute correlation matrix
corr_mat <- cor(corr_data, use = "pairwise.complete.obs")

# 4.3 Plot correlation matrix with original order and labels
out_dir_corr <- file.path(here("outputs"), "sae")
if (!dir.exists(out_dir_corr)) dir.create(out_dir_corr, recursive = TRUE)
png(file.path(out_dir_corr, "correlation_matrix.png"), width = 2000, height = 2000, res = 200)
corrplot(
  corr_mat,
  method      = "color",
  type        = "upper",
  order       = "original",
  addCoef.col = "black",
  tl.col      = "black",
  tl.cex      = 0.8,
  tl.srt      = 45
)
dev.off()

# ---------------------------------------------------------
# 5. Full Fay–Herriot Model Fits
# ---------------------------------------------------------

fh_data <- fh_data %>%
  dplyr::mutate(
    Percent   = as.numeric(Percent),
    var_est   = as.numeric(var_est)
  ) %>%
  as.data.frame()
# Define full formula
formula_full <- as.formula(paste("Percent ~", paste(covariates, collapse = " + ")))

# Initial untransformed model (REML)
fh_initial <- emdi::fh(
  fixed         = formula_full,
  vardir        = "var_est",
  combined_data = fh_data,
  domains       = "County",
  method        = "reml",
  interval      = c(0, 100),
  B             = 1000,
  MSE           = TRUE
)

summary(fh_initial)

# Transformed initial models
fh_arc_init <- emdi::fh(
  fixed              = formula_full,
  vardir             = "var_est",
  combined_data      = fh_data,
  domains            = "County",
  transformation     = "arcsin",
  backtransformation = "bc",
  eff_smpsize        = "eff_sample_size",
  mse_type           = "boot",
  B                  = 1000,
  MSE                = TRUE
)

summary(fh_arc_init)

fh_log_init <- emdi::fh(
  fixed              = formula_full,
  vardir             = "var_est",
  combined_data      = fh_data,
  domains            = "County",
  transformation     = "log",
  backtransformation = "bc_crude",
  eff_smpsize        = "eff_sample_size",
  mse_type           = "analytical",
  B                  = 1000,
  MSE                = TRUE
)

summary(fh_log_init)

fh_logit_init <- emdi::fh(
  fixed              = formula_full,
  vardir             = "var_est",
  combined_data      = fh_data,
  domains            = "County",
  transformation     = "logit",
  backtransformation = "bc",
  eff_smpsize        = "eff_sample_size",
  mse_type           = "boot",
  B                  = 1000,
  MSE                = TRUE
)

summary(fh_logit_init)


# Initial transformed for baseline comparison
fh_initial_trans2 <- emdi::fh(
  fixed              = formula_full,
  vardir             = "var_est",
  combined_data      = fh_data,
  domains            = "County",
  MSE                = TRUE,
  correlation        = "spatial",
  corMatrix          = kk + diag(1e-6, nrow(kk))
)

kk = W[idx, idx]
eigen(kk)$values

# ---------------------------------------------------------
# 6. Reduced Models Fay–Herriot Model
# ---------------------------------------------------------
# Fit full-ML for BIC selection
fh_full_ml <- emdi::fh(
  fixed         = formula_full,
  vardir        = "var_est",
  combined_data = fh_data,
  domains       = "County",
  method        = "ml",
  B             = 1000,
  MSE           = TRUE
)
# Stepwise backward BIC
fh_step <- emdi::step(
  object    = fh_full_ml,
  criteria  = "BIC",
  direction = "backward",
  B         = 1000,
  MSE       = TRUE
)
# Extract reduced formula
formula_step <- fh_step$fixed

# Refit reduced models under REML
fh_red_init  <- emdi::fh(
  fixed = formula_step, vardir = "var_est", combined_data = fh_data, 
  domains = "County", method = "reml", B = 1000, MSE = TRUE
)
fh_red_arc   <- update(fh_arc_init,   fixed = formula_step)
fh_red_log   <- update(fh_log_init,   fixed = formula_step)
fh_red_logit <- update(fh_logit_init, fixed = formula_step)

# ---------------------------------------------------------
# 7. Mapping, Comparison, and Diagnostics
# ---------------------------------------------------------
# Assemble models
models <- list(
  Initial     = fh_initial,
  ArcsinInit  = fh_arc_init,
  LogInit     = fh_log_init,
  LogitInit   = fh_logit_init,
  Stepwise    = fh_step,
  RedInitial  = fh_red_init,
  RedArcsin   = fh_red_arc,
  RedLog      = fh_red_log,
  RedLogit    = fh_red_logit
)

# Helper to rename estimate column
extract_FH <- function(df) {
  if ("FH" %in% names(df)) dplyr::rename(df, FH_est = FH)
  else if ("prediction" %in% names(df)) dplyr::rename(df, FH_est = prediction)
  else df
}

# Loop through models and create outputs
purrr::iwalk(models, function(mod, nm) {
  # 7.1 Prepare map data quietly
  md <- suppressMessages(
    map_plot(
      object     = mod,
      map_obj    = sweden_shape,
      map_dom_id = "NAME_1",
      indicator  = "FH",
      MSE        = TRUE,
      CV         = TRUE,
      return_data= TRUE
    )
  ) %>% extract_FH()
  
  # SAE Map
  ggsave(
    file.path(out_dir, paste0("sae_map_", nm, ".png")),
    ggplot(md) +
      geom_sf(aes(fill = FH_est), color = "grey20", alpha = 0.8) +
      scale_fill_viridis_c() + theme_minimal() +
      labs(title = paste("SAE Estimates -", nm), fill = "Estimate"),
    width  = 8, height = 6, dpi = 300
  )
  
  # Comparison Plot
  compare_path <- file.path(out_dir, paste0("compare_", nm, ".png"))
  png(compare_path, width = 800, height = 600)
  compare_plot(
    object        = mod,
    combined_data = fh_data,
    indicator     = "FH",
    MSE           = TRUE,
    CV            = TRUE
  )
  dev.off()
})

# # Collect models
# models <- list(
#   Initial     = fh_initial,
#   ArcsinInit  = fh_arc_init,
#   LogInit     = fh_log_init,
#   LogitInit   = fh_logit_init,
#   Stepwise    = fh_step,
#   RedInitial  = fh_red_init,
#   RedArcsin   = fh_red_arc,
#   RedLog      = fh_red_log,
#   RedLogit    = fh_red_logit
# )
# 
# out_dir <- here("outputs")
# for (nm in names(models)) {
#   # SAE map
#   md <- map_plot(
#     models[[nm]], map_obj = sweden_shape,
#     map_dom_id = "NAME_1", indicator = "FH", MSE = TRUE, CV = TRUE,
#     return_data = TRUE
#   ) %>% rename(FH_est = FH)
# 
#   ggsave(
#     filename = file.path(out_dir, paste0("sae_map_", nm, ".png")),
#     plot     = ggplot(md) +
#                geom_sf(aes(fill = FH_est), color = "grey20", alpha = 0.8) +
#                scale_fill_viridis_c() + theme_minimal() +
#                labs(title = paste("SAE Estimates -", nm), fill = "Est"),
#     width    = 8, height = 6, dpi = 300
#   )
# 
#   # Compare plot
#   png(file.path(out_dir, paste0("compare_", nm, ".png")), width = 800, height = 600)
#   compare_plot(models[[nm]], CV = TRUE, MSE = TRUE)
#   dev.off()
# }

# ---------------------------------------------------------
# 8. Coefficient Extraction and Saving
# ---------------------------------------------------------
extract_coefs <- function(obj) {
  sm <- summary(obj)
  df <- as.data.frame(sm$model$coefficients, stringsAsFactors = FALSE)
  df$term <- rownames(df)
  df %>% rename(
    estimate  = coefficients,
    std.error = std.error,
    t.value   = t.value,
    p.value   = p.value
  ) %>% select(term, estimate, std.error, t.value, p.value)
}
coefs <- purrr::imap_dfr(models, ~ extract_coefs(.x) %>% mutate(model = .y))

# Save outputs
dir.create(out_dir, showWarnings = FALSE)
saveRDS(models, file = file.path(out_dir, "fh_models.rds"))
write.csv(coefs, file = file.path(out_dir, "fh_coefficients.csv"), row.names = FALSE)

message("test4.R optimized and styled with comment banners.")

## Export final model

unemp = estimators(fh_red_init, MSE = T, CV = T) %>%
  as.data.frame() %>% 
  left_join(sweden_shape, by = c("Domain" = "NAME_1"))

saveRDS(unemp, file = file.path(out_dir, "unemp.rds"))
