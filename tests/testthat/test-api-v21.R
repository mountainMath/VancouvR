# Offline tests against recorded v2.1 responses. These make no network calls and
# so also run on CRAN. See helper-cov-mock.R and data-raw/record-fixtures.R.

# ---- API version -------------------------------------------------------------

test_that("requests target the v2.1 Explore API", {
  local_clean_cov_cache()
  calls <- local_cov_mock(c("public-trees$" = "metadata-public-trees"))
  get_cov_metadata("public-trees")

  expect_match(calls$urls[1], "/api/explore/v2.1/", fixed = TRUE)
  expect_false(grepl("/api/v2/", calls$urls[1], fixed = TRUE))
})

test_that("no request uses the /aggregates endpoint removed in v2.1", {
  local_clean_cov_cache()
  calls <- local_cov_mock(c("exports/json" = "aggregate-grouped",
                            "records"      = "aggregate-ungrouped"))
  aggregate_cov_data("public-trees", group_by = "genus_name")
  aggregate_cov_data("public-trees", select = "count(*) as total")

  expect_length(calls$urls, 2)
  expect_false(any(grepl("/aggregates", calls$urls, fixed = TRUE)))
})

# ---- get_cov_metadata --------------------------------------------------------

test_that("get_cov_metadata reads the flattened v2.1 field list", {
  local_clean_cov_cache()
  local_cov_mock(c("public-trees$" = "metadata-public-trees"))
  result <- get_cov_metadata("public-trees")

  expect_named(result, c("name", "type", "label", "description"))
  expect_gt(nrow(result), 0)
  expect_true(all(c("genus_name", "height_m", "geom") %in% result$name))
  expect_equal(result$type[result$name == "height_m"], "double")
  expect_equal(result$type[result$name == "geom"], "geo_shape")
})

test_that("get_cov_metadata returns the documented shape when there are no fields", {
  local_clean_cov_cache()
  empty <- httr2::response(
    status_code = 200L,
    headers = list(`content-type` = "application/json"),
    body = charToRaw('{"dataset_id": "empty", "fields": []}'))
  local_mocked_bindings(cov_get = function(url, ...) empty, .package = "VancouvR")

  result <- get_cov_metadata("empty-dataset")
  expect_named(result, c("name", "type", "label", "description"))
  expect_equal(nrow(result), 0)
})

# ---- get_cov_data ------------------------------------------------------------

test_that("get_cov_data sends the documented limit parameter, not rows", {
  local_clean_cov_cache()
  calls <- local_cov_mock(c("exports/fgb"   = "data-public-trees",
                            "public-trees$" = "metadata-public-trees"))
  get_cov_data("public-trees", rows = 5)

  export_url <- calls$urls[grepl("exports/", calls$urls)]
  expect_match(export_url, "limit=5")
  expect_false(grepl("rows=", export_url, fixed = TRUE))
})

test_that("get_cov_data suppresses the byte order mark v2.1 adds by default", {
  local_clean_cov_cache()
  calls <- local_cov_mock(c("exports/csv"          = "data-property-tax-report",
                            "property-tax-report$" = "metadata-property-tax-report"))
  result <- get_cov_data("property-tax-report", rows = 5)

  expect_match(calls$urls[grepl("exports/csv", calls$urls)], "with_bom=false")
  expect_false(any(grepl("^﻿", names(result))))
})

test_that("get_cov_data casts column types from metadata", {
  local_clean_cov_cache()
  local_cov_mock(c("exports/csv"           = "data-property-tax-report",
                   "property-tax-report$"  = "metadata-property-tax-report"))
  result <- get_cov_data("property-tax-report", rows = 5)

  meta <- read_fixture("metadata-property-tax-report") |> httr2::resp_body_json()
  types <- stats::setNames(vapply(meta$fields, `[[`, "", "type"),
                           vapply(meta$fields, `[[`, "", "name"))
  int_col <- intersect(names(types)[types == "int"], names(result))[1]
  dbl_col <- intersect(names(types)[types == "double"], names(result))[1]

  expect_type(result[[int_col]], "integer")
  expect_type(result[[dbl_col]], "double")
})

