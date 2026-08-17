#' List all datasets in the CoV open data catalogue
#' @description
#' Fetches the full City of Vancouver Open Data catalogue and returns it as a
#' tibble. Results are cached for the duration of the R session; subsequent
#' calls return the cached copy unless `refresh = TRUE`.
#' @param trim Remove columns that are entirely `NA`, default `TRUE`
#' @param where Filter expression applied by the portal, using
#'   \href{https://help.opendatasoft.com/apis/ods-explore-v2/#section/Opendatasoft-Query-Language-(ODSQL)/Where-clause}{ODSQL syntax}
#'   over the catalogue's own fields, e.g. `"search(title, 'tree')"` or
#'   `"features LIKE 'geo'"`. Default `NULL` returns the whole catalogue.
#' @param refine Catalogue facet filter(s) of the form `"facet:value"`, e.g.
#'   `"theme:Sustainability"`. Values must match the facet exactly; use
#'   [list_cov_facets()] to discover them. Pass a character vector to apply
#'   several; multiple values on the same facet are combined with OR, different
#'   facets with AND. Default `NULL`.
#' @param exclude Catalogue facet exclusion(s), in the same `"facet:value"` form
#'   as `refine`. Default `NULL`.
#' @param apikey the CoV open data API key, optional
#' @param refresh Bypass the session cache and re-download, default `FALSE`
#' @return A tibble with one row per dataset. The first four columns are always
#'   `dataset_id`, `title`, `keyword`, and `search-term`; remaining columns
#'   contain catalogue metadata (trimmed to non-empty columns when `trim = TRUE`).
#'   Returns `NULL` with a warning if the API cannot be reached.
#' @seealso [list_cov_facets()] to discover the values `refine` accepts,
#'   [search_cov_datasets()] to filter the catalogue by a search term,
#'   [get_cov_data()] to download a specific dataset
#' @export
#'
#' @examples
#' \donttest{
#' # Only the datasets that carry geographic records
#' list_cov_datasets(where = "features LIKE 'geo'")
#'
#' # Datasets filed under a catalogue theme
#' list_cov_datasets(refine = "theme:Sustainability")
#' }
#'
#' \dontrun{
#' # The entire catalogue
#' list_cov_datasets()
#' }
#'
list_cov_datasets <- function(trim = TRUE, where=NULL, refine=NULL, exclude=NULL,
                              apikey=getOption("VancouverOpenDataApiKey"),refresh=FALSE){
  filters <- c(where,refine,exclude)
  marker <- if (is.null(filters)) "" else paste0("_",digest(paste0(filters,collapse="_"),algo="md5"))
  cache_file <- file.path(tempdir(),paste0("CoV_data_catalog",marker,".rds"))
  if (!refresh & file.exists(cache_file)) {
    result=readRDS(cache_file)
  } else {
    response <- cov_fetch(paste0(cov_api_base,"/catalog/exports/csv"),
                        query=list(with_bom="false", where=where, refine=refine,
                                   exclude=exclude), apikey=apikey)
    if (is.null(response)) return(NULL)
    result <- read_delim(I(resp_body_string(response)),delim=";",col_types = cols(.default="c"))
    header <- tibble(h=names(result)) %>%
      mutate(hh=case_when(!grepl(".+\\..+|^datasetid$",.data$h) ~ paste0("X.",.data$h), TRUE ~ .data$h))%>%
      mutate(hhh=gsub("^default\\.|^custom\\.|dcat\\.","",.data$hh))
    result<- result %>%
      set_names(header$hhh) %>%
      mutate(dataset_id=.data$datasetid) %>%
      select(all_of(c(main_cols,setdiff(names(.),main_cols)))) %>%
      mutate(across(where(is.character),unqoute_strings))
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
#'   [list_cov_datasets()]. Returns `NULL` with a warning if the API cannot be
#'   reached.
#' @seealso [list_cov_datasets()] to retrieve the full catalogue,
#'   [get_cov_data()] to download a specific dataset
#' @export
#'
#' @examples
#' \donttest{
#' # Search using a plain string
#' search_cov_datasets("trees")
#'
#' # Search using a regular expression
#' search_cov_datasets("parking.*(2019|2020)")
#' }
#'
search_cov_datasets <- function(search_term, trim=TRUE, apikey=getOption("VancouverOpenDataApiKey"),refresh=FALSE){
  datasets <- list_cov_datasets(trim=FALSE,apikey = apikey,refresh = refresh)
  ## The catalogue could not be fetched; list_cov_datasets() has already said so.
  if (is.null(datasets)) return(NULL)

  matches <- datasets %>% filter(grepl(search_term, .data$title, ignore.case = TRUE)|
                                   grepl(search_term, .data$dataset_id, ignore.case = TRUE) |
                                   grepl(search_term, .data$keyword, ignore.case = TRUE) |
                                   grepl(search_term, .data$`search-term`, ignore.case = TRUE))

  if (nrow(matches)==0) {
      hintlist <- tibble(`Similarly named objects`=unique(agrep(search_term, datasets$title, ignore.case = TRUE, value = TRUE)))
    if (nrow(hintlist) > 0) {
      warning("No results found. Please use accurate spelling. See above for list of variables with similar named terms.")
      print(hintlist)
    } else {
      warning("No results found.")
    }
  }

  if (trim) matches <- matches %>% remove_na_cols()
  matches
}

#' List the facets of the CoV open data catalogue
#' @description
#' Returns the values the catalogue can be filtered on, together with the number
#' of datasets carrying each. This is the starting point for browsing the portal
#' rather than searching it: it answers what themes and keywords exist before
#' passing them to [list_cov_datasets()] as a `refine` filter.
#'
#' The catalogue facets are `theme`, `keyword`, `features`, `custom.data-owner`
#' and `custom.data-team`. The `features` facet is worth knowing about: its
#' `geo` value identifies the datasets [get_cov_data()] returns as `sf` objects,
#' and `timeserie` those carrying a date field.
#'
#' Results are cached for the duration of the R session.
#' @param facet Name(s) of the catalogue facets to return. Default `NULL`
#'   returns every facet.
#' @param where Filter expression using
#'   \href{https://help.opendatasoft.com/apis/ods-explore-v2/#section/Opendatasoft-Query-Language-(ODSQL)/Where-clause}{ODSQL syntax},
#'   restricting the datasets the counts are computed over. Default `NULL`.
#' @param refine Facet filter(s) of the form `"facet:value"`. Default `NULL`.
#' @param exclude Facet exclusion(s) of the form `"facet:value"`. Default `NULL`.
#' @param apikey the CoV open data API key, optional
#' @param refresh Bypass the session cache and re-download, default `FALSE`
#' @return A tibble with columns `facet` (the facet name), `value`, and `count`
#'   (the number of datasets). Returns `NULL` with a warning if the API cannot
#'   be reached.
#' @seealso [list_cov_datasets()] to filter the catalogue on these values,
#'   [get_cov_facets()] for the facets of an individual dataset
#' @export
#'
#' @examples
#' \donttest{
#' # Every facet of the catalogue
#' list_cov_facets()
#'
#' # Just the themes, and how many datasets each holds
#' list_cov_facets(facet = "theme")
#' }
#'
list_cov_facets <- function(facet=NULL,where=NULL,refine=NULL,exclude=NULL,
                            apikey=getOption("VancouverOpenDataApiKey"),refresh=FALSE){
  marker <- digest(paste0(c(facet,where,refine,exclude,apikey),collapse="_"),algo="md5")
  cache_file <- file.path(tempdir(),paste0("CoV_catalog_facets_",marker,".rds"))
  if (!refresh & file.exists(cache_file)) {
    result=readRDS(cache_file)
  } else {
    response <- cov_fetch(paste0(cov_api_base,"/catalog/facets"),
                        query=list(facet=facet, where=where, refine=refine,
                                   exclude=exclude),
                        apikey=apikey)
    if (is.null(response)) return(NULL)
    result <- cov_parse_facets(response)
    saveRDS(result,cache_file)
  }
  result
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
#'   Returns `NULL` with a warning if the API cannot be reached.
#' @seealso [get_cov_data()], [list_cov_datasets()]
#' @export
#'
#' @examples
#' \donttest{
#' # View all fields in the public trees dataset
#' get_cov_metadata("public-trees")
#' }
#'
#' \dontrun{
#' # Find which fields are spatial
#' get_cov_metadata("property-parcel-polygons") |>
#'   dplyr::filter(type == "geo_shape")
#' }
#'
get_cov_metadata <- function(dataset_id,apikey=getOption("VancouverOpenDataApiKey"),refresh=FALSE){
  cache_file <- file.path(tempdir(),paste0("CoV_metadata_",digest(dataset_id,algo="md5"),".rds"))
  if (!refresh & file.exists(cache_file)) {
    result=readRDS(cache_file)
  } else {
    response <- cov_fetch(cov_dataset_url(dataset_id), apikey=apikey)
    if (is.null(response)) return(NULL)
    r <- resp_body_json(response)
    ## v2.1 returns `fields` at the top level; v2.0 nested it under `dataset`.
    fields <- r$fields %||% r$dataset$fields
    result <- fields %>%
      lapply(function(d) {
        tibble(name=ifelse(is.null(d$name),NA_character_,d$name),
               type=ifelse(is.null(d$type),NA_character_,d$type),
               label=ifelse(is.null(d$label),NA_character_,d$label),
               description=ifelse(is.null(d$description),NA_character_,d$description))
        }) %>%
      bind_rows
    ## Datasets without published field metadata still get the documented shape.
    if (nrow(result)==0) result <- tibble(name=character(),type=character(),
                                          label=character(),description=character())
    saveRDS(result,cache_file)
  }
  result
}


#' Get the facet values of a CoV open data dataset
#' @description
#' Returns the values available for each facetted field, together with the
#' number of records carrying them. This is a quick way to discover what a
#' field actually contains before writing a `where` clause or a `refine`
#' filter for [get_cov_data()].
#'
#' The portal returns only the most common values of each facet (currently the
#' top 100). Use [aggregate_cov_data()] with a `group_by` for an exhaustive
#' count.
#'
#' Results are cached for the duration of the R session.
#' @param dataset_id the CoV open data dataset id
#' @param facet Name(s) of the fields to facet on. Default `NULL` returns every
#'   facetted field in the dataset.
#' @param where Filter expression using
#'   \href{https://help.opendatasoft.com/apis/ods-explore-v2/#section/Opendatasoft-Query-Language-(ODSQL)/Where-clause}{ODSQL syntax},
#'   restricting the records the counts are computed over. Default `NULL`.
#' @param refine Facet filter(s) of the form `"field:value"`; see [get_cov_data()].
#'   Default `NULL`.
#' @param exclude Facet exclusion(s) of the form `"field:value"`. Default `NULL`.
#' @param apikey the CoV open data API key, optional
#' @param refresh Bypass the session cache and re-download, default `FALSE`
#' @return A tibble with columns `facet` (the field name), `value`, and `count`.
#'   Returns `NULL` with a warning if the API cannot be reached.
#' @seealso [get_cov_metadata()] for the list of fields,
#'   [list_cov_facets()] for the facets of the catalogue itself,
#'   [aggregate_cov_data()] for complete server-side counts
#' @export
#'
#' @examples
#' \donttest{
#' # What values does the genus field take?
#' get_cov_facets("public-trees", facet = "genus_name")
#'
#' # Restricted to trees planted since 2020
#' get_cov_facets("public-trees", facet = "genus_name",
#'                where = "date_planted >= date'2020-01-01'")
#' }
#'
get_cov_facets <- function(dataset_id,facet=NULL,where=NULL,refine=NULL,exclude=NULL,
                           apikey=getOption("VancouverOpenDataApiKey"),refresh=FALSE){
  marker <- digest(paste0(c(dataset_id,facet,where,refine,exclude,apikey),collapse="_"),algo="md5")
  cache_file <- file.path(tempdir(),paste0("CoV_facets_",marker,".rds"))
  if (!refresh & file.exists(cache_file)) {
    result=readRDS(cache_file)
  } else {
    response <- cov_fetch(cov_dataset_url(dataset_id,"facets"),
                        query=list(facet=facet, where=where, refine=refine,
                                   exclude=exclude),
                        apikey=apikey)
    if (is.null(response)) return(NULL)
    result <- cov_parse_facets(response)
    saveRDS(result,cache_file)
  }
  result
}


#' Download a dataset from the Vancouver Open Data Portal
#' @description
#' Downloads a dataset and returns it as a tibble or `sf` object. When
#' `cast_types = TRUE` (the default), field types are looked up via
#' [get_cov_metadata()] and columns are automatically cast to integer, numeric,
#' or Date.
#'
#' Datasets whose metadata declares a `geo_shape` or `geo_point_2d` field are
#' downloaded as \href{https://flatgeobuf.org}{FlatGeobuf} and returned as an
#' `sf` object with its coordinate reference system already set, rather than as
#' CSV with the geometry re-parsed from text. The raw geometry fields are not
#' part of that export, so such datasets come back with a single `geometry`
#' column and no `geom` or `geo_point_2d` column. Setting `cast_types = FALSE`
#' or `use_labels = TRUE` downloads the CSV instead, and returns a plain tibble.
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
#' @param order_by Sort expression using
#'   \href{https://help.opendatasoft.com/apis/ods-explore-v2/#section/Opendatasoft-Query-Language-(ODSQL)/Order-by-clause}{ODSQL syntax},
#'   e.g. `"height_m DESC"`. Default `NULL` leaves the portal's ordering.
#' @param refine Facet filter(s) of the form `"field:value"`, e.g.
#'   `"genus_name:ACER"`. Values must match the facet exactly. Pass a character
#'   vector to apply several; multiple values on the same field are combined
#'   with OR, different fields with AND. Default `NULL`.
#' @param exclude Facet exclusion(s), in the same `"field:value"` form as
#'   `refine`. Default `NULL`.
#' @param apikey Vancouver Open Data API key, default `getOption("VancouverOpenDataApiKey")`
#' @param rows Maximum number of rows to return. Default `NULL` returns all rows.
#' @param cast_types Logical; use metadata to auto-cast column types and to
#'   download spatial datasets as `sf`. Default `TRUE`.
#' @param use_labels Logical; name the columns using the human-readable field
#'   labels instead of the API field names. Default `FALSE`. Setting this to
#'   `TRUE` disables type casting, as metadata is keyed on the API names.
#' @param timezone Timezone used to render datetime fields, e.g. `"America/Vancouver"`.
#'   Default `NULL` uses the portal default (UTC).
#' @param refresh Bypass the session cache and re-download, default `FALSE`
#' @param ... Ignored; retained for compatibility with earlier versions
#' @return A tibble, or an `sf` object when the dataset has a spatial field and
#'   `cast_types = TRUE`. Returns `NULL` with a warning if the API cannot be
#'   reached.
#' @seealso [get_cov_metadata()] for field names and types,
#'   [aggregate_cov_data()] for server-side aggregation,
#'   [search_cov_datasets()] to find dataset IDs
#' @export
#'
#' @examples
#' \donttest{
#' # Select specific columns and limit rows (useful for exploration)
#' get_cov_data("property-tax-report",
#'              select = "tax_assessment_year, current_land_value, zoning_district",
#'              where = "tax_assessment_year = '2024'",
#'              rows = 10)
#'
#' # The ten tallest maples, sorted server-side
#' get_cov_data("public-trees",
#'              refine = "genus_name:ACER",
#'              order_by = "height_m DESC",
#'              rows = 10)
#'
#' # Spatial dataset: returned automatically as an sf object
#' property_polygons <- get_cov_data("property-parcel-polygons", rows = 10)
#' class(property_polygons)  # "sf" "data.frame"
#' }
#'
#' \dontrun{
#' # Whole filtered datasets can be large, so they are not run here
#' get_cov_data("parking-tickets-2017-2019",
#'              where = "block = 1100 AND street = 'ALBERNI ST'")
#' }
#'
get_cov_data <- function(dataset_id,
                         select= "*",
                         where=NULL,order_by=NULL,refine=NULL,exclude=NULL,
                         apikey=getOption("VancouverOpenDataApiKey"),
                         rows=NULL,cast_types=TRUE,use_labels=FALSE,
                         timezone=NULL,refresh=FALSE,
                         ...) {
  cast_types_default <- missing(cast_types)
  ignored <- names(list(...))
  if (length(ignored)>0) {
    warning("Ignoring unsupported argument(s): ",
            paste(ifelse(nzchar(ignored),ignored,"<unnamed>"),collapse=", "),
            call.=FALSE)
  }
  ## Metadata is keyed on the API field names, which labelled columns no longer
  ## carry, so there is nothing to match types or geometry against. Only say so
  ## when type casting was asked for rather than merely left at its default.
  if (cast_types && use_labels) {
    if (!cast_types_default) {
      warning("Ignoring cast_types: column types cannot be matched when use_labels=TRUE",
              call.=FALSE)
    }
    cast_types <- FALSE
  }

  ## Spatial datasets are downloaded as FlatGeobuf, which carries the geometry
  ## natively instead of as text to be re-parsed. Whether a dataset is spatial
  ## is a metadata question, so the lookup has to happen before the download
  ## rather than after it. Without metadata the columns stay as the character
  ## vectors they were read as; get_cov_metadata() has already warned about why.
  metadata <- if (cast_types) get_cov_metadata(dataset_id, apikey=apikey) else NULL
  has_metadata <- !is.null(metadata) && nrow(metadata)>0
  spatial <- has_metadata &&
    any(metadata$type %in% c("geo_shape","geo_point_2d"))

  ## The format is part of the cache key: the same query answered as FlatGeobuf
  ## and as CSV does not have the same columns.
  format <- if (spatial) "fgb" else "csv"
  marker=digest(paste0(c(dataset_id,where,select,order_by,refine,exclude,rows,
                         use_labels,timezone,format,apikey),collapse = "_"), algo = "md5")
  cache_file <- file.path(tempdir(),paste0("CoV_data_",marker, ".rds"))
  if (!refresh & file.exists(cache_file)) {
    message("Reading data from temporary cache")
    result=readRDS(cache_file)
  } else {
    message("Downloading data from CoV Open Data portal")
    ## v2.1 documents `limit` for exports; `rows` survives only as an alias.
    query <- list(where=where, select=select, order_by=order_by, refine=refine,
                  exclude=exclude, limit=rows, timezone=timezone)
    result <- NULL
    if (spatial) {
      response <- cov_fetch(cov_dataset_url(dataset_id,"exports/fgb"),
                            query=query, apikey=apikey)
      if (is.null(response)) return(NULL)
      ## Every dataset whose metadata declares a geometry currently offers a
      ## FlatGeobuf export, but fall back to the CSV rather than fail outright
      ## if one arrives that GDAL cannot read.
      result <- tryCatch(cov_read_fgb(response), error=function(e) {
        warning("Could not read the FlatGeobuf export, falling back to CSV: ",
                conditionMessage(e), call.=FALSE)
        NULL
      })
    }
    if (is.null(result)) {
      response <- cov_fetch(cov_dataset_url(dataset_id,"exports/csv"),
                          query=c(query, list(with_bom="false",
                                   use_labels=if (use_labels) "true" else NULL)),
                          apikey=apikey)
      if (is.null(response)) return(NULL)
      result=read_delim(I(resp_body_string(response)),delim=";",col_types = cols(.default="c"))
    }
    saveRDS(result,cache_file)
  }
  if (cast_types && has_metadata){
    ## FlatGeobuf supplies the geometry itself, so only the CSV path has a
    ## text column left to convert.
    geo_column <- metadata %>% filter(.data$type=="geo_shape") %>% pull(.data$name) %>% intersect(names(result))
    point_column <- metadata %>% filter(.data$type=="geo_point_2d") %>% pull(.data$name) %>% intersect(names(result))
    integer_columns <- metadata %>% filter(.data$type=="int") %>% pull(.data$name) %>% intersect(names(result))
    numeric_columns <- metadata %>% filter(.data$type=="double") %>% pull(.data$name) %>% intersect(names(result))
    date_columns <- metadata %>% filter(.data$type=="date") %>% pull(.data$name) %>% intersect(names(result))
    result <- result %>%
      mutate(across(all_of(integer_columns),cov_as_integer)) %>%
      mutate(across(all_of(numeric_columns),as.numeric))
    if (length(geo_column)>0) {
      result <- tryCatch({
        geo_column <- geo_column[1]
        result <- result %>%
          mutate(...link=as.character(row_number()))
        geo_result <- result %>%
          filter(!is.na(!!as.name(geo_column))) %>%
          mutate(geometry=geojsonsf::geojson_sf(!!as.name(geo_column))$geometry) |>
          select("...link","geometry")

        cov_as_sf(result, geo_result$...link, geo_result$geometry)
      }, error=\(e){
        warning("Error converting geojson to sf, returning as tibble")
        message(e)
        result
      }
    )} else if (length(point_column)>0) {
      ## Datasets that carry only a point field are spatial too.
      result <- tryCatch({
        point_column <- point_column[1]
        result <- result %>%
          mutate(...link=as.character(row_number()))
        located <- result %>%
          filter(!is.na(!!as.name(point_column)), nzchar(!!as.name(point_column)))
        coords <- cov_parse_points(located[[point_column]])
        located <- located[!is.na(coords$lat) & !is.na(coords$lon), ]
        coords <- coords[!is.na(coords$lat) & !is.na(coords$lon), ]

        cov_as_sf(result, located$...link,
                  sf::st_geometry(sf::st_as_sf(coords, coords=c("lon","lat"),
                                               crs=4326)))
      }, error=\(e){
        warning("Error converting coordinates to sf, returning as tibble")
        message(e)
        result
      }
    )}


    if (length(date_columns)>0) { ## be careful here, might break with funny date format
      result <- tryCatch(result %>% mutate(across(all_of(date_columns),as.Date)),
                         error=\(e){
                           warning("Error parsing date columns, returning them as character")
                           result
                         })
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
#'
#' Grouped queries are answered by the dataset export endpoint and so are not
#' subject to a record limit; every group is returned in a single request.
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
#' @param order_by Sort expression using
#'   \href{https://help.opendatasoft.com/apis/ods-explore-v2/#section/Opendatasoft-Query-Language-(ODSQL)/Order-by-clause}{ODSQL syntax},
#'   naming an aggregate from `select` or a field from `group_by`, e.g.
#'   `"count DESC"`. Default `NULL`.
#' @param refine Facet filter(s) of the form `"field:value"`; see [get_cov_data()].
#'   Default `NULL`.
#' @param exclude Facet exclusion(s) of the form `"field:value"`. Default `NULL`.
#' @param limit Maximum number of groups to return. Default `NULL` returns all
#'   groups. Ignored when `group_by` is `NULL`, which always yields one row.
#' @param apikey Vancouver Open Data API key, default `getOption("VancouverOpenDataApiKey")`
#' @param refresh Bypass the session cache and re-download, default `FALSE`
#' @return A tibble with one row per group, with columns named according to the
#'   `select` expression. Returns `NULL` with a warning if the API cannot be
#'   reached.
#' @seealso [get_cov_data()] to download full or filtered records,
#'   [search_cov_datasets()] to find dataset IDs
#' @export
#'
#' @examples
#' \donttest{
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
#'
#' # The ten most common tree genera
#' aggregate_cov_data("public-trees",
#'                    group_by = "genus_name",
#'                    order_by = "count DESC",
#'                    limit = 10)
#' }
#'
aggregate_cov_data <- function(dataset_id,select="count(*) as count",group_by=NULL,where=NULL,
                         order_by=NULL,refine=NULL,exclude=NULL,limit=NULL,
                         apikey=getOption("VancouverOpenDataApiKey"),
                         refresh=FALSE) {
  marker=digest(paste0(c(dataset_id,select,group_by,where,order_by,refine,exclude,
                         limit,apikey),collapse = "_"), algo = "md5")
  cache_file <- file.path(tempdir(),paste0("CoV_aggregate_",marker, ".rds"))
  if (!refresh & file.exists(cache_file)) {
    message("Reading data from temporary cache")
    result=readRDS(cache_file)
  } else {
    message("Downloading data from CoV Open Data portal")
    ## The dedicated /aggregates endpoint was removed in Explore API v2.1.
    ## Grouped queries go to the export endpoint, which applies the group_by
    ## and returns every group. Without a group_by there is nothing to collapse
    ## on, so both endpoints repeat the aggregate once per record -- ask the
    ## records endpoint for a single row instead.
    if (is.null(group_by)) {
      url <- cov_dataset_url(dataset_id,"records")
      query <- list(limit=1)
    } else {
      url <- cov_dataset_url(dataset_id,"exports/json")
      query <- list(group_by=group_by, limit=limit)
    }
    response <- cov_fetch(url, query=c(query, list(where=where, select=select,
                                                 order_by=order_by, refine=refine,
                                                 exclude=exclude)),
                        apikey=apikey)
    if (is.null(response)) return(NULL)
    r <- resp_body_json(response)
    rows <- if (is.null(group_by)) r$results else r
    result <- rows %>% map(aggregation_row) %>% bind_rows()
    saveRDS(result,cache_file)
  }
  result
}


#' @import dplyr
#' @importFrom httr2 request req_url_query req_user_agent req_headers req_options
#' @importFrom httr2 req_error req_retry req_perform
#' @importFrom httr2 resp_status resp_header resp_is_error
#' @importFrom httr2 resp_body_string resp_body_json resp_body_raw
#' @importFrom rlang .data
#' @importFrom rlang %||%
#' @importFrom rlang warn
#' @importFrom tibble as_tibble
## Importing from sf guarantees its namespace is loaded whenever VancouvR is.
## geojsonsf builds sfc-classed vectors without loading sf itself, and dplyr
## rejects an sfc column in mutate() until sf has registered its vctrs methods.
#' @importFrom sf st_as_sf read_sf
#' @importFrom readr read_delim
#' @importFrom readr cols
#' @importFrom digest digest
#' @importFrom tibble tibble
#' @importFrom rlang set_names
#' @importFrom purrr map

NULL

## quiets concerns of R CMD check re: the .'s that appear in pipelines
if(getRversion() >= "2.15.1")  utils::globalVariables(c("."))

