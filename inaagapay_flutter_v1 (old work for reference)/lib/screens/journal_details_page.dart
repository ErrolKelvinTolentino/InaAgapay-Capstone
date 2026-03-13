import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';
import '../widgets/main_header.dart';
import '../widgets/main_button.dart';
import '../services/journal_service.dart';
import '../models/journal_model.dart';

class JournalDetailsPage extends StatefulWidget {
  final JournalEntry entry;

  const JournalDetailsPage({super.key, required this.entry});

  @override
  State<JournalDetailsPage> createState() => _JournalDetailsPageState();
}

class _JournalDetailsPageState extends State<JournalDetailsPage> {
  late JournalEntry _entry;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
  }

  String get _formattedDate {
    return DateFormat('MMMM d, y • h:mm a').format(_entry.createdAt);
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Journal'),
        content: const Text(
          'Are you sure you want to delete this journal entry? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _deleting = true);

    final success = await JournalService.deleteJournal(_entry.entryId);

    setState(() => _deleting = false);

    if (!mounted) return;

    if (success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete journal entry.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,

      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: MainHeader(
          title: 'JOURNAL ENTRY',
          onNotificationTap: () {},
          onAvatarTap: () {},
        ),
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🗓 Date
              Text(
                _formattedDate,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 12),

              // 📌 Title
              Text(
                _entry.title.isNotEmpty ? _entry.title : 'Untitled Entry',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 20),

              // 📖 Content
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _entry.content,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 🔙 BACK BUTTON
              MainButton(
                label: 'Back',
                showIcons: true,
                leadingIcon: Icons.arrow_back,
                onPressed: () {
                  Navigator.pop(context);
                },
              ),

              const SizedBox(height: 12),

              // 🗑 DELETE BUTTON
              MainButton(
                label: _deleting ? 'Deleting...' : 'Delete Entry',
                showIcons: true,
                leadingIcon: Icons.delete_outline,
                backgroundColor: AppColors.error,
                onPressed: _deleting ? null : _confirmDelete,
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
