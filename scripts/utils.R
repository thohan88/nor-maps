library(tidyverse)
library(httr2)
library(sf)
library(duckdb)
library(rvest)

############################# #
# Geonorge ----
############################# #

geonorge_req <- function() {
  request("https://nedlasting.geonorge.no/api")
}

geonorge_get_download_url <- function(dataset_id, area_code, area_type, projection_code, format_name) {
  body <- sprintf('
  {
    "email": "",
    "orderLines": [
      {
        "metadataUuid": "%s",
        "areas": [{"code": "%s", "type": "%s"}],
        "projections": [{"code": "%s"}],
        "formats": [{"name": "%s"}],
      }
    ]
  }', dataset_id, area_code, area_type, projection_code, format_name)

  order <- request("https://nedlasting.geonorge.no/api/order") |>
    req_body_raw(body, "application/json") |>
    req_perform()

  download_url <- order |>
    resp_body_json() |>
    pluck("files", 1, "downloadUrl")

  download_url
}

geonorge_n50_dataset_id <- function() {
  "ea192681-d039-42ec-b1bc-f3ce04c189ac"
}

geonorge_n50_mun_codes <- function() {
  dataset_id <- geonorge_n50_dataset_id()

  area_codelist <- geonorge_req() %>%
    req_url_path_append("capabilities", dataset_id) |>
    req_perform() |>
    resp_body_json() |>
    pluck("_links", 3, "href")

  area <- request(area_codelist) %>%
    req_perform() |>
    resp_body_json() |>
    map(keep, is.atomic) |>
    map_df(as_tibble) |>
    filter(type == "kommune")

  area
}

geonorge_n50_mun_download <- function(area_code, file_name) {
  dataset_id <- geonorge_n50_dataset_id()
  projection_code <- 25833
  format_name <- "FGDB"
  area_type <- "kommune"

  mun_url <- geonorge_get_download_url(dataset_id, area_code, area_type, projection_code, format_name)
  tmpfile <- tempfile(fileext = ".zip")
  foo <- download.file(mun_url, tmpfile, mode = "wb", quiet = TRUE)
  zip_file_name <- unzip(tmpfile, list = TRUE) |>
    filter(str_detect(Name, ".gdb/$")) |>
    pull(Name)

  n50_raw <- st_read(
    dsn = file.path("/vsizip", tmpfile, zip_file_name),
    layer = "N50_Arealdekke_omrade",
    quiet = TRUE
  )
  unlink(tmpfile)

  n50 <- n50_raw %>%
    filter(objtype != "Havflate") %>%
    st_buffer(0) |>
    mutate(code = area_code) |>
    group_by(code) |>
    summarise() |>
    st_cast("MULTIPOLYGON")

  saveRDS(n50, file_name)
}


geonorge_grunnkrets_download <- function(map_id) {
  tmpdir <- tempdir()
  dir.create(tmpdir, showWarnings = FALSE)
  tmpfile <- tempfile(tmpdir = tmpdir, fileext = ".zip")

  download_url <- geonorge_get_download_url(
    dataset_id = map_id,
    area_code = "0000",
    area_type = "landsdekkende",
    projection_code = "25833",
    format_name = "SOSI"
  )

  foo <- request(download_url) |>
    req_perform(path = tmpfile)

  sos_name <- unzip(tmpfile, list = TRUE)[["Name"]][1]
  sos_path <- file.path(tmpdir, sos_name)
  foo <- unzip(tmpfile, exdir = tmpdir)
  foo <- system(paste("./utils/sosicon -2shp", sos_path))
  shp_name <- dir(tmpdir, pattern = "Grunnkrets_FLATE.shp|Grunnkrets.+FLATE.+shp$", full.names = TRUE)[1]
  map_raw <- st_read(shp_name)
  unlink(tmpdir, recursive = TRUE)
  map_raw
}

geonorge_grunnkrets_clean <- function(map_raw, class) {

  # Some maps have a "GRUNNKRETS.1"-column, others don't
  # Bind it with an empty tibble to ensure it has both.
  map_empty <- tibble(
    GRUNNKRETS = character(),
    GRUNNKRETS.1 = character(),
    geometry = st_sfc(crs = st_crs(map_raw))
  )

  map <- map_raw |>
    bind_rows(map_empty) |>
    mutate(
      grunnkrets_1 = str_extract(GRUNNKRETS, "[0-9]{8}"),
      grunnkrets_2 = str_extract(GRUNNKRETS.1, "[0-9]{8}")
    ) |>
    transmute(grunnkrets_no = coalesce(grunnkrets_1, grunnkrets_2))

  map_has_dupes <- map |>
    add_count(grunnkrets_no) |>
    filter(n > 1) |>
    nrow() > 0

  map_non_dup <- map |>
    add_count(grunnkrets_no) |>
    filter(n == 1) |>
    select(-n)

  if (map_has_dupes) {
    map_dup <- map |>
      add_count(grunnkrets_no) |>
      filter(n > 1) |>
      select(-n) |>
      group_by(grunnkrets_no) |>
      summarise()
    map_output <- bind_rows(map_dup, map_non_dup) |>
      mutate(geometry = st_cast(geometry, "MULTIPOLYGON"))
  } else {
    map_output <- map_non_dup
  }

  map_output |>
    left_join(class, by = c("grunnkrets_no")) |>
    relocate(geometry, .after = last_col()) |> 
    st_transform(4326)
}

geonorge_grunnkrets_process_year <- function(map_id, data, class, file_landmask) {
  
  tmpdir <- tempdir()
  dir.create(tmpdir)
  tmpfile_extended <- tempfile(fileext = ".geojson")
  tmpfile_landmask <- tempfile(fileext = ".geojson")

  map <- geonorge_grunnkrets_download(map_id) |>
    geonorge_grunnkrets_clean(class)
  
  dir.create(tmpdir)
  foo <- st_write(map, tmpfile_extended)
  foo <- system(str_glue("mapshaper-xl {tmpfile_extended} -clip {file_landmask} -o {tmpfile_landmask}"))

  prompt_simplify <- "mapshaper-xl {file} -simplify {ratio} keep-shapes -clean -o {tmpfile} precision=0.00001"
  prompt_dissolve <- "mapshaper-xl {tmpfile} -dissolve {levels} -o {file_name}"

  data |>
    nest(data = -c(ratio, boundary, quality)) |>
    mutate(
      file = ifelse(boundary == "extended", tmpfile_extended, tmpfile_landmask),
      tmpfile = map_chr(quality, tempfile, fileext = ".geojson"),
      prompt = str_glue(prompt_simplify),
      foo = map(prompt, system, .progress = TRUE)
    ) |>
    unnest(data) |>
    mutate(
      prompt = str_glue(prompt_dissolve),
      foo = map(prompt, system, .progress = TRUE)
    )

  unlink(tmpdir)
}


############################# #
# SSB Classifications ----
############################# #

con_db <- function() {
  con <- dbConnect(duckdb(), "raw/nor_maps.db")
  foo <- dbExecute(con, read_file("schema.sql"))
  con
}

ssb_req <- function() {
  request("http://data.ssb.no/api/klass/v1/classifications/") |>
    req_throttle(2)
}

ssb_get_classifications <- function(class_id) {
  ssb_req() |>
    req_url_path_append(class_id) |>
    req_perform() |>
    resp_body_string()
}

ssb_get_data <- function(link) {
  ssb_req() |>
    req_url(link) |>
    req_perform() |>
    resp_body_string()
}

ssb_store_class_version <- function(class_id, version_id, version_link) {
  data <- tibble(class_id, version_id, version_link) |>
    mutate(version = map_chr(version_link, ssb_get_data, .progress = TRUE)) |>
    select(-version_link)

  dbWriteTable(con, Id(schema = "raw", table = "class_version"), data, append = TRUE)
}

ssb_store_class_correspondance <- function(class_id, version_id, correspondance_id, link) {
  data <- tibble(class_id, version_id, correspondance_id, link) |>
    mutate(correspondance = map_chr(link, ssb_get_data, .progress = TRUE)) |>
    select(-link)

  dbWriteTable(con, Id(schema = "raw", table = "class_correspondance"), data, append = TRUE)
}
