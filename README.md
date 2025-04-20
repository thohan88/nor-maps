# Norwegian Administrative Maps

This repository contains simplified polygon boundaries for various Norwegian administrative levels, designed for statistical visualization, analysis, and mapping purposes.
All maps preserve boundaries between different administrative levels by aggregating polygons from the lowest level.

## Map Versions

This repo provides administrative boundaries at multiple levels:

- **Grunnkrets** (Basic Statistical Unit Level 1)
- **Delområde** (Basic Statistical Unit Level 2)
- **Bydel** (Districts)
- **Kommune/Bydel** (Municipalities and Districts where available)
- **Kommune** (Municipalities)
- **Fylke** (Counties)
- **Økonomisk region** (Economic Region)

Maps are available in two variants:
- **Landmask**: Contains the clipped Norwegian coastline
- **Extended**: Extends into the maritime border

## Map Quality

Current maps are available in multiple quality levels, representing polygon reduction:
- **xs**: 99.9% reduction (smallest file size)
- **s**: 99.5% reduction
- **m**: 99% reduction
- **l**: 95% reduction
- **xl**: 90% reduction (highest detail)

Historical maps dating back to 2002 are available in **xs** quality only to keep repository size manageable.

## Available Data



<table>
 <thead>
  <tr>
   <th style="text-align:left;"> Area </th>
   <th style="text-align:left;"> Landmask </th>
   <th style="text-align:left;"> Extended </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> Grunnkrets </td>
   <td style="text-align:left;"> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/landmask/grunnkrets_xs.geojson">xs</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/landmask/grunnkrets_s.geojson">s</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/landmask/grunnkrets_m.geojson">m</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/landmask/grunnkrets_l.geojson">l</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/landmask/grunnkrets_xl.geojson">xl</a> </td>
   <td style="text-align:left;"> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/extended/grunnkrets_xs.geojson">xs</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/extended/grunnkrets_s.geojson">s</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/extended/grunnkrets_m.geojson">m</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/extended/grunnkrets_l.geojson">l</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/extended/grunnkrets_xl.geojson">xl</a> </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Delområde </td>
   <td style="text-align:left;"> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/landmask/delomraade_xs.geojson">xs</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/landmask/delomraade_s.geojson">s</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/landmask/delomraade_m.geojson">m</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/landmask/delomraade_l.geojson">l</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/landmask/delomraade_xl.geojson">xl</a> </td>
   <td style="text-align:left;"> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/extended/delomraade_xs.geojson">xs</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/extended/delomraade_s.geojson">s</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/extended/delomraade_m.geojson">m</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/extended/delomraade_l.geojson">l</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/extended/delomraade_xl.geojson">xl</a> </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Bydel </td>
   <td style="text-align:left;"> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/landmask/bydel_xs.geojson">xs</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/landmask/bydel_s.geojson">s</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/landmask/bydel_m.geojson">m</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/landmask/bydel_l.geojson">l</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/landmask/bydel_xl.geojson">xl</a> </td>
   <td style="text-align:left;"> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/extended/bydel_xs.geojson">xs</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/extended/bydel_s.geojson">s</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/extended/bydel_m.geojson">m</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/extended/bydel_l.geojson">l</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/extended/bydel_xl.geojson">xl</a> </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Kommune/Bydel </td>
   <td style="text-align:left;"> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/landmask/kommune_bydel_xs.geojson">xs</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/landmask/kommune_bydel_s.geojson">s</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/landmask/kommune_bydel_m.geojson">m</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/landmask/kommune_bydel_l.geojson">l</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/landmask/kommune_bydel_xl.geojson">xl</a> </td>
   <td style="text-align:left;"> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/extended/kommune_bydel_xs.geojson">xs</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/extended/kommune_bydel_s.geojson">s</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/extended/kommune_bydel_m.geojson">m</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/extended/kommune_bydel_l.geojson">l</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/extended/kommune_bydel_xl.geojson">xl</a> </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Kommune </td>
   <td style="text-align:left;"> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/landmask/kommune_xs.geojson">xs</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/landmask/kommune_s.geojson">s</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/landmask/kommune_m.geojson">m</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/landmask/kommune_l.geojson">l</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/landmask/kommune_xl.geojson">xl</a> </td>
   <td style="text-align:left;"> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/extended/kommune_xs.geojson">xs</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/extended/kommune_s.geojson">s</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/extended/kommune_m.geojson">m</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/extended/kommune_l.geojson">l</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/extended/kommune_xl.geojson">xl</a> </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Fylke </td>
   <td style="text-align:left;"> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/landmask/fylke_xs.geojson">xs</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/landmask/fylke_s.geojson">s</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/landmask/fylke_m.geojson">m</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/landmask/fylke_l.geojson">l</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/landmask/fylke_xl.geojson">xl</a> </td>
   <td style="text-align:left;"> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/extended/fylke_xs.geojson">xs</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/extended/fylke_s.geojson">s</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/extended/fylke_m.geojson">m</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/extended/fylke_l.geojson">l</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/extended/fylke_xl.geojson">xl</a> </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Økonomisk region </td>
   <td style="text-align:left;"> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/landmask/economic_region_xs.geojson">xs</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/landmask/economic_region_s.geojson">s</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/landmask/economic_region_m.geojson">m</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/landmask/economic_region_l.geojson">l</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/landmask/economic_region_xl.geojson">xl</a> </td>
   <td style="text-align:left;"> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/extended/economic_region_xs.geojson">xs</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/extended/economic_region_s.geojson">s</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/extended/economic_region_m.geojson">m</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/extended/economic_region_l.geojson">l</a> <a href="https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/extended/economic_region_xl.geojson">xl</a> </td>
  </tr>
</tbody>
</table>

## Usage

### Direct Download
All maps can be directly accessed via raw GitHub URLs: Use the `current`-folder to retrieve latest version, or 
use the `versioned`-folder if you prefer maps to be freezed. 
```
https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/landmask/kommune_s.geojson
```

## Attribution

- Administrative hierarchies are sourced from Statistics Norway's [Statistical Codelists](https://data.ssb.no/api/klass/v1/api-guide.html)
- Administrative borders are obtained from [Geonorge](https://www.geonorge.no/)
- Historical SOSI-format files were converted using [SOSICON](https://github.com/espena/sosicon)
- Maps are simplified using [Mapshaper](https://github.com/mbloch/mapshaper)


