# Purpose: Take detected ttops and compare against field reference tree data to calculate detection
# accuracy.

library(sf)
library(tidyverse)

# Load all the functions of the ofo R package (in development) from the local repo into the global
# namespace
devtools::load_all("/ofo-share/repos-derek/ofo-r")


# CONSTANTS

# Path to the directory containing the predicted treetop points
PREDICTED_TTOPS_DIR = "/ofo-share/cv-itd-eval_data/cv-predicted-trees/run-01/ttops/"

# Path to the field reference (observed) tree points
OBS_TREES_FILEPATH = "/ofo-share/cv-itd-eval_data/observed-trees/observed-trees_incl-small.geojson"

# Path to the geospatial boundary polygon for the field survey area
OBS_BOUNDARY_FILEPATH = "/ofo-share/cv-itd-eval_data/perimeters/emerald-point-perimeter.geojson"

# Path to the directory for saving the detection accuracy results
ACCURACY_STATS_DIR = "/ofo-share/cv-itd-eval_data/accuracy-stats/run-01"



# MAIN

# Ensure the output dir exists
if (!dir.exists(ACCURACY_STATS_DIR)) {
  dir.create(ACCURACY_STATS_DIR, recursive = TRUE)
}

# Load the observed tree points and boundary polygon
obs_trees = st_read(OBS_TREES_FILEPATH)
obs_boundary = st_read(OBS_BOUNDARY_FILEPATH)

# Get the observed tree points into the standardized format needed for the accuracy
# assessment
obs_prepped = prep_obs_map(obs_trees, obs_boundary, edge_buffer = 5)

# Get the filenames of the predicted treetop files
predicted_ttops_files = list.files(PREDICTED_TTOPS_DIR,
                                   pattern = "^ttops.*gpkg$",
                                   full.names = TRUE)

for (predicted_ttop_file in predicted_ttops_files) {

  # If the accuracy stats file already exists, skip this iteration. For that, we first need to
  # determine what the write filename will be.
  filename_only = predicted_ttop_file |>
                  basename() |>
                  tools::file_path_sans_ext() |>
                  stringr::str_remove("^ttops_")
  stats_filepath = file.path(ACCURACY_STATS_DIR, paste0("stats_", filename_only, ".csv"))

  if (file.exists(stats_filepath)) {
    cat("File ", stats_filepath, " already exists. Skipping.\n")
    next()
  }

  # Load the predicted treetop points
  predicted_ttops = st_read(predicted_ttop_file)

  # Get the predicted tree points into the standardized format needed for the accuracy
  # assessment
  pred_prepped = prep_pred_map(predicted_ttops, obs_boundary, edge_buffer = 5)

  # Match the predicted and observed trees
  obs_matched = match_obs_to_pred_mee(obs = obs_prepped,
                                      pred = pred_prepped,
                                      search_distance_fun_intercept = 1,
                                      search_distance_fun_slope = 0.1,
                                      search_height_proportion = 0.5)

  # Compute recall, precision, F-score, etc.
  match_stats = compute_match_stats(pred_prepped,
                                    obs_matched,
                                    min_height = 10)

  # Include the predicted ttops filename as an identifying column in the match_stats data frame (but
  # without the leading "ttops_")
  match_stats$prediction = filename_only

  write_csv(match_stats, stats_filepath)
}
