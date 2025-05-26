# ---------------------------------------------------------
# 1. Load Libraries and Example Data
# ---------------------------------------------------------
library(emdi)                                   # Small area estimation and mapping tools
library(sp)                                     # Spatial data manipulation
library(spdep)                                  # Spatial dependence tests

data(eusilcA_popAgg)                            # Population-aggregated data for 94 Austrian districts
data(eusilcA_smpAgg)                            # Sample-aggregated data for the same districts

# ---------------------------------------------------------
# 2. Combine Population and Sample Data
# ---------------------------------------------------------
combined_data <- combine_data(
  pop_data    = eusilcA_popAgg,                 # Population data frame
  pop_domains = "Domain",                       # Domain identifier in population data
  smp_data    = eusilcA_smpAgg,                 # Sample data frame
  smp_domains = "Domain"                        # Domain identifier in sample data
)

# ---------------------------------------------------------
# 3. Identify Spatial Structures and Test for Autocorrelation
# ---------------------------------------------------------
load_shapeaustria()                             # Load Austrian district shapefile
shape_austria_dis <- shape_austria_dis[          
  order(shape_austria_dis$PB),                  # Ensure same order as sample data
]

# Merge spatial polygons with sample data by district ID
austria_shape <- merge(
  shape_austria_dis, 
  eusilcA_smpAgg, 
  by.x = "PB", by.y = "Domain", 
  all.x = FALSE
)

# Build spatial weights matrix
rel <- poly2nb(austria_shape, row.names = austria_shape$PB)
eusilcA_prox <- nb2mat(rel, style = "W", zero.policy = TRUE)

# Test for spatial autocorrelation in direct estimates
spatialcor.tests(
  direct    = combined_data$Mean,               # Direct domain means
  corMatrix = eusilcA_prox                      # Spatial weight matrix
)

# ---------------------------------------------------------
# 4. Model Selection for the Standard Fay–Herriot Model
# ---------------------------------------------------------
# Initial candidate model with three covariates
fh_std <- fh(
  fixed         = Mean ~ cash + self_empl + unempl_ben,
  vardir        = "Var_Mean",
  combined_data = combined_data,
  domains       = "Domain",
  method        = "ml",
  B             = c(0, 50)
)
# Stepwise selection using KICb2 criterion
step(fh_std, criteria = "KICb2")

# ---------------------------------------------------------
# 5. Estimate EBLUPs and Compute MSEs
# ---------------------------------------------------------
# Final model with selected covariates
fh_std <- fh(
  fixed         = Mean ~ cash + self_empl,
  vardir        = "Var_Mean",
  combined_data = combined_data,
  domains       = "Domain",
  method        = "ml",
  MSE           = TRUE,
  B             = c(0, 50)
)
summary(fh_std)                                 # Model summary
plot(fh_std)                                    # Diagnostic plots

# ---------------------------------------------------------
# 6. Compare Model-Based Estimates with Direct Estimates
# ---------------------------------------------------------
compare_plot(
  fh_std,
  CV    = TRUE,                                 # Plot coefficient of variation
  label = "no_title"
)

# ---------------------------------------------------------
# 7. Goodness-of-Fit Diagnostics
# ---------------------------------------------------------
compare(fh_std)                                 # Statistical diagnostic tests

# ---------------------------------------------------------
# 8. Benchmarking for Consistency with Known Totals
# ---------------------------------------------------------
fh_bench <- benchmark(
  fh_std,
  benchmark = 20140.09,                         # Known overall total (e.g., mean × population)
  share     = eusilcA_popAgg$ratio_n,          # Domain population shares
  type      = "ratio"
)
head(fh_bench)                                  # First rows of benchmarked estimates

# ---------------------------------------------------------
# 9. Choropleth Mapping of Estimates and MSEs
# ---------------------------------------------------------
load_shapeaustria()                             # Reload shapefile if needed
map_plot(
  object      = fh_std,
  MSE         = TRUE,
  map_obj     = shape_austria_dis,
  map_dom_id  = "PB",
  scale_points = list(
    Direct = list(ind = c(8000, 60000), MSE = c(200000, 10000000)),
    FH     = list(ind = c(8000, 60000), MSE = c(200000, 10000000))
  )
)

# ---------------------------------------------------------
# 10. Extended Area-Level Models
# ---------------------------------------------------------

# 10.1 Arcsin-Transformed Fay–Herriot Model for Proportions
fh_arcsin <- fh(
  fixed              = MTMED ~ cash + age_ben + rent + house_allow,
  vardir             = "Var_MTMED",
  combined_data      = combined_data,
  domains            = "Domain",
  transformation     = "arcsin",
  backtransformation = "bc",
  eff_smpsize        = "n",
  MSE                = TRUE,
  mse_type           = "boot"
)
summary(fh_arcsin)

# 10.2 Spatial Fay–Herriot Model with SAR(1) Correlation
fh_spatial <- fh(
  fixed         = Mean ~ cash + self_empl,
  vardir        = "Var_Mean",
  combined_data = combined_data,
  domains       = "Domain",
  correlation   = "spatial",
  corMatrix     = eusilcA_prox,
  MSE           = TRUE
)

# 10.3 Robust Fay–Herriot Model (REBLUP)
fh_robust <- fh(
  fixed         = Mean ~ cash + self_empl,
  vardir        = "Var_Mean",
  combined_data = combined_data,
  domains       = "Domain",
  method        = "reblup",
  MSE           = TRUE,
  mse_type      = "pseudo"
)

# 10.4 Measurement Error Model for Covariates
P        <- 1                                  # Number of covariates with error
M        <- nrow(eusilcA_smpAgg)               # Number of domains
Ci_array <- array(0, dim = c(P + 1, P + 1, M))  # Covariance array
Ci_array[2, 2, ] <- eusilcA_smpAgg$Var_Cash    # Variance of 'cash' by domain

fh_yl <- fh(
  fixed         = Mean ~ cash,
  vardir        = "Var_Mean",
  combined_data = eusilcA_smpAgg,
  domains       = "Domain",
  method        = "me",
  Ci            = Ci_array,
  MSE           = TRUE,
  mse_type      = "jackknife"
)
summary(fh_yl)

# ---------------------------------------------------------
# Source:
# Based on the emdi package vignette “A Framework for Producing Small Area Estimates Based on Area-Level Models in R” 
# (Harmening et al., 2022) and Kreutzmann et al. (2019), “The R package emdi for estimating and mapping regionally disaggregated indicators.”
# ---------------------------------------------------------
