// lib/screens/mother/add_journal_page.dart

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/secondary_header.dart';
import '../../widgets/main_button.dart';
import '../../widgets/app_input_field.dart';
import '../../services/journal_service.dart';
import '../../models/journal_model.dart';

class AddJournalPage extends StatefulWidget {
  const AddJournalPage({super.key});

  @override
  State<AddJournalPage> createState() => _AddJournalPageState();
}

class _AddJournalPageState extends State<AddJournalPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isSaving = false;

  bool get _isValid => _contentController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveJournal() async {
    if (!_isValid) return;

    setState(() => _isSaving = true);

    try {
      final entry = CreateJournalEntry(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
      );

      await JournalService.createJournal(entry);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Journal entry saved successfully!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: SecondaryHeader(
          title: 'New Journal Entry',
          onBack: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _isSaving
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: AppColors.brandPrimary,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Saving your journal entry...',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Title Field
                          AppInputField(
                            hintText: 'Title (Optional)',
                            controller: _titleController,
                            leadingIcon: Icons.title,
                          ),
                          const SizedBox(height: 20),

                          // Content Field
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppColors.bgSecondary,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: AppColors.borderPrimary),
                            ),
                            child: TextField(
                              controller: _contentController,
                              maxLines: 15,
                              minLines: 8,
                              decoration: const InputDecoration(
                                hintText: 'Write your thoughts here...',
                                border: InputBorder.none,
                                icon: Icon(
                                  Icons.edit_note,
                                  color: AppColors.brandPrimary,
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    MainButton(
                      label: 'Save Entry',
                      onPressed: _isValid ? _saveJournal : null,
                      leftIcon: Icons.save,
                    ),

                    const SizedBox(height: 16),

                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.cancel),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        side: const BorderSide(color: AppColors.borderPrimary),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}