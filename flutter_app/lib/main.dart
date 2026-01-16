import 'package:flutter/material.dart';
import 'services/prediction_service.dart';
import 'models/prediction_result.dart';
import 'widgets/ball_widget.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lottery Prediction',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const PredictionScreen(),
    );
  }
}

class PredictionScreen extends StatefulWidget {
  const PredictionScreen({super.key});

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  final PredictionService _service = PredictionService();
  PredictionResult? _result;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _runPrediction() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _service.predict();
      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Prediction failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Lottery Prediction'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading)
                const CircularProgressIndicator()
              else if (_result == null)
                const Text(
                  'Tap "Predict" to generate lottery numbers',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                )
              else
                _buildPredictionDisplay(),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _runPrediction,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  child: Text('Predict', style: TextStyle(fontSize: 18)),
                ),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPredictionDisplay() {
    return Column(
      children: [
        const Text(
          'Red Balls',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _result!.redBalls
              .map((ball) => BallWidget(number: ball.number))
              .toList(),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _result!.redBalls
              .map((ball) => Text(
                    '${(ball.confidence * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 12),
                  ))
              .toList(),
        ),
        const SizedBox(height: 24),
        const Text(
          'Blue Ball',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        BallWidget(number: _result!.blueBall.number, isBlue: true),
        const SizedBox(height: 8),
        Text(
          '${(_result!.blueBall.confidence * 100).toStringAsFixed(1)}%',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
