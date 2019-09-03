# VancouverOpenData

<!-- badges: start -->
<!-- badges: end -->

VancouverOpenData is an R wrapper around the City of Vancouver Open Data API.

You can install VancouverOpenData from [GitHub](https://) with:

``` r
remotes::install_github("mountainmath/VancouverOpenData")
```

## Example

Get a list of datasets relating to properties

``` r
library(VancouverOpenData)
## basic example code
list_cov_datasets() %>%
  filter(grepl("property",title,ignore.case = TRUE)) %>%
  select(dataset_id,title)
```

Get the first 10 records of the property tax report for 2019 tax year.

``` r
get_cov_data(dataset_id = "property-tax-report",where="tax_assessment_year=2019",rows=10)
```

