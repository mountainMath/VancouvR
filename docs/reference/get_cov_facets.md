# Get the facet values of a CoV open data dataset

Returns the values available for each facetted field, together with the
number of records carrying them. This is a quick way to discover what a
field actually contains before writing a \`where\` clause or a
\`refine\` filter for \[get_cov_data()\].

The portal returns only the most common values of each facet (currently
the top 100). Use \[aggregate_cov_data()\] with a \`group_by\` for an
exhaustive count.

Results are cached for the duration of the R session.

## Usage

``` r
get_cov_facets(
  dataset_id,
  facet = NULL,
  where = NULL,
  refine = NULL,
  exclude = NULL,
  apikey = getOption("VancouverOpenDataApiKey"),
  refresh = FALSE
)
```

## Arguments

- dataset_id:

  the CoV open data dataset id

- facet:

  Name(s) of the fields to facet on. Default \`NULL\` returns every
  facetted field in the dataset.

- where:

  Filter expression using [ODSQL
  syntax](https://help.opendatasoft.com/apis/ods-explore-v2/#section/Opendatasoft-Query-Language-(ODSQL)/Where-clause),
  restricting the records the counts are computed over. Default
  \`NULL\`.

- refine:

  Facet filter(s) of the form \`"field:value"\`; see \[get_cov_data()\].
  Default \`NULL\`.

- exclude:

  Facet exclusion(s) of the form \`"field:value"\`. Default \`NULL\`.

- apikey:

  the CoV open data API key, optional

- refresh:

  Bypass the session cache and re-download, default \`FALSE\`

## Value

A tibble with columns \`facet\` (the field name), \`value\`, and
\`count\`. Returns \`NULL\` with a warning if the API cannot be reached.

## See also

\[get_cov_metadata()\] for the list of fields, \[list_cov_facets()\] for
the facets of the catalogue itself, \[aggregate_cov_data()\] for
complete server-side counts

## Examples

``` r
# \donttest{
# What values does the genus field take?
get_cov_facets("public-trees", facet = "genus_name")
#> # A tibble: 100 × 3
#>    facet      value    count
#>    <chr>      <chr>    <int>
#>  1 genus_name ACER     42180
#>  2 genus_name PRUNUS   30238
#>  3 genus_name QUERCUS   8970
#>  4 genus_name FRAXINUS  8026
#>  5 genus_name TILIA     6785
#>  6 genus_name CARPINUS  6750
#>  7 genus_name THUJA     6215
#>  8 genus_name FAGUS     6186
#>  9 genus_name MAGNOLIA  4705
#> 10 genus_name MALUS     4378
#> # ℹ 90 more rows

# Restricted to trees planted since 2020
get_cov_facets("public-trees", facet = "genus_name",
               where = "date_planted >= date'2020-01-01'")
#> # A tibble: 74 × 3
#>    facet      value    count
#>    <chr>      <chr>    <int>
#>  1 genus_name ACER      2840
#>  2 genus_name QUERCUS   1298
#>  3 genus_name NYSSA     1027
#>  4 genus_name PRUNUS     924
#>  5 genus_name PARROTIA   859
#>  6 genus_name CARPINUS   855
#>  7 genus_name FAGUS      827
#>  8 genus_name MAGNOLIA   469
#>  9 genus_name FRAXINUS   372
#> 10 genus_name STYRAX     353
#> # ℹ 64 more rows
# }
```