test_that("get_cov_data downloads a spatial dataset as FlatGeobuf", {
  local_clean_cov_cache()
  calls <- local_cov_mock(c("exports/fgb"   = "data-public-trees",
                            "public-trees$" = "metadata-public-trees"))
  result <- get_cov_data("public-trees", rows = 5)

  expect_match(calls$urls[grepl("exports/", calls$urls)], "/exports/fgb")
  expect_s3_class(result, "sf")
  expect_equal(sf::st_crs(result)$epsg, 4326)
  # FlatGeobuf carries the geometry itself, so the raw text fields the CSV
  # export exposes are not part of the result.
  expect_true("geometry" %in% names(result))
  expect_false(any(c("geom", "geo_point_2d", "...link") %in% names(result)))
})

test_that("a spatial download is typed by the server and cast from metadata", {
  local_clean_cov_cache()
  local_cov_mock(c("exports/fgb"   = "data-public-trees",
                   "public-trees$" = "metadata-public-trees"))
  result <- get_cov_data("public-trees", rows = 5)

  # The CSV path read everything as character and cast afterwards; FlatGeobuf
  # arrives typed, and metadata still normalises int and date.
  expect_type(result$asset_id, "integer")
  expect_type(result$height_m, "double")
  expect_s3_class(result$date_planted, "Date")
})

test_that("get_cov_data falls back to CSV when FlatGeobuf cannot be read", {
  local_clean_cov_cache()
  calls <- local_cov_mock(c("exports/fgb"   = "data-public-trees",
                            "exports/csv"   = "data-public-trees-csv",
                            "public-trees$" = "metadata-public-trees"))
  local_mocked_bindings(
    cov_read_fgb = function(response) stop("unreadable"),
    .package = "VancouvR"
  )
  expect_warning(result <- get_cov_data("public-trees", rows = 5), "FlatGeobuf")

  expect_true(any(grepl("/exports/fgb", calls$urls)))
  expect_true(any(grepl("/exports/csv", calls$urls)))
  # The CSV path rebuilds the geometry from the geo_shape text column.
  expect_s3_class(result, "sf")
  expect_equal(sf::st_crs(result)$epsg, 4326)
})

test_that("a spatial and a non-spatial read of the same query do not share a cache entry", {
  local_clean_cov_cache()
  local_cov_mock(c("exports/fgb"   = "data-public-trees",
                   "exports/csv"   = "data-public-trees-csv",
                   "public-trees$" = "metadata-public-trees"))

  expect_s3_class(get_cov_data("public-trees", rows = 5), "sf")
  expect_false(inherits(get_cov_data("public-trees", rows = 5, cast_types = FALSE), "sf"))
  expect_length(list.files(tempdir(), pattern = "^CoV_data_"), 2)
})

test_that("get_cov_data cast_types=FALSE skips metadata entirely", {
  local_clean_cov_cache()
  calls <- local_cov_mock(c("exports/csv" = "data-public-trees-csv"))
  result <- get_cov_data("public-trees", rows = 5, cast_types = FALSE)

  expect_length(calls$urls, 1)          # no metadata lookup
  expect_s3_class(result, "tbl_df")
  expect_true(all(vapply(result, is.character, logical(1))))
})

# ---- aggregate_cov_data ------------------------------------------------------

test_that("aggregate_cov_data uses the export endpoint for grouped queries", {
  local_clean_cov_cache()
  calls <- local_cov_mock(c("exports/json" = "aggregate-grouped"))
  result <- aggregate_cov_data("public-trees", group_by = "genus_name")

  expect_match(calls$urls[1], "/exports/json")
  expect_match(calls$urls[1], "group_by=genus_name")
  expect_named(result, c("genus_name", "count"))
  expect_gt(nrow(result), 100)          # past the 100-record cap on /records
})

