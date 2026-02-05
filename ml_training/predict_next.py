import pandas as pd
import numpy as np
import joblib
import os
import xgboost as xgb
import lightgbm as lgb

def calculate_ac_value(reds):
    diffs = set()
    for i in range(len(reds)):
        for j in range(i + 1, len(reds)):
            diffs.add(abs(reds[i] - reds[j]))
    return len(diffs) - (len(reds) - 1)

def calculate_features_single(df_window):
    df = df_window.copy().reset_index(drop=True)
    num_samples = len(df)
    red_cols = ['red1', 'red2', 'red3', 'red4', 'red5', 'red6']
    primes = {2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31}
    
    red_gaps = np.zeros((num_samples, 33))
    red_freqs = np.zeros((num_samples, 33))
    momentum = np.zeros((num_samples, 33))
    red_stats = np.zeros((num_samples, 10))
    red_affinity = np.zeros((num_samples, 10))
    
    current_red_gaps = np.zeros(33)
    co_matrix = np.zeros((34, 34))
    
    for i in range(num_samples):
        red_gaps[i] = current_red_gaps
        row = df.iloc[i]
        reds = sorted([int(row[col]) for col in red_cols])
        
        if i > 0:
            w30, w5 = df.iloc[max(0, i-30):i], df.iloc[max(0, i-5):i]
            for num in range(1, 34):
                red_freqs[i, num-1] = (w30[red_cols] == num).any(axis=1).sum() / 30.0
                momentum[i, num-1] = (w5[red_cols] == num).any(axis=1).sum() / 5.0
            
            prev_reds = sorted([int(df.iloc[i-1][col]) for col in red_cols])
            red_stats[i, 0] = sum(prev_reds) / 200.0
            red_stats[i, 1] = calculate_ac_value(prev_reds) / 10.0
            red_stats[i, 2] = len([n for n in prev_reds if n % 2 != 0]) / 6.0
            red_stats[i, 3] = len([n for n in prev_reds if n > 16]) / 6.0
            red_stats[i, 4] = len([n for n in prev_reds if n in primes]) / 6.0
            red_stats[i, 5] = len([n for n in prev_reds if 1 <= n <= 11]) / 6.0
            red_stats[i, 6] = len([n for n in prev_reds if 12 <= n <= 22]) / 6.0
            red_stats[i, 7] = len([n for n in prev_reds if 23 <= n <= 33]) / 6.0
            red_stats[i, 8] = (max(prev_reds) - min(prev_reds)) / 32.0
            consec, curr_max = 1, 1
            for j in range(len(prev_reds)-1):
                if prev_reds[j+1] == prev_reds[j] + 1: consec += 1
                else: curr_max, consec = max(curr_max, consec), 1
            red_stats[i, 9] = max(curr_max, consec) / 6.0

            for idx in range(10):
                anchor = (idx * 3) + 1
                red_affinity[i, idx] = sum([co_matrix[anchor, p] for p in prev_reds]) / 50.0

        for num in range(1, 34):
            if num in reds: current_red_gaps[num-1] = 0
            else: current_red_gaps[num-1] += 1
        for r1 in reds:
            for r2 in reds:
                if r1 != r2: co_matrix[r1, r2] += 1
                
    return np.clip(red_gaps / 50.0, 0, 1), red_freqs, momentum, red_stats, red_affinity

def prepare_blue_features_single(df_window):
    df = df_window.copy().reset_index(drop=True)
    num_samples = len(df)
    blue_gaps = np.zeros((num_samples, 16))
    blue_freqs = np.zeros((num_samples, 16))
    current_blue_gaps = np.zeros(16)
    
    for i in range(num_samples):
        blue_gaps[i] = current_blue_gaps
        row = df.iloc[i]
        blue = int(row['blue'])
        
        if i > 0:
            w30 = df.iloc[max(0, i-30):i]
            for num in range(1, 17):
                blue_freqs[i, num-1] = (w30['blue'] == num).sum() / 30.0
        
        for num in range(1, 17):
            if num == blue: current_blue_gaps[num-1] = 0
            else: current_blue_gaps[num-1] += 1
            
    return np.clip(blue_gaps / 50.0, 0, 1), blue_freqs

