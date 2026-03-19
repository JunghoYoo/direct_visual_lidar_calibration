FROM koide3/gtsam_docker:noetic

RUN apt-fast update \
  && apt-fast install -y --no-install-recommends \
  git \
  libomp-dev \
  libgoogle-glog-dev \
  libgflags-dev \
  libatlas-base-dev \
  libsuitesparse-dev \
  nlohmann-json3-dev \
  && apt-fast clean \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /root
RUN git clone https://github.com/ceres-solver/ceres-solver \
  && cd ceres-solver \
  && git checkout e47a42c2957951c9fafcca9995d9927e15557069 \
  && mkdir build \
  && cd build \
  && cmake .. -DBUILD_EXAMPLES=OFF -DBUILD_TESTING=OFF -DUSE_CUDA=OFF \
  && make -j$(nproc) \
  && make install \
  && rm -rf /root/ceres-solver

RUN test -f /usr/share/doc/kitware-archive-keyring/copyright || wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | tee /usr/share/keyrings/kitware-archive-keyring.gpg >/dev/null 
RUN echo 'deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ focal main' | tee /etc/apt/sources.list.d/kitware.list >/dev/null
RUN echo 'deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ focal-rc main' | tee -a /etc/apt/sources.list.d/kitware.list >/dev/null

RUN apt-get update \
  && apt-get upgrade -y \
  && apt-fast clean \
  && rm -rf /var/lib/apt/lists/*

# --- Workspace Setup ---
WORKDIR /root/catkin_ws/src

# 1. Copy the source code (Run build from the repo root!)
COPY . /root/catkin_ws/src/direct_visual_lidar_calibration

# --- Install Sophus (Header-only manual install) ---
RUN git clone https://github.com/strasdat/Sophus.git /tmp/Sophus && \
    cd /tmp/Sophus && \
    cp -r sophus /usr/local/include/ && \
    rm -rf /tmp/Sophus

# 2. Install original Livox SDK
RUN git clone https://github.com/Livox-SDK/Livox-SDK.git /tmp/Livox-SDK && \
    cd /tmp/Livox-SDK && mkdir -p build && cd build && \
    cmake .. -DCMAKE_POLICY_VERSION_MINIMUM=3.5 && \
    make -j$(nproc) && make install && \
    rm -rf /tmp/Livox-SDK

# 3. Clone additional dependencies
RUN git clone https://github.com/koide3/livox_to_pointcloud2.git && \
    git clone https://github.com/Livox-SDK/livox_ros_driver.git

# 4. Install ROS dependencies and build
WORKDIR /root/catkin_ws

RUN apt-fast update && \
    rosdep install -i --from-paths src --simulate | \
    sed '1d' | sed 's/apt-get install//' | sed 's/ //g' > /tmp/depends && \
    xargs apt-fast install --no-install-recommends -y < /tmp/depends && \
    apt-fast clean && \
    rm -rf /var/lib/apt/lists/*

RUN /bin/bash -c ". /opt/ros/noetic/setup.bash; catkin_make -j1 -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_BUILD_TYPE=Release"

RUN echo "#!/bin/bash" >> /ros_entrypoint.sh \
  && echo "set -e" >> /ros_entrypoint.sh \
  && echo "source /opt/ros/noetic/setup.bash" >> /ros_entrypoint.sh \
  && echo "source /root/catkin_ws/devel/setup.bash" >> /ros_entrypoint.sh \
  && echo 'exec "$@"' >> /ros_entrypoint.sh \
  && chmod a+x /ros_entrypoint.sh

WORKDIR /root/catkin_ws/src/direct_visual_lidar_calibration

ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["bash"]
