# Regenerate the pkgdown favicon set from the hex logo.
#
# Run manually after the logo changes:
#
#   source("data-raw/generate-favicons.R")
#
# This replaces `pkgdown::build_favicons()`, which uploads the logo to
# realfavicongenerator.net and applies one background policy to every icon.
# Two policies are needed here (see below), so the set is built locally.
#
# Inputs:
#   man/figures/logo.png        240x278, transparent outside the hex
#   images/VancouvR-sticker.png 1037x1200 master, used for the large icons
#
# The logo itself comes from `R/hex_sticker.R`. Note that script passes
# `white_around_sticker = TRUE`, which paints the area outside the hex white --
# the reason `images/add_alpha.sh` exists and the reason the background had to
# be repaired by hand once (see the fix for #6). Set it to FALSE if the sticker
# is ever regenerated, and the alpha will come out of the graphics device
# already anti-aliased.
#
# Output file names are dictated by pkgdown's BS5 head template, which is what
# the built pages link to; see `system.file("BS5/templates/head.html", package
# = "pkgdown")`. Anything it references must exist here or the site 404s.

suppressMessages(library(magick))
library(base64enc)

logo <- image_read("man/figures/logo.png")
big  <- image_read("images/VancouvR-sticker.png")

# pkgdown copies pkgdown/favicon/ into docs/ on build; write both so the built
# site is correct without a rebuild.
out <- c("pkgdown/favicon", "docs")

# image_strip() drops the tIME chunk magick stamps into every PNG; without it
# re-running this script rewrites every icon with identical pixels but a new
# timestamp, showing up as a diff in git.
w2 <- function(im, name) {
  for (d in out) image_write(image_strip(im), file.path(d, name), format = "png")
}

# Hex scaled to fit an n x n square, centred, padding left transparent.
sq <- function(src, n) {
  image_background(
    image_extent(image_scale(src, sprintf("%dx%d", n, n)),
                 sprintf("%dx%d", n, n), gravity = "center"),
    "none")
}

# --- browser favicons: transparent ----------------------------------------
# Transparent so the tab icon sits correctly on light and dark browser themes.
for (n in c(16, 32, 96)) w2(sq(logo, n), sprintf("favicon-%dx%d.png", n, n))
for (d in out) {
  image_write(image_strip(image_join(sq(logo, 48), sq(logo, 32), sq(logo, 16))),
              file.path(d, "favicon.ico"), format = "ico")
}

# --- favicon.svg -----------------------------------------------------------
# A wrapper around a transparent raster rather than a vector export: the
# sticker is a full street network, so a real SVG would be megabytes to draw at
# 16px. Embedding keeps it identical to favicon.ico at the sizes browsers use.
tmp <- tempfile(fileext = ".png")
image_write(image_strip(sq(logo, 192)), tmp, format = "png")
for (d in out) {
  writeLines(sprintf(paste0(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 192 192" ',
    'width="192" height="192">',
    '<image href="data:image/png;base64,%s" width="192" height="192"/></svg>'),
    base64encode(tmp)), file.path(d, "favicon.svg"))
}

# --- home screen icons: opaque ---------------------------------------------
# Deliberately opaque, unlike the favicons above: iOS composites alpha as black
# on the home screen. Black rather than white so the near-black map interior
# merges into the tile and the blue hex outline reads on top.
for (n in c(60, 76, 120, 152, 180)) {
  w2(image_flatten(c(image_blank(n, n, "black"), sq(logo, n))),
     sprintf("apple-touch-icon-%dx%d.png", n, n))
}
w2(image_flatten(c(image_blank(180, 180, "black"), sq(logo, 180))),
   "apple-touch-icon.png")

# Sourced from the master, not upscaled from the 240px logo, so 512 is sharp.
# The master's flood-fill leaves a thin white fringe at the hex edge, but it
# does not survive the downscale.
for (n in c(192, 512)) {
  w2(image_flatten(c(image_blank(n, n, "black"), sq(big, n))),
     sprintf("web-app-manifest-%dx%d.png", n, n))
}

# purpose "any", not "maskable": the hex spans the full height of the square,
# so a maskable crop to a circle or squircle would clip its top and bottom.
manifest <- '{
  "name": "VancouvR",
  "short_name": "VancouvR",
  "icons": [
    { "src": "web-app-manifest-192x192.png", "sizes": "192x192", "type": "image/png", "purpose": "any" },
    { "src": "web-app-manifest-512x512.png", "sizes": "512x512", "type": "image/png", "purpose": "any" }
  ],
  "theme_color": "#0000ff",
  "background_color": "#000000",
  "display": "standalone"
}'
for (d in out) writeLines(manifest, file.path(d, "site.webmanifest"))
