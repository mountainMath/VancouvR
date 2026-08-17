# Offline replay of recorded API responses.
#
# Every request the package makes goes through VancouvR:::cov_get(), so mocking
# that one binding is enough to run the whole stack without a network. Fixtures
# are serialised `httr2` responses recorded by data-raw/record-fixtures.R, so
# the code under test parses them exactly as it would a live response.

read_fixture <- function(name) {
  readRDS(test_path("fixtures", paste0(name, ".rds")))
}

# Serve fixtures for the duration of the calling test.
#
# `routes` is a named character vector mapping a regular expression matched
# against the request URL to a fixture name:
#
#   local_cov_mock(c("exports/csv" = "data-public-trees"))
#
# A request that matches no route is an error rather than a silent fallback, so
# a test that starts making an unexpected call fails loudly. Requested URLs are
# recorded in the returned environment so tests can assert on them.
local_cov_mock <- function(routes, env = parent.frame()) {
  calls <- new.env(parent = emptyenv())
  calls$urls <- character()
  calls$apikeys <- character()
  `%||%` <- function(x, y) if (is.null(x)) y else x

  # Tests must not pick up a real key from the developer's .Rprofile: it would
  # change the request URLs and the cache keys, and leak into test output.
  withr::local_options(VancouverOpenDataApiKey = NULL, .local_envir = env)

  local_mocked_bindings(
    cov_get = function(url, query = list(), apikey = NULL, ...) {
      # Match and assert on the full URL the request would have produced.
      url <- VancouvR:::cov_request(url, query, apikey)$url
      calls$urls <- c(calls$urls, url)
      calls$apikeys <- c(calls$apikeys, apikey %||% NA_character_)
      hits <- names(routes)[vapply(names(routes), grepl, logical(1), x = url)]
      if (length(hits) == 0) {
        stop("No fixture route matches URL:\n  ", url,
             "\nAvailable routes: ", paste(names(routes), collapse = ", "))
      }
      read_fixture(routes[[hits[1]]])
    },
    .package = "VancouvR",
    .env = env
  )

  calls
}

# Clear the session cache so a test always exercises the request path.
local_clean_cov_cache <- function(env = parent.frame()) {
  cached <- list.files(tempdir(), pattern = "^CoV_", full.names = TRUE)
  file.remove(cached)
  withr::defer(
    file.remove(list.files(tempdir(), pattern = "^CoV_", full.names = TRUE)),
    envir = env
  )
}
