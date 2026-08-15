#' List all datasets in the CoV open data catalogue
#' @description
#' Fetches the full City of Vancouver Open Data catalogue and returns it as a
#' tibble. Results are cached for the duration of the R session; subsequent
#' calls return the cached copy unless `refresh = TRUE`.
#' @param trim Remove columns that are entirely `NA`, default `TRUE`
#' @param apikey the CoV open data API key, optional
#' @param refresh Bypass the session cache and re-download, default `FALSE`
#' @return A tibble with one row per dataset. The first four columns are always
#'   `dataset_id`, `title`, `keyword`, and `search-term`; remaining columns
#'   contain catalogue metadata (trimmed to non-empty columns when `trim = TRUE`).
#' @seealso [search_cov_datasets()] to filter the catalogue by a search term,
#'   [get_cov_data()] to download a specific dataset
#' @export
#'
#' @examples
#' \dontrun{
#' list_cov_datasets()
#' }
#'
list_cov_datasets <- function(trim = TRUE, apikey=getOption("VancouverOpenDataApiKey"),refresh=FALSE){
  cache_file <- file.path(tempdir(),paste0("CoV_data_catalog.rda"))
  if (!refresh & file.exists(cache_file)) {
    result=readRDS(cache_file)
  } else {
    url="https://opendata.vancouver.ca/api/v2/catalog/exports/csv"
    if (!is.null(apikey)) url <- param_set(url,"apikey",apikey)
    response <- cov_get(url)
    if (response$status_code!="200") {
      warning(content(response))
      stop(paste0("Stopping, returned status code ",response$status_code))
    }
    result <- read_delim(content(response,as="text"),delim=";",col_types = cols(.default="c"))
    header <- tibble(h=names(result)) %>%
      mutate(hh=case_when(!grepl(".+\\..+|^datasetid$",.data$h) ~ paste0("X.",.data$h), TRUE ~ .data$h))%>%
      mutate(hhh=gsub("^default\\.|^custom\\.|dcat\\.","",.data$hh))
    result<- result %>%
      set_names(header$hhh) %>%
      mutate(dataset_id=.data$datasetid) %>%
      select(all_of(c(main_cols,setdiff(names(.),main_cols)))) %>%
      mutate_if(is.character,unqoute_strings)
    saveRDS(result,cache_file)
  }
  if (trim) result <- result %>% remove_na_cols()
  result
}

#' Search the CoV open data catalogue
#' @description
#' Filters the City of Vancouver Open Data catalogue for datasets whose title,
#' dataset ID, keyword, or search-term fields match `search_term` (using
#' `grepl()`, so regular expressions are supported). When no exact match is
#' found, a fuzzy-match hint list of similarly named datasets is printed.
#' @param search_term A grep-compatible string to search through dataset titles,
#'   IDs, keywords, and search terms
#' @param trim Remove columns that are entirely `NA`, default `TRUE`
#' @param apikey the CoV open data API key, optional
#' @param refresh Bypass the session cache and re-download, default `FALSE`
#' @return A tibble with one row per matching dataset, in the same format as
#'   [list_cov_datasets()].
#' @seealso [list_cov_datasets()] to retrieve the full catalogue,
#'   [get_cov_data()] to download a specific dataset
#' @export
#'
#' @examples
#' \dontrun{
#' # Search using a plain string
#' search_cov_datasets("trees")
#'
#' # Search using a regular expression
#' search_cov_datasets("parking.*(2019|2020)")
#' }
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

