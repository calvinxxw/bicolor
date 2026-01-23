import os
import random
import numpy as np
import pandas as pd
import tensorflow as tf
from tensorflow import keras
from sklearn.cluster import KMeans
from sklearn.decomposition import PCA
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble import RandomForestClassifier
import joblib

SEED = 42
random.seed(SEED)
np.random.seed(SEED)
tf.random.set_seed(SEED)
os.environ["KERAS_BACKEND"] = "tensorflow"

class BacktestExplorer:
    def __init__(self, df):
        self.df, self.red_cols = df, ['red1', 'red2', 'red3', 'red4', 'red5', 'red6']
        self.red_gaps_norm, self.red_freqs, self.momentum, self.blue_gaps_norm, self.blue_freqs, \
        self.red_stats, self.red_corr, self.red_pca, self.pred_clusters = self._prepare_all_features()

    def _prepare_all_features(self):
        df, num_samples, red_cols = self.df, len(self.df), self.red_cols
        red_gaps, red_freqs, momentum = np.zeros((num_samples, 33)), np.zeros((num_samples, 33)), np.zeros((num_samples, 33))
        blue_gaps, blue_freqs = np.zeros((num_samples, 16)), np.zeros((num_samples, 16))
        red_stats, red_corr = np.zeros((num_samples, 10)), np.zeros((num_samples, 33))
        current_red_gaps, current_blue_gaps = np.zeros(33), np.zeros(16)
        co_matrix = np.zeros((34, 34))
        primes = {2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31}
        
        for i in range(num_samples):
            red_gaps[i], blue_gaps[i] = current_red_gaps, current_blue_gaps
            row = df.iloc[i]
            reds = sorted([int(row[col]) for col in red_cols])
            if i > 0:
                w30, w5 = df.iloc[max(0, i-30):i], df.iloc[max(0, i-5):i]
                for num in range(1, 34):
                    red_freqs[i, num-1] = (w30[red_cols] == num).any(axis=1).sum() / 30.0
                    momentum[i, num-1] = (w5[red_cols] == num).any(axis=1).sum() / 5.0
                prev_reds = sorted([int(df.iloc[i-1][col]) for col in red_cols])
                red_stats[i, 0] = sum(prev_reds) / 200.0
                diffs = set()
                for x in range(len(prev_reds)):
                    for y in range(x+1, len(prev_reds)): diffs.add(abs(prev_reds[x]-prev_reds[y]))
                red_stats[i, 1] = (len(diffs)-5)/10.0
                red_stats[i, 2] = len([n for n in prev_reds if n%2!=0])/6.0
                red_stats[i, 3] = len([n for n in prev_reds if n>16])/6.0
                red_stats[i, 4] = len([n for n in prev_reds if n in primes])/6.0
                red_stats[i, 5], red_stats[i, 6], red_stats[i, 7] = len([n for n in prev_reds if 1<=n<=11])/6.0, len([n for n in prev_reds if 12<=n<=22])/6.0, len([n for n in prev_reds if 23<=n<=33])/6.0
                red_stats[i, 8] = (max(prev_reds)-min(prev_reds))/32.0
                consec, curr_max = 1, 1
                for j in range(len(prev_reds)-1):
                    if prev_reds[j+1] == prev_reds[j] + 1: consec += 1
                    else: curr_max, consec = max(curr_max, consec), 1
                red_stats[i, 9] = max(curr_max, consec)/6.0
                max_co = co_matrix.max()
                if max_co > 0:
                    for num in range(1, 34): red_corr[i, num-1] = sum([co_matrix[num, p] for p in prev_reds]) / (6.0 * max_co)
            for num in range(1, 34):
                if num in reds: current_red_gaps[num-1] = 0
                else: current_red_gaps[num-1] += 1
            for r1 in reds:
                for r2 in reds:
                    if r1 != r2: co_matrix[r1, r2] += 1
        
        pca = PCA(n_components=8, random_state=SEED)
        red_pca = pca.fit_transform(StandardScaler().fit_transform(red_gaps))
        kmeans = KMeans(n_clusters=5, n_init=10, random_state=SEED)
        rf = RandomForestClassifier(n_estimators=100, random_state=SEED)
        clusters = kmeans.fit_predict(red_stats)
        rf.fit(red_stats, clusters)
        return np.clip(red_gaps/50.0, 0, 1), red_freqs, momentum, np.clip(blue_gaps/50.0, 0, 1), blue_freqs, red_stats, red_corr, red_pca, rf.predict(red_stats)

def run_backtest():
    print("Executing Deterministic Backtest...")
    df = pd.read_csv('ssq_data.csv')
    df['issue'] = df['issue'].astype(int)
    df = df.sort_values('issue').reset_index(drop=True)
    explorer = BacktestExplorer(df)
    red_model = keras.models.load_model('red_ball_model.keras', safe_mode=False)
    discriminator = joblib.load('pool_discriminator.pkl')
    seq_len, test_count, hit_4_plus = 15, 50, 0
    print("-" * 75)
    for i in range(len(df) - test_count, len(df)):
        X_e = np.hstack([explorer.red_gaps_norm[i-seq_len:i], explorer.red_freqs[i-seq_len:i], explorer.momentum[i-seq_len:i]])
        X_b = explorer.red_stats[i-seq_len:i]
        X_r = np.hstack([explorer.red_pca[i-seq_len:i], explorer.red_corr[i-seq_len:i], explorer.pred_clusters[i-seq_len:i].reshape(-1, 1)])
        state_feat = np.hstack([X_e[-1], X_b[-1], X_r[-1]])
        heatmap = red_model.predict([X_e.reshape(1, seq_len, 99), X_b.reshape(1, seq_len, 10), X_r.reshape(1, seq_len, 42)], verbose=0)[0][0]
        best_pool, best_score, top_20 = None, -1, np.argsort(heatmap)[-20:] + 1
        for _ in range(500):
            cand = np.random.choice(top_20, 12, replace=False)
            pool_vec = np.zeros(33)
            for n in cand: pool_vec[n-1] = 1
            score = discriminator.predict_proba(np.hstack([state_feat, pool_vec]).reshape(1, -1))[0][1]
            if score > best_score: best_score, best_pool = score, set(cand)
        actual_reds = set(df.iloc[i][['red1', 'red2', 'red3', 'red4', 'red5', 'red6']].values)
        hits = len(actual_reds & best_pool)
        if hits >= 4: hit_4_plus += 1
        print(f"{df.iloc[i]['issue']:<8} | Hits: {hits}/6 Score: {best_score:.3f} {' [SUCCESS]' if hits>=4 else ''}")
    print("-" * 75)
    print(f"LOCKED HIT RATE: {hit_4_plus/test_count*100:.1f}%")

if __name__ == '__main__':
    run_backtest()