// lib/screens/mother/profile_widgets/profile_helpers.dart
// Shared formatting & utility functions for the mother profile page.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';

// ── Date / value formatters ────────────────────────────────────────────────

String formatProfileDate(dynamic date) {
  if (date == null) return '-';
  try {
    final parsed = DateTime.tryParse(date.toString());
    if (parsed == null) return date.toString();
    return DateFormat('MMM d, yyyy').format(parsed);
  } catch (e) {
    return date.toString();
  }
}

String formatProfileDateTime(dynamic dateTime) {
  if (dateTime == null) return '-';
  try {
    final parsed = DateTime.tryParse(dateTime.toString());
    if (parsed == null) return dateTime.toString();
    return DateFormat('MMM d, yyyy h:mm a').format(parsed);
  } catch (e) {
    return dateTime.toString();
  }
}

double? toDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value.toString());
}

String formatValue(dynamic value) {
  if (value == null) return '-';
  final str = value.toString().trim();
  return str.isEmpty ? '-' : str;
}

String formatOutcome(String? outcome) {
  if (outcome == null) return '-';
  switch (outcome.toLowerCase()) {
    case 'live_birth':
      return 'Live Birth';
    case 'stillbirth':
      return 'Stillbirth';
    case 'miscarriage':
      return 'Miscarriage';
    case 'abortion':
      return 'Abortion';
    case 'ectopic':
      return 'Ectopic';
    default:
      return outcome;
  }
}

// ── BMI helpers ────────────────────────────────────────────────────────────

String getBMIStatus(double bmi) {
  if (bmi < 18.5) return 'Underweight';
  if (bmi < 25) return 'Normal';
  if (bmi < 30) return 'Overweight';
  return 'Obese';
}

Color getBMIStatusColor(String status) {
  switch (status) {
    case 'Underweight':
      return AppColors.warning;
    case 'Normal':
      return AppColors.success;
    case 'Overweight':
      return AppColors.warning;
    case 'Obese':
      return AppColors.error;
    default:
      return AppColors.textSecondary;
  }
}

// ── Sorting helpers ────────────────────────────────────────────────────────

DateTime? parseDateForSort(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

List<Map<String, dynamic>> sortByDate(
    List list, String field, String order) {
  final sorted = List<Map<String, dynamic>>.from(list);
  sorted.sort((a, b) {
    final dateA = parseDateForSort(a[field]);
    final dateB = parseDateForSort(b[field]);
    if (dateA == null || dateB == null) return 0;
    return order == 'desc' ? dateB.compareTo(dateA) : dateA.compareTo(dateB);
  });
  return sorted;
}

// ── Markdown / AI text helpers ─────────────────────────────────────────────

String safeText(Object? value) => value?.toString() ?? '';

String stripDecorativeDashes(String value) {
  final trimmed = value.trim();
  if (RegExp(r'^[-_=]{2,}$').hasMatch(trimmed)) return '';
  return trimmed.replaceAll(RegExp(r'\s+--+\s+'), ' ').trim();
}

String normalizeMarkdownLine(String input) {
  var line = input;
  line = line.replaceFirst(RegExp(r'^\s*#{1,6}\s*'), '');
  line = line.replaceFirst(RegExp(r'^\s*(?:[-*]|-)\s+'), '');
  return line;
}

String cleanResidualMarkdown(String input) {
  var text = input;
  text = text.replaceAll('**', '');
  text = text.replaceAll('##', '');
  text = text.replaceAll(RegExp(r'(?<!\*)\*(?!\*)'), '');
  return text;
}

List<TextSpan> parseInlineMarkdown(String input) {
  final spans = <TextSpan>[];
  final pattern = RegExp(r'\*\*(.+?)\*\*');
  int current = 0;

  for (final match in pattern.allMatches(input)) {
    if (match.start > current) {
      spans.add(TextSpan(
          text: cleanResidualMarkdown(input.substring(current, match.start))));
    }
    spans.add(TextSpan(
      text: match.group(1) ?? '',
      style: const TextStyle(fontWeight: FontWeight.bold),
    ));
    current = match.end;
  }

  if (current < input.length) {
    spans.add(TextSpan(text: cleanResidualMarkdown(input.substring(current))));
  }

  if (spans.isEmpty) {
    spans.add(TextSpan(text: cleanResidualMarkdown(input)));
  }

  return spans;
}

Widget buildFormattedAiText(String text) {
  if (text.isEmpty) return const SizedBox.shrink();

  final lines = text.split('\n');
  final List<TextSpan> spans = [];

  for (int i = 0; i < lines.length; i++) {
    final normalizedLine = normalizeMarkdownLine(lines[i]);
    spans.addAll(parseInlineMarkdown(normalizedLine));
    if (i < lines.length - 1) spans.add(const TextSpan(text: '\n'));
  }

  return RichText(
    text: TextSpan(
      style:
          const TextStyle(color: Colors.black87, fontSize: 15, height: 1.5),
      children: spans,
    ),
  );
}

String normalizeAspectKey(String input) =>
    input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
