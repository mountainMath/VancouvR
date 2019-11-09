main_cols <- c("dataset_id","title","keyword","search-term")

unqoute_strings <- function(s)gsub('^"|"$','',s)

remove_na_cols <- function(data){
    dplyr::select(data,unique(c(intersect(names(data),main_cols),names(select_if(data,function(d)sum(!is.na(d))>0)))))
}
