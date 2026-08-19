# List the facets of the CoV open data catalogue

Returns the values the catalogue can be filtered on, together with the
number of datasets carrying each. This is the starting point for
browsing the portal rather than searching it: it answers what themes and
keywords exist before passing them to \[list_cov_datasets()\] as a
\`refine\` filter.

The catalogue facets are \`theme\`, \`keyword\`, \`features\`,
\`custom.data-owner\` and \`custom.data-team\`. The \`features\` facet
is worth knowing about: its \`geo\` value identifies the datasets
\[get_cov_data()\] returns as \`sf\` objects, and \`timeserie\` those
carrying a date field.

Results are cached for the duration of the R session.

## Usage

``` r
list_cov_facets(
  facet = NULL,
  where = NULL,
  refine = NULL,
  exclude = NULL,
  apikey = getOption("VancouverOpenDataApiKey"),
  refresh = FALSE
)
```

## Arguments

- facet:

  Name(s) of the catalogue facets to return. Default \`NULL\` returns
  every facet.

- where:

  Filter expression using [ODSQL
  syntax](https://help.opendatasoft.com/apis/ods-explore-v2/#section/Opendatasoft-Query-Language-(ODSQL)/Where-clause),
  restricting the datasets the counts are computed over. Default
  \`NULL\`.

- refine:

  Facet filter(s) of the form \`"facet:value"\`. Default \`NULL\`.

- exclude:

  Facet exclusion(s) of the form \`"facet:value"\`. Default \`NULL\`.

- apikey:

  the CoV open data API key, optional

- refresh:

  Bypass the session cache and re-download, default \`FALSE\`

## Value

A tibble with columns \`facet\` (the facet name), \`value\`, and
\`count\` (the number of datasets). Returns \`NULL\` with a warning if
the API cannot be reached.

## See also

\[list_cov_datasets()\] to filter the catalogue on these values,
\[get_cov_facets()\] for the facets of an individual dataset

## Examples

``` r
# \donttest{
# Every facet of the catalogue
list_cov_facets()
#> # A tibble: 86 × 3
#>    facet    value                 count
#>    <chr>    <chr>                 <int>
#>  1 features analyze                 152
#>  2 features custom_view               8
#>  3 features geo                     135
#>  4 features image                     2
#>  5 features timeserie                42
#>  6 theme    Business and economy      7
#>  7 theme    Culture and education     5
#>  8 theme    Demographics              5
#>  9 theme    Food and housing          6
#> 10 theme    Geography and imagery    19
#> # ℹ 76 more rows

# Just the themes, and how many datasets each holds
list_cov_facets(facet = "theme")
#> # A tibble: 12 × 3
#>    facet value                       count
#>    <chr> <chr>                       <int>
#>  1 theme Business and economy            7
#>  2 theme Culture and education           5
#>  3 theme Demographics                    5
#>  4 theme Food and housing                6
#>  5 theme Geography and imagery          19
#>  6 theme Government and finance         44
#>  7 theme Parks, recreation, and pets    13
#>  8 theme Property and development       32
#>  9 theme Safety                          6
#> 10 theme Streets and transportation     49
#> 11 theme Sustainability                  2
#> 12 theme Water and sewer                13
# }
```
