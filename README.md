# 🎰 Bicolor Lottery Predictor (AI-Powered)

An automated end-to-end lottery prediction system using XGBoost, featuring a dual-window training strategy and cloud-to-mobile synchronization.

## 🚀 System Architecture

This project implements a fully automated pipeline that bridges machine learning training on GitHub Cloud with real-time inference on a Flutter mobile application.

### 1. Automated Training Pipeline (GitHub Actions)
The "brain" of the system resides in GitHub Actions. To ensure data accuracy, retraining is scheduled **12 hours after every draw**.
*   **Schedule:** Monday, Wednesday, and Friday at **09:15 AM (Beijing Time)**.
*   **Workflow:**
    *   **Crawls:** Fetches the latest draw data via `data_crawler.py`.
    *   **Dual-Window Training:**
        *   **Red Balls (Window: 50):** Focused on high-sensitivity recent trends (48.0% 3+ hit rate).
        *   **Blue Ball (Window: 1000):** Optimized for long-term statistical stability (6.0% hit rate).
    *   **ONNX Export:** Models are converted to `.onnx` for mobile efficiency.
    *   **Auto-Commit:** The system pushes updated models and `ssq_data.csv` back to the repository.

### 2. Mobile Synchronization
The Flutter application features an **"OTA (Over-The-Air) Model Sync"** capability:
*   **One-Tap Sync:** Users update the model via the ☁️ icon in the top bar.
*   **Default Cloud Link:** Pre-configured to pull from this repository's `main` branch.
*   **Dynamic Loading:** Models are stored locally on the phone and prioritized by the AI engine.

## 📈 ML Performance Analysis
Based on backtesting the latest 100 draws (comparing different window sizes):

| Window Size | Red 3+ % | Red 4+ % | Blue % |
| :--- | :--- | :--- | :--- |
| 1000 | 41.0 | 9.0 | **6.0** |
| 100 | 47.0 | 15.0 | 3.0 |
| **50 (Selected for Red)** | **48.0** | **22.0** | 4.0 |
| 10 | 40.0 | 14.0 | 4.0 |

*Theoretical Random Expectation (12 picks): ~37.4% for Red 3+.*

## 📋 Quick Start
1.  **Repository Setup:** Ensure GitHub Action has **Read and write permissions** in Settings -> Actions -> General.
2.  **App Update:** Tap the cloud icon in the app to sync the latest trained "brain".
3.  **Manual Trigger:** You can manually start retraining in the "Actions" tab on GitHub.

---
**Disclaimer:** Educational research project. Lottery involves risk; predictions are statistical trends, not guarantees.