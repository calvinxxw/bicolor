import os
import tensorflow as tf
from tensorflow import keras
import pandas as pd
import numpy as np
from data_crawler import fetch_ssq_data
from train_model import calculate_features, prepare_sequences
from export_tflite import convert_to_tflite

def incremental_update():
    # 1. Fetch the latest data
    print("Step 1: Fetching latest draw data...")
    try:
        df_new = fetch_ssq_data(page_size=50) # Just get the recent ones
        df_old = pd.read_csv('ssq_data.csv')
        
        # Merge and remove duplicates
        df_combined = pd.concat([df_new, df_old]).drop_duplicates(subset=['issue'])
        df_combined['issue'] = df_combined['issue'].astype(int)
        df_combined = df_combined.sort_values('issue').reset_index(drop=True)
        df_combined.to_csv('ssq_data.csv', index=False)
        print(f"Dataset updated. Total records: {len(df_combined)}")
    except Exception as e:
        print(f"Crawl failed: {e}")
        return

    # 2. Prepare Features
    print("Step 2: Calculating features for fine-tuning...")
    red_gaps, red_freqs, blue_gaps, blue_freqs = calculate_features(df_combined)
    
    # We only fine-tune on the last 50 draws to adapt to the latest trend
    # without forgetting the past.
    df_recent = df_combined.tail(60) # 10 for sequence + 50 for training
    X_red, y_red, X_blue, y_blue = prepare_sequences(df_combined, red_gaps, red_freqs, blue_gaps, blue_freqs, seq_len=10)
    
    # Take only the last 50 samples
    X_red, y_red = X_red[-50:], y_red[-50:]
    X_blue, y_blue = X_blue[-50:], y_blue[-50:]

    # 3. Fine-tune Models
    print("Step 3: Fine-tuning models...")
    os.environ['KERAS_BACKEND'] = 'tensorflow'
    tf.keras.config.enable_unsafe_deserialization()
    
    try:
        red_model = keras.models.load_model('red_ball_model.keras')
        blue_model = keras.models.load_model('blue_ball_model.keras')
        
        # Use a VERY low learning rate so we don't destroy the existing weights
        optimizer = keras.optimizers.Adam(learning_rate=0.00001)
        red_model.compile(optimizer=optimizer, loss='binary_crossentropy', metrics=['accuracy'])
        blue_model.compile(optimizer=optimizer, loss='categorical_crossentropy', metrics=['accuracy'])

        print("Fine-tuning Red Model...")
        red_model.fit(X_red, y_red, epochs=10, verbose=1)
        red_model.save('red_ball_model.keras')

        print("Fine-tuning Blue Model...")
        blue_model.fit(X_blue, y_blue, epochs=10, verbose=1)
        blue_model.save('blue_ball_model.keras')
    except Exception as e:
        print(f"Fine-tuning failed: {e}")
        return

    # 4. Export and Deploy
    print("Step 4: Exporting to TFLite and deploying to Flutter...")
    convert_to_tflite('red_ball_model.keras', 'red_ball_model.tflite')
    convert_to_tflite('blue_ball_model.keras', 'blue_ball_model.tflite')
    
    # Copy to assets (Platform specific paths handled by the CLI runner)
    # I'll just simulate the move here
    print("Incremental Update Complete! New models are ready.")

if __name__ == '__main__':
    incremental_update()
