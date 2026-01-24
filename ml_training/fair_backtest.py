import os
os.environ["KERAS_BACKEND"] = "tensorflow"
import numpy as np
import pandas as pd
from tensorflow import keras
from train_model import calculate_features, build_ensemble_red_model

def run_fair_backtest():
    print("Executing Fair Backtest (Train on first 90%, Test on last 10%)...")
    df = pd.read_csv('ssq_data.csv').sort_values('issue').reset_index(drop=True)
    rg, rf, m, rs, ra = calculate_features(df)
    
    seq_len = 15
    split_idx = int(len(df) * 0.9)
    
    # Prepare training data
    X_e_train, X_b_train, X_r_train, y_r_train = [], [], [], []
    for i in range(seq_len, split_idx):
        # Using the "Skip One" logic as found in original code to keep it "fair" to the original design
        X_e_train.append(np.hstack([rg[i-seq_len:i], rf[i-seq_len:i], m[i-seq_len:i]]))
        X_b_train.append(rs[i-seq_len:i])
        X_r_train.append(ra[i-seq_len:i])
        target = np.zeros(33)
        for val in df[['red1','red2','red3','red4','red5','red6']].values[i]: target[int(val)-1] = 1
        y_r_train.append(target)
        
    X_e_train = np.array(X_e_train)
    X_b_train = np.array(X_b_train)
    X_r_train = np.array(X_r_train)
    y_r_train = np.array(y_r_train)
    
    print(f"Training on {len(y_r_train)} samples...")
    model = build_ensemble_red_model(seq_len, 99, 10, 10)
    model.fit([X_e_train, X_b_train, X_r_train], {'out_heatmap': y_r_train, 'out_zones': np.zeros((len(y_r_train), 3))}, 
              epochs=50, batch_size=32, verbose=0)
    
    # Test on the remaining 10%
    hit_3 = 0
    hit_4_plus = 0
    test_count = 0
    
    print("-" * 40)
    for i in range(split_idx, len(df)):
        X_e = np.hstack([rg[i-seq_len:i], rf[i-seq_len:i], m[i-seq_len:i]]).reshape(1, seq_len, 99)
        X_b = rs[i-seq_len:i].reshape(1, seq_len, 10)
        X_r = ra[i-seq_len:i].reshape(1, seq_len, 10)
        
        preds = model.predict([X_e, X_b, X_r], verbose=0)
        heatmap = preds[0][0]
        
        top_12 = np.argsort(heatmap)[-12:] + 1
        actual = set(df.iloc[i][['red1', 'red2', 'red3', 'red4', 'red5', 'red6']].values)
        hits = len(actual & set(top_12))
        
        if hits >= 4: hit_4_plus += 1
        elif hits == 3: hit_3 += 1
        test_count += 1
        
    print(f"Fair Backtest Results ({test_count} tests):")
    print(f"Hit 4+: {hit_4_plus} ({hit_4_plus/test_count*100:.1f}%)")
    print(f"Hit 3: {hit_3} ({hit_3/test_count*100:.1f}%)")
    print(f"Overall 3+: {(hit_4_plus+hit_3)/test_count*100:.1f}%")
    
    # Comparison with Random
    # Randomly pick 12 from 33, expected P(3+) is ~37.4%
    print(f"Expected Random 3+ Hit Rate (12 picks): ~37.4%")

if __name__ == '__main__':
    run_fair_backtest()
