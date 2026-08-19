# Download a dataset from the Vancouver Open Data Portal

Downloads a dataset and returns it as a tibble or \`sf\` object. When
\`cast_types = TRUE\` (the default), field types are looked up via
\[get_cov_metadata()\] and columns are automatically cast to integer,
numeric, or Date.

Datasets whose metadata declares a \`geo_shape\` or \`geo_point_2d\`
field are downloaded as [FlatGeobuf](https://flatgeobuf.org) and
returned as an \`sf\` object with its coordinate reference system
already set, rather than as CSV with the geometry re-parsed from text.
The raw geometry fields are not part of that export, so such datasets
come back with a single \`geometry\` column and no \`geom\` or
\`geo_point_2d\` column. Setting \`cast_types = FALSE\` or \`use_labels
= TRUE\` downloads the CSV instead, and returns a plain tibble.

Results are cached for the duration of the R session, keyed on all query
parameters. Re-running the same call does not trigger a second download.

## Usage

``` r
get_cov_data(
  dataset_id,
  select = "*",
  where = NULL,
  order_by = NULL,
  refine = NULL,
  exclude = NULL,
  apikey = getOption("VancouverOpenDataApiKey"),
  rows = NULL,
  cast_types = TRUE,
  use_labels = FALSE,
  timezone = NULL,
  refresh = FALSE,
  ...
)
```

## Arguments

- dataset_id:

  Dataset id from the Vancouver Open Data catalogue

- select:

  Column selection / expression string using [ODSQL
  syntax](https://help.opendatasoft.com/apis/ods-explore-v2/#section/Opendatasoft-Query-Language-(ODSQL)/Select-clause),
  e.g. \`"current_land_value, land_coordinate as coord"\`. Default
  \`"\*"\` returns all columns.

- where:

  Filter expression using [ODSQL
  syntax](https://help.opendatasoft.com/apis/ods-explore-v2/#section/Opendatasoft-Query-Language-(ODSQL)/Where-clause),
  e.g. \`"tax_assessment_year='2024' AND zoning_district LIKE 'RS-'"\`.
  Default \`NULL\` returns all rows.

- order_by:

  Sort expression using [ODSQL
  syntax](https://help.opendatasoft.com/apis/ods-explore-v2/#section/Opendatasoft-Query-Language-(ODSQL)/Order-by-clause),
  e.g. \`"height_m DESC"\`. Default \`NULL\` leaves the portal's
  ordering.

- refine:

  Facet filter(s) of the form \`"field:value"\`, e.g.
  \`"genus_name:ACER"\`. Values must match the facet exactly. Pass a
  character vector to apply several; multiple values on the same field
  are combined with OR, different fields with AND. Default \`NULL\`.

- exclude:

  Facet exclusion(s), in the same \`"field:value"\` form as \`refine\`.
  Default \`NULL\`.

- apikey:

  Vancouver Open Data API key, default
  \`getOption("VancouverOpenDataApiKey")\`

- rows:

  Maximum number of rows to return. Default \`NULL\` returns all rows.

- cast_types:

  Logical; use metadata to auto-cast column types and to download
  spatial datasets as \`sf\`. Default \`TRUE\`.

- use_labels:

  Logical; name the columns using the human-readable field labels
  instead of the API field names. Default \`FALSE\`. Setting this to
  \`TRUE\` disables type casting, as metadata is keyed on the API names.

- timezone:

  Timezone used to render datetime fields, e.g. \`"America/Vancouver"\`.
  Default \`NULL\` uses the portal default (UTC).

- refresh:

  Bypass the session cache and re-download, default \`FALSE\`

- ...:

  Ignored; retained for compatibility with earlier versions

## Value

A tibble, or an \`sf\` object when the dataset has a spatial field and
\`cast_types = TRUE\`. Returns \`NULL\` with a warning if the API cannot
be reached.

## See also

\[get_cov_metadata()\] for field names and types,
\[aggregate_cov_data()\] for server-side aggregation,
\[search_cov_datasets()\] to find dataset IDs

## Examples

``` r
# \donttest{
# Select specific columns and limit rows (useful for exploration)
get_cov_data("property-tax-report",
             select = "tax_assessment_year, current_land_value, zoning_district",
             where = "tax_assessment_year = '2024'",
             rows = 10)
#> Downloading data from CoV Open Data portal
#> # A tibble: 10 × 3
#>    tax_assessment_year current_land_value zoning_district
#>    <chr>                            <int> <chr>          
#>  1 2024                           1183000 C-2            
#>  2 2024                           1401000 RM-1           
#>  3 2024                           1566000 RT-8           
#>  4 2024                           2505000 R1-1           
#>  5 2024                           2681000 R1-1           
#>  6 2024                           2150000 R1-1           
#>  7 2024                           1935000 R1-1           
#>  8 2024                            626000 C-2            
#>  9 2024                           1859000 R1-1           
#> 10 2024                           2475000 R1-1           

# The ten tallest maples, sorted server-side
get_cov_data("public-trees",
             refine = "genus_name:ACER",
             order_by = "height_m DESC",
             rows = 10)
#> Downloading data from CoV Open Data portal
#> Simple feature collection with 10 features and 9 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: -123.2098 ymin: 49.22939 xmax: -123.0759 ymax: 49.30501
#> Geodetic CRS:  WGS 84
#> # A tibble: 10 × 10
#>    asset_id address   common_name genus_name species_name cultivar_name height_m
#>  *    <int> <chr>     <chr>       <chr>      <chr>        <chr>            <dbl>
#>  1   320427 5955 ROS… BIGLEAF MA… ACER       MACROPHYLLUM NONE                32
#>  2   334994 2000 W G… BIGLEAF MA… ACER       MACROPHYLLUM NONE                32
#>  3   335684 2000 W G… BIGLEAF MA… ACER       MACROPHYLLUM NONE                32
#>  4   324809 2000 W G… BIGLEAF MA… ACER       MACROPHYLLUM NONE                32
#>  5   326453 5175 DUM… RED MAPLE   ACER       RUBRUM       NONE                32
#>  6   335121 2000 W G… BIGLEAF MA… ACER       MACROPHYLLUM NONE                32
#>  7   325111 2000 W G… BIGLEAF MA… ACER       MACROPHYLLUM NONE                32
#>  8   335065 2000 W G… BIGLEAF MA… ACER       MACROPHYLLUM NONE                32
#>  9   335086 2000 W G… BIGLEAF MA… ACER       MACROPHYLLUM NONE                32
#> 10   331144 4445 NW … BIGLEAF MA… ACER       MACROPHYLLUM NONE                32
#> # ℹ 3 more variables: diameter_cm <dbl>, date_planted <date>,
#> #   geometry <POINT [°]>

# Spatial dataset: returned automatically as an sf object
property_polygons <- get_cov_data("property-parcel-polygons", rows = 10)
#> Downloading data from CoV Open Data portal
class(property_polygons)  # "sf" "data.frame"
#> [1] "sf"         "tbl_df"     "tbl"        "data.frame"
# }

if (FALSE) { # \dontrun{
# Whole filtered datasets can be large, so they are not run here
get_cov_data("parking-tickets-2017-2019",
             where = "block = 1100 AND street = 'ALBERNI ST'")
} # }
```