test_that("aggregate_cov_data preserves numeric types from the JSON response", {
  local_clean_cov_cache()
  local_cov_mock(c("exports/json" = "aggregate-grouped"))
  result <- aggregate_cov_data("public-trees", group_by = "genus_name")

  expect_true(is.numeric(result$count))
  expect_true(all(result$count > 0))
})

test_that("aggregate_cov_data keeps groups whose key is JSON null", {
  local_clean_cov_cache()
  local_cov_mock(c("exports/json" = "aggregate-grouped"))
  result <- aggregate_cov_data("public-trees", group_by = "genus_name")

  # The recorded response opens with {"genus_name": null, "count": 41}; a naive
  # as_tibble() would drop the column and lose the row's group key.
  expect_true(any(is.na(result$genus_name)))
  expect_equal(nrow(result), length(httr2::resp_body_json(read_fixture("aggregate-grouped"))))
})

test_that("aggregate_cov_data returns a single row when there is no group_by", {
  local_clean_cov_cache()
  calls <- local_cov_mock(c("records" = "aggregate-ungrouped"))
  result <- aggregate_cov_data("public-trees", select = "count(*) as total")

  # Both /records and /exports repeat an ungrouped aggregate once per record,
  # so the request has to cap itself at one row.
  expect_match(calls$urls[1], "/records")
  expect_match(calls$urls[1], "limit=1")
  expect_equal(nrow(result), 1)
  expect_named(result, "total")
  expect_true(is.numeric(result$total))
})

# ---- list_cov_datasets -------------------------------------------------------

test_that("list_cov_datasets parses the catalogue export", {
  local_clean_cov_cache()
  calls <- local_cov_mock(c("catalog/exports/csv" = "catalog-export"))
  result <- list_cov_datasets()

  expect_match(calls$urls[1], "/api/explore/v2.1/catalog/exports/csv", fixed = TRUE)
  expect_s3_class(result, "tbl_df")
  expect_gt(nrow(result), 0)
  expect_equal(names(result)[1:4], c("dataset_id", "title", "keyword", "search-term"))
  expect_false(any(is.na(result$dataset_id)))
})

test_that("search_cov_datasets filters the parsed catalogue", {
  local_clean_cov_cache()
  local_cov_mock(c("catalog/exports/csv" = "catalog-export"))

  result <- search_cov_datasets("tree")
  expect_gt(nrow(result), 0)
  expect_true(all(grepl("tree", result$title, ignore.case = TRUE) |
                  grepl("tree", result$dataset_id, ignore.case = TRUE) |
                  grepl("tree", result$keyword, ignore.case = TRUE) |
                  grepl("tree", result$`search-term`, ignore.case = TRUE)))
})

# ---- error handling ----------------------------------------------------------

test_that("an ODSQL error surfaces the portal's error code and message", {
  local_clean_cov_cache()
  local_cov_mock(c("exports/csv" = "error-odsql"))

  expect_warning(result <- get_cov_data("public-trees", select = "no_such_field",
                                        cast_types = FALSE),
                 "ODSQLError")
  expect_null(result)
})

test_that("a missing dataset reports its status code", {
  local_clean_cov_cache()
  local_cov_mock(c("datasets/" = "error-not-found"))

  expect_warning(result <- get_cov_metadata("does-not-exist"), "404")
  expect_null(result)
})

test_that("every exported function returns NULL rather than failing", {
  local_clean_cov_cache()
  local_cov_mock(c("catalog/exports/csv" = "error-not-found",
                   "catalog/facets"      = "error-not-found",
                   "facets"              = "error-not-found",
                   "exports/csv"         = "error-odsql",
                   "exports/json"        = "error-not-found",
                   "records"             = "error-not-found",
                   "datasets/"           = "error-not-found"))

  expect_null(suppressWarnings(list_cov_datasets()))
  expect_null(suppressWarnings(list_cov_facets()))
  expect_null(suppressWarnings(search_cov_datasets("trees")))
  expect_null(suppressWarnings(get_cov_metadata("public-trees")))
  expect_null(suppressWarnings(get_cov_facets("public-trees")))
  expect_null(suppressWarnings(get_cov_data("public-trees")))
  expect_null(suppressWarnings(aggregate_cov_data("public-trees", group_by = "genus_name")))
  expect_null(suppressWarnings(aggregate_cov_data("public-trees")))
})

