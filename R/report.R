# ---------------------------------------------------------
# SAE Model Reporting Script
# ---------------------------------------------------------
# This script extracts coefficients and fit statistics for full and reduced
# Fay–Herriot models (initial, log, arcsin, logit) and produces a wide-format
# table suitable for publication.

# 1. Load saved FH models ----------------------------------------------
# Read in the list of fitted FH model objects from outputs/sae
models <- readRDS(file.path("outputs", "sae", "fh_models.rds"))

# Define which models are considered full vs reduced
full_names    <- c("Initial", "LogInit", "ArcsinInit", "LogitInit")
reduced_names <- c("RedInitial", "RedLog", "RedArcsin", "RedLogit")

# Load necessary packages
library(dplyr)
library(tidyr)
library(purrr)

# 2. Extract coefficients ---------------------------------------------------
# Custom function to pull estimates and p-values from fh object summaries
extract_coefs_fh <- function(fhobj) {
  sm <- summary(fhobj)
  coef_mat <- sm$model$coefficients  # data.frame with columns: coefficients, std.error, t.value, p.value
  df <- as.data.frame(coef_mat, stringsAsFactors = FALSE, check.names = FALSE)
  df$term <- rownames(df)
  df %>% rename(
    estimate = coefficients,
    p.value  = `p.value`
  ) %>% select(term, estimate, p.value)
}

# Apply to both full and reduced models
coef_list <- purrr::map(models[c(full_names, reduced_names)], extract_coefs_fh)
coef_df   <- purrr::imap_dfr(coef_list, ~ mutate(.x, model = .y))

# Format estimate with p-value in parentheses (fixed 3 decimals)
coef_df <- coef_df %>%
  mutate(
    estimate = round(estimate, 3),
    p.value  = round(p.value, 3),
    est_p    = sprintf("%.3f (%.3f)", estimate, p.value)
  )

# 3. Extract model statistics ---------------------------------------------- ----------------------------------------------
# For FH objects, extract AIC, BIC, R2, and Adjusted R2 from model$model_select
stats_df <- purrr::imap_dfr(models[c(full_names, reduced_names)], function(fhobj, name) {
  ms <- fhobj$model$model_select
  tibble::tibble(
    model = name,
    AIC   = ms$AIC,
    BIC   = ms$BIC,
    R2    = ms$FH_R2,
    AdjR2 = ms$AdjR2
  )
})

# 4. Merge coefficients and stats ------------------------------------------- ----------------------------------------------
# For FH objects, extract AIC, BIC, R2, and Adjusted R2 from model$model_select
stats_df <- purrr::imap_dfr(models[c(full_names, reduced_names)], function(fhobj, name) {
  ms <- fhobj$model$model_select
  tibble::tibble(
    model  = name,
    AIC    = ms$AIC,
    BIC    = ms$BIC,
    R2     = ms$FH_R2,
    AdjR2  = ms$AdjR2
  )
})

# 4. Merge coefficients and stats -------------------------------------------. Merge coefficients and stats -------------------------------------------
# Pivot coefficients: rows = term, cols = model names
coef_wide <- coef_df %>%
  select(model, term, est_p) %>%
  pivot_wider(names_from = model, values_from = est_p)

# Pivot stats: rows = statistic, cols = model names
stats_wide <- stats_df %>%
  pivot_longer(cols = c(AIC, BIC, R2, AdjR2), names_to = "stat", values_to = "value") %>%
  mutate(value = round(value, 3)) %>%
  pivot_wider(names_from = model, values_from = value)

# 5. Combine into final report table ---------------------------------------- ----------------------------------------
report_table <- bind_rows(
  # Coefficients block
  coef_wide  %>% mutate(block = "Coef", row = term) %>% select(block, row, everything()),
  # Statistics block
  stats_wide %>% mutate(block = "Fit",  row = stat) %>% select(block, row, everything())
)

