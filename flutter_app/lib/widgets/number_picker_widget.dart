import 'package:flutter/material.dart';

enum BallType { red, blue }

class NumberPickerWidget extends StatelessWidget {
  final BallType ballType;
  final Set<int> selectedNumbers;
  final Set<int>? aiRecommendedNumbers;
  final List<double>? probabilities;
  final Function(int) onNumberTap;

  const NumberPickerWidget({
    super.key,
    required this.ballType,
    required this.selectedNumbers,
    this.aiRecommendedNumbers,
    this.probabilities,
    required this.onNumberTap,
  });

  @override
  Widget build(BuildContext context) {
    final maxNumber = ballType == BallType.red ? 33 : 16;
    final color = ballType == BallType.red ? Colors.red : Colors.blue;
    final title = ballType == BallType.red ? '红球' : '蓝球';
    final subtitle = ballType == BallType.red
        ? '请选择6-20个红球 (已选${selectedNumbers.length}个)'
        : '请选择1-16个蓝球 (已选${selectedNumbers.length}个)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            crossAxisSpacing: 8,
            mainAxisSpacing: 12,
            childAspectRatio: 0.8,
          ),
          itemCount: maxNumber,
          itemBuilder: (context, index) {
            final number = index + 1;
            final isSelected = selectedNumbers.contains(number);
            final isAiRecommended =
                aiRecommendedNumbers?.contains(number) ?? false;
            final prob = probabilities != null && probabilities!.length > index
                ? probabilities![index]
                : null;

            return GestureDetector(
              onTap: () => onNumberTap(number),
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color
                            : isAiRecommended
                                ? color.withValues(alpha: 0.3)
                                : Colors.grey[200],
                        shape: BoxShape.circle,
                        border: isAiRecommended && !isSelected
                            ? Border.all(color: color, width: 2)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          number.toString().padLeft(2, '0'),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontSize: 14,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (prob != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${(prob * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 10,
                          color: color.withValues(alpha: 0.8),
                          fontWeight: isAiRecommended ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