test_that("a search whose catalogue fetch failed warns only about the failure", {
  local_clean_cov_cache()
  local_cov_mock(c("catalog/exports/csv" = "error-not-found"))

  # Not the "No results found" warning: there was no catalogue to search.
  expect_warning(search_cov_datasets("trees"), "404")
})

test_that("a failed request does not write a cache entry", {
  local_clean_cov_cache()
  local_cov_mock(c("exports/csv" = "error-odsql"))

  suppressWarnings(get_cov_data("public-trees", select = "no_such_field",
                                cast_types = FALSE))
  expect_length(list.files(tempdir(), pattern = "^CoV_data_"), 0)
})

test_that("data is still returned when the metadata lookup fails", {
  local_clean_cov_cache()
  local_cov_mock(c("exports/csv"   = "data-public-trees-csv",
                   "public-trees$" = "error-not-found"))

  expect_warning(result <- get_cov_data("public-trees", rows = 5), "404")
  # Uncast, but the download is not thrown away.
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 5)
  expect_true(all(vapply(result, is.character, logical(1))))
})

# ---- query parameters --------------------------------------------------------

test_that("get_cov_data forwards the ODSQL and facet parameters", {
  local_clean_cov_cache()
  calls <- local_cov_mock(c("exports/csv" = "data-public-trees-csv"))
  get_cov_data("public-trees", where = "height_m > 20", order_by = "height_m DESC",
               refine = "genus_name:ACER", exclude = "species_name:RUBRUM",
               timezone = "America/Vancouver", rows = 5, cast_types = FALSE)

  url <- calls$urls[1]
  expect_match(url, "where=height_m%20%3E%2020")
  expect_match(url, "order_by=height_m%20DESC")
  expect_match(url, "refine=genus_name%3AACER")
  expect_match(url, "exclude=species_name%3ARUBRUM")
  expect_match(url, "timezone=America%2FVancouver")
})

test_that("repeatable parameters are sent once per value", {
  local_clean_cov_cache()
  calls <- local_cov_mock(c("exports/csv" = "data-public-trees-csv"))
  get_cov_data("public-trees", refine = c("genus_name:ACER", "species_name:RUBRUM"),
               cast_types = FALSE)

  # The API reads repeated `refine=` parameters, not one comma-joined value.
  expect_length(gregexpr("refine=", calls$urls[1], fixed = TRUE)[[1]], 2)
  expect_false(grepl("ACER,", calls$urls[1], fixed = TRUE))
})

test_that("use_labels turns off type casting rather than failing", {
  local_clean_cov_cache()
  calls <- local_cov_mock(c("exports/csv" = "data-public-trees-csv"))
  result <- get_cov_data("public-trees", use_labels = TRUE)

  expect_match(calls$urls[1], "use_labels=true")
  expect_length(calls$urls, 1)             # no metadata lookup
  expect_s3_class(result, "tbl_df")
  expect_false(inherits(result, "sf"))
})

test_that("use_labels warns when type casting was asked for explicitly", {
  local_clean_cov_cache()
  local_cov_mock(c("exports/csv" = "data-public-trees-csv"))
  expect_warning(get_cov_data("public-trees", use_labels = TRUE, cast_types = TRUE),
                 "cast_types")
})

test_that("aggregate_cov_data forwards ordering and group limits", {
  local_clean_cov_cache()
  calls <- local_cov_mock(c("exports/json" = "aggregate-grouped"))
  aggregate_cov_data("public-trees", group_by = "genus_name",
                     order_by = "count DESC", limit = 10)

  expect_match(calls$urls[1], "order_by=count%20DESC")
  expect_match(calls$urls[1], "limit=10")
})

