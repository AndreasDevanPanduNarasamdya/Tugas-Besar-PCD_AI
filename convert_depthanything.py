import os
import urllib.request

os.makedirs("assets/models", exist_ok=True)

print("Downloading Depth Anything TFLite...")

url = "https://storage.googleapis.com/mediapipe-models/depth_estimator/depth_anything/float32/latest/depth_anything.tflite"

urllib.request.urlretrieve(
    url,
    "assets/models/depth_anything_v2_small.tflite"
)

size = os.path.getsize("assets/models/depth_anything_v2_small.tflite")
print(f"Done! File size: {size / 1024 / 1024:.1f} MB")