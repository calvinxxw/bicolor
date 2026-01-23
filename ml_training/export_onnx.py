import os
os.environ["KERAS_BACKEND"] = "tensorflow"
import tensorflow as tf
import tf2onnx
import onnx

def convert_model(keras_path, onnx_path):
    print(f"Loading {keras_path}...")
    model = tf.keras.models.load_model(keras_path, safe_mode=False)
    
    # Define input signature
    spec = (tf.TensorSpec(model.input_shape, tf.float32, name="input"),)
    
    print(f"Converting {keras_path} to ONNX...")
    model_proto, _ = tf2onnx.convert.from_keras(model, input_signature=spec, opset=13)
    
    os.makedirs(os.path.dirname(onnx_path), exist_ok=True)
    onnx.save(model_proto, onnx_path)
    print(f"Saved to {onnx_path}")

if __name__ == "__main__":
    # Convert Red Model
    convert_model("red_ball_model.keras", "../flutter_app/assets/models/red_ball_model.onnx")
    # Convert Blue Model
    convert_model("blue_ball_model.keras", "../flutter_app/assets/models/blue_ball_model.onnx")