def predict():
    base_path = os.path.dirname(__file__)
    csv_path = os.path.join(base_path, 'ssq_data.csv')
    df = pd.read_csv(csv_path).sort_values('issue').reset_index(drop=True)
    
    red_xgb = joblib.load(os.path.join(base_path, 'red_ball_xgb.joblib'))
    red_lgbm = joblib.load(os.path.join(base_path, 'red_ball_lgbm.joblib'))
    blue_xgb = joblib.load(os.path.join(base_path, 'blue_ball_xgb.joblib'))
    blue_lgbm = joblib.load(os.path.join(base_path, 'blue_ball_lgbm.joblib'))
    
    df_context = df.tail(45).copy().reset_index(drop=True)
    rg, rf, m, rs, ra = calculate_features_single(df_context)
    bg, bf = prepare_blue_features_single(df_context)
    
    seq_len = 15
    i = len(df_context) 
    
    # Red Features
    red_feat = []
    for step in range(len(df_context) - seq_len, len(df_context)):
        red_feat.extend(rg[step]); red_feat.extend(rf[step]); red_feat.extend(m[step]); red_feat.extend(rs[step]); red_feat.extend(ra[step])
    
    X_red = np.array([red_feat])
    p_red_xgb = red_xgb.predict_proba(X_red)[0]
    p_red_lgbm = red_lgbm.predict_proba(X_red)[0]
    red_probs = (p_red_xgb + p_red_lgbm) / 2.0
    
    top_12_red = sorted(np.argsort(red_probs)[-12:] + 1)
    
    # Blue Features
    blue_feat = []
    for step in range(len(df_context) - seq_len, len(df_context)):
        blue_feat.extend(bg[step]); blue_feat.extend(bf[step])
    
    X_blue = np.array([blue_feat])
    p_blue_xgb = blue_xgb.predict_proba(X_blue)[0]
    p_blue_lgbm = blue_lgbm.predict_proba(X_blue)[0]
    blue_probs = (p_blue_xgb + p_blue_lgbm) / 2.0
    pred_blue = np.argmax(blue_probs) + 1
    
    last_issue = df.iloc[-1]['issue']
    next_issue = int(last_issue) + 1
    
    print(f"Ensemble Predictions for Draw {next_issue}:")
    print(f"Red Balls (Top 12): {[int(x) for x in top_12_red]}")
    print(f"Blue Ball (Top 1): {int(pred_blue)}")
    
    # Simulation Analysis
    i_sim = len(df_context) - 1
    red_feat_sim = []
    for step in range(i_sim - seq_len, i_sim):
        red_feat_sim.extend(rg[step]); red_feat_sim.extend(rf[step]); red_feat_sim.extend(m[step]); red_feat_sim.extend(rs[step]); red_feat_sim.extend(ra[step])
    
    X_red_sim = np.array([red_feat_sim])
    p_red_xgb_sim = red_xgb.predict_proba(X_red_sim)[0]
    p_red_lgbm_sim = red_lgbm.predict_proba(X_red_sim)[0]
    probs_sim = (p_red_xgb_sim + p_red_lgbm_sim) / 2.0
    
    top_12_pred_sim = sorted(np.argsort(probs_sim)[-12:] + 1)
    actual_sim = [int(x) for x in df.iloc[-1][['red1', 'red2', 'red3', 'red4', 'red5', 'red6']].values]
    
    print(f"\nAnalysis for Last Draw {last_issue} (Simulation):")
    print(f"Top 12 Predicted: {[int(x) for x in top_12_pred_sim]}")
    print(f"Actual Red: {actual_sim}")
    hits = set(top_12_pred_sim) & set(actual_sim)
    print(f"Hits: {len(hits)}/6 {sorted(list(hits))}")

if __name__ == '__main__':
    predict()

