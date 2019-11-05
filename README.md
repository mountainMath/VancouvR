# VancouvR

<!-- badges: start -->
[![Build Status](https://travis-ci.org/mountainMath/VancouvR.svg?branch=master)](https://travis-ci.org/mountainMath/VancouvR)
<!-- badges: end -->

VancouverOpenData is an R wrapper around the City of Vancouver Open Data API.

You can install VancouverOpenData from [GitHub](https://github.com/mountainMath/VancouvR) with:

``` r
remotes::install_github("mountainmath/VancouvR")
```

## Reference
[VancouverOpenData package reference](https://mountainmath.github.io/VancouvR/index.html)

## Example

Get a list of datasets relating to properties

``` r
library(VancouvR)

list_cov_datasets() %>%
  filter(grepl("property",default.title,ignore.case = TRUE)) %>%
  select(dataset_id,title)
```

Get the first 10 records of the property tax report for 2019 tax year.

``` r
get_cov_data(dataset_id = "property-tax-report",where="tax_assessment_year=2019",rows=10)
```

