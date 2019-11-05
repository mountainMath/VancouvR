# VancouvR

<!-- badges: start -->
[![Build Status](https://travis-ci.org/mountainMath/VancouvR.svg?branch=master)](https://travis-ci.org/mountainMath/VancouvR)
<!-- badges: end -->

<a href="https://mountainmath.github.io/VancouvR/index.html"><img src="https://raw.githubusercontent.com/mountainMath/VancouvR/master/images/VancouvR-sticker.png" alt="VancouvR logo" align="right" width = "25%" height = "25%"/></a>

VancouverOpenData is an R wrapper around the City of Vancouver Open Data API. It allows transparent and reproducible access to the Vancouver Open Data Portal to facilitate data analysis and sharing of code.


### Reference
[VancouverOpenData package reference](https://mountainmath.github.io/VancouvR/index.html)

### Installing the package
You can install VancouverOpenData from [GitHub](https://github.com/mountainMath/VancouvR) with:

``` r
remotes::install_github("mountainmath/VancouvR")
```

### API key
Smaller datasets can be accessed without an API key, but for larger datasets an API key is required. API keys [are available after registering at the City of Vancouver Open Data Portal](https://opendata.vancouver.ca/signup/).

### Example

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

