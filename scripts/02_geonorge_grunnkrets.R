source("scripts/utils.R")

##################################
# Get classification ----
##################################

class_raw <- read_csv2("raw/classifications.csv.gz") |>
  mutate(year = year(version_date), .before = 1) |>
  select(-version_date)

# Maps from geonorge contain certain grunnkrets which are not
# part of the SSB-classification for old versions, extend it.
class_ext <- tribble(
  ~year, ~grunnkrets_no, ~grunnkrets_name,
  2012,  "19021201",     "Skjelnan",
  2012,  "19022037",     "Selnes",
  2012,  "19020417",     "Heimland-Fredlund",
  2012,  "19022062",     "Åsland",
  2012,  "19022070",     "Håkøybotn",
  2012,  "19021502",     "Nordberg",
  2012,  "19021501",     "Reinelva-Sollielva",
  2006,  "05170109",     "Selsverket",
  2006,  "09290116",     "Eppeland",
  2006,  "09290115",     "Åmli 3",
  2005,  "02310621",     "Skedsmokorset 21",
  2003,  "18540112",     "Sentrum",
  2003,  "18540109",     "Bøstrand",
  2003,  "18540115",     "Arnes",
  2002,  "18540112",     "Sentrum",
  2002,  "18540109",     "Bøstrand",
  2002,  "18540115",     "Arnes",
)

class <- bind_rows(class_raw, class_ext) |>
  arrange(desc(year), grunnkrets_no) |>
  group_by(year) |>
  # Fill missing values with adjacent grunnkrets
  fill(delomraade_no:delomraade_name, kommune_bydel_no:economic_region_name) |>
  ungroup() |>
  nest(class = -year)

##################################
# Grunnkrets ----
##################################

year_min <- 2002

gkrets_current <- tibble(
  map_id = "51d279f8-e2be-4f5e-9f72-1a53f7535ec1",
  year = 2025
)
gkrets_2024 <- tibble(
  map_id = "1f6e38a3-ca49-41d2-99bc-012deefe92d9",
  year = 2024
)

gkrets_historic <- request("https://kartkatalog.geonorge.no/api/getdata/") |>
  req_url_path_append("02b6c97b-63da-4d46-9a70-6e9ef3442d54") |>
  req_perform() |>
  resp_body_json() |>
  pluck("SerieDatasets") |>
  map_df(as_tibble) |>
  transmute(map_id = Uuid, year = as.integer(str_extract(Title, "[0-9]{4}$"))) |>
  arrange(desc(year)) |>
  filter(year >= year_min)

gkrets <- bind_rows(gkrets_current, gkrets_2024, gkrets_historic) |>
  distinct(year, .keep_all = TRUE) |>
  arrange(desc(year))

##################################
# Export ----
##################################

map_size <- tribble(
  ~ratio, ~quality,
  0.1, "xl",
  0.05, "l",
  0.01, "m",
  0.005, "s",
  0.001, "xs"
)

levels <- tibble(level = c(
  "grunnkrets_no", "grunnkrets_name",
  "delomraade_no", "delomraade_name",
  "bydel_no", "bydel_name",
  "kommune_bydel_no", "kommune_bydel_name",
  "kommune_no", "kommune_name",
  "fylke_no", "fylke_name",
  "economic_region_no", "economic_region_name"
)) |>
  mutate(
    level_name = str_replace_all(level, "_no$|_name$", ""),
    level_id = ceiling(row_number() / 2),
    levels = case_match(
      level_name,
      "grunnkrets"      ~ list(c("grunnkrets", "delomraade", "kommune", "kommune_bydel", "bydel", "fylke", "economic_region")),
      "delomraade"      ~ list(c("delomraade", "kommune", "kommune_bydel", "bydel", "fylke", "economic_region")),
      "kommune_bydel"   ~ list(c("kommune_bydel", "kommune", "bydel", "fylke", "economic_region")),
      "kommune"         ~ list(c("kommune", "fylke", "economic_region")),
      "bydel"           ~ list(c("bydel", "kommune", "fylke", "economic_region")),
      "economic_region" ~ list(c("economic_region", "fylke")),
      "fylke"           ~ list(c("fylke"))
    )
  ) |> 
  unnest(levels)

levels_accumulated <- levels  |> 
  left_join(levels, by = join_by(levels == level_name)) |> 
  group_by(
    level_id = level_id.x,
    level_name = level_name
  ) |> 
  summarise(levels = paste(unique(level.y), collapse = ",")) |>
  ungroup() |>
  select(level_id, level_name, levels)

boundary <- c("landmask", "extended")

fn_current <- "maps/{version}/{boundary}/{level_name}_{quality}.geojson"
fn_versioned <- "maps/{version}/{year}/{boundary}/{level_name}.geojson"

file_landmask <- "raw/norway_landmask.geojson.gz"

foo <- gkrets |>
  crossing(map_size) |>
  crossing(levels_accumulated) |>
  crossing(boundary) |>
  arrange(desc(year)) |>
  mutate(version = if_else(year == max(year), list(c("current", "versioned")), list("versioned"))) |>
  unnest(version) |>
  mutate(current = (year == max(year) & version == "current")) |>
  filter((current) | (!current & quality == "xs")) |>
  mutate(file_name = ifelse(current, str_glue(fn_current), str_glue(fn_versioned))) |>
  mutate(foo = map(dirname(file_name), dir.create, recursive=TRUE, showWarnings=FALSE)) |>
  select(-foo) |>
  anti_join(tibble(file_name = dir("maps", full.names = TRUE, recursive = TRUE)), by = "file_name") |> 
  nest(data = -c(map_id, year)) |>
  left_join(class, by = "year") |> 
  mutate(foo = pmap(list(map_id, data, class), geonorge_grunnkrets_process_year, file_landmask, .progress = TRUE))

#knitr::render_markdown("README.rmd")
