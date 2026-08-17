# Tests for the request layer: how requests are built, the HTTP/2 fallback, the
# retry policy, rate limits and authentication. No network calls.

# Set the session flag to `value`, restoring the previous value on test exit.
set_http_flag <- function(value, env = parent.frame()) {
  st  <- VancouvR:::cov_state
  old <- st$force_http_1_1
  withr::defer(st$force_http_1_1 <- old, envir = env)
  st$force_http_1_1 <- value
}

# Reset the recorded quota and the once-per-session warning flag.
reset_rate_limit <- function(env = parent.frame()) {
  st <- VancouvR:::cov_state
  old <- list(rate_limit = st$rate_limit, warned = st$warned_rate_limit)
  withr::defer({
    st$rate_limit <- old$rate_limit
    st$warned_rate_limit <- old$warned
  }, envir = env)
  st$rate_limit <- NULL
  st$warned_rate_limit <- FALSE
}

# A response with no body, for tests that only care about status and headers.
fake_response <- function(status = 200L, headers = list()) {
  httr2::response(status_code = status, headers = headers)
}

# The condition httr2 raises when the transport itself fails. The diagnostic
# sits on the parent, which is where the HTTP/2 wording appears in the wild.
transport_failure <- function(detail) {
  rlang::abort("Failed to perform HTTP request.",
               class = c("httr2_failure", "httr2_error"),
               parent = rlang::error_cnd(message = detail))
}

# Did the request force HTTP/1.1?
forced_http_1_1 <- function(req) {
  isTRUE(req$options$http_version == VancouvR:::curl_http_version_1_1)
}

# ---- building the request ----------------------------------------------------

test_that("cov_request puts the query in the URL", {
  set_http_flag(FALSE)
  req <- VancouvR:::cov_request("https://example.com/records",
                                list(select = "*", where = "height_m > 20"))

  expect_match(req$url, "^https://example\\.com/records\\?")
  expect_match(req$url, "select=%2A")
  expect_match(req$url, "where=height_m%20%3E%2020")
})

test_that("cov_request drops unset parameters", {
  set_http_flag(FALSE)
  req <- VancouvR:::cov_request("https://example.com",
                                list(select = "*", where = NULL, limit = NULL))
  expect_match(req$url, "select=%2A")
  expect_false(grepl("where", req$url, fixed = TRUE))
  expect_false(grepl("limit", req$url, fixed = TRUE))
})

test_that("cov_request repeats a parameter given several values", {
  set_http_flag(FALSE)
  req <- VancouvR:::cov_request("https://example.com",
                                list(refine = c("genus_name:ACER", "height_m:20")))

  # The API reads repeated `refine=`; a comma-joined value would be one literal.
  expect_length(gregexpr("refine=", req$url, fixed = TRUE)[[1]], 2)
  expect_match(req$url, "refine=genus_name%3AACER")
  expect_match(req$url, "refine=height_m%3A20")
})

test_that("requests identify the package with a user agent", {
  set_http_flag(FALSE)
  req <- VancouvR:::cov_request("https://example.com")

  expect_match(req$options$useragent, "^VancouvR/[0-9.]+ ")
  expect_match(req$options$useragent, "github.com/mountainMath/VancouvR", fixed = TRUE)
})

test_that("the API key travels in a header, never in the URL", {
  set_http_flag(FALSE)
  req <- VancouvR:::cov_request("https://example.com", list(select = "*"), "secret-key")

  expect_equal(httr2::req_get_headers(req, "reveal")$Authorization, "Apikey secret-key")
  expect_false(grepl("secret-key", req$url, fixed = TRUE))
  # The key is marked as a secret, so it stays out of anything httr2 prints.
  expect_equal(httr2::req_get_headers(req, "redact")$Authorization, "<REDACTED>")
  expect_false(any(grepl("secret-key", capture.output(print(req)), fixed = TRUE)))
})

test_that("no Authorization header is sent without a key", {
  set_http_flag(FALSE)
  no_key <- VancouvR:::cov_request("https://example.com")
  empty_key <- VancouvR:::cov_request("https://example.com", list(), "")
  expect_null(httr2::req_get_headers(no_key, "reveal")$Authorization)
  expect_null(httr2::req_get_headers(empty_key, "reveal")$Authorization)
})

