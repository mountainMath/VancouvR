#' Report the remaining CoV open data API quota
#' @description
#' The City of Vancouver Open Data portal reports a daily request quota on every
#' response. This returns the quota seen on the most recent request made by this
#' package, so it reflects usage across every `VancouvR` call in the session.
#'
#' The quota is per API key, or per IP address when no key is set, and is shared
#' with any other tool making requests under the same identity. `VancouvR`
#' warns once per session when fewer than 5% of requests remain.
#' @return A tibble with columns `limit`, `remaining` and `reset` (the time the
#'   quota resets, as reported by the portal), or `NULL` if no request has been
#'   made yet in this session.
#' @seealso [get_cov_data()], [aggregate_cov_data()]
#' @export
#'
#' @examples
#' \donttest{
#' get_cov_data("public-trees", rows = 5)
#' get_cov_rate_limit()
#' }
#'
get_cov_rate_limit <- function() {
  state <- cov_state$rate_limit
  if (is.null(state)) return(NULL)
  tibble(limit = state$limit, remaining = state$remaining, reset = state$reset)
}
