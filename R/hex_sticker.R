#' Internal function to generate hex sticker
#' @keywords internal
generate_VancouvR_hex_sticker <- function (){
  # tree_data <- get_cov_data("street-trees",format='geojson') %>%
  #   mutate(Type=case_when(grepl("FIR$|PINE|SPRUCE|CYPRESS|JUNIPER|REDWOOD|CEDAR|SEQUOIA",common_name)~"Conifer",
  #                         grepl("BEECH|ASH|ASPEN|CATALPA|BIRCH|PEAR|POPLAR|WALNUT|WOOD|ALDER|GINKGO|LINDEN|CHESTNUT|HAWTHORN|HORNBEAM|WILLOW|HEMLOCK|ELM|KATSURA|5721",common_name) ~ "Leaf",
  #                         grepl("CHERRY",common_name)~ "Cherry",
  #                         grepl("MAPLE",common_name) ~ "Maple",
  #                         grepl("OAK",common_name)~ "OAK",
  #                         grepl("MAGNOLIA",common_name) ~ "Magnolia",
  #                         grepl("PLUM",common_name) ~ "Plum",
  #                         grepl("PEAR|APPLE|APRICOT|PEACH|FIG",common_name) ~ "Fruit",
  #                         TRUE ~ "Other"))
  # tree_colors <- c(Conifer="#977696",Leaf="#977696",Cherry="#e7a0ae",Fruit="#8e4585",Magnolia="#F8F4FF",
  #                  Maple="#7D0202",Other="#977696",Oak="#765c48",Plum="#977696")

  street_data <- get_cov_data("public-streets",format="geojson")

  greenways <- get_cov_data("greenways",format="geojson")
  parks <- get_cov_data("parks",format="geojson")
  bikeways <- get_cov_data("bikeways",format="geojson")

  parcels <- get_cov_data("property-parcel-polygons",format="geojson")

  park_parcels <- parcels %>% filter(sf::st_intersects(.,parks %>% sf::st_union(),sparse=FALSE) %>% unlist)

  clip <- sf::read_sf('{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {},
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          [
            [
              -123.164,
              49.233
            ],
            [
              -123.066,
              49.233
            ],
            [
              -123.066,
              49.306
            ],
            [
              -123.164,
              49.306
            ],
            [
              -123.164,
              49.233
            ]
          ]
        ]
      }
    }
  ]
}')

  pp <- ggplot() +
    #geom_sf(aes(color=Type),fill=NA,size=0.001,shape=16) +
    #geom_sf(aes(fill=Type),color=NA,size=0.0001,shape=19) +
    geom_sf(data=street_data %>% sf::st_intersection(clip),size=0.1,color="#888888") +
    geom_sf(data=greenways%>% sf::st_intersection(clip),size=0.5,color="#228822") +
    geom_sf(data=bikeways%>% sf::st_intersection(clip),size=0.25,color="#228822") +
    geom_sf(data=park_parcels%>% sf::st_intersection(clip),color=NA,fill="#116611") +
    #scale_color_manual(values=tree_colors,guide=FALSE) +
    #theme(panel.background = element_rect(fill = "black")) +
    coord_sf(datum=NA,xlim=c(-123.17,-123.06),ylim=c(49.23,49.31)) +
    theme_void() +
    hexSticker::theme_transparent()

  hexSticker::sticker(pp, package="VancouvR",
          p_size=8, p_y=1.4,
          s_x=1, s_y=1, s_width=2.1, s_height=2.75,
          h_color="#0000FF",
          h_fill="#000000",
          p_color="#dddddd",
          white_around_sticker = TRUE,
          filename=here::here("images/VancouvR-sticker.png"),dpi=600)

}


#' @import dplyr
#' @import ggplot2
