# Report the remaining CoV open data API quota

The City of Vancouver Open Data portal reports a daily request quota on
every response. This returns the quota seen on the most recent request
made by this package, so it reflects usage across every \`VancouvR\`
call in the session.

The quota is per API key, or per IP address when no key is set, and is
shared with any other tool making requests under the same identity.
\`VancouvR\` warns once per session when fewer than 5

## Usage

``` r
get_cov_rate_limit()
```

## Value

A tibble with columns \`limit\`, \`remaining\` and \`reset\` (the time
the quota resets, as reported by the portal), or \`NULL\` if no request
has been made yet in this session.

## See also

\[get_cov_data()\], \[aggregate_cov_data()\]

## Examples

``` r
# \donttest{
get_cov_data("public-trees", rows = 5)
#> Downloading data from CoV Open Data portal
#> Simple feature collection with 5 features and 9 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: -123.1685 ymin: 49.21486 xmax: -123.052 ymax: 49.2958
#> Geodetic CRS:  WGS 84
#> # A tibble: 5 × 10
#>   asset_id address    common_name genus_name species_name cultivar_name height_m
#> *    <int> <chr>      <chr>       <chr>      <chr>        <chr>            <dbl>
#> 1   318897 1199 W CO… RED MAPLE   ACER       RUBRUM       NONE              10.7
#> 2   317041 7188 MACD… LAVALLEI H… CRATAEGUS  LAVALLEI  X  NONE               7.6
#> 3   318201 7188 MACD… WESTERN RE… THUJA      PLICATA      NONE              19.8
#> 4   342368 7800 VIVI… APPLE TREE  MALUS      XX           NONE               4.6
#> 5   335047 2000 W GE… WESTERN RE… THUJA      PLICATA      NONE              32  
#> # ℹ 3 more variables: diameter_cm <dbl>, date_planted <date>,
#> #   geometry <POINT [°]>
get_cov_rate_limit()
#> # A tibble: 1 × 3
#>   limit remaining reset                    
#>   <int>     <int> <chr>                    
#> 1 20000     19986 2026-08-20 00:00:00+00:00
# }
```
