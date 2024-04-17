# VancouvR

<!-- badges: start -->
[![CRAN_Status_Badge](http://www.r-pkg.org/badges/version/VancouvR)](https://cran.r-project.org/package=VancouvR)
[![CRAN_Downloads_Badge](https://cranlogs.r-pkg.org/badges/VancouvR)](https://cranlogs.r-pkg.org/badges/VancouvR)
[![R-CMD-check](https://github.com/mountainMath/VancouvR/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/mountainMath/VancouvR/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

<a href="https://mountainmath.github.io/VancouvR/index.html"><img src="https://raw.githubusercontent.com/mountainMath/VancouvR/master/images/VancouvR-sticker.png" alt="VancouvR logo" align="right" width = "25%" height = "25%"/></a>

`VancouvR` is an R wrapper around the City of Vancouver Open Data API. It allows transparent and reproducible access to the Vancouver Open Data Portal to facilitate data analysis and sharing of code.

The package caches downloaded data for the duration of the current session, so re-running code blocks will not result in repeated downloads. This speeds up the code, cuts down on unnecessary network traffic and reduces strain on the City of Vancouver Open Data infrastructure.


### Reference
[VancouverOpenData package reference](https://mountainmath.github.io/VancouvR/)

### Installing the package
To install the latest release version of `VancouvR` from CRAN use

``` r
install.packages("VancouvR")
```

The development version of `VancouvR` is available from [GitHub](https://github.com/mountainMath/VancouvR) via

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

### Examples

Get a list of datasets relating to properties

``` r
library(VancouvR)

search_cov_datasets("properties")
```

Get the first 10 records of the property tax report for 2019 tax year.

``` r
get_cov_data(dataset_id = "property-tax-report",where="tax_assessment_year='2021'",rows=10)
```

Get metadata for the street trees dataset.
``` r
get_cov_metadata("street-trees")
```

Count the number of cherry trees by neighbourhood.

``` r
aggregate_cov_data("street-trees",where = "common_name LIKE 'CHERRY'", group_by = "neighbourhood_name")
```

## Cite **VancouvR**

If you wish to cite VancouvR:

  von Bergmann, J. VancouvR: ccess the 'City of Vancouver' Open Data API. v0.1.8.


A BibTeX entry for LaTeX users is
```
  @Manual{VancouvR,
    author = {Jens {von Bergmann}},
    title = {VancouvR: Access the 'City of Vancouver' Open Data API,
    year = {2024},
    note = {R package version 0.1.8},
    url = {https://mountainmath.github.io/VancouvR/},
  }
```
