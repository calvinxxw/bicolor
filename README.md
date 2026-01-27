# 🎰 Bicolor Lottery Predictor (AI-Powered)

An automated end-to-end lottery prediction system using XGBoost, featuring a dual-window training strategy and cloud-to-mobile synchronization.

## 🚀 System Architecture

This project implements a fully automated pipeline that bridges machine learning training on GitHub Cloud with real-time inference on a Flutter mobile application.

### 1. Automated Training Pipeline (GitHub Actions)
The "brain" of the system resides in GitHub Actions. Every Tuesday, Thursday, and Sunday (following the official draws), a virtual server:
*   **Crawls:** Fetches the latest draw data via `data_crawler.py`.
*   **Feature Engineering:** Calculates high-precision Gap, Frequency, and Momentum features.
*   **Dual-Window Training:**
    *   **Red Balls (Window: 50):** Optimized for short-term "hot" trends and recent structural patterns (found to be the most effective in backtesting).
    *   **Blue Ball (Window: 1000):** Optimized for long-term statistical stability.
*   **Conversion:** Converts trained XGBoost models into **ONNX** format for cross-platform compatibility.
*   **Deployment:** Commits the new models back to the repository automatically.

### 2. Mobile Synchronization
The Flutter application features an **"OTA (Over-The-Air) Model Sync"** capability:
*   **Cloud Pull:** Users can trigger a model update by tapping the ☁️ icon.
*   **Dynamic Loading:** The app downloads the latest `.onnx` models from GitHub's raw storage to the phone's internal memory.
*   **Priority Engine:** The AI engine automatically detects and prioritizes the custom-trained models over the default bundled ones.

## 🛠 Tech Stack
*   **ML Core:** Python, XGBoost, Scikit-learn
*   **Model Format:** ONNX (Open Neural Network Exchange)
*   **Mobile:** Flutter (Dart), ONNX Runtime
*   **Automation:** GitHub Actions

## 📈 Backtest Performance (Recent 100 Draws)
| Metric | 50-Draw Window | 1000-Draw Window |
| :--- | :--- | :--- |
| **Red 3+ Hit Rate** | **48.0%** | 41.0% |
| **Red 4+ Hit Rate** | **22.0%** | 9.0% |
| **Blue Ball Hit Rate** | 4.0% | **6.0%** |

*Note: The system automatically combines the best windows (Red: 50, Blue: 1000) for the final prediction.*

## 📋 Installation & Usage
1.  **Retrain Manually:** Go to the "Actions" tab in this repo and run the "Retrain Lottery Model" workflow.
2.  **App Sync:**
    *   Open the app on your phone.
    *   Tap the **Cloud Download** icon in the AppBar.
    *   Click **"立即同步"** to fetch the latest cloud-optimized models.

---
**Disclaimer:** This project is for educational and research purposes only. Lottery involves risk; the AI model provides predictions based on statistical trends but does not guarantee results.
