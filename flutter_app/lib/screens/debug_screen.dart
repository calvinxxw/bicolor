import 'package:flutter/material.dart';

import '../models/debug_data.dart';
import '../services/debug_service.dart';

class DebugScreen extends StatefulWidget {
  final DebugDataLoader loader;

  DebugScreen({super.key, DebugDataLoader? loader})
      : loader = loader ?? DebugService().load;

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  late Future<DebugData> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
  }

  Future<void> _reload() async {
    setState(() {
      _future = widget.loader();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Info'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<DebugData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    Text('Debug load failed: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _reload,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSummaryCard(data),
                const SizedBox(height: 12),
                _buildConstantsSection(data),
                _buildRecentSection(data),
                _buildTopKSection(data),
                _buildStatsSection(data),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(DebugData data) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Text('History: ${data.historyCount}'),
            Text('Latest Issue: ${data.latestIssue}'),
            Text('Latest Date: ${data.latestDate}'),
            Text('Model Source: ${data.modelSource}'),
          ],
        ),
      ),
    );
  }

  Widget _buildConstantsSection(DebugData data) {
    return ExpansionTile(
      title: const Text('Feature Constants'),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        _buildRow('Seq Len', '${data.seqLen}'),
        _buildRow('Red Window', _formatWindow(data.redWindow)),
        _buildRow('Blue Window', _formatWindow(data.blueWindow)),
        _buildRow('Alpha R', data.alphaR.toStringAsFixed(2)),
        _buildRow('Beta R', data.betaR.toStringAsFixed(2)),
        _buildRow('Alpha B', data.alphaB.toStringAsFixed(2)),
        _buildRow('Beta B', data.betaB.toStringAsFixed(2)),
      ],
    );
  }

  Widget _buildRecentSection(DebugData data) {
    return ExpansionTile(
      title: const Text('Recent Draws Used'),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        for (final issue in data.recentIssues) Text(issue),
        if (data.recentIssues.isEmpty) const Text('No recent draws available.'),
      ],
    );
  }

  Widget _buildTopKSection(DebugData data) {
    return ExpansionTile(
      title: const Text('Top-K Probabilities'),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        const Text('Red Top 12', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildProbChips(data.topRed, Colors.red),
        const SizedBox(height: 12),
        const Text('Blue Top 3', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildProbChips(data.topBlue, Colors.blue),
      ],
    );
  }

  Widget _buildStatsSection(DebugData data) {
    return ExpansionTile(
      title: const Text('Probability Sanity'),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        _buildRow(
          'Red min/max/sum',
          '${data.redStats.min.toStringAsFixed(4)} / '
              '${data.redStats.max.toStringAsFixed(4)} / '
              '${data.redStats.sum.toStringAsFixed(4)}',
        ),
        _buildRow('Red NaNs', '${data.redStats.nanCount}'),
        const SizedBox(height: 8),
        _buildRow(
          'Blue min/max/sum',
          '${data.blueStats.min.toStringAsFixed(4)} / '
              '${data.blueStats.max.toStringAsFixed(4)} / '
              '${data.blueStats.sum.toStringAsFixed(4)}',
        ),
        _buildRow('Blue NaNs', '${data.blueStats.nanCount}'),
      ],
    );
  }

  Widget _buildProbChips(List<DebugProbability> items, Color color) {
    if (items.isEmpty) {
      return const Text('No probabilities available.');
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map((item) => Chip(
                label: Text(
                  '${item.number.toString().padLeft(2, '0')} '
                  '${(item.probability * 100).toStringAsFixed(1)}%',
                ),
                backgroundColor: color.withOpacity(0.1),
                labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
              ))
          .toList(),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _formatWindow(int? window) {
    return window == null ? 'full' : window.toString();
  }
}
