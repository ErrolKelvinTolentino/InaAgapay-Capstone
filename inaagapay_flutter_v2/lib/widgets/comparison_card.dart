// lib/widgets/comparison_card.dart

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ComparisonCard extends StatelessWidget {
  final int week;

  const ComparisonCard({
    super.key,
    required this.week,
  });

  // Data source
  static const Map<int, Map<String, String>> _comparisonData = {
    1: {'label': 'Baby will soon be as small as', 'name': 'A Rice Grain'},
    2: {'label': 'Baby will soon be as small as', 'name': 'A Rice Grain'},
    3: {'label': 'Baby will soon be as small as', 'name': 'A Rice Grain'},
    4: {'label': 'Baby is as small as', 'name': 'A Rice Grain'},
    5: {'label': 'Baby is about as big as', 'name': 'A Green Pea'},
    6: {'label': 'Baby is about as big as', 'name': 'A Coffee Bean'},
    7: {'label': 'Baby is now as big as', 'name': 'A Blueberry'},
    8: {'label': 'Baby is now as big as', 'name': 'A Raspberry'},
    9: {'label': 'Baby is now as big as', 'name': 'A Cherry'},
    10: {'label': 'Baby is now as big as', 'name': 'A Strawberry'},
    11: {'label': 'Baby is about as big as', 'name': 'A Lime'},
    12: {'label': 'Baby is about as big as', 'name': 'A Plum'},
    13: {'label': 'Baby is about as big as', 'name': 'A Lemon'},
    14: {'label': 'Baby is about as big as', 'name': 'A Peach'},
    15: {'label': 'Baby is about as big as', 'name': 'An Apple'},
    16: {'label': 'Baby is about as big as', 'name': 'An Avocado'},
    17: {'label': 'Baby is about as big as', 'name': 'A Pear'},
    18: {'label': 'Baby is about as big as', 'name': 'A Bell Pepper'},
    19: {'label': 'Baby is about as big as', 'name': 'A Mango'},
    20: {'label': 'Baby is about as big as', 'name': 'A Banana'},
    21: {'label': 'Baby is about as big as', 'name': 'A Carrot'},
    22: {'label': 'Baby is about as big as', 'name': 'An Orange'},
    23: {'label': 'Baby is about as big as', 'name': 'A Pomelo'},
    24: {'label': 'Baby is about as big as', 'name': 'An Ear of Corn'},
    25: {'label': 'Baby is about as big as', 'name': 'A Cucumber'},
    26: {'label': 'Baby is about as big as', 'name': 'An Eggplant'},
    27: {'label': 'Baby is about as big as', 'name': 'A Cauliflower'},
    28: {'label': 'Baby is about as big as', 'name': 'A Large Carrot'},
    29: {'label': 'Baby is about as big as', 'name': 'A Sweet Potato'},
    30: {'label': 'Baby is about as big as', 'name': 'A Cabbage'},
    31: {'label': 'Baby is about as big as', 'name': 'A Coconut'},
    32: {'label': 'Baby is about as big as', 'name': 'A Large White Onion'},
    33: {'label': 'Baby is about as big as', 'name': 'A Pineapple'},
    34: {'label': 'Baby is about as big as', 'name': 'A Melon'},
    35: {'label': 'Baby is about as big as', 'name': 'A Large Melon'},
    36: {'label': 'Baby is about as big as', 'name': 'A Kabocha Squash'},
    37: {'label': 'Baby is about as big as', 'name': 'A Taro (Gabi)'},
    38: {'label': 'Baby is about as big as', 'name': 'A Beetroot'},
    39: {'label': 'Baby is about as big as', 'name': 'A Mini Watermelon'},
    40: {'label': 'Baby is about as big as', 'name': 'A Small Pumpkin'},
  };

  @override
  Widget build(BuildContext context) {
    final data = _comparisonData[week];
    if (data == null) return const SizedBox.shrink();

    return Container(
      height: 96,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.bgSecondary.withOpacity(0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${data['label']}\n',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        height: 1.6,
                      ),
                    ),
                    TextSpan(
                      text: data['name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandText,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 72,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.food_bank, color: AppColors.brandPrimary),
            ),
          ],
        ),
      ),
    );
  }
}