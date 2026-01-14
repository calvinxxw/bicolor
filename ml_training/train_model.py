import numpy as np
import pandas as pd
import tensorflow as tf
from tensorflow import keras
from sklearn.preprocessing import MinMaxScaler


def load_data(csv_path):
    df = pd.read_csv(csv_path)
    df = df.sort_values('issue').reset_index(drop=True)
    return df


def prepare_red_data(df, seq_len=5):
    red_cols = ['red1', 'red2', 'red3', 'red4', 'red5', 'red6']
    red_data = df[red_cols].values

    X, y = [], []
    for i in range(len(red_data) - seq_len):
        X.append(red_data[i:i+seq_len])
        target = np.zeros((6, 33))
        for j, val in enumerate(red_data[i+seq_len]):
            target[j, val-1] = 1
        y.append(target.flatten())

    return np.array(X), np.array(y)


def prepare_blue_data(df, seq_len=5):
    blue_data = df['blue'].values.reshape(-1, 1)

    X, y = [], []
    for i in range(len(blue_data) - seq_len):
        X.append(blue_data[i:i+seq_len])
        target = np.zeros(16)
        target[blue_data[i+seq_len][0]-1] = 1
        y.append(target)

    return np.array(X), np.array(y)


def build_red_model(seq_len=5):
    model = keras.Sequential([
        keras.layers.LSTM(64, input_shape=(seq_len, 6), return_sequences=True),
        keras.layers.Dropout(0.2),
        keras.layers.LSTM(32),
        keras.layers.Dropout(0.2),
        keras.layers.Dense(128, activation='relu'),
        keras.layers.Dense(6 * 33, activation='softmax')
    ])
    model.compile(optimizer='adam', loss='categorical_crossentropy')
    return model


def build_blue_model(seq_len=5):
    model = keras.Sequential([
        keras.layers.LSTM(32, input_shape=(seq_len, 1)),
        keras.layers.Dropout(0.2),
        keras.layers.Dense(32, activation='relu'),
        keras.layers.Dense(16, activation='softmax')
    ])
    model.compile(optimizer='adam', loss='categorical_crossentropy')
    return model


def train_and_save():
    df = load_data('ssq_data.csv')

    X_red, y_red = prepare_red_data(df)
    red_model = build_red_model()
    red_model.fit(X_red, y_red, epochs=50, batch_size=32, validation_split=0.1)
    red_model.save('red_ball_model.keras')

    X_blue, y_blue = prepare_blue_data(df)
    blue_model = build_blue_model()
    blue_model.fit(X_blue, y_blue, epochs=50, batch_size=32, validation_split=0.1)
    blue_model.save('blue_ball_model.keras')

    print('Models saved!')


if __name__ == '__main__':
    train_and_save()
