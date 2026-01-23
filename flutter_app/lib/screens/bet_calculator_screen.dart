import 'package:flutter/material.dart';
import '../models/bet_selection.dart';
import '../models/bet_combination.dart';
import '../services/bet_service.dart';
import '../widgets/ball_widget.dart';
import '../widgets/probability_display_widget.dart';

class BetCalculatorScreen extends StatefulWidget {
  final BetSelection selection;

  const BetCalculatorScreen({
    super.key,
    required this.selection,
  });

  @override
  State<BetCalculatorScreen> createState() => _BetCalculatorScreenState();
}

class _BetCalculatorScreenState extends State<BetCalculatorScreen> {
  final BetService _betService = BetService();
  List<BetCombination>? _combinations;
  bool _isGenerating = false;
  int _currentPage = 0;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _generateCombinations();
  }

  Future<void> _generateCombinations() async {
    setState(() {
      _isGenerating = true;
    });

    // Use Future.delayed to allow UI to update
    await Future.delayed(const Duration(milliseconds: 100));

    final combinations = _betService.generateCombinationsPage(
      widget.selection,
      _currentPage,
      _pageSize,
    );

    setState(() {
      _combinations = combinations;
      _isGenerating = false;
    });
  }

  void _loadNextPage() {
    final totalPages = _betService.getTotalPages(widget.selection, _pageSize);
    if (_currentPage < totalPages - 1) {
      setState(() {
        _currentPage++;
      });
      _generateCombinations();
    }
  }

  void _loadPreviousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
      _generateCombinations();
    }
  }

  void _exportToText() {
    final text = _betService.exportToText(widget.selection);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导出投注单'),
        content: SingleChildScrollView(
          child: SelectableText(text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = _betService.getTotalPages(widget.selection, _pageSize);

    return Scaffold(
      appBar: AppBar(
        title: const Text('投注详情'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportToText,
            tooltip: '导出',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '投注汇总',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    _buildSummaryRow('投注类型', widget.selection.betTypeDescription),
                    _buildSummaryRow(
                      '选择号码',
                      '红球${widget.selection.selectedRedBalls.length}个 + 蓝球${widget.selection.selectedBlueBalls.length}个',
                    ),
                    _buildSummaryRow(
                      '总注数',
                      '${widget.selection.totalCombinations}注',
                    ),
                    _buildSummaryRow(
                      '总金额',
                      '¥${widget.selection.totalCost.toStringAsFixed(0)}',
                      valueColor: widget.selection.totalCost > 100
                          ? Colors.red
                          : Colors.green,
                    ),
                    if (widget.selection.totalCost > 100)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '⚠️ 投注金额较大，请理性投注',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            ProbabilityDisplayWidget(selection: widget.selection),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '投注组合 (第${_currentPage + 1}页，共$totalPages页)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _currentPage > 0 ? _loadPreviousPage : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed:
                            _currentPage < totalPages - 1 ? _loadNextPage : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 400,
              child: _isGenerating
                  ? const Center(child: CircularProgressIndicator())
                  : _combinations == null || _combinations!.isEmpty
                      ? const Center(child: Text('无投注组合'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _combinations!.length,
                          itemBuilder: (context, index) {
                            final combo = _combinations![index];
                            final globalIndex = _currentPage * _pageSize + index;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 40,
                                      child: Text(
                                        '${globalIndex + 1}.',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: [
                                          ...combo.redBalls.map(
                                            (ball) => BallWidget(
                                              number: ball,
                                              size: 28,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          BallWidget(
                                            number: combo.blueBall,
                                            isBlue: true,
                                            size: 28,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
