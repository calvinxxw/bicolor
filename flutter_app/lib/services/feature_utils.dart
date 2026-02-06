class FeatureUtils {
  static const int seqLen = 15;
  static const int? redWindow = null;
  static const int? blueWindow = null;
  static const double alphaR = 1.0;
  static const double betaR = 5.5;
  static const double alphaB = 1.0;
  static const double betaB = 15.0;

  static double smoothedFrequency(int hits, int window, double alpha, double beta) {
    return (hits + alpha) / (window + alpha + beta);
  }

  static List<T> selectContext<T>(List<T> data, int? window, int seqLen) {
    if (window == null) {
      return List<T>.from(data);
    }
    final size = window + seqLen;
    if (data.length <= size) {
      return List<T>.from(data);
    }
    return data.sublist(data.length - size);
  }
}
