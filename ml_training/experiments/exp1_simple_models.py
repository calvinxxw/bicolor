import os
os.environ["KERAS_BACKEND"] = "tensorflow"
import sys
sys.path.append('..')
import numpy as np
import pandas as pd
from tensorflow import keras
from sklearn.linear_model import LogisticRegression
from sklearn.neural_network import MLPClassifier
from sklearn.ensemble import RandomForestClassifier
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
        for val in df[['red1','red2','red3','red4','red5','red6']].values[i]:
            target[int(val)-1] = 1
        y_test.append(target)

    X_test = np.array(X_test_list)
    y_test = np.array(y_test)

    return X_train, y_train, X_test, y_test, df, split_idx

def evaluate_model(y_pred_proba, y_test, df, split_idx):
    """Evaluate model performance on test set"""
    hit_4_plus = 0
    hit_3 = 0
    test_count = len(y_test)

    for i in range(test_count):
        # Get top 12 predictions
        top_12 = np.argsort(y_pred_proba[i])[-12:] + 1
        actual = set(df.iloc[split_idx + i][['red1', 'red2', 'red3', 'red4', 'red5', 'red6']].values)
        hits = len(actual & set(top_12))

        if hits >= 4:
            hit_4_plus += 1
        elif hits == 3:
            hit_3 += 1

    hit_4_plus_rate = hit_4_plus / test_count * 100
    hit_3_rate = hit_3 / test_count * 100
    overall_3_plus = (hit_4_plus + hit_3) / test_count * 100

    return {
        'hit_4_plus': hit_4_plus,
        'hit_4_plus_rate': hit_4_plus_rate,
        'hit_3': hit_3,
        'hit_3_rate': hit_3_rate,
        'overall_3_plus': overall_3_plus,
        'test_count': test_count
    }

def test_random_forest(X_train, y_train, X_test, y_test, df, split_idx):
    """Test Random Forest model"""
    print("\n" + "="*60)
    print("Testing Random Forest")
    print("="*60)

    predictions = []
    for num_idx in range(33):
        model = RandomForestClassifier(
            n_estimators=100,
            max_depth=5,
            min_samples_split=20,
            random_state=42,
            n_jobs=-1
        )
        model.fit(X_train, y_train[:, num_idx])
        pred = model.predict_proba(X_test)[:, 1]
        predictions.append(pred)

    y_pred_proba = np.array(predictions).T
    results = evaluate_model(y_pred_proba, y_test, df, split_idx)

    print(f"Hit 4+: {results['hit_4_plus']} ({results['hit_4_plus_rate']:.1f}%)")
    print(f"Hit 3: {results['hit_3']} ({results['hit_3_rate']:.1f}%)")
    print(f"Overall 3+: {results['overall_3_plus']:.1f}%")

    return results

def test_shallow_nn(X_train, y_train, X_test, y_test, df, split_idx):
    """Test Shallow Neural Network"""
    print("\n" + "="*60)
    print("Testing Shallow Neural Network (2 layers)")
    print("="*60)

    predictions = []
    for num_idx in range(33):
        model = MLPClassifier(
            hidden_layer_sizes=(128, 64),
            activation='relu',
            max_iter=200,
            random_state=42,
            early_stopping=True,
            validation_fraction=0.1
        )
        model.fit(X_train, y_train[:, num_idx])
        pred = model.predict_proba(X_test)[:, 1]
        predictions.append(pred)

    y_pred_proba = np.array(predictions).T
    results = evaluate_model(y_pred_proba, y_test, df, split_idx)

    print(f"Hit 4+: {results['hit_4_plus']} ({results['hit_4_plus_rate']:.1f}%)")
    print(f"Hit 3: {results['hit_3']} ({results['hit_3_rate']:.1f}%)")
    print(f"Overall 3+: {results['overall_3_plus']:.1f}%")

    return results

def test_linear_model(X_train, y_train, X_test, y_test, df, split_idx):
    """Test Linear Model (Logistic Regression)"""
    print("\n" + "="*60)
    print("Testing Linear Model (Logistic Regression)")
    print("="*60)

    predictions = []
    for num_idx in range(33):
        model = LogisticRegression(
            C=0.1,
            max_iter=500,
            random_state=42
        )
        model.fit(X_train, y_train[:, num_idx])
        pred = model.predict_proba(X_test)[:, 1]
        predictions.append(pred)

    y_pred_proba = np.array(predictions).T
    results = evaluate_model(y_pred_proba, y_test, df, split_idx)

    print(f"Hit 4+: {results['hit_4_plus']} ({results['hit_4_plus_rate']:.1f}%)")
    print(f"Hit 3: {results['hit_3']} ({results['hit_3_rate']:.1f}%)")
    print(f"Overall 3+: {results['overall_3_plus']:.1f}%")

    return results

if __name__ == '__main__':
    print("Experiment 1: Model Complexity Comparison (Simplified)")
    print("="*60)

    # Prepare data
    X_train, y_train, X_test, y_test, df, split_idx = prepare_data()
    print(f"Training samples: {len(X_train)}")
    print(f"Test samples: {len(X_test)}")
    print(f"Feature dimensions: {X_train.shape[1]}")

    # Test all models
    results = {}
    results['random_forest'] = test_random_forest(X_train, y_train, X_test, y_test, df, split_idx)
    results['shallow_nn'] = test_shallow_nn(X_train, y_train, X_test, y_test, df, split_idx)
    results['linear'] = test_linear_model(X_train, y_train, X_test, y_test, df, split_idx)

    # Summary
    print("\n" + "="*60)
    print("SUMMARY: Model Comparison")
    print("="*60)
    print(f"{'Model':<20} | {'4+ Rate':<10} | {'3+ Rate':<10} | {'Overall 3+':<12}")
    print("-"*60)
    for model_name, res in results.items():
        print(f"{model_name:<20} | {res['hit_4_plus_rate']:>9.1f}% | {res['hit_3_rate']:>9.1f}% | {res['overall_3_plus']:>11.1f}%")

    print("\n" + "="*60)
    print("Baseline (Transformer from fair_backtest.py): 12.5% (4+), 37.5% (3+)")
    print("="*60)

