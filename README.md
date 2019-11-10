# VancouvR

<!-- badges: start -->
[![Build Status](https://travis-ci.org/mountainMath/VancouvR.svg?branch=master)](https://travis-ci.org/mountainMath/VancouvR)
<!-- badges: end -->

<a href="https://mountainmath.github.io/VancouvR/index.html"><img src="https://raw.githubusercontent.com/mountainMath/VancouvR/master/images/VancouvR-sticker.png" alt="VancouvR logo" align="right" width = "25%" height = "25%"/></a>

`VancouvR` is an R wrapper around the City of Vancouver Open Data API. It allows transparent and reproducible access to the Vancouver Open Data Portal to facilitate data analysis and sharing of code.

The package caches downloaded data for the duration of the current session, so re-running code blocks will not result in repeated downloads. This speeds up the code, cuts down on unnecessary network traffic and reduces strain on the City of Vancouver Open Data infrastructure.


### Reference
[VancouverOpenData package reference](https://mountainmath.github.io/VancouvR/index.html)

### Installing the package
You can install `VancouvR` from [GitHub](https://github.com/mountainMath/VancouvR) with:

``` r
remotes::install_github("mountainmath/VancouvR")
```

### API key
Smaller datasets can be accessed without an API key, but for larger datasets an API key is required. API keys [are available after registering at the City of Vancouver Open Data Portal](https://opendata.vancouver.ca/signup/). 

Setting the API key in the `.Rprofile` file via
``` {r}
options(VancouverOpenDataApiKey=<your api key>)
```
will ensure that it is automatically loaded and not exposed when you share your code.

### Example

Get a list of datasets relating to properties

``` r
library(VancouvR)

search_cov_datasets("properties")
```

Get the first 10 records of the property tax report for 2019 tax year.

``` r
get_cov_data(dataset_id = "property-tax-report",where="tax_assessment_year=2019",rows=10)
```

Get metadata for the street trees dataset.
``` r
get_cov_metadata("street-trees")
```

Count the number of cherry trees by neighbourhood.

``` r
aggregate_cov_data("street-trees",where = "common_name LIKE 'CHERRY'", group_by = "neighbourhood_name")
```

