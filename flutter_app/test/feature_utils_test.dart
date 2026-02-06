import 'package:flutter_test/flutter_test.dart';
import 'package:lottery_predictor/services/feature_utils.dart';

void main() {
  test('selectContext returns full history when window is null', () {
    final data = List<int>.generate(10, (i) => i);
    final result = FeatureUtils.selectContext(data, null, 3);
    expect(result.length, data.length);
    expect(result.first, data.first);
    expect(result.last, data.last);
  });

  test('selectContext limits history by window + seqLen', () {
    final data = List<int>.generate(20, (i) => i);
    final result = FeatureUtils.selectContext(data, 5, 3);
    expect(result.length, 8);
    expect(result.first, 12);
    expect(result.last, 19);
  });

  test('smoothedFrequency applies bayesian priors', () {
    final value = FeatureUtils.smoothedFrequency(1, 30, 1.0, 5.5);
    expect(value, closeTo(2 / 36.5, 1e-9));
  });

  test('feature constants use full-history windows', () {
    expect(FeatureUtils.redWindow, isNull);
    expect(FeatureUtils.blueWindow, isNull);
    expect(FeatureUtils.seqLen, 15);
    expect(FeatureUtils.alphaR, 1.0);
    expect(FeatureUtils.betaR, 5.5);
    expect(FeatureUtils.alphaB, 1.0);
    expect(FeatureUtils.betaB, 15.0);
  });
}
