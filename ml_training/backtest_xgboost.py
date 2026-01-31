import pandas as pd
import numpy as np
import joblib
import os
import xgboost as xgb
import train_xgboost

def run_backtest():
    """
    Executes an honest walk-forward backtest.
    For each test draw, the model is trained ONLY on data available BEFORE that draw.
    """
    print("Executing Honest XGBoost Backtest (Walk-Forward Validation)...")
    csv_path = os.path.join(os.path.dirname(__file__), 'ssq_data.csv')
    df = pd.read_csv(csv_path).sort_values('issue').reset_index(drop=True)
    
    test_count = 20
    hit_4_plus = 0
    hit_3 = 0
    blue_hits = 0
    
    print("-" * 80)
    print(f"{'Issue':<10} | {'Red Hits (Top 12)':<18} | {'Blue':<6} | {'Status'}")
    print("-" * 80)
    
    for i in range(len(df) - test_count, len(df)):
        # 1. Prepare Training Data (strictly before index i)
        df_train_full = df.iloc[:i].copy()
        
        # Red Window: Use full history
        red_window_size = len(df_train_full) - 15 if len(df_train_full) > 15 else len(df_train_full)
        df_red_train = df_train_full.tail(red_window_size + 15).copy().reset_index(drop=True)
        rg, rf, m, rs, ra = train_xgboost.calculate_features(df_red_train)
        
        # Blue Window: 1000
        blue_window_size = 1000
        df_blue_train = df_train_full.tail(blue_window_size + 15).copy().reset_index(drop=True)
        bg, bf = train_xgboost.prepare_blue_features(df_blue_train)
        
        seq_len = 15
        X_red, y_red = [], []
        X_blue, y_blue = [], []
        
        for j in range(seq_len, len(df_red_train)):
            feat = []
            for step in range(j - seq_len, j):
                feat.extend(rg[step]); feat.extend(rf[step]); feat.extend(m[step]); feat.extend(rs[step]); feat.extend(ra[step])
            for val in df_red_train[['red1','red2','red3','red4','red5','red6']].values[j]:
                X_red.append(feat); y_red.append(int(val) - 1)
        
        for j in range(seq_len, len(df_blue_train)):
            feat = []
            for step in range(j - seq_len, j):
                feat.extend(bg[step]); feat.extend(bf[step])
            X_blue.append(feat); y_blue.append(int(df_blue_train.iloc[j]['blue']) - 1)
            
        for c in range(33):
            if c not in y_red: X_red.append(np.zeros(len(X_red[0]))); y_red.append(c)
        for c in range(16):
            if c not in y_blue: X_blue.append(np.zeros(len(X_blue[0]))); y_blue.append(c)

        # 2. Train Local Models
        red_model = xgb.XGBClassifier(n_estimators=100, max_depth=6, learning_rate=0.1, objective='multi:softprob', num_class=33, tree_method='hist', random_state=42)
        red_model.fit(np.array(X_red), np.array(y_red))
        blue_model = xgb.XGBClassifier(n_estimators=100, max_depth=6, learning_rate=0.1, objective='multi:softprob', num_class=16, tree_method='hist', random_state=42)
        blue_model.fit(np.array(X_blue), np.array(y_blue))
        
        # 3. Predict for index i
        df_test_context = df.iloc[i-45:i+1].copy().reset_index(drop=True)
        rg_t, rf_t, m_t, rs_t, ra_t = train_xgboost.calculate_features(df_test_context)
        bg_t, bf_t = train_xgboost.prepare_blue_features(df_test_context)
        
        last_idx = len(df_test_context) - 1
        feat_red = []
        for step in range(last_idx - seq_len, last_idx):
            feat_red.extend(rg_t[step]); feat_red.extend(rf_t[step]); feat_red.extend(m_t[step]); feat_red.extend(rs_t[step]); feat_red.extend(ra_t[step])
        
        probs_red = red_model.predict_proba(np.array([feat_red]))[0]
        top12 = np.argsort(probs_red)[-12:] + 1
        actual_reds = set(df.iloc[i][['red1','red2','red3','red4','red5','red6']].values)
        hits = len(actual_reds & set(top12))
        
        feat_blue = []
        for step in range(last_idx - seq_len, last_idx):
            feat_blue.extend(bg_t[step]); feat_blue.extend(bf_t[step])
        probs_blue = blue_model.predict_proba(np.array([feat_blue]))[0]
        pred_blue = np.argmax(probs_blue) + 1
        actual_blue = int(df.iloc[i]['blue'])
        blue_hit = (pred_blue == actual_blue)
        
        status = ""
        if hits >= 4:
            hit_4_plus += 1
            status = "[SUCCESS 4+]"
        elif hits == 3:
            hit_3 += 1
            status = "[HIT 3]"
        if blue_hit: blue_hits += 1
        
        print(f"{df.iloc[i]['issue']:<10} | {hits}/6                | {'HIT' if blue_hit else 'MISS':<6} | {status}")

    print("-" * 80)
    print(f"Total Tests (Last {test_count} draws): {test_count}")
    print(f"Red 4+ Hits: {hit_4_plus} ({hit_4_plus/test_count*100:.1f}%)")
    print(f"Red 3+ Hit Rate: {(hit_4_plus + hit_3)/test_count*100:.1f}%")
    print(f"Blue Ball Hits: {blue_hits} ({blue_hits/test_count*100:.1f}%)")

if __name__ == '__main__':
    run_backtest()