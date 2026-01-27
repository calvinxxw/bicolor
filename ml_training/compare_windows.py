import pandas as pd
import numpy as np
import xgboost as xgb
import joblib
import os

def calculate_ac_value(reds):
    diffs = set()
    for i in range(len(reds)):
        for j in range(i + 1, len(reds)):
            diffs.add(abs(reds[i] - reds[j]))
    return len(diffs) - (len(reds) - 1)

def calculate_features(df):
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

def prepare_blue_features(df):
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

def evaluate_window(window_size, test_count=100):
    seq_len = 15
    df = pd.read_csv('ml_training/ssq_data.csv').sort_values('issue').reset_index(drop=True)
    
    # We want the latest test_count for testing.
    # The training window size is window_size.
    # We need seq_len draws before the first training sample for features.
    total_needed = window_size + test_count + seq_len
    df_sub = df.tail(total_needed).copy().reset_index(drop=True)
    
    rg, rf, m, rs, ra = calculate_features(df_sub)
    bg, bf = prepare_blue_features(df_sub)
    
    X_red, y_red_expanded = [], []
    X_blue, y_blue = [], []
    
    # training range: from seq_len to seq_len + window_size
    for i in range(seq_len, seq_len + window_size):
        red_feat = []
        for step in range(i - seq_len, i):
            red_feat.extend(rg[step])
            red_feat.extend(rf[step])
            red_feat.extend(m[step])
            red_feat.extend(rs[step])
            red_feat.extend(ra[step])
        
        for val in df_sub[['red1','red2','red3','red4','red5','red6']].values[i]:
            X_red.append(red_feat)
            y_red_expanded.append(int(val) - 1)
            
        blue_feat = []
        for step in range(i - seq_len, i):
            blue_feat.extend(bg[step])
            blue_feat.extend(bf[step])
        X_blue.append(blue_feat)
        y_blue.append(int(df_sub.iloc[i]['blue']) - 1)
    
    # Add dummy samples to ensure all classes exist
    for c in range(33):
        if c not in y_red_expanded:
            X_red.append(np.zeros(len(X_red[0])))
            y_red_expanded.append(c)
    for c in range(16):
        if c not in y_blue:
            X_blue.append(np.zeros(len(X_blue[0])))
            y_blue.append(c)
        
    X_red, y_red_expanded = np.array(X_red), np.array(y_red_expanded)
    X_blue, y_blue = np.array(X_blue), np.array(y_blue)
    
    # Train
    red_xgb = xgb.XGBClassifier(n_estimators=100, max_depth=6, learning_rate=0.1, 
                                 objective='multi:softprob', num_class=33, tree_method='hist', random_state=42)
    red_xgb.fit(X_red, y_red_expanded)
    
    # Fix for missing classes in blue ball training
    blue_xgb = xgb.XGBClassifier(n_estimators=100, max_depth=6, learning_rate=0.1, 
                                  objective='multi:softprob', num_class=16, tree_method='hist', random_state=42)
    
    # Ensure y_blue is treated as having classes 0-15
    # XGBoost needs all classes to be present or it might fail if they aren't contiguous starting from 0
    # Actually, the error shows it expected [0..14] but got a different set. 
    # Let's ensure the model knows there are 16 classes.
    blue_xgb.fit(X_blue, y_blue)
    hit_4_plus = 0
    hit_3 = 0
    blue_hits = 0
    
    for i in range(len(df_sub) - test_count, len(df_sub)):
        # Red
        red_feat = []
        for step in range(i - seq_len, i):
            red_feat.extend(rg[step])
            red_feat.extend(rf[step])
            red_feat.extend(m[step])
            red_feat.extend(rs[step])
            red_feat.extend(ra[step])
        red_probs = red_model_probs = red_xgb.predict_proba(np.array([red_feat]))[0]
        top_12 = np.argsort(red_probs)[-12:] + 1
        actual_reds = set(df_sub.iloc[i][['red1', 'red2', 'red3', 'red4', 'red5', 'red6']].values)
        hits = len(actual_reds & set(top_12))
        
        # Blue
        blue_feat = []
        for step in range(i - seq_len, i):
            blue_feat.extend(bg[step])
            blue_feat.extend(bf[step])
        blue_probs = blue_xgb.predict_proba(np.array([blue_feat]))[0]
        pred_blue = np.argmax(blue_probs) + 1
        if pred_blue == int(df_sub.iloc[i]['blue']):
            blue_hits += 1
            
        if hits >= 4: hit_4_plus += 1
        elif hits == 3: hit_3 += 1
            
    return {
        'window': window_size,
        'red_3_plus': (hit_4_plus + hit_3) / test_count * 100,
        'red_4_plus': hit_4_plus / test_count * 100,
        'blue_hit': blue_hits / test_count * 100
    }

if __name__ == '__main__':
    windows = [1000, 500, 200, 100, 50, 20, 10]
    results = []
    print(f"{'Window':<10} | {'Red 3+ %':<10} | {'Red 4+ %':<10} | {'Blue %':<10}")
    print("-" * 50)
    for w in windows:
        res = evaluate_window(w)
        results.append(res)
        print(f"{res['window']:<10} | {res['red_3_plus']:<10.1f} | {res['red_4_plus']:<10.1f} | {res['blue_hit']:<10.1f}")