# 6. Format numeric columns to 3 decimal places --------------------------------
# Remove helper columns and round numerics
final_table <- report_table %>%
  select(-c(stat, block, term, row)) %>%
  mutate(across(where(is.numeric), ~ round(., 3)))

# 7. Export table -----------------------------------------------------------
# Write to CSV in outputs/sae folder
write.csv(final_table,
          file = file.path("outputs", "sae", "sae_model_report.csv"),
          row.names = FALSE)

# Print formatted table to console
print(final_table)



 # ---------------------------------------------------------
# # SAE Model Reporting Script
# # ---------------------------------------------------------
# # This script extracts coefficients and fit statistics for full and reduced
# # Fay–Herriot models (initial, log, arcsin, logit) and produces a wide-format
# # table suitable for publication.
# 
# # 1. Load saved FH models ----------------------------------------------
# # Read in the list of fitted FH model objects
# models <- readRDS(file.path("outputs", "sae", "fh_models.rds"))
# 
# # Define which models are considered full vs reduced
# full_names    <- c("Initial", "LogInit", "ArcsinInit", "LogitInit")
# reduced_names <- c("RedInitial", "RedLog", "RedArcsin", "RedLogit")
# 
# # Load necessary packages
# library(dplyr)
# library(tidyr)
# library(purrr)
# 
# # 2. Extract coefficients --------------------------------------------------- ---------------------------------------------------
# # Use summary() to extract coefficient table from fh objects
# extract_coefs_fh <- function(fhobj) {
#   sm <- summary(fhobj)
#   coef_mat <- sm$model$coefficients  # matrix with 'coefficients', 'std.error', etc.
#   df <- as.data.frame(coef_mat, stringsAsFactors = FALSE, check.names = FALSE)
#   df$term <- rownames(df)
#   df %>% rename(
#     estimate  = coefficients,
#     std.error = std.error
#   ) %>% select(term, estimate, std.error)
# }
# 
# # Apply to both full and reduced models
# coef_list <- purrr::map(models[c(full_names, reduced_names)], extract_coefs_fh)
# coef_df   <- purrr::imap_dfr(coef_list, ~ mutate(.x, model = .y))
# 
# # 3. Extract model statistics ----------------------------------------------
# # For FH objects, extract AIC and BIC; R2 not directly available
# stats_df <- purrr::imap_dfr(models[c(full_names, reduced_names)], function(fhobj, name) {
#   ms <- fhobj$model$model_select
#   tibble::tibble(
#     model  = name,
#     AIC    = ms$AIC,
#     BIC    = ms$BIC,
#     R2     = ms$FH_R2,
#     AdjR2  = ms$AdjR2
#   )
# })
# 
# 
# # 4. Merge coefficients and stats ... ---------------------------------------------------
# coef_wide <- coef_df %>%
#   select(model, term, estimate) %>%
#   pivot_wider(names_from = model, values_from = estimate)
# 
# # Pivot stats: rows = statistic, cols = model names
# stats_wide <- stats_df %>%
#   pivot_longer(cols = c(AIC, BIC,R2,AdjR2), names_to = "stat", values_to = "value") %>%
#   pivot_wider(names_from = model, values_from = value)
# 
# # 5. Combine into final report table ----------------------------------------
# report_table <- bind_rows(
#   # Coefficients block
#   coef_wide  %>% mutate(block = "Coef", row = term) %>% select(block, row, everything()),
#   # Statistics block
#   stats_wide %>% mutate(block = "Fit",  row = stat) %>% select(block, row, everything())
# )
# 
# final_table <- report_table %>%
#   select(-c(stat, block, term)) %>%
#   mutate(across(where(is.numeric), ~ round(., 3)))
# 
# # 6. Export table -----------------------------------------------------------
# # Write to CSV in outputs/sae folder
# write.csv(report_table,
#           file = file.path("outputs", "sae", "sae_model_report.csv"),
#           row.names = FALSE)
# 
# # Print to console
# print(report_table)
# 
# summary(models$Initial)
