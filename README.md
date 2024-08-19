# cv-itd-eval-2

Evaluation of computer vision-based tools for tree detection

## Data management

The data files for this analysis are on Jetstream2 at `/ofo-share/cv-itd-eval_data/`. Key
files/folders in the data folder:

- `observed-trees/observed-trees.geojson`: The ground-mapped set of tree points to use as a
reference for evaluating predicted treetops against
- `perimeters/emerald-point-perimeter.geojson`: The perimeter of the ground-mapped area (so that we
  don't assume CV detections outside it are false-positives)
- `photogrammetry-outputs/emerald-point_10a-20230103T2008/`: The orthomosaic and CHM of the study
  area
- `predicted-trees/`: The folder to put new sets of tree detections into (probably under a
  subfolder(s) with descriptive name)


## Workflow

1. Use DeepForest to predict tree bounding boxes for the OFO Emerald Point study site under a range
   of values for different hyperparameters, including orthomosaic resolution, window size,
   patch overlap, and IOU threshold. The script `workflow/01_predict-deepforest-hyperparam-combinations.R`
   demonstrates how this can be done (but currently only varying only one parameter at a time). This
   should be expanded to test all key parameters in a factorial way. This is an R script that calls
   (via the command line) a Python script that runs DeepForest predictions, taking the
   hyperparameter values as command line arguments. This Python script is at `src/deepforest-prediction.py`.
2. Convert the bounding boxes for detected trees into treetop points, with associated heights. This
   is required so that the detected trees can be matched to the observed (field-measured) trees,
   which just have a point location, along with a height. The bbox-to-point conversion process takes
   the centroid of the bbox as the treetop, and estimates its height be extracting a value from a
   drone-derived canopy height model. Specifically, it computes the largest circle that could be
   inscribed within the bounding box and takes the maximum value from the CHM within that circle.
   This is done by `workflow/02_convert-deepforest-bboxes-to-ttops.R`, which loops over all the bbox
   files that exist within the provided directory and saves a series of ttops files in a parallel
   directory.
3. Compute the accuracy of the tree detections by (a) matching the detected trees to the observed
   (field-measured) trees based on horizontal distance and height difference using a refined version
   of the methods [published
   here](https://besjournals.onlinelibrary.wiley.com/doi/10.1111/2041-210X.13860), and then (b)
   based on the matches, computing recall, precision, and F-score. This is performed by
   `workflow/03_compute-detection-accuracy.R`, which saves an accuracy stats file as a CSV
   (separately for each ttops file) into a specified folder. This script leans heavily on functions
   defined in the (in-development) ofo R package, which you will need to clone from GitHub and load
   at the top of the script using `devtools::load_all`, since it is not published on CRAN.
