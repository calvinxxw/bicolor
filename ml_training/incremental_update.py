import os
import pandas as pd
import numpy as np
import xgboost as xgb
import joblib
from data_crawler import fetch_full_ssq_data
from train_xgboost import calculate_features, prepare_blue_features
import onnxmltools
from onnxmltools.convert.common.data_types import FloatTensorType

def incremental_update():
    # 1. Fetch the latest data
    print("Step 1: Fetching latest draw data...")
    try:
        df_new = fetch_full_ssq_data()
        if df_new is None:
            raise Exception("Crawler returned None")
        
        df_old = pd.read_csv('ssq_data.csv')
        
        df_combined = pd.concat([df_new, df_old]).drop_duplicates(subset=['issue'])
        df_combined['issue'] = df_combined['issue'].astype(int)
        df_combined = df_combined.sort_values('issue').reset_index(drop=True)
        df_combined.to_csv('ssq_data.csv', index=False)
        print(f"Dataset updated. Total records: {len(df_combined)}")
    except Exception as e:
        print(f"Crawl failed: {e}")
        return

    # 2. Prepare Features
    print("Step 2: Calculating features for retraining...")
    rg, rf, m, rs, ra = calculate_features(df_combined)
    bg, bf = prepare_blue_features(df_combined)
    
    seq_len = 15
    X_red, y_red = [], []
    X_blue, y_blue = [], []
    
    # We retrain on the whole thing or just a large window because XGBoost is fast
    for i in range(seq_len, len(df_combined)):
        red_feat = []
        for step in range(i - seq_len, i):
            red_feat.extend(rg[step])
            red_feat.extend(rf[step])
            red_feat.extend(m[step])
            red_feat.extend(rs[step])
            red_feat.extend(ra[step])
        X_red.append(red_feat)
        
        # Red targets (simplified approach: expanded for training)
        # For incremental, maybe we just want to train on the latest ones?
        # But XGBoost is so fast we can just retrain the expanded dataset.
        
    # For red balls, we'll expand the dataset like in train_xgboost.py
    X_red_expanded = []
    y_red_expanded = []
    for i in range(len(X_red)):
        for val in df_combined[['red1','red2','red3','red4','red5','red6']].values[i+seq_len]:
            X_red_expanded.append(X_red[i])
            y_red_expanded.append(int(val) - 1)
            
    X_red_expanded = np.array(X_red_expanded)
    y_red_expanded = np.array(y_red_expanded)

    for i in range(seq_len, len(df_combined)):
        blue_feat = []
        for step in range(i - seq_len, i):
            blue_feat.extend(bg[step])
            blue_feat.extend(bf[step])
        X_blue.append(blue_feat)
        y_blue.append(int(df_combined.iloc[i]['blue']) - 1)
        
    X_blue = np.array(X_blue)
    y_blue = np.array(y_blue)

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
    red_xgb.fit(X_red_expanded, y_red_expanded)
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

    # 4. Export to ONNX
    print("Step 4: Exporting to ONNX...")
    
    # Use skl2onnx/onnxmltools conversion logic
    import skl2onnx
    from onnxmltools.convert.xgboost.operator_converters.XGBoost import convert_xgboost
    from onnxmltools.convert.xgboost.shape_calculators.Classifier import calculate_xgboost_classifier_output_shapes
    
    skl2onnx.update_registered_converter(
        xgb.XGBClassifier, 'XGBClassifier',
        calculate_xgboost_classifier_output_shapes, convert_xgboost,
        options={'zipmap': [True, False, 'columns'], 'nocl': [True, False]}
    )

    onx_red = skl2onnx.convert_sklearn(red_xgb, initial_types=[('input', FloatTensorType([None, 1785]))],
                                      target_opset=12, options={'zipmap': False})
    with open("red_ball_xgb.onnx", "wb") as f:
        f.write(onx_red.SerializeToString())

    onx_blue = skl2onnx.convert_sklearn(blue_xgb, initial_types=[('input', FloatTensorType([None, 480]))],
                                        target_opset=12, options={'zipmap': False})
    with open("blue_ball_xgb.onnx", "wb") as f:
        f.write(onx_blue.SerializeToString())
    
    # Copy to assets
    import shutil
    shutil.copy("red_ball_xgb.onnx", "../flutter_app/assets/models/red_ball_xgb.onnx")
    shutil.copy("blue_ball_xgb.onnx", "../flutter_app/assets/models/blue_ball_xgb.onnx")
    
    print("Incremental Update Complete! Models deployed to Flutter.")

if __name__ == '__main__':
    incremental_update()