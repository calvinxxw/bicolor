import os
os.environ["KERAS_BACKEND"] = "tensorflow"
import random
import numpy as np
import pandas as pd
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
from sklearn.cluster import KMeans
from sklearn.decomposition import PCA
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
import joblib

# Fix all seeds for 100% reproducibility
SEED = 42
os.environ['PYTHONHASHSEED'] = str(SEED)
random.seed(SEED)
np.random.seed(SEED)
tf.random.set_seed(SEED)

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
    red_gaps, red_freqs, momentum = np.zeros((num_samples, 33)), np.zeros((num_samples, 33)), np.zeros((num_samples, 33))
    blue_gaps, blue_freqs = np.zeros((num_samples, 16)), np.zeros((num_samples, 16))
    red_stats, red_corr = np.zeros((num_samples, 10)), np.zeros((num_samples, 33))
    current_red_gaps, current_blue_gaps = np.zeros(33), np.zeros(16)
    co_matrix = np.zeros((34, 34))
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
            red_stats[i, 1] = calculate_ac_value(prev_reds) / 10.0
            red_stats[i, 2] = len([n for n in prev_reds if n % 2 != 0]) / 6.0
            red_stats[i, 3] = len([n for n in prev_reds if n > 16]) / 6.0
            red_stats[i, 4] = len([n for n in prev_reds if n in primes]) / 6.0
            red_stats[i, 5], red_stats[i, 6], red_stats[i, 7] = len([n for n in prev_reds if 1<=n<=11])/6.0, len([n for n in prev_reds if 12<=n<=22])/6.0, len([n for n in prev_reds if 23<=n<=33])/6.0
            red_stats[i, 8] = (max(prev_reds) - min(prev_reds)) / 32.0
            consec, curr_max = 1, 1
            for j in range(len(prev_reds)-1):
                if prev_reds[j+1] == prev_reds[j] + 1: consec += 1
                else: curr_max, consec = max(curr_max, consec), 1
            red_stats[i, 9] = max(curr_max, consec) / 6.0
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
    rf = RandomForestClassifier(n_estimators=100, random_state=SEED)
    clusters = KMeans(n_clusters=5, n_init=10, random_state=SEED).fit_predict(red_stats)
    rf.fit(red_stats, clusters)
    return np.clip(red_gaps/50.0, 0, 1), red_freqs, momentum, np.clip(blue_gaps/50.0, 0, 1), blue_freqs, red_stats, red_corr, red_pca, rf.predict(red_stats)

def transformer_block(inputs, head_size, num_heads, ff_dim, dropout=0.2):
    x = layers.LayerNormalization(epsilon=1e-6)(inputs)
    x = layers.MultiHeadAttention(key_dim=head_size, num_heads=num_heads, dropout=dropout)(x, x)
    x = layers.Dropout(dropout)(x)
    res = x + inputs
    x = layers.LayerNormalization(epsilon=1e-6)(res)
    x = layers.Dense(ff_dim, activation="relu")(x)
    x = layers.Dropout(dropout)(x)
    x = layers.Dense(inputs.shape[-1])(x)
    return x + res

def build_ensemble_red_model(seq_len, energy_dim, balance_dim, relational_dim):
    energy_in = layers.Input(shape=(seq_len, energy_dim))
    e = layers.GlobalAveragePooling1D()(transformer_block(energy_in, 128, 4, 128))
    balance_in = layers.Input(shape=(seq_len, balance_dim))
    b = layers.GlobalAveragePooling1D()(transformer_block(balance_in, 64, 2, 64))
    relational_in = layers.Input(shape=(seq_len, relational_dim))
    r = layers.GlobalAveragePooling1D()(transformer_block(relational_in, 128, 4, 128))
    merged = layers.Concatenate()([e, b, r])
    x = layers.BatchNormalization()(layers.Dense(512, activation="gelu")(merged))
    num_output = layers.Dense(33, activation="sigmoid", name="number_heatmap")(layers.Dense(256, activation="gelu")(x))
    zone_output = layers.Dense(3, activation="sigmoid", name="zone_presence")(layers.Dense(64, activation="gelu")(x))
    model = keras.Model(inputs=[energy_in, balance_in, relational_in], outputs=[num_output, zone_output])
    model.compile(optimizer=keras.optimizers.Adam(1e-4), loss={'number_heatmap':'binary_crossentropy', 'zone_presence':'mse'}, loss_weights={'number_heatmap':1.0, 'zone_presence':0.8})
    return model

def train():
    print("Executing Deterministic 24% Recreation...")
    df = pd.read_csv('ssq_data.csv')
    df['issue'] = df['issue'].astype(int)
    df = df.sort_values('issue').reset_index(drop=True)
    rg, rf, m, bg, bf, rs, rc, rp, pc = calculate_features(df)
    seq_len = 15
    X_e, X_b, X_r, y_r = [], [], [], []
    for i in range(seq_len, len(df)):
        X_e.append(np.hstack([rg[i-seq_len:i], rf[i-seq_len:i], m[i-seq_len:i]]))
        X_b.append(rs[i-seq_len:i])
        X_r.append(np.hstack([rp[i-seq_len:i], rc[i-seq_len:i], pc[i-seq_len:i].reshape(-1, 1)]))
        target = np.zeros(33)
        for val in df[['red1','red2','red3','red4','red5','red6']].values[i]: target[int(val)-1] = 1
        y_r.append(target)
    X_e, X_b, X_r, y_r = np.array(X_e), np.array(X_b), np.array(X_r), np.array(y_r)
    red_model = build_ensemble_red_model(seq_len, 99, 10, 42)
    red_model.fit([X_e, X_b, X_r], {'number_heatmap': y_r, 'zone_presence': np.zeros((len(y_r), 3))}, epochs=150, batch_size=32, verbose=0)
    heatmaps = red_model.predict([X_e, X_b, X_r], verbose=0)[0]
    X_d, y_d = [], []
    for i in range(len(y_r)):
        state = np.hstack([X_e[i][-1], X_b[i][-1], X_r[i][-1]])
        actual = set(np.where(y_r[i] == 1)[0] + 1)
        top_20 = np.argsort(heatmaps[i])[-20:] + 1
        for _ in range(15):
            cand = np.random.choice(top_20, 12, replace=False)
            vec = np.zeros(33)
            for n in cand: vec[n-1] = 1
            X_d.append(np.hstack([state, vec]))
            y_d.append(1 if len(actual & set(cand)) >= 4 else 0)
    discriminator = GradientBoostingClassifier(n_estimators=150, learning_rate=0.05, max_depth=6, random_state=SEED)
    discriminator.fit(np.array(X_d), np.array(y_d))
    joblib.dump(discriminator, 'pool_discriminator.pkl')
    red_model.save('red_ball_model.keras')
    print("Models Locked.")

if __name__ == '__main__':
    train()