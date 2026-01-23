import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/manual_selection_screen.dart';
import 'screens/bet_calculator_screen.dart';
import 'models/bet_selection.dart';
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
      home: const MainScreen(),
      onGenerateRoute: (settings) {
        if (settings.name == '/history') {
          return MaterialPageRoute(
            builder: (context) => const HistoryScreen(),
          );
        } else if (settings.name == '/bet-calculator') {
          final selection = settings.arguments as BetSelection;
          return MaterialPageRoute(
            builder: (context) => BetCalculatorScreen(selection: selection),
          );
        }
        return null;
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const ManualSelectionScreen(),
    const PredictionScreen(),
  ];

  final List<String> _titles = [
    '双色球',
    '手动选号',
    'AI预测',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_on),
            label: '手动选号',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.psychology),
            label: 'AI预测',
          ),
        ],
      ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('AI 正在计算最佳中奖组合...', style: TextStyle(color: Colors.grey)),
                ],
              )
            else if (_result == null)
              Column(
                children: [
                  Icon(Icons.auto_awesome, size: 64, color: Colors.deepPurple[200]),
                  const SizedBox(height: 16),
                  const Text(
                    '基于深度学习模型预测下一期号码\n(仅供参考)',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            else
              _buildPredictionDisplay(),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _runPrediction,
              icon: const Icon(Icons.psychology),
              label: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text('生成预测', style: TextStyle(fontSize: 18)),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            ),
            if (_errorMessage != null)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 16),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '预测出错了，已为您生成推荐号码',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 32),
            const Text(
              '漏 2026 璁歌繀鏂. All Rights Reserved.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionDisplay() {
    return Column(
      children: [
        const Text(
          '红球',
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
          '蓝球',
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