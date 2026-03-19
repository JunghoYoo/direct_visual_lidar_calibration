# Targetless Lidar Camera Calibration

**Date:** March 19, 2026
**Hardware:** Intel RealSense D435 (RGB) & Livox Mid-360

## 📌 Overview

This project performs extrinsic calibration between a camera and a LiDAR without predefined target (such as checkerboard or AprilTag).
I didn't use SuperGlue(Automatic matching).

## 🛠 Prerequisites & Environment

* **OS:** Ubuntu 20.04 (Noetic) inside Docker
* **Toolbox:** [direct_visual_lidar_calibration](https://github.com/JunghoYoo/direct_visual_lidar_calibration)
* **Sensor Drivers:** `realsense2_camera`, `livox_ros_driver2`, `livox_to_pointcloud2`
* **Camera Intrinsics:** `Kalibr` or factory calibration information

## 1. Docker build

Native koide3/direct_visual_lidar_calibration docker image only support `pointcloud2` format from Lidar.
However, Livox lidar with default configuration uses CustomMsg (e.g. xfer_format = 1 in livox_ros_driver2).
So, I added livox_to_pointcloud2 code to convert CustomMsg typed rosbag into PointCloud2 typed rosbag.

## 2. Data Collection

Keep the sensor at stable object. Don't hold sensors because result pointcloud during rosbag recording will be blurry.
The camera and Lidar must be securely integrated with rigid fixture.
Depending on frequency of lidar, each rosbag can be 10~60secs.
Recorded scene should be static.
Inspect corners before you choose the scene for rosbag recording. Intensity of reflected laser will varied with respect on object's physical property.
When you choose initial guess on image, it will be black and white image. So, if corners are too dark to recognize the exact location on B&W image, that corner is not good for matching.
Also, baseboard near floor, ceiling molding, and window molding are not good matching points.
Depending on specific type of model, the most reliable distance or type of target may vary.
After data collection, all rosbag files should be saved in 'docker/noetic/livox_mid360_ros1' 

## 3. Full commands

Change camera intrinsic information at line 30 and 31 in script below.

```bash
# ./docker/noetic/run_calibration_w_livox_to_pointcloud2.sh
# Line 30 and 31
  --camera_intrinsic 1368.26257,1366.96008,967.16687,541.67474 \
  --camera_distortion_coeffs 0,0,0,0,0 \
```

run script for full pipeline 

```bash
./docker/noetic/run_calibration_w_livox_to_pointcloud2.sh
```

## 4. initial guess (Manual matching without SuperGlue)

1. Right click a 3D point on the point cloud and a corresponding 2D point on the image
2. Click Add picked points button
3. Repeat 1 and 2 for several points (At least three points. The more the better.)
4. Click Estimate button to obtain an initial guess of the LiDAR-camera transformation
5. Check if the image projection result is fine by changing blend_weight
6. Click Save button to save the initial guess
7. Move to the next rosbag

### Calibration Summaries

```bash
Manual initial guess result found
--- T_lidar_camera ---
-9.99286e-08     0.402522     0.915411            0
          -1 -9.99286e-08 -5.55112e-17            0
-3.88578e-16    -0.915411     0.402522            0
           0            0            0            1
Calibration result found
--- T_lidar_camera ---
 -0.00878801     0.436113     0.899849    0.0667385
   -0.999961  -0.00342455    -0.008106    0.0324764
-0.000453553    -0.899885     0.436126    -0.132306
           0            0            0            1
```

* 📄 [logs](log.txt)

## 5. Engineering Insights

1. Low RANSAC inliers: 4 / 18 (22%) — a good calibration typically sees >50% inliers. This suggests weak point-to-pixel correspondences, likely due to the initial guess or data quality.
2. Fine registration barely converged — cost went from 5.691 to 5.646, less than 1% reduction. A well-converged calibration sees larger cost drops. The gradient g is still ~0.02–0.65 at the end, which is high.                        
3. Multiple line search failures — the optimizer struggled to find a descent direction, indicating the solution may be stuck in a local minimum.                                                                                                                                                                                                   
4. Factory calibration: If the camera has real lens distortion (even minor), this significantly degrades calibration accuracy. Plugging in real distortion coefficients would likely improve the result substantially.    


## 🔗 References

* [direct visual_lidar calibration](https://koide3.github.io/direct_visual_lidar_calibration/)
