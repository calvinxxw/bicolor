import pandas as pd
import numpy as np
import joblib
import xgboost as xgb
from sklearn.metrics import accuracy_score

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

def run_backtest():
    print("Executing XGBoost Backtest...")
    df = pd.read_csv('ssq_data.csv').sort_values('issue').reset_index(drop=True)
    rg, rf, m, rs, ra = calculate_features(df)
    bg, bf = prepare_blue_features(df)
    
    red_model = joblib.load('red_ball_xgb.joblib')
    blue_model = joblib.load('blue_ball_xgb.joblib')
    
    seq_len = 15
    test_count = 50
    hit_4_plus = 0
    hit_3 = 0
    blue_hits = 0
    
    print("-" * 70)
    print(f"{'Issue':<10} | {'Red Hits':<8} | {'Blue':<5} | {'Status'}")
    print("-" * 70)
    
    for i in range(len(df) - test_count, len(df)):
        # Red prediction
        red_feat = []
        for step in range(i - seq_len, i):
            red_feat.extend(rg[step])
            red_feat.extend(rf[step])
            red_feat.extend(m[step])
            red_feat.extend(rs[step])
            red_feat.extend(ra[step])
        
        X_red = np.array([red_feat])
        red_probs = red_model.predict_proba(X_red)
        # red_probs is a list of 33 arrays of shape (1, 2)
        heatmap = np.array([p[0, 1] for p in red_probs])
        
        top_12 = np.argsort(heatmap)[-12:] + 1
        actual_reds = set(df.iloc[i][['red1', 'red2', 'red3', 'red4', 'red5', 'red6']].values)
        hits = len(actual_reds & set(top_12))
        
        # Blue prediction
        blue_feat = []
        for step in range(i - seq_len, i):
            blue_feat.extend(bg[step])
            blue_feat.extend(bf[step])
        X_blue = np.array([blue_feat])
        blue_probs = blue_model.predict_proba(X_blue)[0]
        pred_blue = np.argmax(blue_probs) + 1
        actual_blue = int(df.iloc[i]['blue'])
        blue_hit = (pred_blue == actual_blue)
        if blue_hit: blue_hits += 1
        
        if hits >= 4:
            hit_4_plus += 1
            status = "[SUCCESS 4+]"
        elif hits == 3:
            hit_3 += 1
            status = "[HIT 3]"
        else:
            status = ""
            
        print(f"{df.iloc[i]['issue']:<10} | {hits}/6      | {'HIT' if blue_hit else 'MISS'} | {status}")
        
    print("-" * 70)
    print(f"Total Tests: {test_count}")
    print(f"Hit 4+ Red Balls: {hit_4_plus} ({hit_4_plus/test_count*100:.1f}%)")
    print(f"Hit 3 Red Balls: {hit_3} ({hit_3/test_count*100:.1f}%)")
    print(f"Blue Ball Hits: {blue_hits} ({blue_hits/test_count*100:.1f}%)")
    print(f"Overall 3+ Red Hit Rate: {(hit_4_plus + hit_3)/test_count*100:.1f}%")

if __name__ == '__main__':
    run_backtest()
