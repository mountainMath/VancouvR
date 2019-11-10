#' Download the CoV open data catalogue
#' @param trim trim all NA columns, optional, defaul `TRUE`
#' @param apikey the CoV open data API key, optional
#' @param refresh refresh cached data, default `FALSE``
#' @return tibble format data table output
#' @export
#'
#' @examples
#' # List and search available datasets
#' list_cov_datasets()
#'
list_cov_datasets <- function(trim = TRUE, apikey=getOption("VancouverOpenDataApiKey"),refresh=FALSE){
  cache_file <- file.path(tempdir(),paste0("CoV_data_catalog.rda"))
  if (!refresh & file.exists(cache_file)) {
    result=readRDS(cache_file)
  } else {
    url="https://opendata.vancouver.ca/api/v2/catalog/exports/csv"
    if (!is.null(apikey)) url <- param_set(url,"apikey",apikey)
    response <- GET(url)
    if (response$status_code!="200") {
      warning(content(response))
      stop(paste0("Stopping, returned status code ",response$status_code))
    }
    result=read_delim(content(response,as="text"),delim=";",col_types = cols(.default="c")) %>%
      set_names(gsub("^default\\.|^custom\\.|dcat\\.","",names(.))) %>%
      mutate(dataset_id=.data$datasetid) %>%
      select(c(main_cols,setdiff(names(.),main_cols))) %>%
      mutate_if(is.character,unqoute_strings)
    saveRDS(result,cache_file)
  }
  if (trim) result <- result %>% remove_na_cols()
  result
}

#' Search for CoV open data datasets
#' @param search_term grep string to serach through datasets
#' @param trim trim all NA columns, optional, defaul `TRUE`
#' @param apikey the CoV open data API key, optional
#' @param refresh refresh cached data, default `FALSE``
#' @return tibble format data table output
#' @export
#'
#' @examples
#' # search available datasets relating to trees
#' search_cov_datasets("trees")
#'
search_cov_datasets <- function(search_term, trim=TRUE, apikey=getOption("VancouverOpenDataApiKey"),refresh=FALSE){
  datasets <- list_cov_datasets(trim=FALSE,apikey = apikey,refresh = refresh)

  matches <- datasets %>% filter(grepl(search_term, .data$title, ignore.case = TRUE)|
                                   grepl(search_term, .data$dataset_id, ignore.case = TRUE) |
                                   grepl(search_term, .data$keyword, ignore.case = TRUE) |
                                   grepl(search_term, .data$`search-term`, ignore.case = TRUE))

  if (nrow(matches)==0) {
      hintlist <- tibble(`Similarly named objects`=unique(agrep(search_term, datasets$title, ignore.case = TRUE, value = TRUE)))
    if (length(hintlist) > 0) {
      warning("No results found. Please use accurate spelling. See above for list of variables with similar named terms.")
      print(hintlist)
    } else {
      warning("No results found.")
    }
  }

  if (trim) matches <- matches %>% remove_na_cols()
  matches
}

#' Get metadata for CoV open data dataset
#' @param dataset_id the CoV open data dataset id
#' @param apikey the CoV open data API key, optional
#' @param refresh refresh cached data, default `FALSE``
#' @return tibble format data table output
#' @export
#'
#' @examples
#' # Get the metadata for the street trees dataset
#' get_cov_metadata("street-trees")
#'
get_cov_metadata <- function(dataset_id,apikey=getOption("VancouverOpenDataApiKey"),refresh=FALSE){
  cache_file <- file.path(tempdir(),paste0("CoV_metadata_,",dataset_id,".rda"))
  if (!refresh & file.exists(cache_file)) {
    result=readRDS(cache_file)
  } else {
    url=paste0("https://opendata.vancouver.ca/api/v2/catalog/datasets/",dataset_id)
    if (!is.null(apikey)) url <- param_set(url,"apikey",apikey)
    response <- GET(url)
    if (response$status_code!="200") {
      warning(content(response))
      stop(paste0("Stopping, returned status code ",response$status_code))
    }
    r <- content(response)
    result <- r$dataset$fields %>%
      lapply(function(d) {
        des=d$desciption
        tibble(name=ifelse(is.null(d$name),NA,d$name),
               type=ifelse(is.null(d$type),NA,d$type),
               label=ifelse(is.null(d$label),NA,d$label),
               description=ifelse(is.null(d$description),NA,d$description))
        }) %>%
      bind_rows
    saveRDS(result,cache_file)
  }
  result
}


