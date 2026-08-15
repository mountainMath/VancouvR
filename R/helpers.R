main_cols <- c("dataset_id","title","keyword","search-term")

## Session state for the HTTP/2 workaround in cov_get()
cov_state <- new.env(parent = emptyenv())
cov_state$force_http_1_1 <- FALSE

## The portal serves a `content-security-policy` header with trailing
## whitespace in its value, which RFC 9113 8.2.1 forbids over HTTP/2. Strict
## nghttp2 builds (shipped with recent libcurl) reject the whole stream, while
## older, lenient builds accept it -- so the same call fails on some machines
## and works on others. HTTP/1.1 does not validate field values this way, so we
## retry there and remember the choice for the rest of the session.
cov_get <- function(url) {
  if (cov_state$force_http_1_1) return(GET(url, config(http_version = 2)))

  tryCatch(GET(url), error = function(e) {
    if (!grepl("HTTP/2", conditionMessage(e), fixed = TRUE)) stop(e)
    cov_state$force_http_1_1 <- TRUE
    GET(url, config(http_version = 2))
  })
}

unqoute_strings <- function(s)gsub('^"|"$','',s)

remove_na_cols <- function(data){
    dplyr::select(data,unique(c(intersect(names(data),main_cols),names(select_if(data,function(d)sum(!is.na(d))>0)))))
}
