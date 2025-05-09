source("scripts/utils.R")

tmpfile_zip <- tempfile(fileext = ".zip")
tmpfile_extended <- tempfile(fileext = ".geojson")
tmpfile_landmask <- tempfile(fileext = ".geojson")
file_landmask <- "raw/norway_landmask.geojson.gz"

##################################
# SSB Classifications ----
##################################

class <- read_csv2("raw/classifications.csv.gz") |>
  mutate(year = year(version_date), .before = 1) |>
  filter(year == max(year)) |> 
  select(kommune_no:economic_region_name) |> 
  distinct()

##################################
# Geonorge ----
##################################

download_url <- geonorge_get_download_url(
  dataset_id = "462a5297-33ef-438a-82a5-07fff5799be3",
  area_code = "0000",
  area_type = "landsdekkende",
  projection_code = 25833,
  format_name = "FGDB"
)

foo <- request(download_url) |>
  req_perform(path = tmpfile_zip)

fgdb_name <- unzip(tmpfile_zip, list = TRUE)[["Name"]][1]
fgdb_path <- file.path("/vsizip", tmpfile_zip, fgdb_name)

map_raw <- st_read(fgdb_path)

map <- map_raw |>
  # Remove Svalbard and Jan Mayen
  filter(!kommune %in% c("2100", "2211")) |> 
  group_by(zip_no = postnummer) |>
  summarise(
    zip_name = first(poststed),
    kommune_no = first(kommune)
  ) |> 
  left_join(class) |> 
  relocate(SHAPE, .after = last_col()) |> 
  rename(geometry = SHAPE) |> 
  st_transform(4326)

st_write(map, tmpfile_extended)

foo <- system(str_glue("mapshaper-xl {tmpfile_extended} -clip {file_landmask} -o {tmpfile_landmask}"))

map_size <- tribble(
  ~ratio, ~quality,
  0.1, "xl",
  0.05, "l",
  0.01, "m",
  0.005, "s",
  0.001, "xs"
)
boundary <- c("landmask", "extended")

prompt_simplify <- "mapshaper-xl {file} -simplify {ratio} keep-shapes -clean -o {file_name} precision=0.00001"

map_size |> 
  crossing(boundary) |> 
  mutate(file_name =  str_glue("maps/current/{boundary}/zip_{quality}.geojson")) |> 
  anti_join(tibble(file_name = dir("maps", full.names = TRUE, recursive = TRUE)), by = "file_name") |> 
  mutate(
    file = ifelse(boundary == "extended", tmpfile_extended, tmpfile_landmask),
    tmpfile = map_chr(quality, tempfile, fileext = ".geojson"),
    prompt = str_glue(prompt_simplify)
  ) |>
  mutate(foo = map(prompt, system, .progress = TRUE))

