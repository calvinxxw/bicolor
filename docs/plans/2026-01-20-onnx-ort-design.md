# ONNX Runtime + Transformers Integration Design

**Date:** 2026-01-20  
**Status:** Draft (validated in chat)  
**Scope:** Replace TFLite with on-device Hugging Face Transformers + ONNX Runtime

## 1. Overview

Pivot the mobile-only Flutter app away from TensorFlow Lite. The new inference
stack uses two Hugging Face Transformer models exported to ONNX and executed
on-device via ONNX Runtime Mobile. The app keeps the same UI and data flow:
five recent draws in, top-6 red balls and top-1 blue ball out.

## 2. Goals

- Run prediction locally on Android/iOS with ONNX Runtime Mobile.
- Use base-size Transformer models (separate red/blue models).
- Keep inference in FP32.
- Maintain current UI behavior and prediction flow.

## 3. Non-Goals

- Server-side inference or hybrid routing.
- Accuracy tuning beyond a working baseline.
- Model quantization (FP16/INT8) in this phase.
- Desktop platforms.

## 4. Key Decisions

- **On-device inference:** ORT Mobile only, no backend service.
- **Two models:** `red_ball.onnx` (33-class) and `blue_ball.onnx` (16-class).
- **Input format:** last 5 draws, same shape as existing TFLite flow.
- **FP32:** keep export and runtime in FP32 for the first baseline.

## 5. Architecture

### Components

1. **ML Training Pipeline (Python, HF Transformers)**
   - Custom numeric tokenizer and dataset builder.
   - Base Transformer encoder trained from scratch.
   - Two heads or two separate models (we choose two models).
   - ONNX export scripts.

2. **Flutter Inference Layer (Dart)**
   - `PredictionService` loads ONNX Runtime sessions.
   - Encodes input draws into token IDs + attention masks.
   - Runs red and blue sessions, softmax, top-K selection.

3. **UI**
   - Same prediction screen and display as current Flutter UI.

### Data Flow

```
User taps Predict
  -> Encode 5 draws into tokens
  -> Run red ONNX session -> probs (33)
  -> Run blue ONNX session -> probs (16)
  -> Select top-6 red, top-1 blue
  -> Render predictions
```

## 6. Data and Tokenization

### Input Format

- 5 draws, each with 6 red numbers.
- 5 draws, each with 1 blue number.

### Tokenization Strategy

- Build a tiny vocab:
  - Red tokens: r1..r33
  - Blue tokens: b1..b16
  - Special tokens: [CLS], [SEP], [PAD]
- Sequence example (red):
  `[CLS] r3 r7 r12 r18 r25 r31 [SEP] r5 r9 r15 r22 r28 r33 [SEP] ...`
- Pad/truncate to a fixed length; include attention mask.

## 7. Model Architecture and Training

### Model

- Base Transformer encoder (BERT-base dimensions) with small vocab.
- Two independent models:
  - Red model outputs 33 logits.
  - Blue model outputs 16 logits.

### Training Data

- Historical draw sequences:
  - Input: last 5 draws.
  - Target: next draw (red or blue).
- Use cross-entropy loss on logits.

### Training Notes

- Train from scratch (no English pretraining).
- Track accuracy and calibration, but only require a functional baseline.

## 8. ONNX Export and Validation

- Export with `torch.onnx.export` (opset 13+).
- Validate PyTorch vs ONNX outputs on a fixed input.
- Store ONNX models in `flutter_app/assets/models/`.

## 9. Flutter Integration

### Dependencies

- Replace `tflite_flutter` with `onnxruntime` (official Microsoft Flutter package).
- Keep Android/iOS only.

### Inference

- Create ONNX sessions once and cache them.
- Input tensors:
  - `input_ids`: int64
  - `attention_mask`: int64
- Output:
  - logits -> softmax -> top-K selection.

## 10. Error Handling

- Catch and surface model load failures via SnackBar.
- Validate input length and shapes before inference.
- Fail fast on missing assets with clear logs.

## 11. Testing

### Python

- ONNX export parity test (PyTorch vs ONNX).

### Flutter

- Unit test for tokenization and top-K selection.
- Device smoke test on Android API 26+.

## 12. Migration and Cleanup

- Remove TFLite dependencies and Flex/select-ops setup.
- Replace TFLite docs with ONNX instructions.
- Archive or mark old TFLite plans as superseded.

## 13. Risks

- Base-size Transformer may be heavy for mobile devices.
- Dataset quality drives prediction usefulness.
- ORT Mobile minimum API requirements may force minSdk bump.

## 14. Success Criteria

- App runs on Android/iOS with ONNX Runtime.
- Predict returns 6 red + 1 blue without runtime errors.
- ONNX models load reliably from assets.
- Docs reflect ONNX workflow and training steps.
