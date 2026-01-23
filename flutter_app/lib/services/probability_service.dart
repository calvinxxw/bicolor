import '../models/bet_selection.dart';
import '../models/winning_probability.dart';
import '../utils/combination_math.dart';

class ProbabilityService {
  // Total possible combinations for single bet
  static const int totalRedCombinations = 1107568; // C(33, 6)
  static const int totalBlueBalls = 16;
  static const int totalCombinations = 17721088; // C(33, 6) × 16

  /// Calculate winning probabilities for all prize tiers
  List<WinningProbability> calculateProbabilities(BetSelection selection) {
    if (!selection.isValid) {
      return [];
    }

    final redCount = selection.selectedRedBalls.length;
    final blueCount = selection.selectedBlueBalls.length;

    return [
      _calculateFirstPrize(redCount, blueCount),
      _calculateSecondPrize(redCount, blueCount),
      _calculateThirdPrize(redCount, blueCount),
      _calculateFourthPrize(redCount, blueCount),
      _calculateFifthPrize(redCount, blueCount),
      _calculateSixthPrize(redCount, blueCount),
    ];
  }

  /// First Prize: 6 red + 1 blue
  WinningProbability _calculateFirstPrize(int redCount, int blueCount) {
    // Number of ways to match all 6 red balls from selected red balls
    final matchingRed = CombinationMath.combination(redCount, 6);
    // Number of ways to match 1 blue ball from selected blue balls
    final matchingBlue = blueCount;

    final combinations = matchingRed * matchingBlue;
    final probability = combinations / totalCombinations;

    return WinningProbability(
      tier: PrizeTier.first,
      probability: probability,
      combinations: combinations,
    );
  }

  /// Second Prize: 6 red (any blue)
  WinningProbability _calculateSecondPrize(int redCount, int blueCount) {
    // Match all 6 red balls, but not the blue ball
    final matchingRed = CombinationMath.combination(redCount, 6);
    final nonMatchingBlue = totalBlueBalls - blueCount;

    final combinations = matchingRed * nonMatchingBlue;
    final probability = combinations / totalCombinations;

    return WinningProbability(
      tier: PrizeTier.second,
      probability: probability,
      combinations: combinations,
    );
  }

  /// Third Prize: 5 red + 1 blue
  WinningProbability _calculateThirdPrize(int redCount, int blueCount) {
    // Match 5 out of 6 red balls, and 1 non-selected red ball
    final matchingRed = CombinationMath.combination(redCount, 5);
    final nonMatchingRed = CombinationMath.combination(33 - redCount, 1);
    final matchingBlue = blueCount;

    final combinations = matchingRed * nonMatchingRed * matchingBlue;
    final probability = combinations / totalCombinations;

    return WinningProbability(
      tier: PrizeTier.third,
      probability: probability,
      combinations: combinations,
    );
  }

  /// Fourth Prize: 5 red OR 4 red + 1 blue
  WinningProbability _calculateFourthPrize(int redCount, int blueCount) {
    // Case 1: 5 red, non-matching blue
    final case1MatchingRed = CombinationMath.combination(redCount, 5);
    final case1NonMatchingRed = CombinationMath.combination(33 - redCount, 1);
    final case1NonMatchingBlue = totalBlueBalls - blueCount;
    final case1 = case1MatchingRed * case1NonMatchingRed * case1NonMatchingBlue;

    // Case 2: 4 red + 1 blue
    final case2MatchingRed = CombinationMath.combination(redCount, 4);
    final case2NonMatchingRed = CombinationMath.combination(33 - redCount, 2);
    final case2MatchingBlue = blueCount;
    final case2 = case2MatchingRed * case2NonMatchingRed * case2MatchingBlue;

    final combinations = case1 + case2;
    final probability = combinations / totalCombinations;

    return WinningProbability(
      tier: PrizeTier.fourth,
      probability: probability,
      combinations: combinations,
    );
  }

  /// Fifth Prize: 4 red OR 3 red + 1 blue
  WinningProbability _calculateFifthPrize(int redCount, int blueCount) {
    // Case 1: 4 red, non-matching blue
    final case1MatchingRed = CombinationMath.combination(redCount, 4);
    final case1NonMatchingRed = CombinationMath.combination(33 - redCount, 2);
    final case1NonMatchingBlue = totalBlueBalls - blueCount;
    final case1 = case1MatchingRed * case1NonMatchingRed * case1NonMatchingBlue;

    // Case 2: 3 red + 1 blue
    final case2MatchingRed = CombinationMath.combination(redCount, 3);
    final case2NonMatchingRed = CombinationMath.combination(33 - redCount, 3);
    final case2MatchingBlue = blueCount;
    final case2 = case2MatchingRed * case2NonMatchingRed * case2MatchingBlue;

    final combinations = case1 + case2;
    final probability = combinations / totalCombinations;

    return WinningProbability(
      tier: PrizeTier.fifth,
      probability: probability,
      combinations: combinations,
    );
  }

  /// Sixth Prize: 2 red + 1 blue OR 1 red + 1 blue OR 0 red + 1 blue
  WinningProbability _calculateSixthPrize(int redCount, int blueCount) {
    // Case 1: 2 red + 1 blue
    final case1MatchingRed = CombinationMath.combination(redCount, 2);
    final case1NonMatchingRed = CombinationMath.combination(33 - redCount, 4);
    final case1MatchingBlue = blueCount;
    final case1 = case1MatchingRed * case1NonMatchingRed * case1MatchingBlue;

    // Case 2: 1 red + 1 blue
    final case2MatchingRed = CombinationMath.combination(redCount, 1);
    final case2NonMatchingRed = CombinationMath.combination(33 - redCount, 5);
    final case2MatchingBlue = blueCount;
    final case2 = case2MatchingRed * case2NonMatchingRed * case2MatchingBlue;

    // Case 3: 0 red + 1 blue
    final case3MatchingRed = CombinationMath.combination(redCount, 0);
    final case3NonMatchingRed = CombinationMath.combination(33 - redCount, 6);
    final case3MatchingBlue = blueCount;
    final case3 = case3MatchingRed * case3NonMatchingRed * case3MatchingBlue;

    final combinations = case1 + case2 + case3;
    final probability = combinations / totalCombinations;

    return WinningProbability(
      tier: PrizeTier.sixth,
      probability: probability,
      combinations: combinations,
    );
  }

  /// Calculate probability of winning any prize
  double calculateAnyPrizeProbability(BetSelection selection) {
    final probabilities = calculateProbabilities(selection);
    return probabilities.fold(0.0, (sum, p) => sum + p.probability);
  }
}
