import numpy as np

print("Testing AI models...\n")

# ── Test 1: Depth Anything V2 ──────────────────────────────
print("1. Loading Depth Anything V2...")
try:
    import tensorflow as tf

    interpreter = tf.lite.Interpreter(
        model_path="pandora_box/assets/models/depth_anything_v2_small.tflite"
    )
    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    print(f"   Input shape:  {input_details[0]['shape']}")
    print(f"   Input dtype:  {input_details[0]['dtype']}")
    print(f"   Output shape: {output_details[0]['shape']}")

    # Feed dummy image
    input_shape = input_details[0]['shape']
    dummy_input = np.random.rand(*input_shape).astype(np.float32)
    interpreter.set_tensor(input_details[0]['index'], dummy_input)
    interpreter.invoke()

    output = interpreter.get_tensor(output_details[0]['index'])
    print(f"   Output range: min={output.min():.3f} max={output.max():.3f}")
    print("   Depth Anything V2 works!\n")

except Exception as e:
    print(f"   Failed: {e}\n")


# ── Test 2: MediaPipe Segmentation ────────────────────────
print("2. Loading MediaPipe Segmentation...")
try:
    interpreter2 = tf.lite.Interpreter(
        model_path="pandora_box/assets/models/mediapipe_segmentation.tflite"
    )
    interpreter2.allocate_tensors()

    input_details2 = interpreter2.get_input_details()
    output_details2 = interpreter2.get_output_details()

    print(f"   Input shape:  {input_details2[0]['shape']}")
    print(f"   Input dtype:  {input_details2[0]['dtype']}")
    print(f"   Output shape: {output_details2[0]['shape']}")

    # Feed dummy image
    input_shape2 = input_details2[0]['shape']
    dummy_input2 = np.random.rand(*input_shape2).astype(np.float32)
    interpreter2.set_tensor(input_details2[0]['index'], dummy_input2)
    interpreter2.invoke()

    output2 = interpreter2.get_tensor(output_details2[0]['index'])
    print(f"   Output range: min={output2.min():.3f} max={output2.max():.3f}")
    print("   MediaPipe Segmentation works!\n")

except Exception as e:
    print(f"   Failed: {e}\n")

print("Done!")