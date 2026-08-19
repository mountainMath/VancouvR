# List all datasets in the CoV open data catalogue

Fetches the full City of Vancouver Open Data catalogue and returns it as
a tibble. Results are cached for the duration of the R session;
subsequent calls return the cached copy unless \`refresh = TRUE\`.

## Usage

``` r
list_cov_datasets(
  trim = TRUE,
  where = NULL,
  refine = NULL,
  exclude = NULL,
  apikey = getOption("VancouverOpenDataApiKey"),
  refresh = FALSE
)
```

## Arguments

- trim:

  Remove columns that are entirely \`NA\`, default \`TRUE\`

- where:

  Filter expression applied by the portal, using [ODSQL
  syntax](https://help.opendatasoft.com/apis/ods-explore-v2/#section/Opendatasoft-Query-Language-(ODSQL)/Where-clause)
  over the catalogue's own fields, e.g. \`"search(title, 'tree')"\` or
  \`"features LIKE 'geo'"\`. Default \`NULL\` returns the whole
  catalogue.

- refine:

  Catalogue facet filter(s) of the form \`"facet:value"\`, e.g.
  \`"theme:Sustainability"\`. Values must match the facet exactly; use
  \[list_cov_facets()\] to discover them. Pass a character vector to
  apply several; multiple values on the same facet are combined with OR,
  different facets with AND. Default \`NULL\`.

- exclude:

  Catalogue facet exclusion(s), in the same \`"facet:value"\` form as
  \`refine\`. Default \`NULL\`.

- apikey:

  the CoV open data API key, optional

- refresh:

  Bypass the session cache and re-download, default \`FALSE\`

## Value

A tibble with one row per dataset. The first four columns are always
\`dataset_id\`, \`title\`, \`keyword\`, and \`search-term\`; remaining
columns contain catalogue metadata (trimmed to non-empty columns when
\`trim = TRUE\`). Returns \`NULL\` with a warning if the API cannot be
reached.

## See also

\[list_cov_facets()\] to discover the values \`refine\` accepts,
\[search_cov_datasets()\] to filter the catalogue by a search term,
\[get_cov_data()\] to download a specific dataset

## Examples

``` r
# \donttest{
# Only the datasets that carry geographic records
list_cov_datasets(where = "features LIKE 'geo'")
#> # A tibble: 135 × 27
#>    dataset_id  title keyword `search-term` description theme license license_url
#>    <chr>       <chr> <chr>   <chr>         <chr>       <chr> <chr>   <chr>      
#>  1 greenest-c… Gree… NA      greenest cit… "<div><p> … Sust… Open G… https://op…
#>  2 olympic-tr… Olym… 2010 W… NA            "<div><p>T… Stre… Open G… https://op…
#>  3 lidar-2013  LiDA… NA      lidar, LAS, … "<div><p>L… Geog… Open G… https://op…
#>  4 olympic-tr… Olym… 2010 W… NA            "<div><p>T… Stre… Open G… https://op…
#>  5 voting-pla… Voti… electi… NA            "<div clas… Gove… Open G… https://op…
#>  6 olympic-ve… Olym… 2010 W… NA            "<div><p>​…  Park… Open G… https://op…
#>  7 greenways   Gree… NA      NA            "<div><p>T… Stre… Open G… https://op…
#>  8 wayfinding… Wayf… NA      information,… "<div><p>T… Stre… Open G… https://op…
#>  9 railways    Rail… traffic Rail, track,… "<div><p>T… Stre… Open G… https://op…
#> 10 voting-pla… Voti… electi… NA            "<div><p>T… Gove… Open G… https://op…
#> # ℹ 125 more rows
#> # ℹ 19 more variables: language <chr>, metadata_languages <chr>,
#> #   timezone <chr>, modified <chr>, modified_updates_on_metadata_change <chr>,
#> #   modified_updates_on_data_change <chr>, data_processed <chr>,
#> #   metadata_processed <chr>, geographic_reference_auto <chr>,
#> #   geometry_types <chr>, bbox <chr>, publisher <chr>, records_count <chr>,
#> #   federated <chr>, update_frequency <chr>, `data-owner` <chr>, …

# Datasets filed under a catalogue theme
list_cov_datasets(refine = "theme:Sustainability")
#> # A tibble: 2 × 24
#>   dataset_id   title keyword `search-term` description theme license license_url
#>   <chr>        <chr> <chr>   <chr>         <chr>       <chr> <chr>   <chr>      
#> 1 greenest-ci… Gree… NA      greenest cit… "<div><p> … Sust… Open G… https://op…
#> 2 designated-… Desi… climat… NA            "<p>This d… Sust… Open G… https://op…
#> # ℹ 16 more variables: language <chr>, metadata_languages <chr>,
#> #   modified <chr>, modified_updates_on_metadata_change <chr>,
#> #   modified_updates_on_data_change <chr>, data_processed <chr>,
#> #   metadata_processed <chr>, geometry_types <chr>, bbox <chr>,
#> #   publisher <chr>, records_count <chr>, federated <chr>, `data-owner` <chr>,
#> #   `data-team` <chr>, `change-log` <chr>, datasetid <chr>
# }

if (FALSE) { # \dontrun{
# The entire catalogue
list_cov_datasets()
} # }
```