test_that("error responses are handed back rather than thrown by httr2", {
  set_http_flag(FALSE)
  # cov_fetch() turns them into a warning, so that is where the decision lives.
  is_error <- VancouvR:::cov_request("https://example.com")$policies$error_is_error
  expect_false(is_error(fake_response(404L)))
})

# ---- retry policy ------------------------------------------------------------

test_that("the request carries a retry policy", {
  set_http_flag(FALSE)
  req <- VancouvR:::cov_request("https://example.com", max_tries = 5)
  expect_equal(req$policies$retry_max_tries, 5)
  expect_identical(req$policies$retry_is_transient, VancouvR:::cov_is_transient)
})

test_that("rate limiting and server errors count as transient, client errors do not", {
  expect_true(VancouvR:::cov_is_transient(fake_response(429L)))
  expect_true(VancouvR:::cov_is_transient(fake_response(500L)))
  expect_true(VancouvR:::cov_is_transient(fake_response(502L)))
  expect_true(VancouvR:::cov_is_transient(fake_response(503L)))
  expect_false(VancouvR:::cov_is_transient(fake_response(200L)))
  expect_false(VancouvR:::cov_is_transient(fake_response(400L)))
  expect_false(VancouvR:::cov_is_transient(fake_response(404L)))
})

# ---- HTTP/2 fallback ---------------------------------------------------------

test_that("cov_get passes through when the request succeeds", {
  set_http_flag(FALSE); reset_rate_limit()
  reqs <- list()
  local_mocked_bindings(
    cov_perform = function(req) { reqs[[length(reqs) + 1L]] <<- req; fake_response() },
    .package = "VancouvR"
  )
  expect_s3_class(VancouvR:::cov_get("https://example.com"), "httr2_response")
  expect_length(reqs, 1)
  expect_false(forced_http_1_1(reqs[[1]]))
  expect_false(VancouvR:::cov_state$force_http_1_1)
})

test_that("cov_get retries over HTTP/1.1 after an HTTP/2 framing error", {
  set_http_flag(FALSE); reset_rate_limit()
  reqs <- list()
  local_mocked_bindings(
    cov_perform = function(req) {
      reqs[[length(reqs) + 1L]] <<- req
      if (length(reqs) == 1L)
        transport_failure("Stream error in the HTTP/2 framing layer [opendata.vancouver.ca]")
      fake_response()
    },
    .package = "VancouvR"
  )
  expect_s3_class(VancouvR:::cov_get("https://example.com"), "httr2_response")
  expect_length(reqs, 2)
  expect_false(forced_http_1_1(reqs[[1]]))         # first try used defaults
  expect_true(forced_http_1_1(reqs[[2]]))          # retry forced HTTP/1.1
  expect_true(VancouvR:::cov_state$force_http_1_1) # decision remembered
})

test_that("cov_get skips the failing attempt once the flag is set", {
  set_http_flag(TRUE); reset_rate_limit()
  reqs <- list()
  local_mocked_bindings(
    cov_perform = function(req) { reqs[[length(reqs) + 1L]] <<- req; fake_response() },
    .package = "VancouvR"
  )
  VancouvR:::cov_get("https://example.com")
  expect_length(reqs, 1)
  expect_true(forced_http_1_1(reqs[[1]]))
})

test_that("cov_get re-raises transport failures unrelated to HTTP/2", {
  set_http_flag(FALSE); reset_rate_limit()
  n <- 0
  local_mocked_bindings(
    cov_perform = function(req) {
      n <<- n + 1L
      transport_failure("Could not resolve host: example.invalid")
    },
    .package = "VancouvR"
  )
  expect_error(VancouvR:::cov_get("https://example.invalid"), "Could not resolve host")
  expect_equal(n, 1)                                # not retried
  expect_false(VancouvR:::cov_state$force_http_1_1)
})

# ---- failing gracefully ------------------------------------------------------

test_that("cov_fetch passes a successful response through", {
  set_http_flag(FALSE); reset_rate_limit()
  resp <- fake_response(200L)
  local_mocked_bindings(cov_perform = function(req) resp, .package = "VancouvR")

  expect_silent(result <- VancouvR:::cov_fetch("https://example.com"))
  expect_identical(result, resp)
})

