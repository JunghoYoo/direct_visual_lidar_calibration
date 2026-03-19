#!/usr/bin/env python3
"""
Convert bags containing livox_ros_driver2/CustomMsg on /livox/lidar to
bags containing sensor_msgs/PointCloud2 on /livox/points.

The v1 (livox_ros_driver) and v2 (livox_ros_driver2) CustomMsg definitions
are structurally identical, so we deserialize using the v1 class.
"""
import os
import sys
import glob
import struct

import rosbag
from sensor_msgs.msg import CameraInfo, PointCloud2, PointField
from livox_ros_driver.msg import CustomMsg as LivoxMsg

LIVOX_TOPIC = "/livox/lidar"
POINTS_TOPIC = "/livox/points"
POINT_STEP = 22  # x,y,z (12) + t (4) + intensity (4) + tag (1) + line (1)

FIELDS = [
    PointField("x",         0,  PointField.FLOAT32, 1),
    PointField("y",         4,  PointField.FLOAT32, 1),
    PointField("z",         8,  PointField.FLOAT32, 1),
    PointField("t",         12, PointField.UINT32,  1),
    PointField("intensity", 16, PointField.FLOAT32, 1),
    PointField("tag",       20, PointField.UINT8,   1),
    PointField("line",      21, PointField.UINT8,   1),
]


def to_pointcloud2(livox_msg):
    n = livox_msg.point_num
    data = bytearray(n * POINT_STEP)
    for i, p in enumerate(livox_msg.points):
        off = i * POINT_STEP
        struct.pack_into("<fff", data, off, p.x, p.y, p.z)
        struct.pack_into("<I",   data, off + 12, p.offset_time)
        struct.pack_into("<f",   data, off + 16, float(p.reflectivity))
        data[off + 20] = p.tag
        data[off + 21] = p.line

    pc2 = PointCloud2()
    pc2.header = livox_msg.header
    pc2.height = 1
    pc2.width = n
    pc2.fields = FIELDS
    pc2.is_bigendian = False
    pc2.point_step = POINT_STEP
    pc2.row_step = n * POINT_STEP
    pc2.data = bytes(data)
    pc2.is_dense = True
    return pc2


def get_image_resolution(inbag):
    for _, msg, _ in inbag.read_messages(topics=["/camera/color/camera_info"]):
        return msg.width, msg.height
    return None, None


def convert_bag(input_path, output_path):
    with rosbag.Bag(input_path) as inbag, rosbag.Bag(output_path, "w") as outbag:
        w, h = get_image_resolution(inbag)
        res_str = f"{w}x{h}" if w is not None else "unknown"
        print(f"  {os.path.basename(input_path)} -> {os.path.basename(output_path)}  image: {res_str}")
        for topic, msg, t in inbag.read_messages(raw=True):
            if topic == LIVOX_TOPIC:
                livox_msg = LivoxMsg()
                livox_msg.deserialize(msg[1])
                outbag.write(POINTS_TOPIC, to_pointcloud2(livox_msg), t)
            else:
                outbag.write(topic, msg, t, raw=True)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} <input_dir> <output_dir>")
        sys.exit(1)

    input_dir, output_dir = sys.argv[1], sys.argv[2]
    os.makedirs(output_dir, exist_ok=True)

    bags = sorted(glob.glob(os.path.join(input_dir, "*.bag")))
    if not bags:
        print(f"No .bag files found in {input_dir}")
        sys.exit(1)

    print(f"Converting {len(bags)} bag(s)...")
    for bag_path in bags:
        out_path = os.path.join(output_dir, os.path.basename(bag_path))
        convert_bag(bag_path, out_path)
    print("Done.")
