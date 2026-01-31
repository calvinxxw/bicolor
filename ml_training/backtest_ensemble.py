import pandas as pd
import numpy as np
import xgboost as xgb
import lightgbm as lgb
import os
from train_xgboost import calculate_features, prepare_blue_features

def run_backtest():
    print("Loading data for Backtest...")
    df = pd.read_csv('ssq_data.csv').sort_values('issue').reset_index(drop=True)
    
    seq_len = 15
    test_draws = 20
    
    red_hit_4_plus = 0
    red_hit_3 = 0
    blue_hits = 0
    
    print(f"Starting Walk-forward Backtest (last {test_draws} draws)...")
    
    for i in range(len(df) - test_draws, len(df)):
        issue = df.iloc[i]['issue']
        
        # Training data: everything before i
        df_train = df.iloc[:i].copy()
        
        # Red Features
        red_window = 50
        df_red_train = df_train.tail(red_window + seq_len).copy().reset_index(drop=True)
        rg, rf, m, rs, ra = calculate_features(df_red_train)
        
        X_red, y_red = [], []
        for j in range(seq_len, len(df_red_train)):
            red_feat = []
            for step in range(j - seq_len, j):
                red_feat.extend(rg[step]); red_feat.extend(rf[step]); red_feat.extend(m[step]); red_feat.extend(rs[step]); red_feat.extend(ra[step])
            for val in df_red_train[['red1','red2','red3','red4','red5','red6']].values[j]:
                X_red.append(red_feat); y_red.append(int(val) - 1)
        
        # Ensure classes
        for c in range(33):
            if c not in y_red: X_red.append(np.zeros(len(X_red[0]))); y_red.append(c)
        X_red, y_red = np.array(X_red), np.array(y_red)
        
        # Train Red Ensemble
        r_xgb = xgb.XGBClassifier(n_estimators=50, max_depth=6, learning_rate=0.1, objective='multi:softprob', num_class=33, tree_method='hist', random_state=42)
        r_xgb.fit(X_red, y_red)
        r_lgbm = lgb.LGBMClassifier(n_estimators=50, max_depth=6, learning_rate=0.1, objective='multiclass', num_class=33, random_state=42, verbose=-1)
        r_lgbm.fit(X_red, y_red)
        
        # Predict Red
        df_red_test = df.iloc[i-seq_len:i].copy().reset_index(drop=True)
        # We need calculate_features on a segment including the test row to get features for prediction
        df_red_combined = pd.concat([df_train, df.iloc[i:i+1]]).tail(red_window + seq_len + 1).copy().reset_index(drop=True)
        rg_t, rf_t, m_t, rs_t, ra_t = calculate_features(df_red_combined)
        
        test_red_feat = []
        # Index of prediction is the last row of df_red_combined
        pred_idx = len(df_red_combined) - 1
        for step in range(pred_idx - seq_len, pred_idx):
            test_red_feat.extend(rg_t[step]); test_red_feat.extend(rf_t[step]); test_red_feat.extend(m_t[step]); test_red_feat.extend(rs_t[step]); test_red_feat.extend(ra_t[step])
        
        X_test_red = np.array([test_red_feat])
        p_red_xgb = r_xgb.predict_proba(X_test_red)[0]
        p_red_lgbm = r_lgbm.predict_proba(X_test_red)[0]
        p_red = (p_red_xgb + p_red_lgbm) / 2.0
        
        # Evaluate Red
        top12 = np.argsort(p_red)[-12:] + 1
        actual_reds = set(df.iloc[i][['red1','red2','red3','red4','red5','red6']].values)
        hits = len(actual_reds & set(top12))
        if hits >= 4: red_hit_4_plus += 1
        if hits >= 3: red_hit_3 += 1
        
        # Blue Ensemble
        blue_window = 1000
        df_blue_train = df_train.tail(blue_window + seq_len).copy().reset_index(drop=True)
        bg, bf = prepare_blue_features(df_blue_train)
        
        X_blue, y_blue = [], []
        for j in range(seq_len, len(df_blue_train)):
            blue_feat = []
            for step in range(j - seq_len, j):
                blue_feat.extend(bg[step]); blue_feat.extend(bf[step])
            X_blue.append(blue_feat); y_blue.append(int(df_blue_train.iloc[j]['blue']) - 1)
        
        for c in range(16):
            if c not in y_blue: X_blue.append(np.zeros(len(X_blue[0]))); y_blue.append(c)
        X_blue, y_blue = np.array(X_blue), np.array(y_blue)
        
        b_xgb = xgb.XGBClassifier(n_estimators=50, max_depth=6, learning_rate=0.1, objective='multi:softprob', num_class=16, tree_method='hist', random_state=42)
        b_xgb.fit(X_blue, y_blue)
        b_lgbm = lgb.LGBMClassifier(n_estimators=50, max_depth=6, learning_rate=0.1, objective='multiclass', num_class=16, random_state=42, verbose=-1)
        b_lgbm.fit(X_blue, y_blue)
        
        # Predict Blue
        df_blue_combined = pd.concat([df_train, df.iloc[i:i+1]]).tail(blue_window + seq_len + 1).copy().reset_index(drop=True)
        bg_t, bf_t = prepare_blue_features(df_blue_combined)
        
        test_blue_feat = []
        pred_idx_b = len(df_blue_combined) - 1
        for step in range(pred_idx_b - seq_len, pred_idx_b):
            test_blue_feat.extend(bg_t[step]); test_blue_feat.extend(bf_t[step])
        
        X_test_blue = np.array([test_blue_feat])
        p_blue_xgb = b_xgb.predict_proba(X_test_blue)[0]
        p_blue_lgbm = b_lgbm.predict_proba(X_test_blue)[0]
        p_blue = (p_blue_xgb + p_blue_lgbm) / 2.0
        
        # Evaluate Blue
        top3_blue = np.argsort(p_blue)[-3:] + 1
        actual_blue = df.iloc[i]['blue']
        if actual_blue in top3_blue: blue_hits += 1
        
        print(f"Draw {issue}: Red Hits: {hits}, Blue Hit: {actual_blue in top3_blue}")

    print("\n" + "="*30)
    print(f"Ensemble Backtest Summary ({test_draws} draws):")
    print(f"Red 4+ Hit Rate: {red_hit_4_plus/test_draws*100:.1f}%")
    print(f"Red 3+ Hit Rate: {red_hit_3/test_draws*100:.1f}%")
    print(f"Blue (Top-3) Hit Rate: {blue_hits/test_draws*100:.1f}%")
    print("="*30)

if __name__ == '__main__':
    run_backtest()
