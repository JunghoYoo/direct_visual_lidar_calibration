bag_path=$(realpath livox_ros1)
preprocessed_path=$(realpath livox_ros1_preprocessed)

# Preprocessing
docker run \
  -it \
  --rm \
  --net host \
  --gpus all \
  -e DISPLAY=$DISPLAY \
  -v $HOME/.Xauthority:/root/.Xauthority \
  -v $bag_path:/tmp/input_bags \
  -v $preprocessed_path:/tmp/preprocessed \
  koide3/direct_visual_lidar_calibration:noetic \
  rosrun direct_visual_lidar_calibration preprocess -av \
  --camera_model plumb_bob \
  --camera_intrinsic 1452.711762456289,1455.877531619469,1265.25895179213,1045.818593664107 \
  --camera_distortion_coeffs -0.04203564850455424,0.0873170980751213,0.002386381727224478,0.005629700706305988,-0.04251149335870252 \
  /tmp/input_bags /tmp/preprocessed

# Initial guess
docker run \
  --rm \
  --net host \
  --gpus all \
  -e DISPLAY=$DISPLAY \
  -v $HOME/.Xauthority:/root/.Xauthority \
  -v $preprocessed_path:/tmp/preprocessed \
  koide3/direct_visual_lidar_calibration:noetic \
  rosrun direct_visual_lidar_calibration initial_guess_manual /tmp/preprocessed

# Fine registration
docker run \
  --rm \
  --net host \
  --gpus all \
  -e DISPLAY=$DISPLAY \
  -v $HOME/.Xauthority:/root/.Xauthority \
  -v $preprocessed_path:/tmp/preprocessed \
  koide3/direct_visual_lidar_calibration:noetic \
  rosrun direct_visual_lidar_calibration calibrate /tmp/preprocessed

# Result inspection
docker run \
  --rm \
  --net host \
  --gpus all \
  -e DISPLAY=$DISPLAY \
  -v $HOME/.Xauthority:/root/.Xauthority \
  -v $preprocessed_path:/tmp/preprocessed \
  koide3/direct_visual_lidar_calibration:noetic \
  rosrun direct_visual_lidar_calibration viewer /tmp/preprocessed

