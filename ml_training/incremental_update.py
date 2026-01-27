import os
import pandas as pd
import numpy as np
import xgboost as xgb
import joblib
from data_crawler import fetch_full_ssq_data
from train_xgboost import calculate_features, prepare_blue_features
# import onnxmltools
# from onnxmltools.convert.common.data_types import FloatTensorType

def incremental_update():
    # 1. Fetch the latest data
    print("Step 1: Fetching latest draw data...")
    try:
        df_new = fetch_full_ssq_data()
        if df_new is None:
            raise Exception("Crawler returned None")
        
        csv_path = os.path.join(os.path.dirname(__file__), 'ssq_data.csv')
        df_old = pd.read_csv(csv_path)
        
        df_combined = pd.concat([df_new, df_old]).drop_duplicates(subset=['issue'])
        df_combined['issue'] = df_combined['issue'].astype(int)
        df_combined = df_combined.sort_values('issue').reset_index(drop=True)
        df_combined.to_csv(csv_path, index=False)
        print(f"Dataset updated. Total records: {len(df_combined)}")
    except Exception as e:
        print(f"Crawl failed: {e}")
        return

    # 2. Prepare Features
    print("Step 2: Preparing features with dual windows (Red: 50, Blue: 1000)...")
    
    # Red Training
    red_window_size = 50
    df_red = df_combined.tail(red_window_size + 15).copy().reset_index(drop=True)
    rg, rf, m, rs, ra = calculate_features(df_red)
    
    # Blue Training
    blue_window_size = 1000
    df_blue = df_combined.tail(blue_window_size + 15).copy().reset_index(drop=True)
    bg, bf = prepare_blue_features(df_blue)
    
    seq_len = 15
    X_red, y_red = [], []
    X_blue, y_blue = [], []
    
    # Red features
    for i in range(seq_len, len(df_red)):
        red_feat = []
        for step in range(i - seq_len, i):
            red_feat.extend(rg[step])
            red_feat.extend(rf[step])
            red_feat.extend(m[step])
            red_feat.extend(rs[step])
            red_feat.extend(ra[step])
        for val in df_red[['red1','red2','red3','red4','red5','red6']].values[i]:
            X_red.append(red_feat)
            y_red.append(int(val) - 1)
            
    # Blue features
    for i in range(seq_len, len(df_blue)):
        blue_feat = []
        for step in range(i - seq_len, i):
            blue_feat.extend(bg[step])
            blue_feat.extend(bf[step])
        X_blue.append(blue_feat)
        y_blue.append(int(df_blue.iloc[i]['blue']) - 1)
        
    # Ensure all classes are present
    for c in range(33):
        if c not in y_red:
            X_red.append(np.zeros(len(X_red[0])))
            y_red.append(c)
    for c in range(16):
        if c not in y_blue:
            X_blue.append(np.zeros(len(X_blue[0])))
            y_blue.append(c)

    X_red, y_red = np.array(X_red), np.array(y_red)
    X_blue, y_blue = np.array(X_blue), np.array(y_blue)

    # 3. Retrain Models
    print("Step 3: Retraining XGBoost models...")
    
    # Red Model
    red_xgb = xgb.XGBClassifier(
        n_estimators=100,
        max_depth=6,
        learning_rate=0.1,
        objective='multi:softprob',
        num_class=33,
        tree_method='hist',
        random_state=42
    )
    red_xgb.fit(X_red, y_red)
    joblib.dump(red_xgb, 'red_ball_xgb.joblib')
    print("Red Model Retrained.")

    # Blue Model
    blue_xgb = xgb.XGBClassifier(
        n_estimators=100,
        max_depth=6,
        learning_rate=0.1,
        objective='multi:softprob',
        num_class=16,
        tree_method='hist',
        random_state=42
    )
    blue_xgb.fit(X_blue, y_blue)
    joblib.dump(blue_xgb, 'blue_ball_xgb.joblib')
    print("Blue Model Retrained.")

    # 4. Export to ONNX and Deploy
    print("Step 4: Exporting to ONNX and Deploying to App...")
    import onnxmltools
    from onnxmltools.convert.common.data_types import FloatTensorType
    import shutil

    # Convert Red
    initial_type_red = [('input', FloatTensorType([None, 1785]))]
    onx_red = onnxmltools.convert_xgboost(red_xgb, initial_types=initial_type_red, target_opset=12)
    with open("red_ball_xgb.onnx", "wb") as f:
        f.write(onx_red.SerializeToString())

    # Convert Blue
    initial_type_blue = [('input', FloatTensorType([None, 480]))]
    onx_blue = onnxmltools.convert_xgboost(blue_xgb, initial_types=initial_type_blue, target_opset=12)
    with open("blue_ball_xgb.onnx", "wb") as f:
        f.write(onx_blue.SerializeToString())

    # Copy to Flutter assets
    # In GitHub Actions, the flutter_app dir exists, but we mainly want the file 
    # to be committed to ml_training/ so the app can download it via raw URL.
    asset_dir = os.path.join(os.path.dirname(__file__), '../flutter_app/assets/models/')
    if os.path.exists(asset_dir):
        shutil.copy("red_ball_xgb.onnx", os.path.join(asset_dir, "red_ball_xgb.onnx"))
        shutil.copy("blue_ball_xgb.onnx", os.path.join(asset_dir, "blue_ball_xgb.onnx"))
        print(f"Models deployed to {asset_dir}")
    else:
        print("Note: Flutter asset directory not found locally (expected in CI).")
    
    # Also ensure they are in the current dir for git add
    print("Models saved in ml_training/ for GitHub versioning.")
    
    print("Incremental Update Complete!")

if __name__ == '__main__':
    incremental_update()