INSTALL JSON;
LOAD JSON;
INSTALL ICU;
LOAD ICU;

CREATE SCHEMA IF NOT EXISTS raw;

CREATE OR REPLACE TABLE raw.years AS 
    SELECT
    MAKE_DATE(year, 1, 1) AS date
    FROM generate_series(1900, 2100) AS t(year);

CREATE TABLE IF NOT EXISTS raw.class (
    class_id INT,
    class_type TEXT,
    class JSON,
    PRIMARY KEY (class_id)
);

CREATE TABLE IF NOT EXISTS raw.class_version (
  class_id INT,
  version_id INT,
  version JSON,
  PRIMARY KEY(class_id, version_id)
);

CREATE TABLE IF NOT EXISTS raw.class_correspondance (
  class_id INT,
  version_id INT,
  correspondance_id INT,
  correspondance JSON,
  PRIMARY KEY(class_id, version_id, correspondance_id)
);

CREATE OR REPLACE VIEW class AS (
  WITH
  versions AS (
    SELECT
    (class->>'id')::INT as class_id,
    (class->>'name') as class_name,
    UNNEST(FROM_JSON(class.versions, '["json"]'))::JSON as version
    FROM raw.class
  )
  SELECT
    class_id,
    class_name,
    (version->>'id')::INT version_id,
    (version->>'name')::TEXT version_name,
    (version->>'validFrom')::DATE version_valid_from,
    COALESCE((version->>'validTo')::DATE, MAKE_DATE(EXTRACT(YEAR FROM CURRENT_DATE) + 1, 1, 1)) - INTERVAL 1 DAY version_valid_to,
    (version->>'_links'->>'self'->>'href')::TEXT version_link,
  FROM versions
);

CREATE OR REPLACE VIEW class_version AS (
  WITH
  class_versions AS (
    SELECT
    class_id,
    version_id,
    (version->>'validFrom')::DATE version_valid_from,
    COALESCE((version->>'validTo')::DATE, MAKE_DATE(EXTRACT(YEAR FROM CURRENT_DATE) + 1, 1, 1)) - INTERVAL 1 DAY version_valid_to,
    UNNEST(FROM_JSON(version.classificationItems, '["json"]'))::JSON as version
    FROM raw.class_version
  )

  SELECT
    class_id,
    version_id,
    version_valid_from,
    version_valid_to,
    (version->>'code') as code,
    NULLIF(version->>'parentCode', '') as parent_code,
    (version->>'level')::INT as level,
    (version->>'name') as name,
    (version->>'shortName')::TEXT as short_name,
    NULLIF(version->>'notes', '') as notes,
  FROM class_versions
);

CREATE OR REPLACE VIEW class_correspondance AS (
  WITH correspondance AS (
    SELECT
    class_id,
    version_id,
    UNNEST(FROM_JSON(version.correspondenceTables, '["json"]')) correspondance
    FROM raw.class_version
  )

  SELECT
    class_id,
    version_id,
    (correspondance->>'id')::INT as correspondance_id,
    (correspondance->>'name') as correspondance_name,
    (correspondance->>'source') as source,
    (correspondance->>'sourceId') as source_id,
    (correspondance->>'sourceLevel'->>'levelNumber') as source_level_number,
    (correspondance->>'sourceLevel'->>'levelName') as source_level_name,
    (correspondance->>'target') as target,
    (correspondance->>'targetId') as target_id,
    (correspondance->>'targetLevel'->>'levelNumber') as target_level_number,
    (correspondance->>'targetLevel'->>'levelName') as target_level_name,
    (correspondance->>'changeTable') as change_table,
    (correspondance->>'_links'->>'self'->>'href') as link
  FROM correspondance
);

CREATE OR REPLACE VIEW class_correspondance_maps AS (
  WITH
  correspondance AS (
    SELECT
      class_id,
      version_id,
      (correspondance->>'id')::INT as correspondance_id,
      (correspondance->>'name') as correspondance_name,
      UNNEST(FROM_JSON(correspondance.correspondenceMaps, '["json"]')) correspondance
    FROM raw.class_correspondance
  )
  SELECT
    class_id,
    version_id,
    correspondance_id,
    correspondance_name,
    correspondance->>'sourceCode' as source_code,
    correspondance->>'sourceName' as source_name,
    correspondance->>'targetCode' as target_code,
    correspondance->>'targetName' as target_name
  FROM correspondance
);

