# Changelog

## VancouvR 0.1.11

### Major changes

- migrate from the deprecated Explore API v2 to v2.1. The portal flags
  every v2 request with an `ods-explore-api-deprecation` response
  header.
- [`aggregate_cov_data()`](https://mountainmath.github.io/VancouvR/reference/aggregate_cov_data.md)
  no longer uses the `/aggregates` endpoint, which was removed in v2.1
  and now returns HTTP 410. Grouped queries are answered by the dataset
  export endpoint, so they are no longer capped at 100 groups; ungrouped
  queries use the records endpoint.

### Behaviour changes

- spatial datasets are downloaded as FlatGeobuf rather than as CSV with
  the geometry re-parsed from text. The geometry arrives with its
  coordinate reference system already set, and columns arrive typed by
  the portal instead of being read as character and cast afterwards.
  Because the FlatGeobuf export does not carry the raw geometry fields,
  such datasets now come back with a single `geometry` column and no
  longer with the `geom` and `geo_point_2d` text columns beside it. Set
  `cast_types = FALSE` to download the CSV instead.
- every function now fails gracefully: an unreachable portal, a refused
  request or a malformed query yields `NULL` and a warning rather than
  an error, so a script or a knitted document degrades instead of
  stopping. Code that relied on an error being thrown should test the
  result for `NULL`, or turn the warning back into an error:
  `tryCatch(get_cov_data("..."), cov_api_warning = function(w) stop(conditionMessage(w)))`.
- [`get_cov_data()`](https://mountainmath.github.io/VancouvR/reference/get_cov_data.md)
  returns the downloaded data even when the metadata lookup behind
  `cast_types = TRUE` fails; the columns are simply left as character.
- [`aggregate_cov_data()`](https://mountainmath.github.io/VancouvR/reference/aggregate_cov_data.md)
  now returns groups whose grouping key is empty. The old `/aggregates`
  endpoint omitted these, which silently dropped records: grouping
  `property-tax-report` by `tax_assessment_year`, for example, hid 6,009
  records that have no assessment year.

### New features

- [`get_cov_facets()`](https://mountainmath.github.io/VancouvR/reference/get_cov_facets.md)
  lists the values a facetted field takes, with record counts, making it
  easier to discover what a field contains before filtering on it.
- [`list_cov_facets()`](https://mountainmath.github.io/VancouvR/reference/list_cov_facets.md)
  does the same for the catalogue itself, listing the themes, keywords,
  data owners and data teams datasets are filed under, with the number
  of datasets in each. Its `features` facet identifies the 135 datasets
  that carry geographic records, and so come back as `sf` objects.
- [`list_cov_datasets()`](https://mountainmath.github.io/VancouvR/reference/list_cov_datasets.md)
  gained `refine` and `exclude`, so the catalogue can be filtered on
  those facet values, e.g. `refine = "theme:Sustainability"`.
- [`get_cov_data()`](https://mountainmath.github.io/VancouvR/reference/get_cov_data.md)
  gained `order_by`, `refine`, `exclude`, `use_labels` and `timezone`;
  [`aggregate_cov_data()`](https://mountainmath.github.io/VancouvR/reference/aggregate_cov_data.md)
  gained `order_by`, `refine`, `exclude` and `limit`. `refine` and
  `exclude` accept a character vector and are sent as repeated
  parameters.
- [`list_cov_datasets()`](https://mountainmath.github.io/VancouvR/reference/list_cov_datasets.md)
  gained a `where` argument, so the catalogue can be filtered by the
  portal instead of after download.
- the API key is now sent as an `Authorization: Apikey` header instead
  of a query parameter, so it no longer appears in request URLs, and
  therefore not in server logs, proxies, or error messages.
- requests that fail with HTTP 429 or a server error are retried with an
  exponential backoff, honouring the portal’s `Retry-After` header.
- [`get_cov_rate_limit()`](https://mountainmath.github.io/VancouvR/reference/get_cov_rate_limit.md)
  reports the daily request quota, and the package warns once per
  session when fewer than 5% of the allowance remain.
- [`get_cov_data()`](https://mountainmath.github.io/VancouvR/reference/get_cov_data.md)
  now returns an `sf` object for datasets whose only spatial field is a
  `geo_point_2d`, not just those with a `geo_shape`.
- requests identify themselves with a `VancouvR/<version>` user agent.

### Bug fixes

- [`search_cov_datasets()`](https://mountainmath.github.io/VancouvR/reference/search_cov_datasets.md)
  prints its list of similarly named datasets only when the list is
  non-empty. It previously tested the number of columns rather than the
  number of rows, so a search with no near matches printed an empty
  tibble alongside the warning.
- [`get_cov_data()`](https://mountainmath.github.io/VancouvR/reference/get_cov_data.md)
  warns about unrecognised arguments passed through `...` instead of
  ignoring them silently.
- [`get_cov_metadata()`](https://mountainmath.github.io/VancouvR/reference/get_cov_metadata.md)
  reads the field list from the top level of the response, where v2.1
  moved it from `dataset.fields`. Against v2.1 the old path returned no
  metadata, which in turn silently disabled column type casting and `sf`
  conversion in
  [`get_cov_data()`](https://mountainmath.github.io/VancouvR/reference/get_cov_data.md).
- [`get_cov_data()`](https://mountainmath.github.io/VancouvR/reference/get_cov_data.md)
  no longer fails outright when a date column cannot be parsed; it warns
  and returns the column as character, as was always intended.
- [`get_cov_data()`](https://mountainmath.github.io/VancouvR/reference/get_cov_data.md)
  sends the documented `limit` export parameter instead of the
  undocumented `rows` alias, and suppresses the byte order mark that
  v2.1 adds to CSV exports by default.
- failed requests report the portal’s `error_code` and message instead
  of printing the raw response body.
- [`get_cov_data()`](https://mountainmath.github.io/VancouvR/reference/get_cov_data.md)
  no longer turns values that overflow R’s 32-bit integer range into
  `NA`. The portal’s `int` type is 64-bit, and assessed land values
  exceed it; such columns are now returned as doubles rather than
  silently corrupted.
- [`get_cov_data()`](https://mountainmath.github.io/VancouvR/reference/get_cov_data.md)
  passes its `apikey` argument on to the metadata lookup behind
  `cast_types = TRUE`. That lookup previously fell back to the option,
  so an explicit key was ignored for it.

### Minor changes

- the package now uses `httr2` instead of `httr` for its HTTP requests.
  `httr` is superseded and no longer developed. Retries, query parameter
  encoding and the redaction of the API key from printed requests are
  now handled by `httr2` rather than by hand. The session cache of
  downloaded data is unchanged.
- the warning raised by a failed request is classed, so it can be caught
  selectively: `cov_api_warning` for any failure, `cov_unreachable` when
  the portal could not be reached, and one class per status code, e.g.
  `cov_http_404`.
- examples that fetch a bounded amount of data now run, rather than only
  being shown. The remaining `\dontrun{}` examples are those that
  download the whole catalogue or a whole dataset.
- the test suite now replays recorded API responses, so it runs offline
  and on CRAN instead of skipping. Fixtures are refreshed by
  `data-raw/record-fixtures.R`.
- dropped the `urltools` dependency; query parameters are now assembled
  by `httr2`, which also fixes the escaping of ODSQL expressions.
- added `inst/CITATION` so `citation("VancouvR")` reports the current
  version.

## VancouvR 0.1.10

### Bug fixes

- work around a malformed `content-security-policy` header sent by the
  open data portal that causes requests to fail with “Stream error in
  the HTTP/2 framing layer” on systems with a strict `nghttp2` build.
  Affected requests are now automatically retried over HTTP/1.1.

## VancouvR 0.1.9

CRAN release: 2026-03-04

### Minor changes

- better handling of cases where API does not have metadata
- improved documentation of functions and vignettes
- unit tests

## VancouvR 0.1.8

CRAN release: 2024-04-18

### Minor changes

- automatically determin if a dataset has a spatial component and
  transform to sf object if it does

## VancouvR 0.1.7

CRAN release: 2021-10-21

### Minor changes

- exclude examples from tests to guard against CoV API hiccups

## VancouvR 0.1.6

CRAN release: 2021-07-09

### Minor changes

- exclude examples from tests to guard against CoV API hiccups

## VancouvR 0.1.5

### Minor changes

- adapt to changes in format of CoV dataset list

## VancouvR 0.1.4

CRAN release: 2021-06-07

### Minor changes

- adapt to changes in CoV property-tax-report dataset
- remove vignette compilation from CRAN checks to avoid triggering CRAN
  issues when COV open data portal is offline
- add daily CRAN check GitHub action identify issues

## VancouvR 0.1.3

CRAN release: 2021-05-10

### Minor changes

- addapt to changes in CoV property-tax-report dataset

## VancouvR 0.1.2

CRAN release: 2021-01-13

### Minor changes

- add isoline vignette
- fix issue in demo vignette by adapting to City of Vancouver renaming
  and splitting of datasets

## VancouvR 0.1.1

CRAN release: 2019-11-15

### Major changes

- add functionality for aggregate API endjoint
- add functionality for metadata endpoint \### Minor changes
- add functionality for seraching datasets
- improve documentation

## VancouvR 0.1.0

### Major changes

- Initial release
