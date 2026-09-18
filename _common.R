# Shared setup sourced by every chapter.
#
# Quarto renders each chapter in its own R session (unlike bookdown, which
# shared one session across the whole book), so chapters that relied on a
# package being loaded earlier in the book (rather than loading it
# themselves) would otherwise fail. To reproduce the old shared-session
# behaviour, we load here the full set of packages that used to be loaded
# somewhere across the book.
suppressPackageStartupMessages({
  # multcomp pulls in TH.data, which in turn attaches MASS, and MASS::select()
  # masks dplyr::select(). Load tidyverse/dplyr last so their functions win.
  library(GGally)
  library(gridExtra)
  library(car)
  library(coin)
  library(faraway)
  library(multcomp)
  library(mvtnorm)
  library(NHANES)
  library(plot3D)
  library(plotrix)
  library(tidyverse)
  library(dplyr)
  library(ggplot2)
})

tableType <- if (knitr::is_latex_output()) "latex" else "html"
