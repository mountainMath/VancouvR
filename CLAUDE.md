# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Package Overview

VancouvR is an R package that wraps the City of Vancouver Open Data API (`https://opendata.vancouver.ca/api/v2/`). It provides functions to list, search, and download datasets from the portal, with session-level caching via `tempdir()`.

## Common Commands

```r
# Document (regenerate man/ and NAMESPACE from roxygen2 comments)
devtools::document()

# Check the package (equivalent to R CMD check)
devtools::check()

# Run tests
devtools::test()

# Run a specific test file
testthat::test_file("tests/testthat/test-datasets.R")

# Install locally
devtools::install()

# Build pkgdown site
pkgdown::build_site()
```

## Architecture

**`R/helpers.R`** — Internal utilities: `main_cols` constant (priority columns for display), `unqoute_strings()`, `remove_na_cols()`.

**`R/datasets.R`** — All exported functions:
- `list_cov_datasets()` — fetches the full catalogue CSV, caches to `tempdir()`
- `search_cov_datasets()` — filters the catalogue by title/id/keyword using grep
- `get_cov_metadata()` — fetches field-level metadata for a dataset (JSON endpoint)
- `get_cov_data()` — downloads a dataset as CSV, caches by MD5 hash of parameters; when `cast_types=TRUE` uses metadata to type-cast columns and auto-converts geo_shape columns to an `sf` object
- `aggregate_cov_data()` — hits the `/aggregates` endpoint for server-side group-by queries

**Caching pattern:** All functions cache results as `.rda` files in `tempdir()`. Cache is keyed by an MD5 digest of the request parameters. Pass `refresh=TRUE` to bypass.

**API key:** Read from `getOption("VancouverOpenDataApiKey")`. Users set this in `.Rprofile`. Smaller datasets work without a key; larger ones require one.

**Spatial data:** `get_cov_data()` automatically detects `geo_shape` fields via metadata and converts to `sf` using `geojsonsf::geojson_sf()`, falling back to a plain tibble with a warning if conversion fails.

## Documentation

- Docs are generated with roxygen2 (`devtools::document()`). Edit comments in `R/datasets.R`; do not edit `man/` or `NAMESPACE` directly.
- Vignettes are in `vignettes/` (Demo.Rmd, Isolines.Rmd) and built via knitr. They are excluded from CRAN checks (`\dontrun{}` wrappers on examples) to avoid failures when the CoV API is offline.
- pkgdown site is published at `https://mountainmath.github.io/VancouvR/`.

## Special considerations

All @example code in the package documentation that makes API calls has to be wrapped with `\downtrun{}` to avoid CRAN check failures when the CoV API is offline. This means that examples will not be run during testing, so it is important to have good unit test coverage in `tests/testthat/` to catch issues with API interactions. Tests involving API calls are skipped on CRAN too.
