// lib/screens/mother/journal_details_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../widgets/secondary_header.dart';
import '../../widgets/main_button.dart';
import '../../services/journal_service.dart';
import '../../models/journal_model.dart';

class JournalDetailsPage extends StatefulWidget {
  final JournalEntry entry;

  const JournalDetailsPage({super.key, required this.entry});

  @override
  State<JournalDetailsPage> createState() => _JournalDetailsPageState();
}

class _JournalDetailsPageState extends State<JournalDetailsPage> {
  late JournalEntry _entry;
  bool _deleting = false;
  bool _isEditing = false;

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _titleController.text = _entry.title;
    _contentController.text = _entry.content;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  String get _formattedDate {
    return DateFormat('MMMM d, y • h:mm a').format(_entry.createdAt);
  }

  String get _formattedUpdatedDate {
    if (_entry.updatedAt != _entry.createdAt) {
      return ' • Updated ${DateFormat('MMM d, h:mm a').format(_entry.updatedAt)}';
    }
    return '';
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Journal Entry'),
        content: const Text(
          'Are you sure you want to delete this journal entry? '
          'This action cannot be undone.',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
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

    try {
      final success = await JournalService.deleteJournal(_entry.entryId);

      if (!mounted) return;

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Journal entry deleted'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        Navigator.pop(context, true);
      } else {
        throw Exception('Failed to delete');
      }
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
        setState(() => _deleting = false);
      }
    }
  }

  Future<void> _saveEdit() async {
    final newTitle = _titleController.text.trim();
    final newContent = _contentController.text.trim();

    if (newContent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Content cannot be empty'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _deleting = true); // Reusing as saving indicator

    try {
      final updateEntry = UpdateJournalEntry(
        title: newTitle,
        content: newContent,
      );

      final success = await JournalService.updateJournal(_entry.entryId, updateEntry);

      if (!mounted) return;

      if (success) {
        setState(() {
          _entry = JournalEntry(
            entryId: _entry.entryId,
            motherId: _entry.motherId,
            title: newTitle,
            content: newContent,
            createdAt: _entry.createdAt,
            updatedAt: DateTime.now(),
          );
          _isEditing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Journal entry updated'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        throw Exception('Failed to update');
      }
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
        setState(() => _deleting = false);
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
          title: 'Journal Entry',
          onBack: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _deleting && !_isEditing
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: AppColors.brandPrimary,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Processing...',
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
                    // Date
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formattedDate,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (_entry.updatedAt != _entry.createdAt)
                          Text(
                            _formattedUpdatedDate,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Title (Editable or Display)
                    if (_isEditing)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: AppColors.borderPrimary),
                        ),
                        child: TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            hintText: 'Title (Optional)',
                            border: InputBorder.none,
                            icon: Icon(
                              Icons.title,
                              color: AppColors.brandPrimary,
                            ),
                          ),
                        ),
                      )
                    else
                      Text(
                        _entry.title.isNotEmpty ? _entry.title : 'Untitled Entry',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Content (Editable or Display)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
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
                      child: _isEditing
                          ? TextField(
                              controller: _contentController,
                              maxLines: 15,
                              decoration: const InputDecoration(
                                hintText: 'Write your thoughts here...',
                                border: InputBorder.none,
                              ),
                            )
                          : Text(
                              _entry.content,
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.6,
                                color: AppColors.textPrimary,
                              ),
                            ),
                    ),

                    const SizedBox(height: 20),

                    // Action Buttons
                    if (_isEditing) ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isEditing = false;
                                  _titleController.text = _entry.title;
                                  _contentController.text = _entry.content;
                                });
                              },
                              icon: const Icon(Icons.close),
                              label: const Text('Cancel'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: MainButton(
                              label: 'Save Changes',
                              onPressed: _saveEdit,
                              leftIcon: Icons.save,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Back'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isEditing = true;
                                });
                              },
                              icon: const Icon(Icons.edit),
                              label: const Text('Edit'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.brandPrimary,
                                side: const BorderSide(color: AppColors.brandPrimary),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      MainButton(
                        label: 'Delete Entry',
                        onPressed: _confirmDelete,
                        leftIcon: Icons.delete_outline,
                      ),
                    ],

                    const SizedBox(height: 16),
                  ],
                ),
              ),
      ),
    );
  }
}