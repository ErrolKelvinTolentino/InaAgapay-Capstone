// lib/widgets/ai_analytics_card.dart

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'profile_helpers.dart';

class AiAnalyticsCard extends StatefulWidget {
  final String text;
  final bool isLoading;

  const AiAnalyticsCard({
    super.key,
    required this.text,
    this.isLoading = false,
  });

  @override
  State<AiAnalyticsCard> createState() => _AiAnalyticsCardState();
}

class _AiAnalyticsCardState extends State<AiAnalyticsCard> {
  bool _isExpanded = false;
  bool _showFilipino = false;

  @override
  void didUpdateWidget(covariant AiAnalyticsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      _isExpanded = false;
      _showFilipino = false;
    }
  }

  String _extractLanguageSection(String fullText, bool filipino) {
    final englishMatch = RegExp(
      r'## English\s*([\s\S]*?)(?=(## Filipino|\z))',
      caseSensitive: false,
    ).firstMatch(fullText);
    final filipinoMatch = RegExp(
      r'## Filipino\s*([\s\S]*?)(?=(## English|\z))',
      caseSensitive: false,
    ).firstMatch(fullText);

    final englishText = englishMatch?.group(1)?.trim();
    final filipinoText = filipinoMatch?.group(1)?.trim();

    if (filipino) {
      return filipinoText ?? englishText ?? fullText.trim();
    }
    return englishText ?? filipinoText ?? fullText.trim();
  }

  String _selectedText(String fullText) {
    final text = _extractLanguageSection(fullText, _showFilipino);
    return text.isEmpty ? fullText.trim() : text;
  }

  String _getSummary(String fullText) {
    final trimmed = fullText.trim();
    if (trimmed.length <= 200) return trimmed;

    final lines =
        trimmed.split('\n').where((line) => line.trim().isNotEmpty).toList();
    final buffer = StringBuffer();

    for (final line in lines) {
      final textLine = line.trim();
      if (buffer.length + textLine.length > 210) {
        if (buffer.isEmpty) {
          return '${textLine.substring(0, 210)}...';
        }
        break;
      }
      buffer.writeln(textLine);
      if (buffer.length > 170) break;
    }

    final summary = buffer.toString().trim();
    return summary.length < trimmed.length ? '$summary...' : summary;
  }

  Widget _buildLanguageToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildLanguageButton('English', !_showFilipino),
        const SizedBox(width: 8),
        _buildLanguageButton('Filipino', _showFilipino),
      ],
    );
  }

  Widget _buildLanguageButton(String label, bool selected) {
    return TextButton(
      onPressed: () {
        setState(() {
          _showFilipino = label == 'Filipino';
          _isExpanded = false;
        });
      },
      style: TextButton.styleFrom(
        backgroundColor: selected
            ? AppColors.brandPrimary.withValues(alpha: 0.12)
            : AppColors.bgSecondary,
        foregroundColor: selected ? AppColors.brandPrimary : AppColors.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: selected ? AppColors.brandPrimary : AppColors.textSecondary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedText = _selectedText(widget.text);
    final displayText = _isExpanded ? selectedText : _getSummary(selectedText);
    final shouldShowToggle = selectedText.length > 200;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.brandPrimary.withValues(alpha: 0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: AppColors.brandPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'AI GROWTH ANALYSIS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandPrimary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (widget.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(
                  color: AppColors.brandPrimary,
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildFormattedAiText(displayText),
                if (shouldShowToggle) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      icon: Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                      ),
                      label: Text(
                        _isExpanded ? 'Show less' : 'Show full',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.brandPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
