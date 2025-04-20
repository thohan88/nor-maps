source("scripts/utils.R")

# Creating a landmask for Norway based on full version of N50
# results in OOM-errors. Instead, we loop through each municipality
# and union them in the end.

folder_name <- "temp"
dir.create(folder_name)

# Get a list of municipality codes
codes <- geonorge_n50_mun_codes() |>
  mutate(file_name = str_glue("{folder_name}/{code}.RDS"))

# For each municipality, download and union all area layers except seabed
foo <- codes |>
  anti_join(tibble(file_name = dir(folder_name, full.names = TRUE))) |>
  mutate(foo = map2(code, file_name, geonorge_n50_mun_download, .progress = TRUE))

# Union and merge all municpalities to get a detailed norwegian polygon
nor <- dir("temp", full.names = TRUE) |>
  map(readRDS) |>
  bind_rows() |>
  st_union(is_coverage = TRUE) |>
  st_transform(4326)

tmpfile <- tempfile(fileext = ".shp")
st_write(nor, tmpfile)
system(str_glue("mapshaper-xl {tmpfile} -o raw/norway_landmask.geojson.gz"))
unlink(temp)
unlink(tmpfile)