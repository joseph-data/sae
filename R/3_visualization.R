# ---------------------------------------------------------
# 3_visualization.R (Revised)
# ---------------------------------------------------------

# 1. Source Libraries & Data
# ---------------------------------------------------------
library(here)
source(here("R", "1_load_libraries.R"))     # Loads sf, tidyverse, tmap, etc.
source(here("R", "2_sweden_preprocess.R"))  # Loads sweden_map_data

# 2. Prepare Map Data
# ---------------------------------------------------------
# Format percent labels
sweden_map_data <- sweden_map_data %>%
  dplyr::mutate(
    Percent_label = scales::label_percent(accuracy = 0.1)(Percent)
  )

# 3. Ensure Output Directories
# ---------------------------------------------------------
out_html <- here("outputs", "html")
out_img  <- here("outputs", "img")
dir.create(out_html, recursive = TRUE, showWarnings = FALSE)
dir.create(out_img,  recursive = TRUE, showWarnings = FALSE)

# 4. Interactive Map with tmap + Leaflet
# ---------------------------------------------------------
tmap::tmap_mode("view")
tm_direct <-
  tm_shape(sweden_map_data) +
  tm_polygons(
    col        = "Percent",
    palette    = "Blues",
    border.col = "grey20",
    alpha      = 0.7,
    title      = "Unemployment Rate"
  ) +
  tm_text(
    text           = "Percent_label",
    size           = "AREA",
    remove.overlap = TRUE,
    bg.color       = "white",
    bg.alpha       = 0.5
  ) +
  tm_layout(
    main.title      = "Direct Unemployment Estimates by County",
    main.title.size = 1.2,
    legend.outside  = TRUE,
    frame           = FALSE
  )
print(tm_direct)

leaflet_map <- tmap_leaflet(tm_direct)
htmlwidgets::saveWidget(
  widget        = leaflet_map,
  file          = here(out_html, "sweden_direct_map.html"),
  selfcontained = TRUE
)

# 5. Static Thematic Map (tmap → PNG)
# ---------------------------------------------------------
tmap::tmap_mode("plot")
tmap::tmap_save(
  tm_direct,
  filename = here(out_img, "sweden_direct_map_tmap.png"),
  dpi      = 300,
  width    = 8, height = 6, units = "in"
)

# 6. Static Map with ggplot2
# ---------------------------------------------------------
sweden_proj <- sf::st_transform(sweden_map_data, crs = 3006)
static_map <- ggplot2::ggplot() +
  ggplot2::geom_sf(
    data  = sweden_proj,
    aes(fill = Percent),
    color = "grey20",
    alpha = 0.8
  ) +
  ggplot2::geom_sf_label(
    data          = sweden_proj,
    aes(label = Percent_label),
    size          = 3,
    label.padding = grid::unit(0.15, "lines"),
    fill          = "white"
  ) +
  scale_fill_viridis_c(name = "Unemployment (%)") +
  theme_minimal() +
  labs(
    title    = "Direct Unemployment Estimates by County",
    subtitle = "Sweden, 2025"
  ) +
  theme(
    panel.grid      = element_blank(),
    legend.position = "right"
  )
print(static_map)

ggplot2::ggsave(
  filename = here(out_img, "sweden_direct_map_ggplot.png"),
  plot     = static_map,
  dpi      = 300,
  width    = 8, height = 6, units = "in"
)

# 7. Save Visualization Objects
# ---------------------------------------------------------
dir.create(here("data"), recursive = TRUE, showWarnings = FALSE)
save(
  tm_direct,
  static_map,
  file = data_path("visual.RData")
)
message("Visualization outputs saved under 'outputs/' and objects to ", data_path("visual.RData"))


# # ---------------------------------------------------------
# # 3_visualization.R (Updated)
# # ---------------------------------------------------------

# # ---------------------------------------------------------
# # 1. Source Libraries and Data
# # ---------------------------------------------------------
# library(here)
# source(here("R", "1_load_libraries.R"))    # Loads tidyverse, tmap, sf, etc.
# source(here("R", "2_sweden_preprocess.R")) # Loads sweden_map_data

# # ---------------------------------------------------------
# # 2. Prepare Map Data
# # ---------------------------------------------------------
# # Create formatted labels using updated 'Percent'
# sweden_map_data <- sweden_map_data %>%
#   dplyr::mutate(
#     Percent_label = scales::label_percent(accuracy = 0.1)(Percent)
#   )

# # Ensure outputs directory exists for exported files
# output_dir <- here("outputs")
# if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

# # ---------------------------------------------------------
# # 3. Interactive Map (tmap + Leaflet)
# # ---------------------------------------------------------
# tmap::tmap_mode("view")

# # Build and display interactive map with 'Percent'
# tm_direct <-
#   tm_shape(sweden_map_data) +
#   tm_polygons(
#     col        = "Percent",
#     palette    = "Blues",
#     border.col = "grey20",
#     alpha      = 0.7,
#     title      = "Unemployment Rate"
#   ) +
#   tm_text(
#     text           = "Percent_label",
#     size           = "AREA",
#     remove.overlap = TRUE,
#     bg.color       = "white",
#     bg.alpha       = 0.5
#   ) +
#   tm_layout(
#     main.title      = "Direct Unemployment Estimates by County",
#     main.title.size = 1.2,
#     legend.outside  = TRUE,
#     frame           = FALSE
#   )
# print(tm_direct)

# # Save interactive map as standalone HTML
# leaflet_map <- tmap_leaflet(tm_direct)
# htmlwidgets::saveWidget(
#   leaflet_map,
#   file          = file.path(output_dir, "sweden_direct_map.html"),
#   selfcontained = TRUE
# )

# # ---------------------------------------------------------
# # 4. Export Static Tmap Map as PNG
# # ---------------------------------------------------------
# tmap::tmap_mode("plot")
# tmap::tmap_save(
#   tm_direct,
#   filename = file.path(output_dir, "sweden_direct_map.png"),
#   dpi      = 300,
#   width    = 8,
#   height   = 6,
#   units    = "in"
# )

# # ---------------------------------------------------------
# # 5. Static Map (ggplot2)
# # ---------------------------------------------------------
# # Reproject for accurate spatial labeling
# sweden_proj <- sf::st_transform(sweden_map_data, crs = 3006)

# static_map <- ggplot2::ggplot() +
#   ggplot2::geom_sf(
#     data  = sweden_proj,
#     aes(fill = Percent),
#     color = "grey20",
#     alpha = 0.8
#   ) +
#   ggplot2::geom_sf_label(
#     data          = sweden_proj,
#     aes(label = Percent_label),
#     size          = 3,
#     label.padding = grid::unit(0.15, "lines"),
#     fill          = "white"
#   ) +
#   scale_fill_viridis_c(name = "Unemployment (%)") +
#   theme_minimal() +
#   labs(
#     title    = "Direct Unemployment Estimates by County",
#     subtitle = "Sweden, 2025"
#   ) +
#   theme(
#     panel.grid      = element_blank(),
#     legend.position = "right"
#   )
# print(static_map)

# # Export static ggplot map as high-resolution PNG
# ggsave(
#   filename = file.path(output_dir, "sweden_direct_map_static.png"),
#   plot     = static_map,
#   dpi      = 300,
#   width    = 8,
#   height   = 6,
#   units    = "in"
# )

# # ---------------------------------------------------------
# # 6. Save Visualization Objects
# # ---------------------------------------------------------
# save(
#   tm_direct,
#   static_map,
#   file = here("data", "visual.RData")
# )
# message("Visualization scripts updated to use 'Percent' variable")
