# --- skill ---
# name: Shuangseqiu Predictor
# description: Analyzes and predicts China Shuangseqiu lottery using ML (PyTorch/TF). Handles data parsing, frequency analysis, LSTM prediction.
# keywords: 双色球, lottery, prediction, tensorflow, pytorch, lstm
# category: finance, ml, prediction
# version: 1.0 (2026-01)
# ---

## Activation Triggers
Load when query mentions: "双色球", "shuangseqiu", "lottery prediction", "彩票分析", "预测开奖".

## Core Checklist (Strictly Follow)
1. **Data Loading**: Parse CSV/ TXT with pandas. Red balls as list[int], blue as int. Sort by date ascending.
2. **Analysis**: Frequency (热号/冷号), odd/even ratio, sum/range stats, correlation matrix.
3. **Preprocessing**: Normalize numbers (MinMaxScaler 0-1), sequence for LSTM (e.g., last 5 draws predict next).
4. **Model**: Use PyTorch LSTM (input_size=6 for red, hidden=50) or TF Keras LSTM. Train on historical, predict next 6 red + 1 blue (separate models).
5. **Prediction**: Output sorted unique numbers (1-33 red, 1-16 blue). Add confidence (e.g., MSE loss).
6. **Risk Note**: Lottery is random; this is for fun/education, not financial advice.
7. **Testing**: Backtest on last 20 draws, compute accuracy (e.g., hit rate).

## Recommended Tech (PyTorch Example)
- Packages: torch, pandas, sklearn, numpy.
- Data Source: Load from CSV or GitHub raw (e.g., https://raw.githubusercontent.com/yinqishuo/Bicolorballs-AI/main/Bicolorballs.csv).
- Architecture: LSTM for sequence prediction.

## Code Templates (In workflows/ folder)
- predictor.py: 
  import torch
  import torch.nn as nn
  from torch.utils.data import Dataset, DataLoader
  import pandas as pd
  from sklearn.preprocessing import MinMaxScaler
  import numpy as np

  class LotteryDataset(Dataset):
      def __init__(self, X, y):
          self.X = torch.tensor(X, dtype=torch.float32)
          self.y = torch.tensor(y, dtype=torch.float32)

      def __len__(self):
          return len(self.X)

      def __getitem__(self, idx):
          return self.X[idx], self.y[idx]

  class LSTMPredictor(nn.Module):
      def __init__(self, input_size=6, hidden_size=50, output_size=6):
          super().__init__()
          self.lstm = nn.LSTM(input_size, hidden_size, batch_first=True)
          self.fc = nn.Linear(hidden_size, output_size)

      def forward(self, x):
          out, _ = self.lstm(x)
          out = self.fc(out[:, -1, :])
          return out

  def train_model(data_csv):
      df = pd.read_csv(data_csv)
      df['red_balls'] = df['red_balls'].apply(lambda x: list(map(int, x.split())))
      red_numbers = df['red_balls'].values[::-1]  # Chronological
      scaler = MinMaxScaler()
      red_scaled = scaler.fit_transform(np.array(red_numbers))

      seq_len = 5
      X, y = [], []
      for i in range(len(red_scaled) - seq_len):
          X.append(red_scaled[i:i+seq_len])
          y.append(red_scaled[i+seq_len])

      dataset = LotteryDataset(X, y)
      loader = DataLoader(dataset, batch_size=4, shuffle=True)

      model = LSTMPredictor()
      criterion = nn.MSELoss()
      optimizer = torch.optim.Adam(model.parameters(), lr=0.001)

      for epoch in range(50):  # More epochs for better fit
          for inputs, labels in loader:
              optimizer.zero_grad()
              outputs = model(inputs)
              loss = criterion(outputs, labels)
              loss.backward()
              optimizer.step()

      return model, scaler

  def predict_next(model, scaler, last_draws):
      last_scaled = scaler.transform(np.array(last_draws))
      input_tensor = torch.tensor([last_scaled[-5:]], dtype=torch.float32)
      with torch.no_grad():
          pred_scaled = model(input_tensor)
          pred = scaler.inverse_transform(pred_scaled.numpy())
      return sorted(np.round(pred[0]).astype(int).clip(1, 33))  # Unique sorted

  # Usage: model, scaler = train_model('data.csv')
  # pred_red = predict_next(model, scaler, recent_reds)