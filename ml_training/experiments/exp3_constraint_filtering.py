import os
os.environ["KERAS_BACKEND"] = "tensorflow"
import sys
sys.path.append('..')
import numpy as np
import pandas as pd
from tensorflow import keras
from itertools import combinations
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
    return rg, rf, m, rs, ra, df, seq_len, split_idx

def evaluate_selection_strategy(predictions, df, split_idx, strategy_name, selection_func):
    """Evaluate a selection strategy"""
    hit_4_plus = 0
    hit_3 = 0
    test_count = len(predictions)

    for i in range(test_count):
        selected = selection_func(predictions[i])
        actual = set(df.iloc[split_idx + i][['red1', 'red2', 'red3', 'red4', 'red5', 'red6']].values)
        hits = len(actual & set(selected))

        if hits >= 4:
            hit_4_plus += 1
        elif hits == 3:
            hit_3 += 1

    hit_4_plus_rate = hit_4_plus / test_count * 100
    hit_3_rate = hit_3 / test_count * 100
    overall_3_plus = (hit_4_plus + hit_3) / test_count * 100

    print(f"{strategy_name:<40} | {hit_4_plus:>3} ({hit_4_plus_rate:>5.1f}%) | {hit_3:>3} ({hit_3_rate:>5.1f}%) | {overall_3_plus:>5.1f}%")

    return {
        'strategy': strategy_name,
        'hit_4_plus': hit_4_plus,
        'hit_4_plus_rate': hit_4_plus_rate,
        'hit_3': hit_3,
        'hit_3_rate': hit_3_rate,
        'overall_3_plus': overall_3_plus
    }

def select_top_12(probs):
    """Strategy 1: Simple top-12"""
    return np.argsort(probs)[-12:] + 1

def select_with_sum_constraint(probs):
    """Strategy 2: Top-15, filter by sum constraint (80-120)"""
    top_15 = np.argsort(probs)[-15:] + 1

    # Try all combinations of 6 from top-15
    best_combo = None
    best_score = -1

    for combo in combinations(top_15, 6):
        combo_sum = sum(combo)
        if 80 <= combo_sum <= 120:
            # Score by average probability
            score = sum([probs[num-1] for num in combo])
            if score > best_score:
                best_score = score
                best_combo = combo

    # If no valid combo found, fall back to top-12
    if best_combo is None:
        return select_top_12(probs)

    # Return the 12 numbers: best_combo + next best from top-15
    result = list(best_combo)
    for num in top_15:
        if num not in result and len(result) < 12:
            result.append(num)

    return np.array(result)

def select_with_all_constraints(probs):
    """Strategy 3: Top-15, filter by multiple constraints"""
    top_15 = np.argsort(probs)[-15:] + 1

    best_combo = None
    best_score = -1

    for combo in combinations(top_15, 6):
        combo_list = sorted(list(combo))
        combo_sum = sum(combo_list)
        span = max(combo_list) - min(combo_list)
        odd_count = sum([1 for n in combo_list if n % 2 != 0])

        # Check constraints
        sum_ok = 80 <= combo_sum <= 120
        span_ok = 20 <= span <= 30
        odd_ok = 2 <= odd_count <= 4

        if sum_ok and span_ok and odd_ok:
            score = sum([probs[num-1] for num in combo])
            if score > best_score:
                best_score = score
                best_combo = combo

    if best_combo is None:
        return select_top_12(probs)

    result = list(best_combo)
    for num in top_15:
        if num not in result and len(result) < 12:
            result.append(num)

    return np.array(result)

def select_dynamic_pool(probs):
    """Strategy 4: Dynamic pool size based on confidence"""
    confidence = max(probs) - np.median(probs)

    if confidence > 0.15:
        pool_size = 10
    elif confidence > 0.10:
        pool_size = 12
    else:
        pool_size = 14

    return np.argsort(probs)[-pool_size:] + 1

if __name__ == '__main__':
    print("Experiment 3: Constraint Filtering Impact")
    print("="*80)

    # Prepare data
    rg, rf, m, rs, ra, df, seq_len, split_idx = prepare_data()

    # Load trained model
    print("Loading trained model...")
    model = keras.models.load_model('../red_ball_model.keras', safe_mode=False)

    # Generate predictions for test set
    print(f"Generating predictions for {len(df) - split_idx} test samples...")
    predictions = []
    for i in range(split_idx, len(df)):
        X_e = np.hstack([rg[i-seq_len:i], rf[i-seq_len:i], m[i-seq_len:i]]).reshape(1, seq_len, 99)
        X_b = rs[i-seq_len:i].reshape(1, seq_len, 10)
        X_r = ra[i-seq_len:i].reshape(1, seq_len, 10)

        outputs = model.predict([X_e, X_b, X_r], verbose=0)
        heatmap = outputs[0][0] if isinstance(outputs, list) else outputs[0]
        predictions.append(heatmap)

    predictions = np.array(predictions)

    # Test different selection strategies
    print("\n" + "="*80)
    print(f"{'Strategy':<40} | {'4+ Hits':<15} | {'3 Hits':<15} | {'Overall 3+':<10}")
    print("-"*80)

    results = []
    results.append(evaluate_selection_strategy(predictions, df, split_idx, "1. Top-12 (Baseline)", select_top_12))
    results.append(evaluate_selection_strategy(predictions, df, split_idx, "2. Top-15 + Sum Constraint (80-120)", select_with_sum_constraint))
    results.append(evaluate_selection_strategy(predictions, df, split_idx, "3. Top-15 + All Constraints", select_with_all_constraints))
    results.append(evaluate_selection_strategy(predictions, df, split_idx, "4. Dynamic Pool Size", select_dynamic_pool))

    print("="*80)

    # Find best strategy
    best = max(results, key=lambda x: x['hit_4_plus_rate'])
    print(f"\nBest Strategy: {best['strategy']}")
    print(f"Improvement: {best['hit_4_plus_rate'] - results[0]['hit_4_plus_rate']:.1f}% (4+ hits)")