CREATE OR REPLACE VIEW grunnkrets_delomraade AS (
  WITH
  grunnkrets AS (
    SELECT
      class_id,
      version_id,
      version_valid_from,
      version_valid_to,
      parent_code delomraade_no,
      code grunnkrets_no,
      name grunnkrets_name
    FROM class_version
    WHERE class_id = 1 AND level = 2
  ),

  delomraade AS (
    SELECT
      class_id,
      version_id,
      code delomraade_no,
      name delomraade_name
    FROM class_version
    WHERE class_id = 1 AND level = 1
  )

  SELECT
    grunnkrets.class_id,
    grunnkrets.version_id,
    grunnkrets.version_valid_from,
    grunnkrets.version_valid_to,
    years.date version_date,
    grunnkrets_no,
    grunnkrets_name,
    grunnkrets.delomraade_no,
    delomraade_name
  FROM grunnkrets
  LEFT JOIN delomraade ON
    TRUE
    AND grunnkrets.class_id = delomraade.class_id
    AND grunnkrets.version_id = delomraade.version_id
    AND grunnkrets.delomraade_no = delomraade.delomraade_no
  LEFT JOIN raw.years as years ON 
    TRUE
    AND years.date >= grunnkrets.version_valid_from 
    AND years.date <= grunnkrets.version_valid_to 
);

CREATE OR REPLACE VIEW kommune_fylke AS (
  SELECT
    class_version.class_id,
    class_version.version_id,
    class_correspondance_maps.correspondance_id,
    class_version.version_valid_from,
    class_version.version_valid_to,
    years.date as version_date,
    code as kommune_no,
    name kommune_name,
    CASE
      WHEN source_code IS NOT NULL THEN source_code
      -- Missing entries in Classification 131, Version 1102, Correspondance 440
      WHEN code = '1515' THEN '15'
      WHEN code = '2014' THEN '20'
      WHEN code = '9999' THEN '99'
    END as fylke_no,
    CASE
      WHEN source_code IS NOT NULL THEN source_name
      -- Missing entries in Classification 131, Version 1102, Correspondance 440
      WHEN code = '1515' THEN 'Møre og Romsdal'
      WHEN code = '2014' THEN 'Finnmark - Finnmárku'
      WHEN code = '9999' THEN 'Uoppgitt'
    END as fylke_name,
  FROM class_version
  LEFT JOIN class_correspondance_maps ON
    TRUE
    AND class_version.class_id = class_correspondance_maps.class_id
    AND class_version.version_id = class_correspondance_maps.version_id
    AND class_correspondance_maps.correspondance_name ILIKE '%Fylkesinndeling%'
    AND class_correspondance_maps.correspondance_name ILIKE '%Kommuneinndeling%'
    AND class_version.code = class_correspondance_maps.target_code
  LEFT JOIN raw.years as years ON 
    TRUE
    AND years.date >= class_version.version_valid_from 
    AND years.date <= class_version.version_valid_to 
  WHERE class_version.class_id = 131 AND version_valid_from >= '1995-01-01'
  QUALIFY ROW_NUMBER() OVER (PARTITION BY class_version.version_id, years.date, kommune_no ORDER BY class_correspondance_maps.correspondance_id DESC) = 1
  ORDER BY version_valid_from DESC, kommune_no
);

