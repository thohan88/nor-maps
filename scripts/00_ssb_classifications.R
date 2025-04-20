source("scripts/utils.R")
con <- con_db()

##################################
# Get SSB classes ----
##################################

classes <- tribble(
  ~class_id, ~class_type,
  1, "Grunnkrets",
  103, "Bydel",
  131, "Kommune"
)

# Classes
foo <- classes |>
  mutate(class = map_chr(class_id, ssb_get_classifications)) |>
  anti_join(tbl(con, Id(schema = "raw", table = "class")) |> collect(), by = "class_id") |>
  dbWriteTable(con, Id(schema = "raw", table = "class"), value = _, append = TRUE)

# Versions
versions <- tbl(con, "class") |>
  anti_join(tbl(con, Id(schema = "raw", table = "class_version")), by = join_by(class_id, version_id)) |>
  select(class_id, version_id, version_link) |>
  collect() |>
  mutate(foo = pmap(list(class_id, version_id, version_link), ssb_store_class_version, .progress = TRUE))

# Correspondance tables
correspondance <- tbl(con, "class_correspondance") |>
  anti_join(tbl(con, Id(schema = "raw", table = "class_correspondance")), by = join_by(correspondance_id)) |>
  distinct(class_id, version_id, correspondance_id, link) |>
  collect() |>
  mutate(foo = pmap(list(class_id, version_id, correspondance_id, link), ssb_store_class_correspondance, .progress = TRUE))

# Export
tbl(con, "all_class") |> 
  collect() |> 
  write_csv2("raw/classifications.csv.gz")

