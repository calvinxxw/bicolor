"""
Enhanced Data Preprocessing Module for Lottery Prediction
Implements best practices for handling random event data:
- Bayesian smoothing for frequency estimates
- Class balancing strategies
- Feature scaling and normalization
- Data validation and quality checks
"""

import pandas as pd
import numpy as np
from sklearn.utils.class_weight import compute_class_weight
from scipy import stats
import warnings
warnings.filterwarnings('ignore')


class LotteryDataPreprocessor:
    """Enhanced preprocessor for lottery data with statistical rigor"""

    def __init__(self, random_state=42):
        self.random_state = random_state
        np.random.seed(random_state)

        # Bayesian priors for smoothing
        # Red: 6/33 ≈ 0.182 probability
        self.alpha_red = 1.0
        self.beta_red = 5.5  # (33-6)/6 ≈ 4.5, rounded to 5.5

        # Blue: 1/16 = 0.0625 probability
        self.alpha_blue = 1.0
        self.beta_blue = 15.0

        self.primes = {2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31}

    def validate_data(self, df):
        """Validate data quality and check for anomalies"""
        print("Validating data quality...")

        # Check for missing values
        if df.isnull().any().any():
            print("WARNING: Missing values detected!")
            print(df.isnull().sum())

        # Check red ball ranges (1-33)
        red_cols = ['red1', 'red2', 'red3', 'red4', 'red5', 'red6']
        for col in red_cols:
            if (df[col] < 1).any() or (df[col] > 33).any():
                print(f"WARNING: {col} has values outside valid range [1, 33]")

        # Check blue ball range (1-16)
        if (df['blue'] < 1).any() or (df['blue'] > 16).any():
            print("WARNING: blue has values outside valid range [1, 16]")

        # Check for duplicates within same draw
        for idx, row in df.iterrows():
            reds = [row[col] for col in red_cols]
            if len(reds) != len(set(reds)):
                print(f"WARNING: Duplicate red balls in draw {row['issue']}")

        # Statistical randomness test (chi-square)
        self._test_randomness(df)

        print("Data validation complete.\n")
        return True

    def _test_randomness(self, df):
        """Perform chi-square test for randomness"""
        red_cols = ['red1', 'red2', 'red3', 'red4', 'red5', 'red6']

        # Test red ball distribution
        all_reds = df[red_cols].values.flatten()
        observed_freq = np.bincount(all_reds, minlength=34)[1:]  # Exclude 0
        expected_freq = len(all_reds) / 33

        chi2_stat, p_value = stats.chisquare(observed_freq, [expected_freq] * 33)
        print(f"Red Ball Chi-Square Test: chi2={chi2_stat:.2f}, p-value={p_value:.4f}")
        if p_value < 0.05:
            print("  -> Significant deviation from uniform distribution detected")
        else:
            print("  -> Distribution consistent with randomness")

        # Test blue ball distribution
        blue_freq = df['blue'].value_counts().reindex(range(1, 17), fill_value=0).values
        expected_blue = len(df) / 16
        chi2_blue, p_blue = stats.chisquare(blue_freq, [expected_blue] * 16)
        print(f"Blue Ball Chi-Square Test: chi2={chi2_blue:.2f}, p-value={p_blue:.4f}")
        if p_blue < 0.05:
            print("  -> Significant deviation from uniform distribution detected")
        else:
            print("  -> Distribution consistent with randomness")

    def calculate_ac_value(self, reds):
        """Calculate AC (Arithmetic Complexity) value"""
        diffs = set()
        for i in range(len(reds)):
            for j in range(i + 1, len(reds)):
                diffs.add(abs(reds[i] - reds[j]))
        return len(diffs) - (len(reds) - 1)

    def calculate_red_features(self, df, use_bayesian=True):
        """
        Calculate comprehensive red ball features with Bayesian smoothing

        Args:
            df: DataFrame with lottery data
            use_bayesian: Whether to apply Bayesian smoothing to frequencies

        Returns:
            Tuple of feature arrays (gaps, freqs, momentum, stats, affinity)
        """
        num_samples = len(df)
        red_cols = ['red1', 'red2', 'red3', 'red4', 'red5', 'red6']

        # Initialize feature matrices
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
                w30 = df.iloc[max(0, i-30):i]
                w5 = df.iloc[max(0, i-5):i]

                for num in range(1, 34):
                    if use_bayesian:
                        # Apply Bayesian smoothing
                        count_30 = (w30[red_cols] == num).any(axis=1).sum()
                        count_5 = (w5[red_cols] == num).any(axis=1).sum()
                        red_freqs[i, num-1] = (count_30 + self.alpha_red) / (30.0 + self.alpha_red + self.beta_red)
                        momentum[i, num-1] = (count_5 + self.alpha_red) / (5.0 + self.alpha_red + self.beta_red)
                    else:
                        # Raw frequencies
                        red_freqs[i, num-1] = (w30[red_cols] == num).any(axis=1).sum() / 30.0
                        momentum[i, num-1] = (w5[red_cols] == num).any(axis=1).sum() / 5.0

                # Statistical features from previous draw
                prev_reds = sorted([int(df.iloc[i-1][col]) for col in red_cols])
                red_stats[i, 0] = sum(prev_reds) / 200.0  # Normalized sum
                red_stats[i, 1] = self.calculate_ac_value(prev_reds) / 10.0  # AC value
                red_stats[i, 2] = len([n for n in prev_reds if n % 2 != 0]) / 6.0  # Odd ratio
                red_stats[i, 3] = len([n for n in prev_reds if n > 16]) / 6.0  # High ratio
                red_stats[i, 4] = len([n for n in prev_reds if n in self.primes]) / 6.0  # Prime ratio
                red_stats[i, 5] = len([n for n in prev_reds if 1 <= n <= 11]) / 6.0  # Zone 1
                red_stats[i, 6] = len([n for n in prev_reds if 12 <= n <= 22]) / 6.0  # Zone 2
                red_stats[i, 7] = len([n for n in prev_reds if 23 <= n <= 33]) / 6.0  # Zone 3
                red_stats[i, 8] = (max(prev_reds) - min(prev_reds)) / 32.0  # Span

                # Consecutive numbers
                consec, curr_max = 1, 1
                for j in range(len(prev_reds)-1):
                    if prev_reds[j+1] == prev_reds[j] + 1:
                        consec += 1
                    else:
                        curr_max = max(curr_max, consec)
                        consec = 1
                red_stats[i, 9] = max(curr_max, consec) / 6.0

                # Affinity features (co-occurrence patterns)
                for idx in range(10):
                    anchor = (idx * 3) + 1
                    red_affinity[i, idx] = sum([co_matrix[anchor, p] for p in prev_reds]) / 50.0

            # Update gaps and co-occurrence matrix
            for num in range(1, 34):
                if num in reds:
                    current_red_gaps[num-1] = 0
                else:
                    current_red_gaps[num-1] += 1

            for r1 in reds:
                for r2 in reds:
                    if r1 != r2:
                        co_matrix[r1, r2] += 1

        # Clip gaps to [0, 1] range
        red_gaps = np.clip(red_gaps / 50.0, 0, 1)

        return red_gaps, red_freqs, momentum, red_stats, red_affinity

    def calculate_blue_features(self, df, use_bayesian=True):
        """
        Calculate blue ball features with Bayesian smoothing

        Args:
            df: DataFrame with lottery data
            use_bayesian: Whether to apply Bayesian smoothing

        Returns:
            Tuple of (gaps, freqs) arrays
        """
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
                    if use_bayesian:
                        count = (w30['blue'] == num).sum()
                        blue_freqs[i, num-1] = (count + self.alpha_blue) / (30.0 + self.alpha_blue + self.beta_blue)
                    else:
                        blue_freqs[i, num-1] = (w30['blue'] == num).sum() / 30.0

            # Update gaps
            for num in range(1, 17):
                if num == blue:
                    current_blue_gaps[num-1] = 0
                else:
                    current_blue_gaps[num-1] += 1

        # Clip gaps to [0, 1] range
        blue_gaps = np.clip(blue_gaps / 50.0, 0, 1)

        return blue_gaps, blue_freqs

    def compute_class_weights(self, y, method='balanced'):
        """
        Compute class weights for imbalanced data

        Args:
            y: Target labels
            method: 'balanced' or 'sqrt' (square root of inverse frequency)

        Returns:
            Dictionary of class weights
        """
        classes = np.unique(y)

        if method == 'balanced':
            weights = compute_class_weight('balanced', classes=classes, y=y)
        elif method == 'sqrt':
            # Square root of inverse frequency (less aggressive than balanced)
            class_counts = np.bincount(y)
            weights = np.sqrt(len(y) / (len(classes) * class_counts[classes]))
        else:
            weights = np.ones(len(classes))

        return dict(zip(classes, weights))

    def apply_smote_sampling(self, X, y, sampling_strategy='auto', k_neighbors=5):
        """
        Apply SMOTE (Synthetic Minority Over-sampling Technique)

        Note: For lottery data, this may not be appropriate as it creates
        synthetic samples. Use with caution and compare against baseline.

        Args:
            X: Feature matrix
            y: Target labels
            sampling_strategy: SMOTE sampling strategy
            k_neighbors: Number of nearest neighbors

        Returns:
            Resampled X, y
        """
        try:
            from imblearn.over_sampling import SMOTE
            smote = SMOTE(sampling_strategy=sampling_strategy,
                         k_neighbors=k_neighbors,
                         random_state=self.random_state)
            X_resampled, y_resampled = smote.fit_resample(X, y)
            print(f"SMOTE applied: {len(y)} → {len(y_resampled)} samples")
            return X_resampled, y_resampled
        except ImportError:
            print("WARNING: imbalanced-learn not installed. Skipping SMOTE.")
            return X, y

    def prepare_training_data(self, df, seq_len=15, window_size=None,
                             balance_method=None, use_bayesian=True):
        """
        Prepare complete training dataset with all preprocessing steps

        Args:
            df: Raw lottery data
            seq_len: Sequence length for temporal features
            window_size: Training window size (None = use all data)
            balance_method: 'weights', 'smote', or None
            use_bayesian: Whether to use Bayesian smoothing

        Returns:
            Dictionary with X_red, y_red, X_blue, y_blue, and optional weights
        """
        print(f"Preparing training data (seq_len={seq_len}, window={window_size})...")

        # Validate data first
        self.validate_data(df)

        # Apply window if specified
        if window_size:
            df_windowed = df.tail(window_size + seq_len).copy().reset_index(drop=True)
        else:
            df_windowed = df.copy()

        # Calculate features
        print("Calculating red ball features...")
        rg, rf, m, rs, ra = self.calculate_red_features(df_windowed, use_bayesian)

        print("Calculating blue ball features...")
        bg, bf = self.calculate_blue_features(df_windowed, use_bayesian)

        # Build sequences
        X_red, y_red_expanded = [], []
        X_blue, y_blue = [], []

        red_cols = ['red1', 'red2', 'red3', 'red4', 'red5', 'red6']

        for i in range(seq_len, len(df_windowed)):
            # Red features
            red_feat = []
            for step in range(i - seq_len, i):
                red_feat.extend(rg[step])
                red_feat.extend(rf[step])
                red_feat.extend(m[step])
                red_feat.extend(rs[step])
                red_feat.extend(ra[step])

            # Expand: each draw's 6 red balls creates 6 samples
            for val in df_windowed[red_cols].values[i]:
                X_red.append(red_feat)
                y_red_expanded.append(int(val) - 1)

            # Blue features
            blue_feat = []
            for step in range(i - seq_len, i):
                blue_feat.extend(bg[step])
                blue_feat.extend(bf[step])
            X_blue.append(blue_feat)
            y_blue.append(int(df_windowed.iloc[i]['blue']) - 1)

        # Ensure all classes present (important for multi-class classification)
        for c in range(33):
            if c not in y_red_expanded:
                X_red.append(np.zeros(len(X_red[0])))
                y_red_expanded.append(c)

        for c in range(16):
            if c not in y_blue:
                X_blue.append(np.zeros(len(X_blue[0])))
                y_blue.append(c)

        X_red, y_red = np.array(X_red), np.array(y_red_expanded)
        X_blue, y_blue = np.array(X_blue), np.array(y_blue)

        print(f"Dataset prepared: Red={X_red.shape}, Blue={X_blue.shape}")

        result = {
            'X_red': X_red,
            'y_red': y_red,
            'X_blue': X_blue,
            'y_blue': y_blue
        }

        # Apply class balancing if requested
        if balance_method == 'weights':
            result['red_weights'] = self.compute_class_weights(y_red)
            result['blue_weights'] = self.compute_class_weights(y_blue)
            print("Class weights computed.")
        elif balance_method == 'smote':
            result['X_red'], result['y_red'] = self.apply_smote_sampling(X_red, y_red)
            result['X_blue'], result['y_blue'] = self.apply_smote_sampling(X_blue, y_blue)

        return result


if __name__ == '__main__':
    # Test the preprocessor
    preprocessor = LotteryDataPreprocessor(random_state=42)
    df = pd.read_csv('ssq_data.csv').sort_values('issue').reset_index(drop=True)

    # Prepare data with Bayesian smoothing and class weights
    data = preprocessor.prepare_training_data(
        df,
        seq_len=15,
        window_size=None,
        balance_method='weights',
        use_bayesian=True
    )

    print("\nPreprocessing complete!")
    print(f"Red samples: {data['X_red'].shape}")
    print(f"Blue samples: {data['X_blue'].shape}")
    if 'red_weights' in data:
        print(f"Red class weights: {len(data['red_weights'])} classes")
        print(f"Blue class weights: {len(data['blue_weights'])} classes")

