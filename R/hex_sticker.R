#' Internal function to generate hex sticker
#' @keywords internal
generate_cansim_hex_sticker <- function (){
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

  bbox <- sf::read_sf('{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {},
      "geometry": {
        "type": "Point",
        "coordinates": [
          3.387908935546875,
          6.458257931949705
        ]
      }
    },
    {
      "type": "Feature",
      "properties": {},
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          [
            [
              -123.16738128662111,
              49.231723108823424
            ],
            [
              -123.0743408203125,
              49.231723108823424
            ],
            [
              -123.0743408203125,
              49.29938216794409
            ],
            [
              -123.16738128662111,
              49.29938216794409
            ],
            [
              -123.16738128662111,
              49.231723108823424
            ]
          ]
        ]
      }
    }
  ]
}')

  pp <- ggplot(tree_data  %>% sf::st_intersection(bbox)) +
    #geom_sf(aes(color=Type),fill=NA,size=0.001,shape=16) +
    #geom_sf(aes(fill=Type),color=NA,size=0.0001,shape=19) +
    geom_sf(data=street_data,size=0.1,color="#888888") +
    geom_sf(data=greenways,size=0.5,color="#228822") +
    geom_sf(data=bikeways,size=0.25,color="#228822") +
    geom_sf(data=park_parcels,color=NA,fill="#116611") +
    scale_color_manual(values=tree_colors,guide=FALSE) +
    scale_fill_manual(values=tree_colors,guide=FALSE) +
    #theme(panel.background = element_rect(fill = "black")) +
    coord_sf(datum=NA,xlim=c(-123.157,-123.075),ylim=c(49.231,49.299)) +
    theme_void() +
    hexSticker::theme_transparent()

  hexSticker::sticker(pp, package="VancouvR",
          p_size=8, p_y=1.4,
          s_x=1, s_y=1, s_width=2.1, s_height=2.75,
          h_color="#0000FF",
          h_fill="#000000",
          p_color="#dddddd",
          white_around_sticker = TRUE,
          filename=here::here("images/VancouvR-sticker.png"))

}


#' @import dplyr
#' @import ggplot2
