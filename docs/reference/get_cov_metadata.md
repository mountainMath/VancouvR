# Get field-level metadata for a CoV open data dataset

Returns a tibble describing each field in the dataset, including its API
name, data type, display label, and description. Results are cached for
the duration of the R session.

This function is called internally by \[get_cov_data()\] when
\`cast_types = TRUE\` to determine column types and identify spatial
fields.

## Usage

``` r
get_cov_metadata(
  dataset_id,
  apikey = getOption("VancouverOpenDataApiKey"),
  refresh = FALSE
)
```

## Arguments

- dataset_id:

  the CoV open data dataset id

- apikey:

  the CoV open data API key, optional

- refresh:

  Bypass the session cache and re-download, default \`FALSE\`

## Value

A tibble with one row per field and columns:

- name:

  Field name as used in \`where\` and \`select\` queries

- type:

  API data type (e.g. \`"text"\`, \`"int"\`, \`"double"\`, \`"date"\`,
  \`"geo_shape"\`)

- label:

  Human-readable display label

- description:

  Field description, if provided by the portal

Returns \`NULL\` with a warning if the API cannot be reached.

## See also

\[get_cov_data()\], \[list_cov_datasets()\]

## Examples

``` r
# \donttest{
# View all fields in the public trees dataset
get_cov_metadata("public-trees")
#> # A tibble: 11 × 4
#>    name          type         label         description                         
#>    <chr>         <chr>        <chr>         <chr>                               
#>  1 asset_id      int          Asset ID      "Asset ID"                          
#>  2 address       text         Address       "Nearest address"                   
#>  3 common_name   text         Common name   "Common name"                       
#>  4 genus_name    text         Genus name    "Genus name"                        
#>  5 species_name  text         Species name  "Species name"                      
#>  6 cultivar_name text         Cultivar name "Cultivar name"                     
#>  7 height_m      double       height_(m)     NA                                 
#>  8 diameter_cm   double       diameter_(cm)  NA                                 
#>  9 date_planted  date         Date planted  "Date is in YYYY-MM-DD format.  Pla…
#> 10 geom          geo_shape    Geom          "Spatial representation of feature" 
#> 11 geo_point_2d  geo_point_2d geo_point_2d   NA                                 
# }

if (FALSE) { # \dontrun{
# Find which fields are spatial
get_cov_metadata("property-parcel-polygons") |>
  dplyr::filter(type == "geo_shape")
} # }
```
