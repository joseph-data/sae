# ---------------------------------------------------------
# Sweden Preprocess (Revised)
# ---------------------------------------------------------

# ---------------------------------------------------------
# 1. Source Library Loader
# ---------------------------------------------------------
source(here::here("R", "1_load_libraries.R"))

# ---------------------------------------------------------
# 2. Define Paths & Helper Functions
# ---------------------------------------------------------
paths <- list(
  shapefile   = data_path("SWE_adm", "SWE_adm1.shp"),
  direct_est  = data_path("direct_estimates.csv"),
  geodata     = data_path("geodata.csv"),
  popdensity  = data_path("popdensity.csv"),
  vacancies   = data_path("vacancies.csv")
)

# County name recoding (fix special characters)
name_map <- c("Orebro" = "Örebro")
recode_county <- function(x) {
  factor(dplyr::recode(as.character(x), !!!name_map))
}

# CSV reader with status messages
read_data <- function(path) {
  message("Reading: ", path)
  readr::read_csv(path, show_col_types = FALSE)
}

# ---------------------------------------------------------
# 3. Load & Clean County Shapefile
# ---------------------------------------------------------
sweden_shape <-
  sf::st_read(paths$shapefile, quiet = TRUE) %>%
  sf::st_make_valid() %>%
  sf::st_transform(4326) %>%
  dplyr::select(NAME_1) %>%
  dplyr::mutate(NAME_1 = recode_county(NAME_1)) %>%
  dplyr::arrange(NAME_1)
message("Shapefile loaded: ", nrow(sweden_shape), " polygons")

# ---------------------------------------------------------
# 4. Read Direct Estimates & Compute Variance
# ---------------------------------------------------------
direct_est <-
  read_data(paths$direct_est) %>%
  dplyr::mutate(
    County          = recode_county(County),
    Percent         = na_if(Percent_2025K1, "..") %>% as.numeric() / 100,
    SE95            = na_if(Percent_2025K1_me, "..") %>% as.numeric() / 100,
    standard_error  = SE95 / 1.96,
    var_est         = standard_error^2,
    eff_sample_size = (Percent / standard_error)^2
  ) %>%
  dplyr::select(County, Percent, standard_error, var_est, eff_sample_size)
message("Direct estimates processed: ", nrow(direct_est), " records")

# ---------------------------------------------------------
# 5. Read & Clean Covariates
# ---------------------------------------------------------
# a) Geospatial covariates: select annual indicators (excluding precipitation)
geo_data <-
  read_data(paths$geodata) %>%
  dplyr::select(
    County         = NAME_1,
    VIIRS_avg      = VIIRS_avg_2024,
    Urban_pct      = Urban_pct_2024,
    NDVI_avg       = NDVI_avg_2024,
    LST_C          = LST_C_2024,
    NO2_mol_m2     = NO2_mol_m2_2024,
    SoilMoisture   = SoilM_m3m3_2024,
    Elevation_m    = Elevation_m_2024,
    Slope_deg      = Slope_deg_2024
  ) %>%
  dplyr::mutate(
    County = recode_county(County),
    across(-County, as.numeric)
  )
message("Geospatial data loaded: ", nrow(geo_data), " rows with selected indicators")

# b) Population density
pop_density <-
  read_data(paths$popdensity) %>%
  dplyr::rename(
    County         = County,
    PopDensity     = PopDensity_2024
  ) %>%
  dplyr::mutate(
    County = recode_county(County),
    PopDensity = as.numeric(PopDensity)
  )
message("Population density loaded: ", nrow(pop_density), " rows")

# c) Job vacancies (latest period)
vacancies <-
  read_data(paths$vacancies) %>%
  dplyr::filter(Period == max(Period, na.rm = TRUE)) %>%
  dplyr::mutate(
    County      = stringr::str_remove(Län, " län$"),           # drop ' län'
    County      = stringr::str_remove(County, "s$")           # remove trailing 's'
    %>% stringr::str_to_title()                                 # title case
    %>% recode_county(),
    Vacancy_New = as.numeric(`Nya lediga jobb`)
  ) %>%
  dplyr::select(County, Vacancy_New)
message("Vacancies loaded: ", nrow(vacancies), " rows")

# ---------------------------------------------------------
# 6. Merge All Data
# ---------------------------------------------------------
northern_list <- c("Norrbotten", "Västerbotten", "Jämtland", "Västernorrland", "Gävleborg")
combined_data <-
  direct_est %>%
  dplyr::left_join(geo_data,    by = "County") %>%
  dplyr::left_join(pop_density, by = "County") %>%
  dplyr::left_join(vacancies,   by = "County") %>%
  dplyr::mutate(
    Northern = factor(
      ifelse(as.character(County) %in% northern_list, "North", "South"),
      levels = c("South", "North")
    )
  )
message("Data merged: ", nrow(combined_data), " rows with all covariates")

# ---------------------------------------------------------
# 7. Prepare Spatial Join for Mapping
# ---------------------------------------------------------
sweden_map_data <-
  sweden_shape %>%
  dplyr::left_join(combined_data, by = c("NAME_1" = "County"))
missing_count <- sum(is.na(sweden_map_data$Percent))
if (missing_count > 0) {
  warning(missing_count, " features missing data after join")
}
message("Spatial join complete: ", nrow(sweden_map_data), " features")

# ---------------------------------------------------------
# 8. Save Processed Data
# ---------------------------------------------------------
dir.create(here::here("data"), showWarnings = FALSE)
save(
  sweden_shape,
  combined_data,
  sweden_map_data,
  file = data_path("processed_sweden.RData")
)
message("Processed data saved to ", data_path("processed_sweden.RData"))
