
#' Download the CoV open data catalogue
#' @param apikey the CoV open data API key, optional
#' @param refresh refresh cached data, default `FALSE``
#' @export
list_cov_datasets <- function(apikey=getOption("VancouverOpenDataApiKey"),refresh=FALSE){
  cache_file <- file.path(tempdir(),paste0("CoV_data_catalog.rda"))
  if (!refresh & file.exists(cache_file)) {
    result=readRDS(cache_file)
  } else {
    url="https://opendata.vancouver.ca/api/v2/catalog/datasets?rows=100"
    data <- NULL
    `%|%` <- function(x,replacement) ifelse(is.null(x),replacement,x)
    while (length(url)>0) {
      if (!is.null(apikey)) url=paste0(url,"&apikey=",apikey)
      result <- GET(url) %>%
        content()
      links <- result$links %>% lapply(as_tibble) %>% bind_rows
      new_data <- result$datasets %>% lapply(function(ds){
        l=ds$links %>% lapply(as_tibble) %>% bind_rows
        d=ds$dataset
        tibble(dataset_id=d$dataset_id,dataset_uid=d$dataset_uid %|% NA,
               records_count=d$meta$default$records_count %|% NA,
               title=d$meta$default$title %|% NA,
               data_processed=d$meta$default$data_processed %|% NA,
               publisher=d$meta$default$publisher %|% NA,
               license=d$meta$default$license %|% NA,
               description=d$meta$default$description %|% NA,
               modified=d$meta$default$modified %|% NA,
               license_url=d$meta$default$license_url %|% NA,
               `data-team`=d$meta$custom$`data-team` %|% NA,
               `data-owner`=d$meta$custom$`data-owner` %|% NA,
               url=filter(l,rel=="self")$href)
      })
      data <- bind_rows(data,new_data)
      url <- filter(links,rel=="next")$href
    }
    saveRDS(data,cache_file)
  }
  data
}


#' Get datasets from Vancouver Open Data Portal
#' @export
#' @param dataset_id Dataset id from the Vancouver Open Data catalogue
#' @param format `csv` or `geojson` are supported at this time (default `csv`)
#' @param where Query parameter to filter data (default `NULL` no filter)
#' @param apikey Vancouver Open Data API key, default `getOption("VancouverOpenDataApiKey")`
#' @param rows Maximum number of rows to return (default `NULL` returns all rows)
#' @param refresh refresh cached data, default `FALSE``
get_cov_data <- function(dataset_id,format=c("csv","geojson"),where=NULL,apikey=getOption("VancouverOpenDataApiKey"),rows=NULL,refresh=FALSE) {
  format=format[1]
  marker=digest::digest(paste0(c(dataset_id,format,where,rows),collapse = "_"), algo = "md5")
  cache_file <- file.path(tempdir(),paste0("CoV_data_",marker, ".rda"))
  if (!refresh & file.exists(cache_file)) {
    message("Reading data from temporary cache")
    result=readRDS(cache_file)
  } else {
    message("Downloading data from CoV Open Data portal")
    #url=paste0("https://opendata.vancouver.ca/api/records/1.0/download?dataset=",dataset_id,"&format=",format)
    url=paste0("https://opendata.vancouver.ca/api/v2/catalog/datasets/",dataset_id,"/exports/",format)
    if (!is.null(where)) url <- urltools::param_set(url,"where",urltools::url_encode(where))
    if (!is.null(apikey)) url <- urltools::param_set(url,"apikey",apikey)
    if (!is.null(rows)) url <- urltools::param_set(url,"rows",rows)
    response <- GET(url)
    if (response$status_code!="200") {
      warning(content(response))
      stop(paste0("Stopping, returned status code ",response$status_code))
    }
    if (format=="csv")
      result=readr::read_delim(content(response,as="text"),delim=";")
    else if (format=="geojson") {
      result=sf::read_sf(content(response,as="text"))
    }
    saveRDS(result,cache_file)
  }
  result
}


#' @import dplyr
#' @import httr
#' @importFrom tibble as_tibble
#' @importFrom rvest html_node
#' @importFrom rvest html_nodes
#' @importFrom rvest html_text
#' @importFrom rlang .data
#' @importFrom stats na.omit
#' @importFrom rlang set_names
#' @importFrom rlang .data
#' @importFrom purrr map
#' @importFrom rlang :=

NULL
