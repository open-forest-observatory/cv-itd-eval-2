# Title: Convert DeepForest Bounding Boxes to Treetop Points
# Description: This script reads in bounding boxes (bboxes) of trees predicted by
#              DeepForest and converts them to treetop points for comparison against
#              a reference stem map. This process involves extracting heights from
#              a CHM (since deepforest does not produce height estimates of trees).
#              The user specifies a folder of bbox files (e.g., each one from a 
#              different run of deepforest) and a CHM. The script converts each bbox
#              file to a corresponding treetop points file. Each bbox file to be
#              processed is expected to have a filename in the format: `*_bboxes.gpkg`.

library(terra)
library(tidyverse)
library(sf)


#### CONSTANTS ####

# Path to dir containing predicted deepforest tree bboxes (separate file for each hyperparam run)
BBOXES_PATH = "/ofo-share/cv-itd-eval_data/cv-detected-trees/run-01/bboxes/"

# Path to canopy height model for assigning heights to treetops
CHM_FILEPATH = "/ofo-share/cv-itd-eval_data/photogrammetry-outputs/emerald-point_10a-20230103T2008/chm.tif"

# Path to dir for saving the resulting treetop points (separate file for each hyperparam run)
TTOPS_PATH = "/ofo-share/cv-itd-eval_data/cv-detected-trees/run-01/ttops/"

# Load the bboxes files
bboxes_files = list.files(BBOXES_PATH, pattern = "^bboxes.*gpkg$", full.name = TRUE)

# Create output directory
if (!dir.exists(TTOPS_PATH)) {
  dir.create(TTOPS_PATH, recursive = TRUE)
}

# For each set of bboxes, convert to treetop points
for (bboxes_file in bboxes_files) {

  # Get the filename to use for saving the treetop points
  filename_only = bboxes_file |> basename() |> tools::file_path_sans_ext()
  # Change 'bboxes' to 'ttops'
  filename_only = str_replace(filename_only, fixed("bboxes"), "ttops")
  out_filepath = paste0(TTOPS_PATH, "/", filename_only, ".gpkg")

  cat("\nConverting bboxes to ttops for:", out_filepath, "\n")

  # Skip if alredy exists
  if (file.exists(out_filepath)) {
    cat("Already exists. Skipping.\n")
    next()
  }

  # Load bboxes (vector) and CHM (raster)
  bboxes = st_read(bboxes_file)
  chm = rast(CHM_FILEPATH)

  # Get bbox centroids (i.e., ttops)
  ttops = st_centroid(bboxes)

  # Get a zone within which to get canopy height (as max value within zone). Want a circle with a
  # radius equal to the short dimension of the bbox.

  # Get the inscribed circle
  inscr_circles = st_inscribed_circle(st_geometry(bboxes), dTolerance = 1)
  inscr_circles = st_as_sf(inscr_circles)

  # For some reason the above creates two sets of inscribed circles, one with empty geometry, so
  # remove those
  inscr_circles = inscr_circles |> filter(!st_is_empty(inscr_circles))

  # Get the circle radius via its area
  circle_areas = st_area(inscr_circles)
  inscr_circles$comp_area = circle_areas
  radii = sqrt(circle_areas / 3.14)

  # Make a new circle with that computed radius, centered on the centroid of the bbox
  inscr_circles$comp_radius = radii
  circles = st_buffer(ttops, radii)

  # Was the prediction a sliver (long skinny rectangular box)? We will assign this as an attribute
  # to the ttops
  bbox_area = st_area(bboxes)
  is_sliver = circle_areas < (bbox_area / 3)

  # Get the height, as the max CHM value within the circle
  height = terra::extract(chm, circles, fun = "max")

  # Save the attributes (height and sliver) back to ttops
  ttops$height = height[, 2]
  ttops$is_sliver = is_sliver

  # Remove ttops below 3 m height
  ttops = ttops |>
    filter(height >= 3)

  st_write(ttops, out_filepath, delete_dsn = TRUE)

}
