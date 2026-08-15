test_that("unqoute_strings removes surrounding double quotes", {
  expect_equal(VancouvR:::unqoute_strings('"hello"'), "hello")
  expect_equal(VancouvR:::unqoute_strings("hello"),   "hello")
  expect_equal(VancouvR:::unqoute_strings('""'),       "")
  expect_equal(VancouvR:::unqoute_strings('"'),        "")  # lone quote is stripped
})

test_that("unqoute_strings is vectorised", {
  expect_equal(
    VancouvR:::unqoute_strings(c('"a"', 'b', '"c"')),
    c("a", "b", "c")
  )
})

test_that("remove_na_cols drops all-NA columns", {
  df <- tibble::tibble(
    dataset_id   = c("a", "b"),
    title        = c("A", "B"),
    keyword      = c("k1", "k2"),
    `search-term` = c("s1", "s2"),
    all_na       = c(NA_character_, NA_character_),
    has_data     = c(1, NA)
  )
  result <- VancouvR:::remove_na_cols(df)
  expect_false("all_na"   %in% names(result))
  expect_true("has_data"  %in% names(result))
})

test_that("remove_na_cols always keeps main_cols even when all NA", {
  df <- tibble::tibble(
    dataset_id    = c(NA_character_, NA_character_),
    title         = c(NA_character_, NA_character_),
    keyword       = c(NA_character_, NA_character_),
    `search-term` = c(NA_character_, NA_character_),
    other_na      = c(NA_character_, NA_character_)
  )
  result <- VancouvR:::remove_na_cols(df)
  expect_true(all(c("dataset_id", "title", "keyword", "search-term") %in% names(result)))
  expect_false("other_na" %in% names(result))
})

test_that("remove_na_cols puts main_cols before non-main columns", {
  df <- tibble::tibble(
    has_data      = c(1, 2),
    `search-term` = c("s", "t"),
    keyword       = c("k", "l"),
    title         = c("A", "B"),
    dataset_id    = c("a", "b")
  )
  result <- VancouvR:::remove_na_cols(df)
  main_positions  <- which(names(result) %in% c("dataset_id", "title", "keyword", "search-term"))
  other_positions <- which(!names(result) %in% c("dataset_id", "title", "keyword", "search-term"))
  expect_true(max(main_positions) < min(other_positions))
})

# ---- cov_get HTTP/2 fallback -------------------------------------------------
# These use mocked bindings and make no network calls.

# Set the session flag to `value`, restoring the previous value on test exit.
set_http_flag <- function(value, env = parent.frame()) {
  st  <- VancouvR:::cov_state
  old <- st$force_http_1_1
  withr::defer(st$force_http_1_1 <- old, envir = env)
  st$force_http_1_1 <- value
}

test_that("cov_get passes through when the request succeeds", {
  set_http_flag(FALSE)
  local_mocked_bindings(GET = function(url, ...) list(ok = TRUE, n_config = ...length()),
                        .package = "VancouvR")
  result <- VancouvR:::cov_get("https://example.com")
  expect_true(result$ok)
  expect_equal(result$n_config, 0)               # no config passed on first try
  expect_false(VancouvR:::cov_state$force_http_1_1)
})

test_that("cov_get retries over HTTP/1.1 after an HTTP/2 framing error", {
  set_http_flag(FALSE)
  calls <- list()
  local_mocked_bindings(
    GET = function(url, ...) {
      calls[[length(calls) + 1L]] <<- list(...)
      if (length(calls) == 1L)
        stop("Stream error in the HTTP/2 framing layer [opendata.vancouver.ca]")
      list(ok = TRUE)
    },
    .package = "VancouvR"
  )
  result <- VancouvR:::cov_get("https://example.com")
  expect_true(result$ok)
  expect_length(calls, 2)                        # failed, then retried
  expect_length(calls[[1]], 0)                   # first try used defaults
  expect_equal(calls[[2]][[1]]$options$http_version, 2)  # retry forced HTTP/1.1
  expect_true(VancouvR:::cov_state$force_http_1_1)       # decision remembered
})

test_that("cov_get skips the failing attempt once the flag is set", {
  set_http_flag(TRUE)
  calls <- list()
  local_mocked_bindings(
    GET = function(url, ...) {
      calls[[length(calls) + 1L]] <<- list(...)
      list(ok = TRUE)
    },
    .package = "VancouvR"
  )
  expect_true(VancouvR:::cov_get("https://example.com")$ok)
  expect_length(calls, 1)                        # went straight to the retry path
  expect_equal(calls[[1]][[1]]$options$http_version, 2)
})

test_that("cov_get re-raises errors unrelated to HTTP/2", {
  set_http_flag(FALSE)
  n <- 0
  local_mocked_bindings(
    GET = function(url, ...) { n <<- n + 1L; stop("Could not resolve host: example.invalid") },
    .package = "VancouvR"
  )
  expect_error(VancouvR:::cov_get("https://example.invalid"), "Could not resolve host")
  expect_equal(n, 1)                             # not retried
  expect_false(VancouvR:::cov_state$force_http_1_1)
})
