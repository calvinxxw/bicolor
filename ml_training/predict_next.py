import pandas as pd
import numpy as np
import joblib
import os
import xgboost as xgb

def calculate_ac_value(reds):
    diffs = set()
    for i in range(len(reds)):
        for j in range(i + 1, len(reds)):
            diffs.add(abs(reds[i] - reds[j]))
    return len(diffs) - (len(reds) - 1)

def calculate_features_single(df_window):
    # df_window should be the last 15 draws for features + enough historical context for freq
    # But wait, our feature engineering needs 30 draws for freq.
    # Let's just use the logic from the train script but only for the very last step.
    
    # To be safe, let's take a larger chunk to calculate stats correctly
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
    
    red_model = joblib.load(os.path.join(base_path, 'red_ball_xgb.joblib'))
    blue_model = joblib.load(os.path.join(base_path, 'blue_ball_xgb.joblib'))
    
    # We need the last 15 draws + context for stats (30 draws context)
    # Total 45 draws
    df_context = df.tail(45).copy().reset_index(drop=True)
    rg, rf, m, rs, ra = calculate_features_single(df_context)
    bg, bf = prepare_blue_features_single(df_context)
    
    # The last index in df_context is the most recent draw
    # To predict the NEXT draw, we use features calculated AFTER the most recent draw
    # In the training loop, X[i] uses features from steps i-seq_len to i-1
    # So for the next draw (unseen), we use features from steps len(df)-seq_len to len(df)-1
    
    seq_len = 15
    i = len(df_context) 
    
    # Red Features
    red_feat = []
    # Since we need features for the draw AFTER the last one in df_context,
    # we need to calculate one more step of features.
    
    # Actually, the calculate_features function already calculates 'current_red_gaps' etc. 
    # but the arrays rg, rf, etc. only go up to len(df)-1.
    # Let's just manually append the last state.
    
    # Simplest way: Run backtest-style logic for the last possible window
    red_feat = []
    for step in range(len(df_context) - seq_len, len(df_context)):
        red_feat.extend(rg[step])
        red_feat.extend(rf[step])
        red_feat.extend(m[step])
        red_feat.extend(rs[step])
        red_feat.extend(ra[step])
    
    X_red = np.array([red_feat])
    red_probs = red_model.predict_proba(X_red)[0]
    top_12_red = np.argsort(red_probs)[-12:] + 1
    top_12_red = sorted(top_12_red)
    
    # Blue Features
    blue_feat = []
    for step in range(len(df_context) - seq_len, len(df_context)):
        blue_feat.extend(bg[step])
        blue_feat.extend(bf[step])
    
    X_blue = np.array([blue_feat])
    blue_probs = blue_model.predict_proba(X_blue)[0]
    pred_blue = np.argmax(blue_probs) + 1
    
    last_issue = df.iloc[-1]['issue']
    next_issue = int(last_issue) + 1
    
    print(f"Predictions for Draw {next_issue}:")
    print(f"Red Balls (Top 12): {top_12_red}")
    print(f"Blue Ball (Top 1): {pred_blue}")
    
    # Now let's analyze 26012 specifically
    # 26012 is the last draw in the CSV.
    # To predict 26012, we would have used features from before it.
    
    # Analysis for Draw 26012
    # To see what it WOULD have predicted without knowing 26012, 
    # we use features up to the draw before 26012.
    i_26012 = len(df_context) - 1
    red_feat_26012 = []
    for step in range(i_26012 - seq_len, i_26012):
        red_feat_26012.extend(rg[step])
        red_feat_26012.extend(rf[step])
        red_feat_26012.extend(m[step])
        red_feat_26012.extend(rs[step])
        red_feat_26012.extend(ra[step])
    
    X_red_26012 = np.array([red_feat_26012])
    probs_26012 = red_model.predict_proba(X_red_26012)[0]
    top_12_pred_26012 = sorted(np.argsort(probs_26012)[-12:] + 1)
    actual_26012 = [3, 5, 7, 16, 20, 24]
    
    print(f"\nAnalysis for Draw 26012 (Simulation):")
    print(f"Top 12 Predicted: {top_12_pred_26012}")
    print(f"Actual Red: {actual_26012}")
    hits = set(top_12_pred_26012) & set(actual_26012)
    print(f"Hits: {len(hits)}/6 {sorted(list(hits))}")
    for r in actual_26012:
        prob = probs_26012[r-1]
        rank = 33 - np.where(np.argsort(probs_26012) == (r-1))[0][0]
        print(f"  Ball {r:02d}: Prob={prob:.4f}, Rank={rank}")

if __name__ == '__main__':
    predict()
