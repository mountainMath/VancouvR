main_cols <- c("dataset_id","title","keyword","search-term")

## Base URL for the Opendatasoft Explore API. The portal still answers on the
## legacy /api/v2 path, but flags it with an `ods-explore-api-deprecation`
## response header; v2.1 is the current version.
cov_api_base <- "https://opendata.vancouver.ca/api/explore/v2.1"

cov_dataset_url <- function(dataset_id, path = NULL) {
  paste0(c(cov_api_base, "catalog/datasets", dataset_id, path), collapse = "/")
}

## Session state: the HTTP/2 workaround decision and the last seen rate limit.
cov_state <- new.env(parent = emptyenv())
cov_state$force_http_1_1 <- FALSE
cov_state$rate_limit <- NULL
cov_state$warned_rate_limit <- FALSE

## Identify the package to the portal so its operators can attribute traffic.
cov_user_agent <- function() {
  paste0("VancouvR/", utils::packageVersion("VancouvR"),
         " (https://github.com/mountainMath/VancouvR)")
}

## CURL_HTTP_VERSION_1_1, the value libcurl expects for its http_version option.
curl_http_version_1_1 <- 2L

## Rate limiting and server-side hiccups are worth retrying; httr2 only treats
## 429 and 503 as transient by default, but the portal also emits 500 and 502.
cov_is_transient <- function(resp) {
  status <- resp_status(resp)
  status == 429 || status >= 500
}

## Build the request for an API call. Kept separate from performing it so the
## URL, headers and policies can be inspected -- in tests, and when retrying
## over HTTP/1.1 below.
cov_request <- function(url, query = list(), apikey = NULL, max_tries = 3) {
  req <- request(url) %>%
    req_user_agent(cov_user_agent()) %>%
    ## `refine` and `exclude` are repeatable, so vector values become one
    ## parameter each rather than a single comma-joined value.
    req_url_query(!!!query, .multi = "explode") %>%
    ## Failed requests are handled in one place, by cov_fetch().
    req_error(is_error = function(resp) FALSE) %>%
    req_retry(max_tries = max_tries, is_transient = cov_is_transient)

  ## Pass the key as a header rather than a query parameter so it stays out of
  ## request URLs, and therefore out of server logs, proxies and error messages.
  if (!is.null(apikey) && nzchar(apikey)) {
    req <- req_headers(req, Authorization = paste("Apikey", apikey),
                       .redact = "Authorization")
  }
  if (cov_state$force_http_1_1) {
    req <- req_options(req, http_version = curl_http_version_1_1)
  }
  req
}

## Indirection so tests can drive the fallback below without a network.
cov_perform <- function(req) req_perform(req)

## httr2 wraps transport failures, so the diagnostic naming HTTP/2 may sit on
## the parent condition rather than the one that surfaces.
cov_condition_text <- function(cnd) {
  paste(c(conditionMessage(cnd),
          if (!is.null(cnd$parent)) conditionMessage(cnd$parent)),
        collapse = " ")
}

## The portal serves a `content-security-policy` header with trailing
## whitespace in its value, which RFC 9113 8.2.1 forbids over HTTP/2. Strict
## nghttp2 builds (shipped with recent libcurl) reject the whole stream, while
## older, lenient builds accept it -- so the same call fails on some machines
## and works on others. HTTP/1.1 does not validate field values this way, so we
## retry there and remember the choice for the rest of the session.
cov_get <- function(url, query = list(), apikey = NULL, max_tries = 3) {
  response <- tryCatch(
    cov_perform(cov_request(url, query, apikey, max_tries)),
    httr2_failure = function(cnd) {
      if (cov_state$force_http_1_1 ||
          !grepl("HTTP/2", cov_condition_text(cnd), fixed = TRUE)) {
        stop(cnd)
      }
      cov_state$force_http_1_1 <- TRUE
      cov_perform(cov_request(url, query, apikey, max_tries))
    })

  cov_record_rate_limit(response)
  response
}

## Remember the quota the portal reports, and warn once per session as it runs
## low. The daily allowance is shared across every call the user makes.
cov_record_rate_limit <- function(response) {
  raw_limit <- resp_header(response, "x-ratelimit-limit")
  if (is.null(raw_limit)) return(invisible(NULL))
  limit <- suppressWarnings(as.integer(raw_limit))
  remaining <- suppressWarnings(as.integer(resp_header(response, "x-ratelimit-remaining")))
  reset <- resp_header(response, "x-ratelimit-reset")
  cov_state$rate_limit <- list(limit = limit, remaining = remaining, reset = reset)

  if (!is.na(limit) && !is.na(remaining) && limit > 0 &&
      remaining <= limit * 0.05 && !cov_state$warned_rate_limit) {
    cov_state$warned_rate_limit <- TRUE
    warning("Only ", remaining, " of ", limit,
            " City of Vancouver Open Data API requests remain",
            if (is.null(reset)) "." else paste0(" until ", reset, "."),
            call. = FALSE)
  }
  invisible(NULL)
}

