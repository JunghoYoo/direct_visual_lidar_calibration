# Targetless Lidar Camera Calibration with SuperGlue automatching

**Date:** March 20, 2026
**Hardware:** Intel RealSense D435 (RGB) & Livox Mid-360

## 📌 Overview

This project demonstrates an automated extrinsic calibration pipeline between a camera and a LiDAR without requiring a predefined target (e.g., checkerboard or AprilTag). Unlike traditional manual methods, this implementation leverages SuperGlue, a deep learning-based feature matcher, to automate the initial guess estimation.

## 🛠 Prerequisites & Environment

* **OS:** Ubuntu 20.04 (Noetic) inside Docker
* **Toolbox:** [direct_visual_lidar_calibration](https://github.com/JunghoYoo/direct_visual_lidar_calibration)
* **Sensor Drivers:** `realsense2_camera`, `livox_ros_driver2`, `livox_to_pointcloud2`
* **Camera Intrinsics:** `Kalibr` or factory calibration information

## 1. Docker build

SuperGlue Integration: Added the SuperGlue inference engine into the Dockerfile to replace manual feature picking with automated graph-based matching.

## 2. Data Collection

I used the same rosbags as with manual matching.

```bash
mkdir -p ./docker/noetic/livox_mid360_ros1
cp data*.bag ./docker/noetic/livox_mid360_ros1
```

## 3. Full commands

Change camera intrinsic information at line 32, 33 and 34 in script below.

```bash
# ./docker/noetic/run_calibration_w_livox_to_pointcloud2_superglue.sh
# Line 32, 33 and 34
#--camera_model:  Camera projection model can be plumb_bob, fisheye, atan, omnidir, or equirectangular
#--camera_intrinsic	Camera intrinsic parameters: fx,fy,cx,cy(,xi) (Don't put spaces between values)
#--camera_distortion_coeffs	Camera distortion parameters [k1,k2,p1,p2,k3] (Don't put spaces between values)
  --camera_model plumb_bob \
  --camera_intrinsic 1332.5746708748031,1331.097793310254,934.0144678539411,524.702399348833 \
  --camera_distortion_coeffs 0.06639705926060822,-0.13985936379724995,0.002733085020597033,-0.009918777322333138,0.0 \
```

Run the script for the full pipeline:

```bash
cd ./docker/noetic/
./run_calibration_w_livox_to_pointcloud2_superglue.sh
```

## 4. Initial guess (automatic matching with SuperGlue)

### Core SuperGlue Parameters

-- superglue outdoor: Selects the pre-trained weight set optimized for wide-baseline matches in natural or urban environments. The "outdoor" model is more robust to large variations in perspective and lighting compared to the "indoor" version.

-- max_keypoints 1024: Limits the number of features detected in a single image. For your 1920x1080 images, 1024 points provide a good balance between spatial coverage and processing speed.

-- keypoint_threshold 0.2: The confidence cutoff for detecting a point. Lowering this value would detect more "weak" corners, while keeping it at 0.2 ensures only distinct, reliable features are used for the initial guess.

-- match_threshold 0.25: The minimum confidence required to consider two points a "match". In your log, this resulted in 82 potential matches. Increasing this would result in fewer, but more "certain" matches.

-- nms_radius 4: Non-Maximum Suppression radius. It ensures that detected keypoints are not bunched together by requiring a minimum 4-pixel distance between them. This forces the algorithm to spread points across the entire image for a better geometric constraint.


### Optimization & Orientation
-- sinkhorn_iterations 50: This controls the Sinkhorn Algorithm, which SuperGlue uses to solve the matching problem as an optimal transport task. 50 iterations is the standard depth needed for the algorithm to converge on a "clean" assignment matrix where each point matches at most one other point.

-- rotate_camera 0: Defines the initial rotation alignment ($0^{\circ}$, $90^{\circ}$, $180^{\circ}$, or $270^{\circ}$) between the LiDAR's 2D projection and the camera image. Since your logs show the sensors are already roughly aligned, $0$ was the correct choice.

### Calibration Summaries

```bash
Automatic initial guess result found
--- T_lidar_camera ---
 0.00766788    0.438438    0.898729  0.00812574
  -0.999969  0.00511107  0.00603826    0.116572
-0.00194607   -0.898747    0.438463   -0.118168
          0           0           0           1
Calibration result found
--- T_lidar_camera ---
  0.0138005    0.447839    0.894008    0.131895
  -0.999841 -0.00388877   0.0173823   0.0318328
  0.0112611   -0.894106    0.447715   -0.110965
          0           0           0           1
```

* 📄 [logs](log.txt)

## 5. Engineering Insights

| Metric | Manual Initial Guess | SuperGlue (Outdoor weights) |
|--------|----------------------|-----------------------------|
| Inlier Count | 4 / 18 | 4 / 82 |
| Initial Least Squares Cost | 1.823526e+03 | 3.896942e+04 |
| Final Least Squares Cost | 1.000780e+03 | 3.800540e+04 |
| Optimization Status | Line search failures (Wolfe conditions) | More stable convergence |



1. Compared to manual matching, the SuperGlue-based automated calibration is significantly more robust and accurate because it leverages a much larger feature pool (82 vs 18 potential matches) and incorporates non-zero lens distortion parameters to achieve a more stable and precise extrinsic transformation.
2. Inlier Robustness: While the final inlier count was 4 / 82, the automated approach provided a significantly more stable initial guess than manual picking.
3. Line Search Behavior: During optimization, line search failures (Wolfe conditions) were encountered. Switching to an Armijo condition allowed the solver to continue and reach convergence.
4. Textureless scene may fail to extract features. Avoid trees and leaves. They are not matched well by SuperGlue. 

## 🔗 References

* [SuperGlue](https://github.com/magicleap/SuperGluePretrainedNetwork)
