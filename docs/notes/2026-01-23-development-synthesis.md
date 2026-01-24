# Lottery Predictor: Development Synthesis & Project Evolution
**Date Range:** January 14 – January 22, 2026
**Status:** Feature Complete / Ready for Device Testing

## 1. Executive Summary
This document provides a consolidated history of the Lottery Predictor (SSQ) project. It tracks the evolution from a basic Flutter prototype to a sophisticated, on-device machine learning application. Key milestones include a major pivot in ML engines (TFLite to ONNX), critical performance optimizations for large-scale mathematical combinations, and the implementation of personalized on-device training.

---

## 2. Phase 1: Foundation & Architectural Design (Jan 14–15)
The project launched with the goal of creating a professional analytical tool for the Double Color Ball (SSQ).
*   **Architecture:** Established a clean, three-layer architecture:
    *   **Data/Service Layer:** Handling SQLite persistence, CWL API crawling, and prediction logic.
    *   **Model Layer:** Standardized data structures for lottery results, bet selections, and probabilities.
    *   **UI/Widget Layer:** Modular components like the `BallWidget` and `DrawCountdownWidget`.
*   **Initial ML Strategy:** Selected **TensorFlow Lite (TFLite)** with LSTM models trained on historical CSV data.
*   **Key Document:** `docs/plans/2026-01-14-lottery-design.md`

## 3. Phase 2: Technical Hurdles & Engine Pivot (Jan 15–16)
The implementation of TFLite hit significant cross-platform compatibility issues, specifically regarding "Flex delegates" on Windows and Linux.
*   **The Struggle:** Manual compilation of TensorFlow source code failed due to environment mismatches.
*   **The Pivot:** Switched to **pre-built binaries** (`tflite_flutter`) for desktop development and later prepared for a more significant engine shift.
*   **Data Integrity:** Resolved redirect loops and header issues with the official CWL API to ensure reliable daily synchronization.
*   **Key Document:** `docs/plans/2026-01-15-prebuilt-tflite-implementation.md`

## 4. Phase 3: Scaling & Performance Optimization (Jan 16–21)
As features like "Manual Selection" and "Bet Calculator" were added, the application faced a critical performance bottleneck.
*   **The OOM (Out of Memory) Crisis:** Generating all possible combinations for large selections (e.g., 20 red balls) resulted in app hangs and memory crashes.
*   **The Solution:** Implemented a **Paginated Combination Algorithm** (`_getKthCombination`). Instead of pre-generating millions of objects, the app now calculates only the specific combinations needed for the current view, reducing memory usage from gigabytes to kilobytes.
*   **Fallback Logic:** Added a robust error-handling layer that provides "Recommended Numbers" based on statistical fallbacks if the ML model fails to load.
*   **Key Document:** `docs/notes/2026-01-21-session-summary-fixed.md`

## 5. Phase 4: Advanced Intelligence & Personalization (Jan 20–22)
The final stage of development focused on maximizing prediction accuracy and system stability.
*   **ONNX Migration:** Formally migrated the inference engine from TFLite to **ONNX Runtime (ORT)**. This resolved serialization issues with custom Keras layers and provided better support for modern mobile architectures.
*   **On-Device Personalization:** Integrated `OnDeviceTrainingService`. The model now performs local weight updates (recalibrating a bias layer) after every draw sync, allowing it to adapt to the "local trend" of recent results.
*   **UI Polish:** Introduced "AI Analysis" overlays on the selection screen, providing ball-by-ball probability percentages (%) for informed user decision-making.
*   **Key Document:** `docs/notes/2026-01-22-session-summary.md`

---

## 6. Current Technical Stack
| Component | Technology |
| :--- | :--- |
| **Framework** | Flutter (Dart) |
| **Database** | SQLite (sqflite) |
| **ML Engine** | ONNX Runtime (ORT) |
| **Model Type** | LSTM (Long Short-Term Memory) |
| **Data Source** | Official CWL API Crawler |
| **Optimizations** | Lazy-loading combinations, FP16 Quantization |

---

## 7. Final Status & Verification
*   **Core Features:** Live countdown, historical data sync, AI prediction, manual selection, and bet calculation are all **Verified Working**.
*   **Stability:** Passed `flutter analyze` with 0 issues; OOM risks eliminated via algorithmic paging.
*   **Next Steps:** Proceed to physical ARM device testing to finalize native library (ORT) verification.

**Integrated References:**
- `docs/notes/2026-01-21-final-testing-report.md` (Testing & Bug Fixes)
- `docs/plans/2026-01-20-onnx-ort-impl-plan.md` (Technical Migration)
- `docs/notes/2026-01-16-platform-change.md` (Engine Decision History)
