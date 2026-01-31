import joblib
import numpy as np
import onnxmltools
from onnxmltools.convert.common.data_types import FloatTensorType
import onnxruntime as ort
import os

def convert():
    print("Loading models...")
    red_xgb = joblib.load('red_ball_xgb.joblib')
    red_lgbm = joblib.load('red_ball_lgbm.joblib')
    blue_xgb = joblib.load('blue_ball_xgb.joblib')
    blue_lgbm = joblib.load('blue_ball_lgbm.joblib')
    
    # Define input shapes
    red_input_dim = 1785
    blue_input_dim = 480
    
    # --- Red Models ---
    print("Converting Red XGBoost to ONNX...")
    initial_type_red = [('input', FloatTensorType([None, red_input_dim]))]
    onx_red_xgb = onnxmltools.convert_xgboost(red_xgb, initial_types=initial_type_red, target_opset=12)
    with open("red_ball_xgb.onnx", "wb") as f:
        f.write(onx_red_xgb.SerializeToString())
        
    print("Converting Red LightGBM to ONNX...")
    onx_red_lgbm = onnxmltools.convert_lightgbm(red_lgbm, initial_types=initial_type_red, target_opset=12, zipmap=False)
    with open("red_ball_lgbm.onnx", "wb") as f:
        f.write(onx_red_lgbm.SerializeToString())

    # --- Blue Models ---
    print("Converting Blue XGBoost to ONNX...")
    initial_type_blue = [('input', FloatTensorType([None, blue_input_dim]))]
    onx_blue_xgb = onnxmltools.convert_xgboost(blue_xgb, initial_types=initial_type_blue, target_opset=12)
    with open("blue_ball_xgb.onnx", "wb") as f:
        f.write(onx_blue_xgb.SerializeToString())
        
    print("Converting Blue LightGBM to ONNX...")
    onx_blue_lgbm = onnxmltools.convert_lightgbm(blue_lgbm, initial_types=initial_type_blue, target_opset=12, zipmap=False)
    with open("blue_ball_lgbm.onnx", "wb") as f:
        f.write(onx_blue_lgbm.SerializeToString())

    print("\nVerification...")
    def verify(path, input_dim, expected_classes):
        try:
            sess = ort.InferenceSession(path)
            dummy_input = np.random.randn(1, input_dim).astype(np.float32)
            outputs = sess.run(None, {'input': dummy_input})
            # For these converters:
            # Output 0 is usually label
            # Output 1 is usually probabilities (dict or array)
            probs = outputs[1]
            if isinstance(probs, list): # LightGBM might return list of dicts or array
                prob_shape = np.array(probs).shape
            elif isinstance(probs, dict):
                prob_shape = (1, len(probs))
            else:
                prob_shape = probs.shape
            
            print(f"Model {path} verified. Probabilities shape: {prob_shape} (Expected classes: {expected_classes})")
        except Exception as e:
            print(f"Verification failed for {path}: {e}")

    verify("red_ball_xgb.onnx", red_input_dim, 33)
    verify("red_ball_lgbm.onnx", red_input_dim, 33)
    verify("blue_ball_xgb.onnx", blue_input_dim, 16)
    verify("blue_ball_lgbm.onnx", blue_input_dim, 16)

    # Copy to assets
    assets_dir = "../flutter_app/assets/models/"
    if os.path.exists(assets_dir):
        import shutil
        print(f"Copying models to {assets_dir}...")
        shutil.copy("red_ball_xgb.onnx", os.path.join(assets_dir, "red_ball_xgb.onnx"))
        shutil.copy("red_ball_lgbm.onnx", os.path.join(assets_dir, "red_ball_lgbm.onnx"))
        shutil.copy("blue_ball_xgb.onnx", os.path.join(assets_dir, "blue_ball_xgb.onnx"))
        shutil.copy("blue_ball_lgbm.onnx", os.path.join(assets_dir, "blue_ball_lgbm.onnx"))

if __name__ == "__main__":
    convert()