CREATE OR REPLACE VIEW grunnkrets_kommune AS (
  WITH
  class_correspondance_filtered AS (
    SELECT *
    FROM class_correspondance_maps
    WHERE correspondance_name LIKE 'Kommuneinndeling ____ - Delområde- og grunnkretsinndeling ____'
  ),
  grunnkrets_kommune AS (
    SELECT
    grunnkrets_delomraade.class_id,
    grunnkrets_delomraade.version_id,
    grunnkrets_delomraade.version_valid_from,
    grunnkrets_delomraade.version_valid_to,
    grunnkrets_delomraade.version_date,
    COALESCE(
        class_correspondance_grunnkrets.correspondance_id,
        class_correspondance_delomraade.correspondance_id,
    ) correspondance_id,
    COALESCE(
        class_correspondance_grunnkrets.correspondance_name,
        class_correspondance_delomraade.correspondance_name,
    ) correspondance_name,
    grunnkrets_delomraade.grunnkrets_no,
    grunnkrets_delomraade.grunnkrets_name,
    grunnkrets_delomraade.delomraade_no,
    grunnkrets_delomraade.delomraade_name,
    COALESCE(
      class_correspondance_grunnkrets.source_code,
      class_correspondance_delomraade.source_code,
      COALESCE(
        LAST_VALUE(class_correspondance_grunnkrets.source_code IGNORE NULLS) OVER (PARTITION BY grunnkrets_delomraade.grunnkrets_no ORDER BY version_valid_from),
        LAST_VALUE(class_correspondance_delomraade.source_code IGNORE NULLS) OVER (PARTITION BY grunnkrets_delomraade.grunnkrets_no ORDER BY version_valid_from)
    ),
    SUBSTRING(grunnkrets_no, 1, 4)
    ) as kommune_no,
    FROM grunnkrets_delomraade
    LEFT JOIN class_correspondance_filtered AS class_correspondance_grunnkrets ON
      TRUE
      AND grunnkrets_delomraade.class_id = class_correspondance_grunnkrets.class_id
      AND grunnkrets_delomraade.version_id = class_correspondance_grunnkrets.version_id
      AND grunnkrets_delomraade.grunnkrets_no = class_correspondance_grunnkrets.target_code
    LEFT JOIN class_correspondance_filtered AS class_correspondance_delomraade ON
      TRUE
      AND grunnkrets_delomraade.class_id = class_correspondance_delomraade.class_id
      AND grunnkrets_delomraade.version_id = class_correspondance_delomraade.version_id
      AND grunnkrets_delomraade.delomraade_no = class_correspondance_delomraade.target_code
    QUALIFY ROW_NUMBER() OVER (PARTITION BY grunnkrets_delomraade.version_id, version_date, grunnkrets_no ORDER BY COALESCE(class_correspondance_grunnkrets.correspondance_name, class_correspondance_delomraade.correspondance_name) DESC) = 1
  )

  SELECT
    grunnkrets_kommune.*,
    kommune_fylke.kommune_name,
    kommune_fylke.fylke_no,
    kommune_fylke.fylke_name
  FROM grunnkrets_kommune
  LEFT JOIN kommune_fylke ON 
    TRUE 
    AND grunnkrets_kommune.kommune_no = kommune_fylke.kommune_no
    AND grunnkrets_kommune.version_date = kommune_fylke.version_date
  WHERE TRUE
    AND grunnkrets_kommune.version_date >= '2002-01-01'
    AND grunnkrets_kommune.kommune_no <> '2100'
);

CREATE OR REPLACE VIEW grunnkrets_bydel AS (
  WITH
  class_correspondance_filtered AS (
    SELECT *
    FROM class_correspondance_maps
    WHERE TRUE
    AND correspondance_name LIKE 'Bydelsinndeling ____ - Delområde- og grunnkretsinndeling ____'
  ),

  grunnkrets AS (
    SELECT
    grunnkrets_delomraade.class_id,
    grunnkrets_delomraade.version_id,
    grunnkrets_delomraade.version_valid_from,
    grunnkrets_delomraade.version_valid_to,
    grunnkrets_delomraade.version_date,
    class_correspondance_filtered.correspondance_id,
    class_correspondance_filtered.correspondance_name,
    grunnkrets_delomraade.grunnkrets_no,
    grunnkrets_delomraade.grunnkrets_name,
    COALESCE(
      class_correspondance_filtered.source_code,
      FIRST_VALUE(class_correspondance_filtered.source_code IGNORE NULLS) OVER (PARTITION BY grunnkrets_delomraade.grunnkrets_no ORDER BY version_valid_from ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING),
    ) as bydel_no,
    COALESCE(
      class_correspondance_filtered.source_name,
      FIRST_VALUE(class_correspondance_filtered.source_name IGNORE NULLS) OVER (PARTITION BY grunnkrets_delomraade.grunnkrets_no ORDER BY version_valid_from ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING),
    ) as bydel_name,
    FROM grunnkrets_delomraade
    LEFT JOIN class_correspondance_filtered ON
      TRUE
      AND grunnkrets_delomraade.class_id = class_correspondance_filtered.class_id
      AND grunnkrets_delomraade.version_id = class_correspondance_filtered.version_id
      AND grunnkrets_delomraade.grunnkrets_no = class_correspondance_filtered.target_code
    WHERE version_date >= '2002-01-01'
    QUALIFY ROW_NUMBER() OVER (PARTITION BY version_date, grunnkrets_no ORDER BY correspondance_name DESC) = 1
  )

  SELECT *
  FROM grunnkrets
  WHERE bydel_no IS NOT NULL
  ORDER BY version_date, grunnkrets_no 
);