#' Get field-level metadata for a CoV open data dataset
#' @description
#' Returns a tibble describing each field in the dataset, including its API
#' name, data type, display label, and description. Results are cached for the
#' duration of the R session.
#'
#' This function is called internally by [get_cov_data()] when
#' `cast_types = TRUE` to determine column types and identify spatial fields.
#' @param dataset_id the CoV open data dataset id
#' @param apikey the CoV open data API key, optional
#' @param refresh Bypass the session cache and re-download, default `FALSE`
#' @return A tibble with one row per field and columns:
#'   \describe{
#'     \item{name}{Field name as used in `where` and `select` queries}
#'     \item{type}{API data type (e.g. `"text"`, `"int"`, `"double"`,
#'       `"date"`, `"geo_shape"`)}
#'     \item{label}{Human-readable display label}
#'     \item{description}{Field description, if provided by the portal}
#'   }
#' @seealso [get_cov_data()], [list_cov_datasets()]
#' @export
#'
#' @examples
#' \dontrun{
#' # View all fields in the street trees dataset
#' get_cov_metadata("street-trees")
#'
#' # Find which fields are spatial
#' get_cov_metadata("property-parcel-polygons") |>
#'   dplyr::filter(type == "geo_shape")
#' }
#'
get_cov_metadata <- function(dataset_id,apikey=getOption("VancouverOpenDataApiKey"),refresh=FALSE){
  cache_file <- file.path(tempdir(),paste0("CoV_metadata_,",dataset_id,".rda"))
  if (!refresh & file.exists(cache_file)) {
    result=readRDS(cache_file)
  } else {
    url=paste0("https://opendata.vancouver.ca/api/v2/catalog/datasets/",dataset_id)
    if (!is.null(apikey)) url <- param_set(url,"apikey",apikey)
    response <- cov_get(url)
    if (response$status_code!="200") {
      warning(content(response))
      stop(paste0("Stopping, returned status code ",response$status_code))
    }
    r <- content(response)
    result <- r$dataset$fields %>%
      lapply(function(d) {
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


#' Download a dataset from the Vancouver Open Data Portal
#' @description
#' Downloads a dataset and returns it as a tibble or `sf` object. When
#' `cast_types = TRUE` (the default), field types are looked up via
#' [get_cov_metadata()] and columns are automatically cast to integer, numeric,
#' or Date. Datasets containing a `geo_shape` field are returned as an `sf`
#' object; if spatial conversion fails a plain tibble is returned with a warning.
#'
#' Results are cached for the duration of the R session, keyed on all query
#' parameters. Re-running the same call does not trigger a second download.
#' @param dataset_id Dataset id from the Vancouver Open Data catalogue
#' @param where Filter expression using
#'   \href{https://help.opendatasoft.com/apis/ods-explore-v2/#section/Opendatasoft-Query-Language-(ODSQL)/Where-clause}{ODSQL syntax},
#'   e.g. `"tax_assessment_year='2024' AND zoning_district LIKE 'RS-'"`.
#'   Default `NULL` returns all rows.
#' @param select Column selection / expression string using
#'   \href{https://help.opendatasoft.com/apis/ods-explore-v2/#section/Opendatasoft-Query-Language-(ODSQL)/Select-clause}{ODSQL syntax},
#'   e.g. `"current_land_value, land_coordinate as coord"`. Default `"*"`
#'   returns all columns.
#' @param apikey Vancouver Open Data API key, default `getOption("VancouverOpenDataApiKey")`
#' @param rows Maximum number of rows to return. Default `NULL` returns all rows.
#' @param cast_types Logical; use metadata to auto-cast column types and convert
#'   spatial datasets to `sf`. Default `TRUE`.
#' @param refresh Bypass the session cache and re-download, default `FALSE`
#' @param ... Ignored; retained for compatibility with earlier versions
#' @return A tibble, or an `sf` object when the dataset has a `geo_shape` field
#'   and `cast_types = TRUE`.
#' @seealso [get_cov_metadata()] for field names and types,
#'   [aggregate_cov_data()] for server-side aggregation,
#'   [search_cov_datasets()] to find dataset IDs
#' @export
#'
#' @examples
#' \dontrun{
#' # Filtered download: parking tickets on one block
#' get_cov_data("parking-tickets-2017-2019",
#'              where = "block = 1100 AND street = 'ALBERNI ST'")
#'
#' # Select specific columns and limit rows (useful for exploration)
#' get_cov_data("property-tax-report",
#'              select = "tax_assessment_year, current_land_value, zoning_district",
#'              where = "tax_assessment_year = '2024'",
#'              rows = 100)
#'
#' # Spatial dataset: returned automatically as an sf object
#' property_polygons <- get_cov_data("property-parcel-polygons")
#' class(property_polygons)  # "sf" "data.frame"
#' }
#'
get_cov_data <- function(dataset_id,
                         select= "*",
                         where=NULL,apikey=getOption("VancouverOpenDataApiKey"),
                         rows=NULL,cast_types=TRUE,refresh=FALSE,
                         ...) {
  format="csv"
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
    response <- cov_get(url)
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
    if (nrow(metadata)>0) {
      geo_column <- metadata %>% filter(.data$type=="geo_shape") %>% pull(.data$name) %>% intersect(names(result))
      integer_columns <- metadata %>% filter(.data$type=="int") %>% pull(.data$name) %>% intersect(names(result))
      numeric_columns <- metadata %>% filter(.data$type=="double") %>% pull(.data$name) %>% intersect(names(result))
      date_columns <- metadata %>% filter(.data$type=="date") %>% pull(.data$name) %>% intersect(names(result))
      text_columns <- metadata %>% filter(.data$type=="text") %>% pull(.data$name) %>% intersect(names(result))
      result <- result %>%
        mutate_at(integer_columns,as.integer) %>%
        mutate_at(numeric_columns,as.numeric)
      if (length(geo_column)>0) {
        result <- tryCatch({
          geo_column <- geo_column[1]
          result <- result %>%
            mutate(...link=as.character(row_number()))
          geo_result <- result %>%
            filter(!is.na(!!as.name(geo_column))) %>%
            mutate(geometry=geojsonsf::geojson_sf(!!as.name(geo_column))$geometry) |>
            select("...link","geometry")

          result |>
            left_join(geo_result,by="...link") %>%
            select(-"...link") %>%
            sf::st_as_sf()
        }, error=\(e){
          warning("Error converting geojson to sf, returning as tibble")
          message(e)
          result
        }
      )}


      if (length(date_columns>0)) { ## be more careful here, might break with funny date format
        result <- tryCatch(result %>% mutate_at(date_columns,as.Date), finally = result)
      }
    }
  }
  result
}

#' Aggregate data from the Vancouver Open Data Portal
#' @description
#' Sends a server-side aggregation query to the CoV Open Data API and returns
#' the result as a tibble. Because aggregation is performed by the API, this is
#' suitable for summarising large datasets without downloading all records.
#'
#' Results are cached for the duration of the R session.
#' @param dataset_id Dataset id from the Vancouver Open Data catalogue
#' @param select Aggregation expression using
#'   \href{https://help.opendatasoft.com/apis/ods-explore-v2/#section/Opendatasoft-Query-Language-(ODSQL)/Select-clause}{ODSQL syntax}.
#'   Default `"count(*) as count"`.
#' @param group_by Grouping expression using
#'   \href{https://help.opendatasoft.com/apis/ods-explore-v2/#section/Opendatasoft-Query-Language-(ODSQL)/Group-by-clause}{ODSQL syntax}.
#'   Default `NULL` (no grouping).
#' @param where Filter expression using
#'   \href{https://help.opendatasoft.com/apis/ods-explore-v2/#section/Opendatasoft-Query-Language-(ODSQL)/Where-clause}{ODSQL syntax}.
#'   Default `NULL` (no filter).
#' @param apikey Vancouver Open Data API key, default `getOption("VancouverOpenDataApiKey")`
#' @param refresh Bypass the session cache and re-download, default `FALSE`
#' @return A tibble with one row per group, with columns named according to the
#'   `select` expression.
#' @seealso [get_cov_data()] to download full or filtered records,
#'   [search_cov_datasets()] to find dataset IDs
#' @export
#'
#' @examples
#' \dontrun{
#' # Count of each ticket status for fire hydrant infractions
#' aggregate_cov_data("parking-tickets-2017-2019",
#'                    group_by = "status",
#'                    where = "infractiontext LIKE 'FIRE'")
#'
#' # Sum land and building values by tax year (server-side, no full download needed)
#' aggregate_cov_data("property-tax-report",
#'                    select = "sum(current_land_value) as Land,
#'                              sum(current_improvement_value) as Building",
#'                    group_by = "tax_assessment_year")
#' }
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
    response <- cov_get(url)
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

