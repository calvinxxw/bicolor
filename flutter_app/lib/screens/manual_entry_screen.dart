import 'package:flutter/material.dart';
import '../models/lottery_result.dart';
import '../services/database_service.dart';
import '../services/bet_service.dart';
import '../widgets/number_picker_widget.dart';

class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _issueController = TextEditingController();
  final BetService _betService = BetService();
  DateTime _selectedDate = DateTime.now();
  final Set<int> _selectedReds = {};
  int? _selectedBlue;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchSuggestedIssue();
  }

  Future<void> _fetchSuggestedIssue() async {
    final latestIssue = await DatabaseService().getLatestIssue();
    if (latestIssue != null) {
      int? issueNum = int.tryParse(latestIssue);
      if (issueNum != null) {
        setState(() {
          _issueController.text = (issueNum + 1).toString();
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _toggleRedBall(int number) {
    setState(() {
      if (_selectedReds.contains(number)) {
        _selectedReds.remove(number);
      } else {
        if (_selectedReds.length < 6) {
          _selectedReds.add(number);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('红球只能选择6个')),
          );
        }
      }
    });
  }

  void _selectBlueBall(int number) {
    setState(() {
      _selectedBlue = number;
    });
  }

  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedReds.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择6个红球')),
      );
      return;
    }
    if (_selectedBlue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择1个蓝球')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final reds = _selectedReds.toList()..sort();
      final result = LotteryResult(
        id: 0,
        issue: _issueController.text,
        drawDate: "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}",
        redBalls: reds,
        blueBall: _selectedBlue!,
        createdAt: DateTime.now(),
      );

      final id = await DatabaseService().insertResult(result);
      if (id > 0) {
        // Trigger bet verification
        await _betService.verifyAllBets();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('成功保存开奖结果并已更新中奖状态'), backgroundColor: Colors.green),
          );
          Navigator.pop(context, true);
        }
      } else {
        throw Exception("数据库插入失败，可能期号已存在");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('手动录入开奖'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _issueController,
                decoration: const InputDecoration(
                  labelText: '期号 (如 2024001)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入期号';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('开奖日期'),
                subtitle: Text("${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}"),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 24),
              NumberPickerWidget(
                ballType: BallType.red,
                selectedNumbers: _selectedReds,
                onNumberTap: _toggleRedBall,
                subtitle: '请选择恰好6个红球 (已选${_selectedReds.length}个)',
              ),
              const SizedBox(height: 24),
              NumberPickerWidget(
                ballType: BallType.blue,
                selectedNumbers: _selectedBlue != null ? {_selectedBlue!} : {},
                onNumberTap: _selectBlueBall,
                subtitle: '请选择恰好1个蓝球',
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveEntry,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('确认保存', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
