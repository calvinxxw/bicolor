import os
os.environ["KERAS_BACKEND"] = "tensorflow"
import sys
sys.path.append('..')
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.feature_selection import mutual_info_classif
import warnings
warnings.filterwarnings('ignore')

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from train_model import calculate_features

def prepare_data():
    """Prepare data for experiments"""
    df = pd.read_csv('../ssq_data.csv').sort_values('issue').reset_index(drop=True)
    rg, rf, m, rs, ra = calculate_features(df)

    seq_len = 15
    split_idx = int(len(df) * 0.9)

    # Prepare training data
    X_train_list, y_train = [], []
    for i in range(seq_len, split_idx):
        features = np.hstack([
            rg[i-seq_len:i].flatten(),
            rf[i-seq_len:i].flatten(),
            m[i-seq_len:i].flatten(),
            rs[i-seq_len:i].flatten(),
            ra[i-seq_len:i].flatten()
        ])
        X_train_list.append(features)

        target = np.zeros(33)
        for val in df[['red1','red2','red3','red4','red5','red6']].values[i]:
            target[int(val)-1] = 1
        y_train.append(target)

    X_train = np.array(X_train_list)
    y_train = np.array(y_train)

    # Prepare test data
    X_test_list, y_test = [], []
    for i in range(split_idx, len(df)):
        features = np.hstack([
            rg[i-seq_len:i].flatten(),
            rf[i-seq_len:i].flatten(),
            m[i-seq_len:i].flatten(),
            rs[i-seq_len:i].flatten(),
            ra[i-seq_len:i].flatten()
        ])
        X_test_list.append(features)

        target = np.zeros(33)
