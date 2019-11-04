#' Download the CoV open data catalogue
#' @param apikey the CoV open data API key, optional
#' @param refresh refresh cached data, default `FALSE``
#' @export
list_cov_datasets <- function(apikey=getOption("VancouverOpenDataApiKey"),refresh=FALSE){
  cache_file <- file.path(tempdir(),paste0("CoV_data_catalog.rda"))
  if (!refresh & file.exists(cache_file)) {
    result=readRDS(cache_file)
  } else {
    url="https://opendata.vancouver.ca/api/v2/catalog/exports/csv"
    response <- GET(url)
    if (!is.null(apikey)) url=paste0(url,"&apikey=",apikey)
    result <- GET(url) %>%
      content()
    if (response$status_code!="200") {
      warning(content(response))
      stop(paste0("Stopping, returned status code ",response$status_code))
    }
    result=readr::read_delim(content(response,as="text"),delim=";",col_types = readr::cols(.default="c")) %>%
      mutate(title=.data$default.title,dataset_id=.data$datasetid)
    saveRDS(result,cache_file)
  }
  result
}


#' Get datasets from Vancouver Open Data Portal
#' @param dataset_id Dataset id from the Vancouver Open Data catalogue
#' @param format `csv` or `geojson` are supported at this time (default `csv`)
#' @param where Query parameter to filter data (default `NULL` no filter)
#' @param apikey Vancouver Open Data API key, default `getOption("VancouverOpenDataApiKey")`
#' @param rows Maximum number of rows to return (default `NULL` returns all rows)
#' @param refresh refresh cached data, default `FALSE``
#' @export
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
      result=readr::read_delim(content(response,as="text"),delim=";",col_types = readr::cols(.default="c"))
    else if (format=="geojson") {
      result=sf::read_sf(content(response,as="text"))
    }
    saveRDS(result,cache_file)
  }
  result
}


#' @import dplyr
#' @import httr
#' @importFrom rlang .data

NULL
