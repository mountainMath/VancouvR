# Record HTTP fixtures for the offline test suite.
#
# Run manually against the live portal after an API change:
#
#   source("data-raw/record-fixtures.R")
#
# Fixtures are stored as serialised `httr2` response objects, so the mocked
# `cov_get()` in tests/testthat/helper-cov-mock.R can hand them straight to
# `httr2::resp_body_json()` exactly as a live response would be. Requests are
# recorded without an API key, and the request -- which would carry one if the
# environment supplied it -- is dropped before saving.

library(httr2)

fixture_dir <- "tests/testthat/fixtures"
dir.create(fixture_dir, showWarnings = FALSE, recursive = TRUE)

base <- "https://opendata.vancouver.ca/api/explore/v2.1"

record <- function(name, path, ...) {
  message("Recording ", name)
  response <- request(paste0(base, path)) |>
    req_url_query(...) |>
    req_error(is_error = function(resp) FALSE) |>
    req_perform()
  # Never let a key reach disk, even if one leaks in from the environment.
  response$url <- sub("([?&])apikey=[^&]*", "\\1apikey=REDACTED", response$url)
  response$request <- NULL
  saveRDS(response, file.path(fixture_dir, paste0(name, ".rds")), compress = "xz")
  invisible(response)
}

# Catalogue --------------------------------------------------------------------
record("catalog-export", "/catalog/exports/csv", with_bom = "false")

# Field metadata ---------------------------------------------------------------
record("metadata-public-trees",        "/catalog/datasets/public-trees")
record("metadata-property-tax-report", "/catalog/datasets/property-tax-report")

# Records ----------------------------------------------------------------------
# public-trees is spatial, so get_cov_data() downloads it as FlatGeobuf;
# property-tax-report is not and exercises the CSV plus int/double casting path.
record("data-public-trees", "/catalog/datasets/public-trees/exports/fgb",
       select = "*", limit = 5)
record("data-public-trees-csv", "/catalog/datasets/public-trees/exports/csv",
       with_bom = "false", select = "*", limit = 5)
record("data-property-tax-report", "/catalog/datasets/property-tax-report/exports/csv",
       with_bom = "false", select = "*", limit = 5)

# Aggregations -----------------------------------------------------------------
record("aggregate-grouped", "/catalog/datasets/public-trees/exports/json",
       group_by = "genus_name", select = "count(*) as count")
record("aggregate-ungrouped", "/catalog/datasets/public-trees/records",
       limit = 1, select = "count(*) as total")

# Facets -----------------------------------------------------------------------
record("facets-public-trees", "/catalog/datasets/public-trees/facets",
       facet = "genus_name")
record("facets-catalog", "/catalog/facets")

# Error responses --------------------------------------------------------------
record("error-odsql", "/catalog/datasets/public-trees/exports/csv",
       select = "no_such_field")
record("error-not-found", "/catalog/datasets/does-not-exist")

message("Done. Fixture sizes:")
print(file.size(list.files(fixture_dir, full.names = TRUE)) |>
        stats::setNames(list.files(fixture_dir)))
