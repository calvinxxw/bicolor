import '../models/bet_selection.dart';
import '../models/bet_combination.dart';
import '../utils/combination_math.dart';

class BetService {
  /// Generate all bet combinations from a selection
  List<BetCombination> generateCombinations(BetSelection selection) {
    if (!selection.isValid) {
      return [];
    }

    final redBallsList = selection.selectedRedBalls.toList()..sort();
    final blueBallsList = selection.selectedBlueBalls.toList()..sort();

    // Generate all combinations of 6 red balls
    final redCombinations = CombinationMath.generateCombinations(redBallsList, 6);

    // Generate all bet combinations
    final List<BetCombination> combinations = [];
    for (final redCombo in redCombinations) {
      for (final blueBall in blueBallsList) {
        combinations.add(BetCombination(
          redBalls: redCombo,
          blueBall: blueBall,
        ));
      }
    }

    return combinations;
  }

  /// Generate combinations with pagination (optimized)
  List<BetCombination> generateCombinationsPage(
    BetSelection selection, {
    required int page,
    required int pageSize,
  }) {
    if (!selection.isValid) {
      return [];
    }

    final total = selection.totalCombinations;
    final startIndex = page * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, total);

    if (startIndex >= total) {
      return [];
    }

    final redBallsList = selection.selectedRedBalls.toList()..sort();
    final blueBallsList = selection.selectedBlueBalls.toList()..sort();
    final blueCount = blueBallsList.length;

    final List<BetCombination> results = [];
    
    // Calculate which red combinations we need
    // Each red combination is repeated blueCount times
    for (int i = startIndex; i < endIndex; i++) {
      final redComboIndex = i ~/ blueCount;
      final blueIndex = i % blueCount;
      
      final redCombo = _getKthCombination(redBallsList, 6, redComboIndex);
      results.add(BetCombination(
        redBalls: redCombo,
        blueBall: blueBallsList[blueIndex],
      ));
    }

    return results;
  }

  /// Get the k-th combination of r elements from a list
  /// This is much more memory efficient than generating all combinations
  List<int> _getKthCombination(List<int> elements, int r, int k) {
    List<int> result = [];
    int n = elements.length;
    int currentK = k;

    for (int i = 0; i < r; i++) {
      for (int j = 1; j <= n; j++) {
        int c = CombinationMath.combination(n - j, r - i - 1);
        if (currentK < c) {
          result.add(elements[elements.length - n + j - 1]);
          n = n - j;
          break;
        } else {
          currentK -= c;
        }
      }
    }
    return result;
  }

  /// Calculate total pages for pagination
  int getTotalPages(BetSelection selection, int pageSize) {
    final totalCombinations = selection.totalCombinations;
    return (totalCombinations / pageSize).ceil();
  }

  /// Export combinations to text format (limited to first 1000)
  String exportToText(BetSelection selection) {
    final total = selection.totalCombinations;
    final exportCount = total > 1000 ? 1000 : total;
    
    final buffer = StringBuffer();

    buffer.writeln('双色球投注单');
    buffer.writeln('=' * 40);
    buffer.writeln('投注类型: ${selection.betTypeDescription}');
    buffer.writeln('总注数: $total');
    buffer.writeln('总金额: ¥${selection.totalCost.toStringAsFixed(0)}');
    if (total > 1000) {
      buffer.writeln('备注: 仅导出前1000注');
    }
    buffer.writeln('=' * 40);
    buffer.writeln();

    final redBallsList = selection.selectedRedBalls.toList()..sort();
    final blueBallsList = selection.selectedBlueBalls.toList()..sort();
    final blueCount = blueBallsList.length;

    for (int i = 0; i < exportCount; i++) {
      final redComboIndex = i ~/ blueCount;
      final blueIndex = i % blueCount;
      final redCombo = _getKthCombination(redBallsList, 6, redComboIndex);
      
      final combo = BetCombination(
        redBalls: redCombo,
        blueBall: blueBallsList[blueIndex],
      );
      buffer.writeln('${(i + 1).toString().padLeft(4, ' ')}. ${combo.toString()}');
    }

    return buffer.toString();
  }
}
