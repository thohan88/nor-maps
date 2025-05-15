source("scripts/utils.R")

population_raw <- ssb_download_tbl("04317")

class_raw <- read_csv2("raw/classifications.csv.gz")

class <- class_raw |> 
  transmute(
    grunnkrets_no,
    grunnkrets_name,
    delomraade_no,
    delomraade_name,
    year = year(version_date))

population <- population_raw |> 
  select(
    grunnkrets_no = Grunnkretser_code,
    grunnkrets_name = Grunnkretser_name,
    year = Tid_code, 
    population = Personer1_code
  ) |> 
  filter(year >= 2002, population > 0)

write_csv2(population, "raw/population_grunnkrets.csv.gz")

