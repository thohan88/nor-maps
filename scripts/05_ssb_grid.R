source("scripts/utils.R")

##################################
# SSB Grids ----
##################################

grid_0250m_raw <- geonorge_read_fgdb("122cf146-90a9-4557-96ea-e639fb28d896")
grid_1000m_raw <- geonorge_read_fgdb("d8346ab9-05ba-4f48-b33a-b7270b433c2d")
grid_5000m_raw <- geonorge_read_fgdb("32ac0653-d95c-446c-8558-bf9b79f4934e")

grid_0250m <- transmute(grid_0250m_raw, ssb_id = as.numeric(ssbid250m))

ras <- rast(
    extent = ext(grid_5000m_raw), # Use biggest grid as extent
    resolution = 250,
    crs = crs(grid)
)

##################################
# SSB Datasets ----
##################################

datasets_raw <- bind_rows(
    ssb_search_datasets("befolkning"),
    ssb_search_datasets("bygningsmasse"),
    ssb_search_datasets("bedrifter")
)

col_mapping <- list(
    building = list(
        list(buildings_all = "bui0all"),
        list(buildings_dwellings = "bui1dwe")
    ),
    population = list(
        list(population = "pop_tot")
    ),
    establishments = list(
        list(establishments = "est_tot"),
        list(employees = "emp_tot")
    )
)

file_name_versioned <- "maps/versioned/{year}/statgrid/{col}_{res}.tif"

datasets <- datasets_raw |>
    transmute(
        dataset_id = data_dataset,
        year = as.integer(str_extract(alias, "[0-9]{4}$")),
        cat = case_when(
            str_detect(alias, "bygning") ~ "building",
            str_detect(alias, "befolkn") ~ "population",
            str_detect(alias, "bedrift") ~ "establishments"
        ),
        res = case_when(
            str_detect(alias, "250m") ~ "0250m",
            str_detect(alias, "1km") ~ "1000m",
            str_detect(alias, "5km") ~ "5000m"
        ),
        cols = case_match(
            cat,
            "building" ~ list(col_mapping$building),
            "population" ~ list(col_mapping$population),
            "establishments" ~ list(col_mapping$establishments)
        ),
    ) |>
    filter(!is.na(cat)) |>
    arrange(cat, res, desc(year)) |>
    unnest(cols) |>
    mutate(
        col = map_chr(cols, names),
        file_name = str_glue(file_name_versioned),
        dir_name = map_chr(file_name, dirname)
    ) |>
    filter(year >= 2002)

##################################
# Create versioned 250m rasters ----
##################################
foo <- map(unique(datasets$dir_name), dir.create, showWarnings = FALSE)


datasets |>
    arrange(desc(year), desc(cat)) |>
    filter(res == "0250m") |>
    #filter(!file_name %in% dir("maps/versioned", full.names = TRUE, recursive = TRUE)) |>
    mutate(
        foo = pmap(
            list(dataset_id, file_name, cols),
            ssb_download_and_process_dataset,
            grid_0250m,
            ras,
            .progress = TRUE
        )
    )

##################################
# Aggregate versioned 1000m/5000m rasters ----
##################################

dir("maps/versioned", full.names = TRUE, recursive = TRUE) |>
    tibble(from = _) |>
    filter(str_detect(from, "statgrid")) |>
    mutate(
        to_1000m = str_replace_all(from, "0250m", "1000m"),
        to_5000m = str_replace_all(from, "0250m", "5000m")
    ) |>
    arrange(desc(from)) |>
    mutate(
        foo = map2(
            from,
            to_1000m,
            ssb_aggregate_grid,
            factor = 4,
            .progress = TRUE
        )
    )
mutate(
    foo = map2(
        to_1000m,
        to_5000m,
        ssb_aggregate_grid,
        factor = 5,
        .progress = TRUE
    )
)

###################################
# Create latest ----
###################################

foo <- dir("maps/versioned", full.names = TRUE, recursive = TRUE) |>
    tibble(file_name = _) |>
    filter(str_detect(file_name, "statgrid")) |>
    mutate(
        basename = basename(file_name),
        year = str_extract(file_name, "20[0-9]{2}")
    ) |>
    arrange(desc(year)) |>
    distinct(basename, .keep_all = TRUE) |>
    mutate(
        to = str_replace_all(file_name, "versioned/[0-9]{4}", "current"),
        foo = map2(file_name, to, file.copy, overwrite = TRUE)
    )

##################################
# Verify grids ----
##################################

# library(leaflet)
# library(leaflet.extras2)
# library(terra)
# library(sf)
# library(stars)

# grid_0250m_raw <- geonorge_read_fgdb("122cf146-90a9-4557-96ea-e639fb28d896")
# pop_2025 <- ssb_download_dataset("067eea08-5ed1-7644-8000-7e73d4313b2d")

# ras <- read_stars("maps/current/statgrid/population_0250m.tif")

# bbox <- tibble(lat = 59.911491, lng = 10.757933) |>
#   st_as_sf(coords = c("lng", "lat"), crs = 4326) |>
#   st_transform(25833) |>
#   st_buffer(20E3) |>
#   st_transform(st_crs(ras)) |>
#   st_bbox()

# ras_3857 <- ras |>
#   st_crop(bbox) |>
#   rast() |>
#   project("EPSG:3857")

# grid_3857 <- grid_0250m_raw |>
#   mutate(ssbid250m = as.numeric(ssbid250m)) |>
#   inner_join(pop_2025, by = "ssbid250m") |>
#   select(pop_tot) |>
#   st_rasterize(dx = 250, dy = 250) |>
#   st_crop(bbox) |>
#   rast() |>
#   project("EPSG:3857")

# pal <- colorNumeric("Spectral", domain = c(0, 2500), na.color = "transparent")

# leaflet() |>
#   setView(lng = 10.76, lat = 59.91, zoom = 13) |>
#   addMapPane("right", zIndex = 0) |>
#   addMapPane("left", zIndex = 0) |>
#   addTiles(
#     group = "base",
#     layerId = "baseid1",
#     options = pathOptions(pane = "right")
#   ) |>
#   addTiles(
#     group = "base",
#     layerId = "baseid2",
#     options = pathOptions(pane = "left")
#   ) |>
#   addRasterImage(
#     ras_3857,
#     colors = pal,
#     options = leafletOptions(pane = "right"),
#     group = "raster"
#   ) |>
#   addRasterImage(
#     grid_3857,
#     colors = pal,
#     options = leafletOptions(pane = "left"),
#     group = "grid"
#   ) |>
#   addLayersControl(overlayGroups = c("grid", "raster")) |>
#   addSidebyside(
#     layerId = "sidecontrols",
#     rightId = "baseid1",
#     leftId = "baseid2"
#   )

# leaflet() |>
#   addTiles() |>
#   addRasterImage(ras_3857)
