#!/bin/sh
# Build the full published site.
#
# The book and the slides/ lecture pages are two independent Quarto
# projects that both publish into docs/ (slides -> docs/rmd/), because
# GitHub Pages can only serve one folder. `quarto render` deletes its
# entire output directory before rendering, every time -- so rendering
# the book alone wipes out docs/rmd/, and vice versa. Always rebuild both
# together with this script instead of running `quarto render` directly
# in either directory.
set -e

quarto render
(cd slides && quarto render)