test_that("list_cov_datasets can filter the catalogue server-side", {
  local_clean_cov_cache()
  calls <- local_cov_mock(c("catalog/exports/csv" = "catalog-export"))
  list_cov_datasets(where = "search(title, 'tree')")

  expect_match(calls$urls[1], "where=search")
  # Filtered and unfiltered catalogues must not share a cache entry.
  expect_length(list.files(tempdir(), pattern = "^CoV_data_catalog"), 1)
  list_cov_datasets()
  expect_length(list.files(tempdir(), pattern = "^CoV_data_catalog"), 2)
})

# ---- get_cov_facets ----------------------------------------------------------

test_that("get_cov_facets returns one row per facet value", {
  local_clean_cov_cache()
  calls <- local_cov_mock(c("facets" = "facets-public-trees"))
  result <- get_cov_facets("public-trees", facet = "genus_name")

  expect_match(calls$urls[1], "/facets")
  expect_match(calls$urls[1], "facet=genus_name")
  expect_named(result, c("facet", "value", "count"))
  expect_gt(nrow(result), 0)
  expect_equal(unique(result$facet), "genus_name")
  expect_type(result$count, "integer")
  expect_true(all(result$count > 0))
})

test_that("get_cov_facets caches per query", {
  local_clean_cov_cache()
  calls <- local_cov_mock(c("facets" = "facets-public-trees"))
  get_cov_facets("public-trees", facet = "genus_name")
  get_cov_facets("public-trees", facet = "genus_name")
  expect_length(calls$urls, 1)

  get_cov_facets("public-trees", facet = "genus_name", where = "height_m > 20")
  expect_length(calls$urls, 2)
})

# ---- list_cov_facets ---------------------------------------------------------

test_that("list_cov_facets returns one row per catalogue facet value", {
  local_clean_cov_cache()
  calls <- local_cov_mock(c("catalog/facets" = "facets-catalog"))
  result <- list_cov_facets()

  expect_match(calls$urls[1], "/api/explore/v2.1/catalog/facets", fixed = TRUE)
  expect_named(result, c("facet", "value", "count"))
  expect_true(all(c("theme", "keyword", "features") %in% result$facet))
  expect_type(result$count, "integer")
  expect_true(all(result$count > 0))
})

test_that("list_cov_facets reports the geo feature that routes spatial downloads", {
  local_clean_cov_cache()
  local_cov_mock(c("catalog/facets" = "facets-catalog"))
  geo <- list_cov_facets() %>%
    dplyr::filter(.data$facet == "features", .data$value == "geo")

  # The datasets get_cov_data() fetches as FlatGeobuf are discoverable up front.
  expect_equal(nrow(geo), 1)
  expect_gt(geo$count, 0)
})

test_that("list_cov_facets forwards its query and caches per query", {
  local_clean_cov_cache()
  calls <- local_cov_mock(c("catalog/facets" = "facets-catalog"))
  list_cov_facets(facet = "theme")
  list_cov_facets(facet = "theme")
  expect_match(calls$urls[1], "facet=theme")
  expect_length(calls$urls, 1)

  list_cov_facets(facet = "theme", refine = "features:geo")
  expect_match(calls$urls[2], "refine=features%3Ageo")
  expect_length(calls$urls, 2)
})

test_that("list_cov_datasets sends catalogue refine and exclude filters", {
  local_clean_cov_cache()
  calls <- local_cov_mock(c("catalog/exports/csv" = "catalog-export"))
  list_cov_datasets(refine = "theme:Sustainability")
  list_cov_datasets(refine = c("theme:Sustainability", "keyword:water"),
                    exclude = "features:geo")

  expect_match(calls$urls[1], "refine=theme%3ASustainability")
  # Repeated parameters rather than one comma-joined value.
  expect_length(gregexpr("refine=", calls$urls[2], fixed = TRUE)[[1]], 2)
  expect_match(calls$urls[2], "exclude=features%3Ageo")
  # Each distinct filter gets its own cache entry.
  expect_length(list.files(tempdir(), pattern = "^CoV_data_catalog"), 2)
})
