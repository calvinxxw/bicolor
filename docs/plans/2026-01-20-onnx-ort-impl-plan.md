# Implementation Plan: ONNX Runtime + Transformers

**Date:** 2026-01-20  
**Status:** Draft  
**Depends on:** `docs/plans/2026-01-20-onnx-ort-design.md`

## Phase 0: Decide Runtime Package

1. Use `onnxruntime` (official Microsoft Flutter package).
2. Verify Android/iOS support and minimum API requirements for `onnxruntime`.

## Phase 1: ML Training Pipeline (Python)

1. Create `ml/` directory with:
   - Dataset loader and preprocessing scripts.
   - Tokenizer definition for numeric tokens.
2. Implement two model configs:
   - `red_model.py` (33 outputs)
   - `blue_model.py` (16 outputs)
3. Train baseline models on historical draws.
4. Export to ONNX (opset 13+).
5. Add ONNX parity test (PyTorch vs ONNX).

## Phase 2: Flutter Integration

1. Add ONNX Runtime dependency to `pubspec.yaml`.
2. Add `assets/models/red_ball.onnx` and `assets/models/blue_ball.onnx`.
3. Replace TFLite code in `PredictionService`:
   - Tokenization and tensor creation.
   - ORT session initialization and caching.
   - Softmax and top-K selection.
4. Keep UI unchanged; reuse current prediction screen.

## Phase 3: Cleanup and Docs

1. Remove `tflite_flutter` and select-ops dependencies.
2. Remove TFLite-related docs and setup steps.
3. Update README with ONNX workflow and training steps.
4. Mark TFLite plans as superseded in docs.

## Phase 4: Validation

1. Android device/emulator run (API per ORT requirements).
2. Verify predict flow returns 6 red + 1 blue.
3. Capture logs for model load and inference timing.

## Phase 5: Optional Follow-ups

1. Investigate FP16/INT8 quantization if size/latency is an issue.
2. Consider smaller model variants if base size is too heavy.
