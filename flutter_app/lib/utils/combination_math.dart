class CombinationMath {
  static int countCombinations(int n, int k) {
    if (k < 0 || k > n) return 0;
    if (k == 0 || k == n) return 1;
    if (k > n / 2) k = n - k;

    int result = 1;
    for (int i = 1; i <= k; i++) {
      result = result * (n - i + 1) ~/ i;
    }
    return result;
  }

  static List<List<int>> getCombinations(List<int> elements, int k) {
    List<List<int>> result = [];
    _generateCombinations(elements, k, 0, [], result);
    return result;
  }

  static void _generateCombinations(List<int> elements, int k, int start, List<int> current, List<List<int>> result) {
    if (current.length == k) {
      result.add(List.from(current));
      return;
    }

    for (int i = start; i < elements.length; i++) {
      current.add(elements[i]);
      _generateCombinations(elements, k, i + 1, current, result);
      current.removeLast();
    }
  }
}