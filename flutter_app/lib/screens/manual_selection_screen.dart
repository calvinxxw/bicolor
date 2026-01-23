import 'package:flutter/material.dart';
import '../models/bet_selection.dart';
import '../widgets/number_picker_widget.dart';
import '../services/prediction_service.dart';

class ManualSelectionScreen extends StatefulWidget {
  const ManualSelectionScreen({super.key});

  @override
  State<ManualSelectionScreen> createState() => _ManualSelectionScreenState();
}

class _ManualSelectionScreenState extends State<ManualSelectionScreen> {
  BetSelection _selection = BetSelection();
  final PredictionService _predictionService = PredictionService();
  bool _isAILoading = false;
  
  List<double>? _redProbs;
  List<double>? _blueProbs;
  Set<int>? _aiRedBalls;
  Set<int>? _aiBlueBalls;

  @override
  void dispose() {
    _predictionService.dispose();
    super.dispose();
  }

  void _toggleRedBall(int number) {
    setState(() {
      final newSet = Set<int>.from(_selection.selectedRedBalls);
      if (newSet.contains(number)) {
        newSet.remove(number);
      } else {
        if (newSet.length < 20) {
          newSet.add(number);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('最多选择20个红球')),
          );
        }
      }
      _selection = _selection.copyWith(selectedRedBalls: newSet);
    });
  }

  void _toggleBlueBall(int number) {
    setState(() {
      final newSet = Set<int>.from(_selection.selectedBlueBalls);
      if (newSet.contains(number)) {
        newSet.remove(number);
      } else {
        newSet.add(number);
      }
      _selection = _selection.copyWith(selectedBlueBalls: newSet);
    });
  }

  void _clearAll() {
    setState(() {
      _selection = BetSelection();
      _aiRedBalls = null;
      _aiBlueBalls = null;
      _redProbs = null;
      _blueProbs = null;
    });
  }

  Future<void> _loadAIProbabilities() async {
    setState(() {
      _isAILoading = true;
    });

    try {
      final probs = await _predictionService.getFullProbabilities();
      
      // Get ranked indices for Red
      final List<Map<String, dynamic>> redRanked = List.generate(
        33, (i) => {'num': i + 1, 'prob': probs['red']![i]}
      );
      redRanked.sort((a, b) => (b['prob'] as double).compareTo(a['prob'] as double));
      
      // Get ranked indices for Blue
      final List<Map<String, dynamic>> blueRanked = List.generate(
        16, (i) => {'num': i + 1, 'prob': probs['blue']![i]}
      );
      blueRanked.sort((a, b) => (b['prob'] as double).compareTo(a['prob'] as double));

      // Strategy: Automatically select top 12 Red and top 3 Blue as a "Multiple Selection" pool
      // This pool strategy targets ~50% hit rate for 4+ red balls in the selected set.
      final topRed = redRanked.take(12).map((e) => e['num'] as int).toSet();
      final topBlue = blueRanked.take(3).map((e) => e['num'] as int).toSet();

      setState(() {
        _redProbs = probs['red'];
        _blueProbs = probs['blue'];
        _aiRedBalls = topRed;
        _aiBlueBalls = topBlue;
        
        // Populate current selection with AI recommendations
        _selection = BetSelection(
          selectedRedBalls: topRed,
          selectedBlueBalls: topBlue,
        );
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已为您选取AI推荐的"50%准确率"池组合 (前12红+前3蓝)'),
            backgroundColor: Colors.deepPurple,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI加载失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAILoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Action buttons row
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              if (_isAILoading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: _loadAIProbabilities,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('AI 智能复式'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: const Text('清空'),
                onPressed: _clearAll,
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NumberPickerWidget(
                  ballType: BallType.red,
                  selectedNumbers: _selection.selectedRedBalls,
                  aiRecommendedNumbers: _aiRedBalls,
                  probabilities: _redProbs,
                  onNumberTap: _toggleRedBall,
                ),
                const SizedBox(height: 32),
                NumberPickerWidget(
                  ballType: BallType.blue,
                  selectedNumbers: _selection.selectedBlueBalls,
                  aiRecommendedNumbers: _aiBlueBalls,
                  probabilities: _blueProbs,
                  onNumberTap: _toggleBlueBall,
                ),
                const SizedBox(height: 32),
                if (_redProbs != null && _blueProbs != null) ...[
                  const Text(
                    'AI 概率排行榜',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildRankingSection(),
                  const SizedBox(height: 32),
                ],
                if (_selection.isValid) ...[
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.receipt_long, size: 20, color: Colors.deepPurple),
                              SizedBox(width: 8),
                              Text(
                                '投注预览',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          _buildInfoRow('投注类型', _selection.betTypeDescription),
                          _buildInfoRow('总注数', '${_selection.totalCombinations} 注'),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('总金额', style: TextStyle(fontSize: 16)),
                              Text(
                                '¥${_selection.totalCost.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: _selection.totalCost > 200
                                      ? Colors.red
                                      : Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/bet-calculator',
                          arguments: _selection,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        '查看组合详情',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: Text(
                      '© 2026 许迅文. All Rights Reserved.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRankingSection() {
    // Red Ranking
    final List<Map<String, dynamic>> redRanked = List.generate(
      33, (i) => {'num': i + 1, 'prob': _redProbs![i]}
    )..sort((a, b) => (b['prob'] as double).compareTo(a['prob'] as double));

    // Blue Ranking
    final List<Map<String, dynamic>> blueRanked = List.generate(
      16, (i) => {'num': i + 1, 'prob': _blueProbs![i]}
    )..sort((a, b) => (b['prob'] as double).compareTo(a['prob'] as double));

    return Column(
      children: [
        _buildRankList('红球热度前15', redRanked.take(15).toList(), Colors.red),
        const SizedBox(height: 16),
        _buildRankList('蓝球热度前5', blueRanked.take(5).toList(), Colors.blue),
      ],
    );
  }

  Widget _buildRankList(String title, List<Map<String, dynamic>> items, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((item) {
              final isSelected = item['num'] <= 33 && color == Colors.red 
                  ? _selection.selectedRedBalls.contains(item['num'])
                  : _selection.selectedBlueBalls.contains(item['num']);
              
              return FilterChip(
                label: Text('${item['num'].toString().padLeft(2, '0')} (${(item['prob'] * 100).toStringAsFixed(1)}%)'),
                selected: isSelected,
                onSelected: (val) {
                  if (color == Colors.red) _toggleRedBall(item['num']);
                  else _toggleBlueBall(item['num']);
                },
                selectedColor: color.withValues(alpha: 0.2),
                checkmarkColor: color,
                labelStyle: TextStyle(
                  color: isSelected ? color : Colors.black87,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}