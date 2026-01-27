import joblib
import numpy as np
import onnxmltools
from onnxmltools.convert.common.data_types import FloatTensorType
import onnxruntime as ort

def convert():
    print("Loading models...")
    red_model = joblib.load('red_ball_xgb.joblib')
    blue_model = joblib.load('blue_ball_xgb.joblib')
    
    # XGBoost Scikit-learn wrapper models can usually be converted 
    # directly by onnxmltools.convert_xgboost
    
    print("Converting Red Model to ONNX...")
    # input: 1785 features
    initial_type_red = [('input', FloatTensorType([None, 1785]))]
    onx_red = onnxmltools.convert_xgboost(red_model, initial_types=initial_type_red, target_opset=12)
    with open("red_ball_xgb.onnx", "wb") as f:
        f.write(onx_red.SerializeToString())
    print("Red ONNX saved.")

    print("Converting Blue Model to ONNX...")
    # input: 480 features
    initial_type_blue = [('input', FloatTensorType([None, 480]))]
    onx_blue = onnxmltools.convert_xgboost(blue_model, initial_types=initial_type_blue, target_opset=12)
    with open("blue_ball_xgb.onnx", "wb") as f:
        f.write(onx_blue.SerializeToString())
    print("Blue ONNX saved.")

    # Verification
    print("\nVerifying...")
    try:
        s_red = ort.InferenceSession("red_ball_xgb.onnx")
        # XGBoost ONNX output 0 is label, output 1 is probabilities
        r_red = s_red.run(None, {'input': np.random.randn(1, 1785).astype(np.float32)})
        print(f"Red Probabilities shape: {r_red[1].shape}") # Expected (1, 33) 
        
        s_blue = ort.InferenceSession("blue_ball_xgb.onnx")
        r_blue = s_blue.run(None, {'input': np.random.randn(1, 480).astype(np.float32)})
        print(f"Blue Probabilities shape: {r_blue[1].shape}") # Expected (1, 16)
    except Exception as e:
        print(f"Verification failed: {e}")

if __name__ == "__main__":
    convert()
