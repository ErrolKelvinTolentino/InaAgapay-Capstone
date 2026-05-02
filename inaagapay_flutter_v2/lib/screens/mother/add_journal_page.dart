// lib/screens/mother/add_journal_page.dart

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/journal_service.dart';
import '../../widgets/main_button.dart';
import '../../models/journal_model.dart';

class AddJournalPage extends StatefulWidget {
  const AddJournalPage({super.key});

  @override
  State<AddJournalPage> createState() => _AddJournalPageState();
}

class _AddJournalPageState extends State<AddJournalPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  bool _saving = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveJournal() async {
    if (_contentController.text.trim().isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Please write something before saving.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _hasError = false;
      _errorMessage = '';
    });

    final entry = CreateJournalEntry(
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
    );

    final success = await JournalService.createJournal(entry);

    setState(() => _saving = false);

    if (!mounted) return;

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Journal entry saved successfully!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      Navigator.pop(context, true);
    } else {
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to save journal. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text(
          'New Journal',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: AppColors.textPrimary,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Write freely 🌷',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'This is your personal space. Write anything you feel or experience today.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // 📌 TITLE FIELD
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Title (optional)',
                    hintStyle: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 📝 CONTENT FIELD
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _contentController,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'How are you feeling today?',
                      hintStyle: TextStyle(color: AppColors.textSecondary),
                    ),
                    onChanged: (_) {
                      if (_hasError) {
                        setState(() {
                          _hasError = false;
                          _errorMessage = '';
                        });
                      }
                    },
                  ),
                ),
              ),

              if (_hasError) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 13,
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // 💾 SAVE BUTTON
              MainButton(
                label: _saving ? 'Saving...' : 'Save Journal',
                showIcons: true,
                leftIcon: Icons.save,
                onPressed: _saving ? null : _saveJournal,
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}