#' Get datasets from Vancouver Open Data Portal
#' @param dataset_id Dataset id from the Vancouver Open Data catalogue
#' @param format `csv` or `geojson` are supported at this time (default `csv`)
#' @param where Query parameter to filter data (default `NULL` no filter)
#' It accepts \href{https://help.opendatasoft.com/apis/ods-search-v2/#where-clause}{ODSQL syntax}.
#' @param select select string for fields to return, returns all fields by default.
#' It accepts \href{https://help.opendatasoft.com/apis/ods-search-v2/#select-clause}{ODSQL syntax}.
#' @param apikey Vancouver Open Data API key, default `getOption("VancouverOpenDataApiKey")`
#' @param rows Maximum number of rows to return (default `NULL` returns all rows)
#' @param cast_types Logical, use metadata to look up types and type-cast automatically, default `TRUE`
#' @param refresh refresh cached data, default `FALSE``
#' @return tibble or sf object data table output, depending on the value of the `format` parameter
#' @export
#'
#' @examples
#' # Get all parking tickets issued at the 1100 block of Alberni Street between 2017 and 2019
#' get_cov_data("parking-tickets-2017-2019",where = "block = 1100 AND street = 'ALBERNI ST'")
#'
get_cov_data <- function(dataset_id,format=c("csv","geojson"),
                         select= "*",
                         where=NULL,apikey=getOption("VancouverOpenDataApiKey"),
                         rows=NULL,cast_types=TRUE,refresh=FALSE) {
  format=format[1]
  marker=digest(paste0(c(dataset_id,format,where,select,rows,apikey),collapse = "_"), algo = "md5")
  cache_file <- file.path(tempdir(),paste0("CoV_data_",marker, ".rda"))
  if (!refresh & file.exists(cache_file)) {
    message("Reading data from temporary cache")
    result=readRDS(cache_file)
  } else {
    message("Downloading data from CoV Open Data portal")
    url=paste0("https://opendata.vancouver.ca/api/v2/catalog/datasets/",dataset_id,"/exports/",format)
    if (!is.null(where)) url <- param_set(url,"where",url_encode(where))
    if (!is.null(select)) url <- param_set(url,"select",url_encode(select))
    if (!is.null(apikey)) url <- param_set(url,"apikey",apikey)
    if (!is.null(rows)) url <- param_set(url,"rows",rows)
    response <- GET(url)
    if (response$status_code!="200") {
      warning(content(response))
      stop(paste0("Stopping, returned status code ",response$status_code))
    }
    if (format=="csv")
      result=read_delim(content(response,as="text"),delim=";",col_types = cols(.default="c"))
    else if (format=="geojson") {
      result=read_sf(content(response,as="text"))
    }
    saveRDS(result,cache_file)
  }
  if (cast_types){
    metadata <- get_cov_metadata(dataset_id)
    integer_columns <- metadata %>% filter(.data$type=="int") %>% pull(.data$name) %>% intersect(names(result))
    numeric_columns <- metadata %>% filter(.data$type=="double") %>% pull(.data$name) %>% intersect(names(result))
    date_columns <- metadata %>% filter(.data$type=="date") %>% pull(.data$name) %>% intersect(names(result))
    text_columns <- metadata %>% filter(.data$type=="text") %>% pull(.data$name) %>% intersect(names(result))
    result <- result %>%
      mutate_at(integer_columns,as.integer) %>%
      mutate_at(numeric_columns,as.numeric)
    if (length(date_columns>0)) { ## be more careful here, might break with funny date format
      result <- tryCatch(result %>% mutate_at(date_columns,as.Date), finally = result)
    }
  }
  result
}

#' Get aggregates from dataset from Vancouver Open Data Portal
#' @param dataset_id Dataset id from the Vancouver Open Data catalogue
#' @param select select string for aggregation, default is `count(*) as count`
#' It accepts \href{https://help.opendatasoft.com/apis/ods-search-v2/#select-clause}{ODSQL syntax}.
#' @param group_by grouping variables for the query
#' It accepts \href{https://help.opendatasoft.com/apis/ods-search-v2/#group-by-clause}{ODSQL syntax}.
#' @param where Query parameter to filter data (default `NULL` no filter)
#' It accepts \href{https://help.opendatasoft.com/apis/ods-search-v2/#where-clause}{ODSQL syntax}.
#' @param apikey Vancouver Open Data API key, default `getOption("VancouverOpenDataApiKey")`
#' @param refresh refresh cached data, default `FALSE``
#' @return tibble format data table output
#' @export
#'
#' @examples
#' # Count all parking tickets that relate to fire hydrants by ticket status
#' aggregate_cov_data("parking-tickets-2017-2019",
#'                    group_by = "status",
#'                    where = "infractiontext LIKE 'FIRE'")
#'
aggregate_cov_data <- function(dataset_id,select="count(*) as count",group_by=NULL,where=NULL,apikey=getOption("VancouverOpenDataApiKey"),
                         refresh=FALSE) {
  marker=digest(paste0(c(dataset_id,select,group_by,where,select),collapse = "_"), algo = "md5")
  cache_file <- file.path(tempdir(),paste0("CoV_data_",marker, ".rda"))
  if (!refresh & file.exists(cache_file)) {
    message("Reading data from temporary cache")
    result=readRDS(cache_file)
  } else {
    message("Downloading data from CoV Open Data portal")
    url=paste0("https://opendata.vancouver.ca/api/v2/catalog/datasets/",dataset_id,"/aggregates")
    if (!is.null(where)) url <- param_set(url,"where",url_encode(where))
    if (!is.null(select)) url <- param_set(url,"select",url_encode(select))
    if (!is.null(group_by)) url <- param_set(url,"group_by",url_encode(group_by))
    if (!is.null(apikey)) url <- param_set(url,"apikey",apikey)
    response <- GET(url)
    if (response$status_code!="200") {
      warning(content(response))
      stop(paste0("Stopping, returned status code ",response$status_code))
    }
    r <- content(response)
    result <- r$aggregations %>% map(as_tibble) %>% bind_rows()
    saveRDS(result,cache_file)
  }
  result
}


#' @import dplyr
#' @import httr
#' @importFrom rlang .data
#' @importFrom sf read_sf
#' @importFrom readr read_delim
#' @importFrom readr cols
#' @importFrom digest digest
#' @import urltools
#' @importFrom tibble tibble
#' @importFrom rlang set_names
#' @importFrom purrr map

NULL

## quiets concerns of R CMD check re: the .'s that appear in pipelines
if(getRversion() >= "2.15.1")  utils::globalVariables(c("."))