## Describe a failed API response. The portal returns a JSON body with
## `error_code` and `message` keys for 4xx responses.
cov_error_message <- function(response) {
  detail <- tryCatch({
    body <- resp_body_json(response)
    d <- paste(c(body$error_code, body$message), collapse = ": ")
    if (nzchar(d)) d else NULL
  }, error = function(e) NULL)

  paste0("City of Vancouver Open Data API request failed [", resp_status(response), "]",
         if (is.null(detail)) "" else paste0("\n", detail))
}

## Warnings are classed so they can be caught, or escalated back into errors:
## tryCatch(get_cov_data("..."), cov_api_warning = function(w) stop(conditionMessage(w)))
cov_warn <- function(message, class) {
  warn(message, class = c(class, "cov_api_warning"))
}

## Perform a request, or explain why it could not be done. Nothing that happens
## to a request is fatal: an unreachable portal, a refused request and a
## malformed query all yield NULL and a warning, so that a script or a knitted
## document degrades instead of stopping. This is also what CRAN asks of
## packages that depend on an internet resource.
cov_fetch <- function(url, query = list(), apikey = NULL) {
  response <- tryCatch(
    cov_get(url, query = query, apikey = apikey),
    error = function(cnd) {
      cov_warn(paste0("Could not reach the City of Vancouver Open Data API.\n",
                      cov_condition_text(cnd)),
               "cov_unreachable")
      NULL
    })
  if (is.null(response)) return(NULL)

  if (resp_is_error(response)) {
    cov_warn(cov_error_message(response),
             paste0("cov_http_", resp_status(response)))
    return(NULL)
  }
  response
}

## Both the catalogue and the dataset facet endpoints answer with the same
## nested shape: a list of facets, each holding a list of values and counts.
cov_parse_facets <- function(response) {
  result <- resp_body_json(response)$facets %>%
    map(function(f) {
      tibble(facet=f$name,
             value=vapply(f$facets,function(v) as.character(v$value %||% NA),""),
             count=vapply(f$facets,function(v) as.integer(v$count %||% NA),integer(1)))
    }) %>%
    bind_rows()
  if (nrow(result)==0) result <- tibble(facet=character(),value=character(),
                                        count=integer())
  result
}

## FlatGeobuf is a binary format, so it has to reach GDAL as a file rather than
## as a string the way the CSV exports do.
cov_read_fgb <- function(response) {
  path <- tempfile(fileext = ".fgb")
  on.exit(unlink(path), add = TRUE)
  writeBin(resp_body_raw(response), path)
  read_sf(path)
}

## The portal's `int` type is 64-bit, so a column it declares as integer can
## still hold values beyond R's 32-bit range -- assessed land values do. Casting
## those with as.integer() turns them silently into NA, so fall back to double
## for the whole column when any value would not survive the trip.
cov_as_integer <- function(x) {
  n <- suppressWarnings(as.numeric(x))
  i <- suppressWarnings(as.integer(n))
  if (any(is.na(i) & !is.na(n))) n else i
}

## Attach geometry to the rows identified by `link`, leaving every other row
## with empty geometry, and return an sf object. Rows are matched on the
## temporary `...link` column that the caller adds before subsetting.
cov_as_sf <- function(data, link, geometry) {
  data %>%
    left_join(tibble(...link = link, geometry = geometry), by = "...link") %>%
    select(-"...link") %>%
    st_as_sf()
}

## geo_point_2d fields export as a "latitude, longitude" string.
cov_parse_points <- function(x) {
  tibble(lat = as.numeric(sub(",.*$", "", x)),
         lon = as.numeric(sub("^[^,]*,", "", x)))
}

## Turn one record of an aggregation response into a single-row tibble. JSON
## nulls arrive as NULL and would otherwise silently drop the column.
aggregation_row <- function(row) {
  row <- lapply(row, function(v) {
    if (is.null(v) || length(v) == 0) return(NA)
    if (length(v) > 1) return(paste(unlist(v), collapse = ", "))
    v
  })
  as_tibble(row)
}

unqoute_strings <- function(s)gsub('^"|"$','',s)

remove_na_cols <- function(data){
    keep <- names(data)[vapply(data, function(d) any(!is.na(d)), logical(1))]
    dplyr::select(data,all_of(unique(c(intersect(names(data),main_cols),keep))))
}
