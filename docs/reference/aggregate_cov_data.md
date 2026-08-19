# Aggregate data from the Vancouver Open Data Portal

Sends a server-side aggregation query to the CoV Open Data API and
returns the result as a tibble. Because aggregation is performed by the
API, this is suitable for summarising large datasets without downloading
all records.

Results are cached for the duration of the R session.

Grouped queries are answered by the dataset export endpoint and so are
not subject to a record limit; every group is returned in a single
request.

## Usage

``` r
aggregate_cov_data(
  dataset_id,
  select = "count(*) as count",
  group_by = NULL,
  where = NULL,
  order_by = NULL,
  refine = NULL,
  exclude = NULL,
  limit = NULL,
  apikey = getOption("VancouverOpenDataApiKey"),
  refresh = FALSE
)
```

## Arguments

- dataset_id:

  Dataset id from the Vancouver Open Data catalogue

- select:

  Aggregation expression using [ODSQL
  syntax](https://help.opendatasoft.com/apis/ods-explore-v2/#section/Opendatasoft-Query-Language-(ODSQL)/Select-clause).
  Default \`"count(\*) as count"\`.

- group_by:

  Grouping expression using [ODSQL
  syntax](https://help.opendatasoft.com/apis/ods-explore-v2/#section/Opendatasoft-Query-Language-(ODSQL)/Group-by-clause).
  Default \`NULL\` (no grouping).

- where:

  Filter expression using [ODSQL
  syntax](https://help.opendatasoft.com/apis/ods-explore-v2/#section/Opendatasoft-Query-Language-(ODSQL)/Where-clause).
  Default \`NULL\` (no filter).

- order_by:

  Sort expression using [ODSQL
  syntax](https://help.opendatasoft.com/apis/ods-explore-v2/#section/Opendatasoft-Query-Language-(ODSQL)/Order-by-clause),
  naming an aggregate from \`select\` or a field from \`group_by\`, e.g.
  \`"count DESC"\`. Default \`NULL\`.

- refine:

  Facet filter(s) of the form \`"field:value"\`; see \[get_cov_data()\].
  Default \`NULL\`.

- exclude:

  Facet exclusion(s) of the form \`"field:value"\`. Default \`NULL\`.

- limit:

  Maximum number of groups to return. Default \`NULL\` returns all
  groups. Ignored when \`group_by\` is \`NULL\`, which always yields one
  row.

- apikey:

  Vancouver Open Data API key, default
  \`getOption("VancouverOpenDataApiKey")\`

- refresh:

  Bypass the session cache and re-download, default \`FALSE\`

## Value

A tibble with one row per group, with columns named according to the
\`select\` expression. Returns \`NULL\` with a warning if the API cannot
be reached.

## See also

\[get_cov_data()\] to download full or filtered records,
\[search_cov_datasets()\] to find dataset IDs

## Examples

``` r
# \donttest{
# Count of each ticket status for fire hydrant infractions
aggregate_cov_data("parking-tickets-2017-2019",
                   group_by = "status",
                   where = "infractiontext LIKE 'FIRE'")
#> Downloading data from CoV Open Data portal
#> # A tibble: 3 × 2
#>   status count
#>   <chr>  <int>
#> 1 IS     10385
#> 2 VA      1850
#> 3 WR        14

# Sum land and building values by tax year (server-side, no full download needed)
aggregate_cov_data("property-tax-report",
                   select = "sum(current_land_value) as Land,
                             sum(current_improvement_value) as Building",
                   group_by = "tax_assessment_year")
#> Downloading data from CoV Open Data portal
#> # A tibble: 8 × 3
#>   tax_assessment_year         Land     Building
#>   <chr>                      <dbl>        <dbl>
#> 1 2026                366807717749 120014837253
#> 2 2025                409280520781 110058619834
#> 3 2024                414664943260 105575866549
#> 4 2023                409192967059 108807348071
#> 5 2022                394201892132 102591491465
#> 6 2021                353851075215  89683743459
#> 7 2020                349029074554  87789231207
#> 8 NA                             0            0

# The ten most common tree genera
aggregate_cov_data("public-trees",
                   group_by = "genus_name",
                   order_by = "count DESC",
                   limit = 10)
#> Downloading data from CoV Open Data portal
#> # A tibble: 10 × 2
#>    genus_name count
#>    <chr>      <int>
#>  1 ACER       42180
#>  2 PRUNUS     30238
#>  3 QUERCUS     8970
#>  4 FRAXINUS    8026
#>  5 TILIA       6785
#>  6 CARPINUS    6750
#>  7 THUJA       6215
#>  8 FAGUS       6186
#>  9 MAGNOLIA    4705
#> 10 MALUS       4378
# }
```
