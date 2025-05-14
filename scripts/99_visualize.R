source("scripts/utils.R")

area_order <- c(
  "Grunnkrets",
  "Postnummerområde",
  "Delområde",
  "Bydel",
  "Kommune/Bydel",
  "Kommune",
  "Økonomisk region",
  "Fylke"
)

maps <- dir(
  "maps/current",
  full.names = TRUE,
  recursive = TRUE,
  pattern = "_s.geojson"
) |>
  tibble(file_name = _) |>
  mutate(
    boundary = str_extract(file_name, "landmask|extended"),
    area = str_extract(basename(file_name), ".+(?=_s\\.geojson)"),
    title = case_match(
      area,
      "bydel" ~ "Bydel",
      "delomraade" ~ "Delområde",
      "grunnkrets" ~ "Grunnkrets",
      "kommune_bydel" ~ "Kommune/Bydel",
      "kommune" ~ "Kommune",
      "fylke" ~ "Fylke",
      "economic_region" ~ "Økonomisk region",
      "zip" ~ "Postnummerområde"
    ) |>
      fct_relevel(area_order),
    label = paste0(area, "_name")
  )

plot_map <- function(file_name, boundary, title, label) {
  sf_use_s2(FALSE)
  xmin <- 10.5
  xmax <- 11
  ymin <- 59.8
  ymax <- 60

  map_raw <- st_read(file_name, quiet = TRUE)

  map_raw |>
    st_crop(st_bbox(
      c(xmin = xmin, xmax = xmax, ymax = ymax, ymin = ymin),
      crs = st_crs(4326)
    )) |>
    ggplot() +
    aes(fill = .data[[label]]) +
    geom_sf(color = "white", size = 0.2) +
    xlim(xmin, xmax) +
    ylim(ymin, ymax) +
    theme_void() +
    annotate(
      "label",
      x = xmin,
      y = ymax,
      label = str_glue("{title}\n{str_to_title(boundary)}"),
      size = 3,
      hjust = 0,
      vjust = 1,
      colour = "white",
      fill = "black",
      label.size = 0,
      label.r = unit(0, "lines"),
    ) +
    scale_fill_viridis_d() +
    theme(legend.position = "none")
}

maps |>
  filter(!str_detect(str_to_lower(area), "bydel")) |>
  arrange(desc(boundary), title) |>
  mutate(plot = pmap(list(file_name, boundary, title, label), plot_map)) |>
  pull(plot) |>
  wrap_plots(ncol = 6)

ggsave("docs/img/maps.png", width = 30, height = 7.3, unit = "cm")