test_that("a refused request warns and returns NULL instead of erroring", {
  set_http_flag(FALSE); reset_rate_limit()
  resp <- httr2::response(
    status_code = 400L,
    headers = list(`content-type` = "application/json"),
    body = charToRaw('{"error_code": "ODSQLError", "message": "no such field"}'))
  local_mocked_bindings(cov_perform = function(req) resp, .package = "VancouvR")

  expect_warning(result <- VancouvR:::cov_fetch("https://example.com"), "ODSQLError")
  expect_null(result)
  expect_warning(VancouvR:::cov_fetch("https://example.com"), "no such field")
  # Classed, so callers can single it out or escalate it back into an error.
  expect_warning(VancouvR:::cov_fetch("https://example.com"), class = "cov_api_warning")
  expect_warning(VancouvR:::cov_fetch("https://example.com"), class = "cov_http_400")
})

test_that("a failure still reports its status without a usable body", {
  set_http_flag(FALSE); reset_rate_limit()
  resp <- httr2::response(status_code = 503L, body = charToRaw("<html>nope</html>"))
  local_mocked_bindings(cov_perform = function(req) resp, .package = "VancouvR")

  expect_warning(result <- VancouvR:::cov_fetch("https://example.com"), "503")
  expect_null(result)
  expect_warning(VancouvR:::cov_fetch("https://example.com"), class = "cov_http_503")
})

test_that("an unreachable portal warns and returns NULL", {
  set_http_flag(FALSE); reset_rate_limit()
  local_mocked_bindings(
    cov_perform = function(req) transport_failure("Could not resolve host: example.invalid"),
    .package = "VancouvR"
  )

  expect_warning(result <- VancouvR:::cov_fetch("https://example.invalid"),
                 "Could not reach")
  expect_null(result)
  expect_warning(VancouvR:::cov_fetch("https://example.invalid"),
                 "Could not resolve host")
  expect_warning(VancouvR:::cov_fetch("https://example.invalid"),
                 class = "cov_unreachable")
})

test_that("the warning can be escalated back into an error", {
  set_http_flag(FALSE); reset_rate_limit()
  local_mocked_bindings(cov_perform = function(req) fake_response(404L),
                        .package = "VancouvR")

  expect_error(
    tryCatch(VancouvR:::cov_fetch("https://example.com"),
             cov_api_warning = function(w) stop(conditionMessage(w))),
    "404")
})

# ---- rate limit --------------------------------------------------------------

test_that("get_cov_rate_limit reports the quota from the last response", {
  set_http_flag(FALSE); reset_rate_limit()
  expect_null(get_cov_rate_limit())

  local_mocked_bindings(
    cov_perform = function(req) fake_response(200L, list(
      `x-ratelimit-limit` = "15000",
      `x-ratelimit-remaining` = "14981",
      `x-ratelimit-reset` = "2026-08-17 00:00:00+00:00")),
    .package = "VancouvR"
  )
  VancouvR:::cov_get("https://example.com")

  quota <- get_cov_rate_limit()
  expect_s3_class(quota, "tbl_df")
  expect_equal(quota$limit, 15000L)
  expect_equal(quota$remaining, 14981L)
  expect_equal(quota$reset, "2026-08-17 00:00:00+00:00")
})

test_that("a nearly exhausted quota warns once per session", {
  set_http_flag(FALSE); reset_rate_limit()
  local_mocked_bindings(
    cov_perform = function(req) fake_response(200L, list(
      `x-ratelimit-limit` = "15000", `x-ratelimit-remaining` = "12")),
    .package = "VancouvR"
  )
  expect_warning(VancouvR:::cov_get("https://example.com"), "12 of 15000")
  # The warning is not repeated for every subsequent request.
  expect_no_warning(VancouvR:::cov_get("https://example.com"))
})

test_that("responses without rate limit headers leave the quota untouched", {
  set_http_flag(FALSE); reset_rate_limit()
  local_mocked_bindings(cov_perform = function(req) fake_response(),
                        .package = "VancouvR")
  VancouvR:::cov_get("https://example.com")
  expect_null(get_cov_rate_limit())
})
