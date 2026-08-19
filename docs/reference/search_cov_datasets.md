# Search the CoV open data catalogue

Filters the City of Vancouver Open Data catalogue for datasets whose
title, dataset ID, keyword, or search-term fields match \`search_term\`
(using \`grepl()\`, so regular expressions are supported). When no exact
match is found, a fuzzy-match hint list of similarly named datasets is
printed.

## Usage

``` r
search_cov_datasets(
  search_term,
  trim = TRUE,
  apikey = getOption("VancouverOpenDataApiKey"),
  refresh = FALSE
)
```

## Arguments

- search_term:

  A grep-compatible string to search through dataset titles, IDs,
  keywords, and search terms

- trim:

  Remove columns that are entirely \`NA\`, default \`TRUE\`

- apikey:

  the CoV open data API key, optional

- refresh:

  Bypass the session cache and re-download, default \`FALSE\`

## Value

A tibble with one row per matching dataset, in the same format as
\[list_cov_datasets()\]. Returns \`NULL\` with a warning if the API
cannot be reached.

## See also

\[list_cov_datasets()\] to retrieve the full catalogue,
\[get_cov_data()\] to download a specific dataset

## Examples

``` r
# \donttest{
# Search using a plain string
search_cov_datasets("trees")
#> # A tibble: 2 × 24
#>   dataset_id   title keyword `search-term` description theme license license_url
#>   <chr>        <chr> <chr>   <chr>         <chr>       <chr> <chr>   <chr>      
#> 1 public-trees Publ… NA      tree canopy;… "<div><p> … Stre… Open G… https://op…
#> 2 community-g… Comm… NA      local, commu… "<div><p> … Food… Open G… https://op…
#> # ℹ 16 more variables: language <chr>, metadata_languages <chr>,
#> #   modified <chr>, modified_updates_on_metadata_change <chr>,
#> #   modified_updates_on_data_change <chr>, data_processed <chr>,
#> #   metadata_processed <chr>, geometry_types <chr>, bbox <chr>,
#> #   publisher <chr>, records_count <chr>, federated <chr>, `data-owner` <chr>,
#> #   `data-team` <chr>, `change-log` <chr>, datasetid <chr>

# Search using a regular expression
search_cov_datasets("parking.*(2019|2020)")
#> # A tibble: 2 × 22
#>   dataset_id   title keyword `search-term` description theme license license_url
#>   <chr>        <chr> <chr>   <chr>         <chr>       <chr> <chr>   <chr>      
#> 1 parking-tic… Park… parking violation, i… "<div><p>T… Gove… Open G… https://op…
#> 2 parking-tic… Park… parking NA            "<div><p>T… Gove… Open G… https://op…
#> # ℹ 14 more variables: language <chr>, metadata_languages <chr>,
#> #   modified <chr>, modified_updates_on_metadata_change <chr>,
#> #   modified_updates_on_data_change <chr>, data_processed <chr>,
#> #   metadata_processed <chr>, publisher <chr>, records_count <chr>,
#> #   federated <chr>, `data-owner` <chr>, `data-team` <chr>, `change-log` <chr>,
#> #   datasetid <chr>
# }
```
