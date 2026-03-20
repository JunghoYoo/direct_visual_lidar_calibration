#!/bin/bash

bag_path=$(realpath livox_mid360_ros1)
converted_path=$(realpath livox_mid360_ros1_converted)
preprocessed_path=$(realpath livox_mid360_ros1_preprocessed)

# --- Convert livox_ros_driver2/CustomMsg bags to sensor_msgs/PointCloud2 ---
docker run \
  --rm \
  -v $bag_path:/tmp/input_bags \
  -v $converted_path:/tmp/converted_bags \
  -v $(realpath convert_livox_bags.py):/tmp/convert_livox_bags.py \
  direct_visual_lidar_calibration_w_livox_superglue:noetic \
  python3 /tmp/convert_livox_bags.py /tmp/input_bags /tmp/converted_bags

# --- Preprocessing ---
#--camera_model:  Camera projection model can be plumb_bob, fisheye, atan, omnidir, or equirectangular
#--camera_intrinsic	Camera intrinsic parameters: fx,fy,cx,cy(,xi) (Don't put spaces between values)
#--camera_distortion_coeffs	Camera distortion parameters [k1,k2,p1,p2,k3] (Don't put spaces between values)
docker run \
  -it \
  --rm \
  --net host \
  --gpus all \
  -e DISPLAY=$DISPLAY \
  -v $HOME/.Xauthority:/root/.Xauthority \
  -v $converted_path:/tmp/input_bags \
  -v $preprocessed_path:/tmp/preprocessed \
  direct_visual_lidar_calibration_w_livox_superglue:noetic \
  rosrun direct_visual_lidar_calibration preprocess -av \
  --points_topic /livox/points \
  --camera_model plumb_bob \
  --camera_intrinsic 1332.5746708748031,1331.097793310254,934.0144678539411,524.702399348833 \
  --camera_distortion_coeffs 0.06639705926060822,-0.13985936379724995,0.002733085020597033,-0.009918777322333138,0.0 \
  /tmp/input_bags /tmp/preprocessed

# --- Initial guess (find match with super glue) #1---
# ┌──────────────────────┬────────────────┬───────────────────────────────────────────────────────┐                        
# │      Parameter       │    Current     │                      Suggestion                       │
# ├──────────────────────┼────────────────┼───────────────────────────────────────────────────────┤                        
# │ --superglue          │ outdoor        │ try indoor if it's an indoor scene                    │
# ├──────────────────────┼────────────────┼───────────────────────────────────────────────────────┤
# │ --max_keypoints      │ -1 (unlimited) │ try 1024 or 2048 to limit to strongest keypoints      │                        
# ├──────────────────────┼────────────────┼───────────────────────────────────────────────────────┤                        
# │ --keypoint_threshold │ 0.05           │ lower (e.g. 0.01) → more keypoints detected           │                        
# ├──────────────────────┼────────────────┼───────────────────────────────────────────────────────┤                        
# │ --match_threshold    │ 0.01           │ raise (e.g. 0.2) → stricter, fewer but better matches │
# ├──────────────────────┼────────────────┼───────────────────────────────────────────────────────┤                        
# │ --show_keypoints     │ off            │ add flag to visualize keypoints in output images      │
# ├──────────────────────┼────────────────┼───────────────────────────────────────────────────────┤                        
# │ --force_cpu          │ false          │ add flag to force CPU if GPU results are inconsistent │
# └──────────────────────┴────────────────┴───────────────────────────────────────────────────────┘  
#  rotate_camera 0, 90, 180, 270. (2d image rotation in degree, default: 0)

docker run \
  --rm \
  --net host \
  --gpus all \
  -e DISPLAY=$DISPLAY \
  -v $HOME/.Xauthority:/root/.Xauthority \
  -v $preprocessed_path:/tmp/preprocessed \
  direct_visual_lidar_calibration_w_livox_superglue:noetic \
  rosrun direct_visual_lidar_calibration find_matches_superglue.py /tmp/preprocessed \
  --superglue outdoor \
  --max_keypoints 1024 \
  --keypoint_threshold 0.2 \
  --match_threshold 0.25 \
  --nms_radius 4 \
  --sinkhorn_iterations 50 \
  --rotate_camera 0 \
  --show_keypoints

# --- Initial guess (super glue) #2---
docker run \
  --rm \
  --net host \
  --gpus all \
  -e DISPLAY=$DISPLAY \
  -v $HOME/.Xauthority:/root/.Xauthority \
  -v $preprocessed_path:/tmp/preprocessed \
  direct_visual_lidar_calibration_w_livox_superglue:noetic \
  rosrun direct_visual_lidar_calibration initial_guess_auto /tmp/preprocessed 
  
# --- Fine registration ---
docker run \
  --rm \
  --net host \
  --gpus all \
  -e DISPLAY=$DISPLAY \
  -v $HOME/.Xauthority:/root/.Xauthority \
  -v $preprocessed_path:/tmp/preprocessed \
  direct_visual_lidar_calibration_w_livox_superglue:noetic \
  rosrun direct_visual_lidar_calibration calibrate /tmp/preprocessed

# --- Result inspection ---
docker run \
  --rm \
  --net host \
  --gpus all \
  -e DISPLAY=$DISPLAY \
  -v $HOME/.Xauthority:/root/.Xauthority \
  -v $preprocessed_path:/tmp/preprocessed \
  direct_visual_lidar_calibration_w_livox_superglue:noetic \
  rosrun direct_visual_lidar_calibration viewer /tmp/preprocessed
