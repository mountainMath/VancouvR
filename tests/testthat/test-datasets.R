# All tests in this file require a live connection to opendata.vancouver.ca.
# They are skipped automatically on CRAN.


# ---- list_cov_datasets -------------------------------------------------------

test_that("list_cov_datasets returns a tibble with expected columns", {
  skip_on_cran()
  result <- list_cov_datasets()
  expect_s3_class(result, "tbl_df")
  expect_true(all(c("dataset_id", "title") %in% names(result)))
  expect_gt(nrow(result), 0)
})

test_that("list_cov_datasets trim=FALSE keeps at least as many columns as trim=TRUE", {
  skip_on_cran()
  trimmed   <- list_cov_datasets(trim = TRUE,  refresh = TRUE)
  untrimmed <- list_cov_datasets(trim = FALSE, refresh = TRUE)
  expect_gte(ncol(untrimmed), ncol(trimmed))
})

# ---- search_cov_datasets -----------------------------------------------------

test_that("search_cov_datasets returns matching rows", {
  skip_on_cran()
  result <- search_cov_datasets("public-trees")
  expect_s3_class(result, "tbl_df")
  expect_gt(nrow(result), 0)
  expect_true(any(grepl("tree", result$title, ignore.case = TRUE) |
                  grepl("tree", result$dataset_id, ignore.case = TRUE)))
})

test_that("search_cov_datasets supports regular expressions", {
  skip_on_cran()
  result <- search_cov_datasets("parking.*(2017|2018|2019)")
  expect_s3_class(result, "tbl_df")
  expect_gt(nrow(result), 0)
})

test_that("search_cov_datasets warns when no datasets match", {
  skip_on_cran()
  expect_warning(
    search_cov_datasets("zzznomatchxxx99"),
    regexp = "No results found"
  )
})

# ---- get_cov_metadata --------------------------------------------------------

test_that("get_cov_metadata returns a tibble with the four expected columns", {
  skip_on_cran()
  result <- get_cov_metadata("public-trees")
  expect_s3_class(result, "tbl_df")
  expect_named(result, c("name", "type", "label", "description"))
  expect_gt(nrow(result), 0)
})

test_that("get_cov_metadata type column contains known type values", {
  skip_on_cran()
  result <- get_cov_metadata("public-trees")
  known_types <- c("text", "int", "double", "date", "geo_shape", "geo_point_2d")
  expect_true(any(result$type %in% known_types))
})

# ---- get_cov_data ------------------------------------------------------------

test_that("get_cov_data returns a tibble for a non-spatial dataset", {
  skip_on_cran()
  result <- get_cov_data("property-tax-report",
                         where = "tax_assessment_year='2024'",
                         rows = 5)
  expect_s3_class(result, "data.frame")
  expect_lte(nrow(result), 5)
})

test_that("get_cov_data rows argument limits result size", {
  skip_on_cran()
  result <- get_cov_data("property-tax-report",
                         where = "tax_assessment_year='2024'",
                         rows = 3)
  expect_lte(nrow(result), 3)
})

test_that("get_cov_data where argument filters results", {
  skip_on_cran()
  result <- get_cov_data("public-trees",
                         where = "genus_name = 'ACER'",
                         rows = 10)
  expect_gt(nrow(result), 0)
  expect_true(all(result$genus_name == "ACER"))
})

test_that("get_cov_data returns an sf object for a spatial dataset", {
  skip_on_cran()
  result <- get_cov_data("property-parcel-polygons", rows = 5)
  expect_s3_class(result, "sf")
  expect_true(!is.null(sf::st_geometry(result)))
})

test_that("get_cov_data cast_types=FALSE returns only character columns", {
  skip_on_cran()
  result <- get_cov_data("property-tax-report",
                         where = "tax_assessment_year='2024'",
                         rows = 5,
                         cast_types = FALSE)
  expect_s3_class(result, "tbl_df")
  col_types <- sapply(result, class)
  expect_true(all(col_types == "character"))
})

test_that("get_cov_data messages when reading from cache", {
  skip_on_cran()
  get_cov_data("public-trees",
               where = "genus_name = 'ACER'",
               rows = 5,
               refresh = TRUE)
  expect_message(
    get_cov_data("public-trees",
                 where = "genus_name = 'ACER'",
                 rows = 5),
    regexp = "Reading data from temporary cache"
  )
})

# ---- aggregate_cov_data ------------------------------------------------------

test_that("aggregate_cov_data returns a tibble", {
  skip_on_cran()
  result <- aggregate_cov_data("public-trees",
                                where = "common_name LIKE 'CHERRY'",
                                group_by = "genus_name")
  expect_s3_class(result, "tbl_df")
  expect_gt(nrow(result), 0)
})

test_that("aggregate_cov_data default select produces a 'count' column", {
  skip_on_cran()
  result <- aggregate_cov_data("public-trees",
                                where = "common_name LIKE 'CHERRY'",
                                group_by = "genus_name")
  expect_true("count" %in% names(result))
  expect_true(all(result$count > 0))
})

test_that("aggregate_cov_data respects custom select column alias", {
  skip_on_cran()
  result <- aggregate_cov_data("public-trees",
                                select = "count(*) as n",
                                group_by = "genus_name")
  expect_true("n" %in% names(result))
  expect_false("count" %in% names(result))
})

test_that("aggregate_cov_data without group_by returns a single row", {
  skip_on_cran()
  result <- aggregate_cov_data("public-trees",
                                select = "count(*) as total",
                                where = "common_name LIKE 'CHERRY'")
  expect_equal(nrow(result), 1)
  expect_true(result$total > 0)
})

test_that("aggregate_cov_data messages when reading from cache", {
  skip_on_cran()
  aggregate_cov_data("public-trees", group_by = "genus_name", refresh = TRUE)
  expect_message(
    aggregate_cov_data("public-trees", group_by = "genus_name"),
    regexp = "Reading data from temporary cache"
  )
})
