class CombinationMath {
  /// Calculate combination C(n, r) = n! / (r! * (n-r)!)
  static int combination(int n, int r) {
    if (r > n) return 0;
    if (r == 0 || r == n) return 1;

    // Optimize by using smaller r
    if (r > n - r) {
      r = n - r;
    }

    int result = 1;
    for (int i = 0; i < r; i++) {
      result *= (n - i);
      result ~/= (i + 1);
    }
    return result;
  }

  /// Calculate factorial n!
  static int factorial(int n) {
    if (n <= 1) return 1;
    int result = 1;
    for (int i = 2; i <= n; i++) {
      result *= i;
    }
    return result;
  }

  /// Generate all combinations of r elements from a list of n elements
  static List<List<T>> generateCombinations<T>(List<T> elements, int r) {
    if (r > elements.length) return [];
    if (r == 0) return [[]];
    if (r == elements.length) return [elements];

    List<List<T>> result = [];
    _generateCombinationsHelper(elements, r, 0, [], result);
    return result;
  }

  static void _generateCombinationsHelper<T>(
    List<T> elements,
    int r,
    int start,
    List<T> current,
    List<List<T>> result,
  ) {
    if (current.length == r) {
      result.add(List.from(current));
      return;
    }

    for (int i = start; i <= elements.length - (r - current.length); i++) {
      current.add(elements[i]);
      _generateCombinationsHelper(elements, r, i + 1, current, result);
      current.removeLast();
    }
  }
}
