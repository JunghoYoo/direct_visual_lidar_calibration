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
  direct_visual_lidar_calibration_w_livox:noetic \
  python3 /tmp/convert_livox_bags.py /tmp/input_bags /tmp/converted_bags

# --- Preprocessing ---
docker run \
  -it \
  --rm \
  --net host \
  --gpus all \
  -e DISPLAY=$DISPLAY \
  -v $HOME/.Xauthority:/root/.Xauthority \
  -v $converted_path:/tmp/input_bags \
  -v $preprocessed_path:/tmp/preprocessed \
  direct_visual_lidar_calibration_w_livox:noetic \
  rosrun direct_visual_lidar_calibration preprocess -av \
  --points_topic /livox/points \
  --camera_model plumb_bob \
  --camera_intrinsic 1368.26257,1366.96008,967.16687,541.67474 \
  --camera_distortion_coeffs 0,0,0,0,0 \
  /tmp/input_bags /tmp/preprocessed

# --- Initial guess ---
docker run \
  --rm \
  --net host \
  --gpus all \
  -e DISPLAY=$DISPLAY \
  -v $HOME/.Xauthority:/root/.Xauthority \
  -v $preprocessed_path:/tmp/preprocessed \
  direct_visual_lidar_calibration_w_livox:noetic \
  rosrun direct_visual_lidar_calibration initial_guess_manual /tmp/preprocessed

# --- Fine registration ---
docker run \
  --rm \
  --net host \
  --gpus all \
  -e DISPLAY=$DISPLAY \
  -v $HOME/.Xauthority:/root/.Xauthority \
  -v $preprocessed_path:/tmp/preprocessed \
  direct_visual_lidar_calibration_w_livox:noetic \
  rosrun direct_visual_lidar_calibration calibrate /tmp/preprocessed

# --- Result inspection ---
docker run \
  --rm \
  --net host \
  --gpus all \
  -e DISPLAY=$DISPLAY \
  -v $HOME/.Xauthority:/root/.Xauthority \
  -v $preprocessed_path:/tmp/preprocessed \
  direct_visual_lidar_calibration_w_livox:noetic \
  rosrun direct_visual_lidar_calibration viewer /tmp/preprocessed
