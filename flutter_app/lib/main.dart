import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/manual_selection_screen.dart';
import 'screens/bet_calculator_screen.dart';
import 'screens/backtest_screen.dart';
import 'screens/manual_entry_screen.dart';
import 'screens/debug_screen.dart';
import 'models/bet_selection.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lottery Predictor',
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
        } else if (settings.name == '/manual-entry') {
          return MaterialPageRoute(
            builder: (context) => const ManualEntryScreen(),
          );
        } else if (settings.name == '/bet-calculator') {
          final selection = settings.arguments as BetSelection;
          return MaterialPageRoute(
            builder: (context) => BetCalculatorScreen(selection: selection),
          );
        } else if (settings.name == '/debug') {
          return MaterialPageRoute(
            builder: (context) => DebugScreen(),
          );
        }
        return null;
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  final List<Widget>? screens;
  final List<String>? titles;

  const MainScreen({super.key, this.screens, this.titles});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  List<Widget> get _screens => widget.screens ?? const [
    const HomeScreen(),
    const ManualSelectionScreen(),
    const BacktestScreen(),
  ];

  List<String> get _titles => widget.titles ?? const [
    '双色球',
    '手动选号',
    '历史回测',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: _currentIndex == 0
            ? [
                PopupMenuButton<int>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 0) {
                      Navigator.pushNamed(context, '/debug');
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 0,
                      child: Text('Debug'),
                    ),
                  ],
                ),
              ]
            : null,
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
            icon: Icon(Icons.history_edu),
            label: '历史回测',
          ),
        ],
      ),
    );
  }
}