CREATE OR REPLACE VIEW kommune_economic_region AS (
    SELECT
    kommune_fylke.class_id,
    kommune_fylke.version_id,
    kommune_fylke.version_valid_from,
    kommune_fylke.version_valid_to,
    kommune_fylke.version_date,
    class_correspondance_maps.correspondance_id,
    class_correspondance_maps.correspondance_name,
    kommune_fylke.kommune_no,
    kommune_fylke.kommune_name,
    COALESCE(
      class_correspondance_maps.source_code,
      FIRST_VALUE(class_correspondance_maps.source_code IGNORE NULLS) OVER (PARTITION BY kommune_no ORDER BY version_valid_from),
      '9999'
    ) economic_region_no,
    COALESCE(
      class_correspondance_maps.source_name,
      FIRST_VALUE(class_correspondance_maps.source_name IGNORE NULLS) OVER (PARTITION BY kommune_no ORDER BY version_valid_from),
      'Uoppgitt'
    ) economic_region_name,
    FROM kommune_fylke
    LEFT JOIN class_correspondance_maps ON
      TRUE
      AND kommune_fylke.class_id = class_correspondance_maps.class_id
      AND kommune_fylke.version_id = class_correspondance_maps.version_id
      AND kommune_fylke.kommune_no = class_correspondance_maps.target_code
      AND class_correspondance_maps.correspondance_name LIKE 'Økonomiske regioner ____ - Kommuneinndeling ____'
    WHERE version_date >= '2002-01-01'
    QUALIFY ROW_NUMBER() OVER (PARTITION BY version_date, kommune_no ORDER BY correspondance_name DESC) = 1
);

CREATE OR REPLACE VIEW all_class AS (
  SELECT
  grunnkrets_delomraade.version_date,
  grunnkrets_delomraade.grunnkrets_no,
  grunnkrets_delomraade.grunnkrets_name,
  grunnkrets_delomraade.delomraade_no,
  grunnkrets_delomraade.delomraade_name,
  grunnkrets_bydel.bydel_no,
  grunnkrets_bydel.bydel_name,
  COALESCE(grunnkrets_bydel.bydel_no, grunnkrets_kommune.kommune_no) kommune_bydel_no,
  COALESCE(grunnkrets_bydel.bydel_name, grunnkrets_kommune.kommune_name) kommune_bydel_name,
  grunnkrets_kommune.kommune_no,
  grunnkrets_kommune.kommune_name,
  grunnkrets_kommune.fylke_no,
  grunnkrets_kommune.fylke_name,
  kommune_economic_region.economic_region_no,
  kommune_economic_region.economic_region_name
  FROM grunnkrets_delomraade
  LEFT JOIN grunnkrets_bydel ON
    TRUE
    AND grunnkrets_delomraade.grunnkrets_no = grunnkrets_bydel.grunnkrets_no
    AND grunnkrets_delomraade.version_date = grunnkrets_bydel.version_date
  LEFT JOIN grunnkrets_kommune ON
    TRUE
    AND grunnkrets_delomraade.grunnkrets_no = grunnkrets_kommune.grunnkrets_no
    AND grunnkrets_delomraade.version_date = grunnkrets_kommune.version_date
  LEFT JOIN kommune_economic_region ON
    TRUE
    AND grunnkrets_kommune.kommune_no = kommune_economic_region.kommune_no
    AND grunnkrets_delomraade.version_date  = kommune_economic_region.version_date
  WHERE
    TRUE
    AND grunnkrets_delomraade.version_date >= '2002-01-01'
    AND SUBSTRING(grunnkrets_delomraade.grunnkrets_no, 1, 2) <> '21'
  ORDER BY grunnkrets_delomraade.version_date, grunnkrets_delomraade.grunnkrets_no 
);
