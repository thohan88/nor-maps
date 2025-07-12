library(tidyverse)
library(httr2)
library(sf)
library(duckdb)
library(rvest)
library(pxweb)

############################# #
# Geonorge ----
############################# #

geonorge_req <- function() {
  request("https://nedlasting.geonorge.no/api") |>
    req_throttle(1)
}

geonorge_get_download_url <- function(
  dataset_id,
  area_code = "0000",
  area_type = "landsdekkende",
  projection_code = "25833",
  format_name = "FGDB"
) {
  body <- sprintf(
    '
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
  }',
    dataset_id,
    area_code,
    area_type,
    projection_code,
    format_name
  )

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

geonorge_read_fgdb <- function(dataset_id) {
  tmpfile <- tempfile(fileext = ".zip")

  download_url <- geonorge_get_download_url(
    dataset_id
  )

  foo <- geonorge_req() |>
    req_url(download_url) |>
    req_perform(path = tmpfile)

  fgdb_name <- unzip(tmpfile, list = TRUE)[["Name"]][1]
  fgdb_path <- file.path("/vsizip", tmpfile, fgdb_name)

  data <- st_read(fgdb_path)
  unlink(tmpfile)
  data
}

geonorge_n50_mun_download <- function(area_code, file_name) {
  dataset_id <- geonorge_n50_dataset_id()
  projection_code <- "25833"
  format_name <- "FGDB"
  area_type <- "kommune"

  mun_url <- geonorge_get_download_url(
    dataset_id,
    area_code,
    area_type,
    projection_code,
    format_name
  )
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
  shp_name <- dir(
    tmpdir,
    pattern = "Grunnkrets_FLATE.shp|Grunnkrets.+FLATE.+shp$",
    full.names = TRUE
  )[1]
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
    nrow() >
    0

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

geonorge_grunnkrets_process_year <- function(
  map_id,
  data,
  class,
  file_landmask
) {
  tmpdir <- tempdir()
  dir.create(tmpdir)
  tmpfile_extended <- tempfile(fileext = ".geojson")
  tmpfile_landmask <- tempfile(fileext = ".geojson")

  map <- geonorge_grunnkrets_download(map_id) |>
    geonorge_grunnkrets_clean(class)

  dir.create(tmpdir)
  foo <- st_write(map, tmpfile_extended)
  foo <- system(str_glue(
    "mapshaper-xl {tmpfile_extended} -clip {file_landmask} -o {tmpfile_landmask}"
  ))

  prompt_simplify <- "mapshaper-xl {file} -simplify {ratio} keep-shapes -clean -o {tmpfile} precision=0.00001"
  prompt_dissolve <- "mapshaper-xl {tmpfile} -dissolve {levels} calc='population = sum(population)' -filter '{level_name}_no != null' -o {file_name}"

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

  dbWriteTable(
    con,
    Id(schema = "raw", table = "class_version"),
    data,
    append = TRUE
  )
}

ssb_store_class_correspondance <- function(
  class_id,
  version_id,
  correspondance_id,
  link
) {
  data <- tibble(class_id, version_id, correspondance_id, link) |>
    mutate(correspondance = map_chr(link, ssb_get_data, .progress = TRUE)) |>
    select(-link)

  dbWriteTable(
    con,
    Id(schema = "raw", table = "class_correspondance"),
    data,
    append = TRUE
  )
}

ssb_download_tbl <- function(tbl_id) {
  path_url <- paste0("http://data.ssb.no/api/v0/no/table/", tbl_id)

  info_query_raw <- request(path_url) |>
    req_perform()

  codes <- info_query_raw |>
    resp_body_json(simplifyVector = TRUE) |>
    pluck("variables", "code")

  dims <- rep("*", length(codes)) %>%
    set_names(codes) %>%
    as.list()

  tbl_code <- pxweb_get_data(
    url = path_url,
    query = dims,
    verbose = TRUE,
    column.name.type = "code",
    variable.value.type = "code"
  )

  tbl_name <- pxweb_get_data(
    url = path_url,
    query = dims,
    verbose = TRUE,
    column.name.type = "code",
    variable.value.type = "text"
  )

  test <- bind_cols(
    tbl_code %>% set_names(~ paste0(.x, "_code")),
    tbl_name %>% set_names(~ paste0(.x, "_name"))
  ) |>
    as_tibble()
}

##################################
# SSB Maps ----
##################################

ssb_search_datasets <- function(query) {
  ssb_req <- request("https://kart.ssb.no/api/search/v1/content") |>
    req_throttle(1)

  data_raw <- ssb_req |>
    req_body_json(
      list(
        query = query,
        categories = list(),
        types = c("map_layer", "dataset"),
        limit = 100L,
        lang = "en"
      )
    ) |>
    req_perform()

  data_raw |>
    resp_body_json() |>
    pluck("data") |>
    map(modify_tree, pre = list_flatten) |>
    map_df(keep, is.atomic)
}

ssb_download_dataset <- function(dataset_id) {
  resp <- request("https://kart.ssb.no/api/core/v1/export/file") |>
    req_throttle(1) |>
    req_body_json(
      list(
        dataset = dataset_id,
        format = "Csv",
        attributes = c(),
        srid = "32633",
        language = "en"
      )
    ) |>
    req_perform() |>
    resp_body_json()

  status <- "pending"
  while (status != "complete") {
    Sys.sleep(1)
    status <- request("https://kart.ssb.no/api/core/v1/export/status/") |>
      req_url_path_append(resp$id) |>
      req_perform() |>
      resp_body_json() |>
      pluck("status")
    print(paste(Sys.time(), "Status:", status))
  }

  tmpfile <- tempfile(fileext = ".csv")
  request(resp$url) |>
    req_perform(path = tmpfile)

  read_csv2(tmpfile)
}

ssb_download_and_process_dataset <- function(
  dataset_id,
  file_name,
  cols,
  grid,
  rast
) {
  data_raw <- ssb_download_dataset(dataset_id)
  col_id <- names(data_raw)[str_detect(
    names(data_raw),
    "ssb.+[0-9]{3,4}.*m|SSB.+[0-9]{3,4}.*M"
  )]

  data <- data_raw |>
    filter(!is.na(.data[[col_id]])) |>
    select(ssb_id = {{ col_id }}, !!!cols)

  grid_data <- grid |>
    inner_join(data, by = "ssb_id")

  centroids_sf <- st_centroid(grid_data)
  centroids_vect <- vect(centroids_sf)

  ras <- rasterize(centroids_vect, rast, field = names(cols))

  setGDALconfig("GDAL_PAM_ENABLED", "FALSE")
  writeRaster(
    ras,
    file_name,
    overwrite = TRUE,
    filetype = "COG",
    gdal = c("COMPRESS=LZW"),
    datatype = "INT2U"
  )
}

ssb_aggregate_grid <- function(from, to, factor) {
    ras <- rast(from)
    ras_agg <- aggregate(ras, fact = factor, fun = "sum", na.rm = TRUE)
    setGDALconfig("GDAL_PAM_ENABLED", "FALSE")
    writeRaster(
        ras_agg,
        to,
        overwrite = TRUE,
        filetype = "COG",
        gdal = c("COMPRESS=LZW"),
        datatype = "INT2U"
    )
}
