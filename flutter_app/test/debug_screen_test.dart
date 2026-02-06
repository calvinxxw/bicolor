import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottery_predictor/main.dart';
import 'package:lottery_predictor/models/debug_data.dart';
import 'package:lottery_predictor/screens/debug_screen.dart';

void main() {
  testWidgets('debug menu opens debug screen with summary', (tester) async {
    final debugData = DebugData(
      historyCount: 123,
      latestIssue: '26010',
      latestDate: '2026-02-05',
      modelSource: 'Bundled',
      seqLen: 15,
      redWindow: null,
      blueWindow: null,
      alphaR: 1.0,
      betaR: 5.5,
      alphaB: 1.0,
      betaB: 15.0,
      recentIssues: const ['26010 (2026-02-05)'],
      topRed: const [DebugProbability(number: 1, probability: 0.12)],
      topBlue: const [DebugProbability(number: 2, probability: 0.34)],
      redStats: const ProbabilityStats(min: 0.01, max: 0.12, sum: 1.0, nanCount: 0),
      blueStats: const ProbabilityStats(min: 0.02, max: 0.34, sum: 1.0, nanCount: 0),
    );

    await tester.pumpWidget(MaterialApp(
      home: const MainScreen(
        screens: [SizedBox(), SizedBox(), SizedBox()],
        titles: ['Home', 'Manual', 'History'],
      ),
      routes: {
        '/debug': (_) => DebugScreen(loader: () async => debugData),
      },
    ));

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Debug'), findsOneWidget);

    await tester.tap(find.text('Debug'));
    await tester.pumpAndSettle();

    expect(find.text('Debug Info'), findsOneWidget);
    expect(find.textContaining('History: 123'), findsOneWidget);
    expect(find.textContaining('Latest Issue: 26010'), findsOneWidget);
  });
}
