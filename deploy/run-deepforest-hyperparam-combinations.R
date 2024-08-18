# Title: Run DeepForest Across Multiple Hyperparameter Combinations
# Description: This script runs DeepForest (using predict_tile) on a forest orthomosaic
#              on a range of a specified parameter via run-deepforest-prediction-
#              from-command-line.py. It saves the detected tree bounding boxes as
#              a .gpkg with the same name as the orthomosaic, followed by the parameter
#              value.
# Credit: Largely based on a script developed by Derek Young for OFO

library(tidyverse)

#### CONSTANTS ####

# Path to the orthomosaic to detect trees from
ORTHO_FILEPATH = "/ofo-share/cv-itd-eval_data/photogrammetry-outputs/emerald-point_10a-20230103T2008/ortho.tif"

# Directory to save the results (detected trees) to
OUT_DIR = "/ofo-share/cv-itd-eval_data/cv-detected-trees/run-01"

# The parameter to vary (i.e. ortho_resolution, window_size, patch_overlap, iou_threshold)
SINGLE_PARAM = "window_size"
SINGLE_PARAM_VALUES = c(500, 1000, 1250, 1500, 2000) # a vector of the single parameter values

# Define default param values
DEFAULT_PARAM_VALUES = list(ortho_resolution = 1,
                            window_size = 1250,
                            patch_overlap = 0.25,
                            iou_threshold = 0.15)

DEEPFOREST_SCRIPT_PATH = "/ofo-share/repos-derek/cv-itd-eval-2/src/run-deepforest-prediction-from-command-line.py"


#### CONVENIENCE FUNCTIONS ####

# Function to pad with 5-digit leading zero to integer
pad_5dig = function(x) {
  x = as.numeric(as.character(x))
  str_pad(x, width = 5, side = "left", pad = "0")
}


#### MAIN ####

# Check if single_param is correctly set to an included parameter
allowed_params = c("ortho_resolution", "window_size", "patch_overlap", "iou_threshold")
if (!(SINGLE_PARAM %in% allowed_params)) {
  stop(paste("Error: Invalid parameter. Allowed parameters are:",
             paste(allowed_params, collapse = ", ")))
}

# Make out directory if needed
if (!dir.exists(OUT_DIR)) {
  dir.create(OUT_DIR, recursive = TRUE)
}

# Get the base filename to use for saving (same as the ortho filename, but without extension)
filename_minus_extension = ORTHO_FILEPATH |>
  basename() |>
  tools::file_path_sans_ext()

param_values = DEFAULT_PARAM_VALUES

# Loop through all values of the varying parameter, and run DeepForest for each one
for (single_param_value in SINGLE_PARAM_VALUES) {
  # reassign current parameter of interest
  param_values[[SINGLE_PARAM]] = single_param_value

  # Prep bbox output file name
  bbox_gpkg_out_filepath = paste0(OUT_DIR, "/bboxes_", filename_minus_extension, "_", "dpf", "_",
                                  single_param_value |> pad_5dig(), ".gpkg")

  cat("\nStarting detection for", bbox_gpkg_out_filepath, "\n")

  # if it already exists, skip
  if(file.exists(bbox_gpkg_out_filepath)) {
    cat("Already exists. Skipping.\n")
    next()
  }

  # Construct and run command line call to run DeepForest with these param values
  call = paste("python3",
               DEEPFOREST_SCRIPT_PATH,
               ORTHO_FILEPATH,
               param_values$window_size,
               param_values$patch_overlap,
               param_values$ortho_resolution,
               param_values$iou_threshold,
               bbox_gpkg_out_filepath,
               sep = " ")
  system(call)
}

