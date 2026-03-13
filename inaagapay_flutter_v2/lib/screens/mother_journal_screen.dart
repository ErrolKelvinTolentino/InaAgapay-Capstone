// lib/screens/mother/mother_journal_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../services/auth_storage.dart';
import '../../services/supabase_service.dart';

class MotherJournalScreen extends StatefulWidget {
  const MotherJournalScreen({super.key});

  @override
  State<MotherJournalScreen> createState() => _MotherJournalScreenState();
}

class _MotherJournalScreenState extends State<MotherJournalScreen> {
  List<Map<String, dynamic>> _entries = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEntries();
    _searchController.addListener(_filterEntries);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Ensure session is active
      final sessionActive = await SupabaseService.ensureSession();
      if (!sessionActive) {
        throw Exception('No active session. Please login again.');
      }

      final motherId = await AuthStorage.getMotherId();
      if (motherId == null) throw Exception('Mother ID not found');

      print('Loading entries for mother ID: $motherId');

      // Get journal entries
      final entriesResponse = await SupabaseService.client
          .from('journal_entries')
          .select()
          .eq('mother_id', motherId)
          .order('created_at', ascending: false);

      print('Entries response: $entriesResponse');

      final List<Map<String, dynamic>> entries = List<Map<String, dynamic>>.from(entriesResponse);

      // For each entry, get its associated files
      for (var entry in entries) {
        print('Loading files for entry ID: ${entry['entry_id']}');
        
        final filesResponse = await SupabaseService.client
            .from('files')
            .select()
            .eq('reference_type', 'journal_entry')
            .eq('reference_id', entry['entry_id'])
            .order('created_at', ascending: true);

        print('Files response: $filesResponse');
        
        entry['files'] = filesResponse;
      }

      setState(() {
        _entries = entries;
        _isLoading = false;
      });
      
      print('Total entries loaded: ${entries.length}');
    } catch (e) {
      print('Error loading entries: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      
      // If session error, redirect to login
      if (e.toString().contains('session') || e.toString().contains('JWT')) {
        _handleSessionError();
      }
    }
  }

  void _handleSessionError() async {
    await AuthStorage.clearAll();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session expired. Please login again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _filterEntries() {
    setState(() {});
  }

  List<Map<String, dynamic>> get _filteredEntries {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return _entries;
    
    return _entries.where((entry) {
      return (entry['title']?.toString().toLowerCase().contains(query) ?? false) ||
          (entry['content']?.toString().toLowerCase().contains(query) ?? false);
    }).toList();
  }

  Future<void> _addEntry(Map<String, dynamic> entryData) async {
    try {
      final motherId = await AuthStorage.getMotherId();
      final accountId = await AuthStorage.getUserId();
      
      if (motherId == null) throw Exception('Mother ID not found');
      if (accountId == null) throw Exception('Account ID not found');

      print('=== DEBUG INFO ===');
      print('Mother ID: $motherId');
      print('Account ID: $accountId');
      
      // Verify Supabase session
      final sessionActive = await SupabaseService.ensureSession();
      print('Session active: $sessionActive');
      
      if (!sessionActive) {
        throw Exception('No active session. Please login again.');
      }
      
      final session = Supabase.instance.client.auth.currentSession;
      print('Session user ID: ${session?.user.id}');
      print('Session access token: ${session?.accessToken.substring(0, 20)}...');
      
      // Verify mother record exists
      final verifyResponse = await SupabaseService.client
          .from('mothers')
          .select('mother_id, account_id')
          .eq('mother_id', motherId)
          .maybeSingle();
      
      print('Mother record verification: $verifyResponse');
      
      if (verifyResponse == null) {
        throw Exception('Mother record not found for mother_id: $motherId');
      }

      print('Creating journal entry for mother ID: $motherId');

      // Prepare the insert data with all required fields
      final now = DateTime.now().toIso8601String();
      final insertData = {
        'mother_id': motherId,
        'title': entryData['title'] ?? 'Untitled',
        'content': entryData['content'],
        'created_at': now,
        'updated_at': now,
      };
      
      print('Insert data: $insertData');

      // Create journal entry
      final entryResponse = await SupabaseService.client
          .from('journal_entries')
          .insert(insertData)
          .select()
          .single();

      print('Journal entry created with ID: ${entryResponse['entry_id']}');

      final entryId = entryResponse['entry_id'];

      // Upload files if any
      if (entryData['image_files'] != null && entryData['image_files'].isNotEmpty) {
        for (int i = 0; i < entryData['image_files'].length; i++) {
          final image = entryData['image_files'][i];
          final bytes = await image.readAsBytes();
          final fileName = 'journal_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          final filePath = 'journal-photos/$motherId/$fileName';

          print('Uploading file: $filePath');

          // Upload to Supabase Storage
          await Supabase.instance.client.storage
              .from('files')
              .uploadBinary(
                filePath,
                bytes,
                fileOptions: const FileOptions(contentType: 'image/jpeg'),
              );

          // Insert file record
          await SupabaseService.client
              .from('files')
              .insert({
                'bucket_name': 'files',
                'file_path': filePath,
                'file_name': fileName,
                'file_category': 'journal_photo',
                'mime_type': 'image/jpeg',
                'file_size': bytes.length,
                'uploaded_by': accountId,
                'reference_type': 'journal_entry',
                'reference_id': entryId,
                'processing_type': 'journal_photo',
                'ai_processed': false,
                'created_at': now,
              });

          print('File record created for: $fileName');
        }
      }

      // Reload entries
      await _loadEntries();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Journal entry saved!'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      print('Error saving entry: $e');
      if (e is PostgrestException) {
        print('PostgrestException details:');
        print('Message: ${e.message}');
        print('Code: ${e.code}');
        print('Details: ${e.details}');
        print('Hint: ${e.hint}');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save entry: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // If session error, redirect to login
        if (e.toString().contains('session') || e.toString().contains('JWT') || 
            e.toString().contains('42501')) {
          _handleSessionError();
        }
      }
    }
  }

  Future<void> _deleteEntry(int entryId) async {
    try {
      print('Deleting entry ID: $entryId');

      // Ensure session is active
      final sessionActive = await SupabaseService.ensureSession();
      if (!sessionActive) {
        throw Exception('No active session');
      }

      // Get associated files
      final filesResponse = await SupabaseService.client
          .from('files')
          .select('file_path')
          .eq('reference_type', 'journal_entry')
          .eq('reference_id', entryId);

      // Delete files from storage
      for (var file in filesResponse) {
        print('Deleting file: ${file['file_path']}');
        await Supabase.instance.client.storage
            .from('files')
            .remove([file['file_path']]);
      }

      // Delete file records
      await SupabaseService.client
          .from('files')
          .delete()
          .eq('reference_type', 'journal_entry')
          .eq('reference_id', entryId);

      // Delete journal entry
      await SupabaseService.client
          .from('journal_entries')
          .delete()
          .eq('entry_id', entryId);

      setState(() {
        _entries.removeWhere((e) => e['entry_id'] == entryId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.delete_outline, color: Colors.white),
                SizedBox(width: 8),
                Text('Entry deleted'),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error deleting entry: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _getFileUrl(Map<String, dynamic> file) {
    return Supabase.instance.client.storage
        .from(file['bucket_name'])
        .getPublicUrl(file['file_path']);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.brandPrimary,
              ),
            )
          : _error != null
              ? _buildErrorWidget()
              : Column(
                  children: [
                    // Search Bar
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search your journal...',
                            hintStyle: TextStyle(
                              color: AppColors.textSecondary.withValues(alpha: 0.5),
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: AppColors.brandPrimary,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Stats Summary
                    if (_entries.isNotEmpty) ...[
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.brandPrimary.withValues(alpha: 0.1),
                              AppColors.brandAccent.withValues(alpha: 0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.brandPrimary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(
                              'Total Entries',
                              _entries.length.toString(),
                              Icons.menu_book,
                            ),
                            Container(
                              height: 30,
                              width: 1,
                              color: AppColors.borderPrimary,
                            ),
                            _buildStatItem(
                              'This Month',
                              _entries.where((e) {
                                final date = DateTime.parse(e['created_at']);
                                return date.month == DateTime.now().month;
                              }).length.toString(),
                              Icons.calendar_month,
                            ),
                            Container(
                              height: 30,
                              width: 1,
                              color: AppColors.borderPrimary,
                            ),
                            _buildStatItem(
                              'With Photos',
                              _entries.where((e) => 
                                e['files'] != null && 
                                (e['files'] as List).isNotEmpty
                              ).length.toString(),
                              Icons.photo,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Entries List
                    Expanded(
                      child: _filteredEntries.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: _loadEntries,
                              color: AppColors.brandPrimary,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                                itemCount: _filteredEntries.length,
                                itemBuilder: (context, index) {
                                  final entry = _filteredEntries[index];
                                  final files = entry['files'] as List? ?? [];
                                  final imageUrls = files.map((f) => _getFileUrl(f)).toList();
                                  
                                  return JournalEntryCard(
                                    entry: entry,
                                    imageUrls: imageUrls,
                                    onDelete: () => _deleteEntry(entry['entry_id']),
                                    onTap: () => _openFullScreenEntry(entry, imageUrls),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openFullScreenEditor(),
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'New Entry',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    );
  }

  void _openFullScreenEntry(Map<String, dynamic> entry, List<String> imageUrls) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenEntryView(
          entry: entry,
          imageUrls: imageUrls,
          onDelete: () => _deleteEntry(entry['entry_id']),
        ),
      ),
    );
  }

  void _openFullScreenEditor() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenEditor(
          onSave: (entryData) async => await _addEntry(entryData),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppColors.brandPrimary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Oops! Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadEntries,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isSearching = _searchController.text.isNotEmpty;
    
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.bgSecondary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSearching ? Icons.search_off_rounded : Icons.auto_stories_outlined,
                size: 64,
                color: AppColors.brandPrimary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isSearching ? 'No matching entries' : 'Your journal is empty',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isSearching
                  ? 'Try adjusting your search'
                  : 'Start documenting your pregnancy journey',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            if (!isSearching) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _openFullScreenEditor,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Write First Entry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Journal Entry Card
class JournalEntryCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final List<String> imageUrls;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const JournalEntryCard({
    super.key,
    required this.entry,
    required this.imageUrls,
    required this.onDelete,
    required this.onTap,
  });

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today, ${DateFormat('h:mm a').format(date)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday, ${DateFormat('h:mm a').format(date)}';
    } else if (difference.inDays < 7) {
      return '${DateFormat('EEEE').format(date)}, ${DateFormat('h:mm a').format(date)}';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry['title'] ?? 'Untitled',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(entry['created_at']),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (imageUrls.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brandPrimary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.photo,
                              size: 12,
                              color: AppColors.brandPrimary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${imageUrls.length}',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.brandPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Delete button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onDelete,
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: AppColors.error.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Content preview
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bgSecondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    entry['content'] ?? '',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                // Image preview if has images
                if (imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: imageUrls.length,
                      itemBuilder: (context, index) {
                        return Container(
                          width: 60,
                          height: 60,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.borderPrimary,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              imageUrls[index],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: AppColors.bgSecondary,
                                child: const Icon(
                                  Icons.broken_image,
                                  size: 20,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Full Screen Entry View
class FullScreenEntryView extends StatelessWidget {
  final Map<String, dynamic> entry;
  final List<String> imageUrls;
  final VoidCallback onDelete;

  const FullScreenEntryView({
    super.key,
    required this.entry,
    required this.imageUrls,
    required this.onDelete,
  });

  String _formatFullDate(String dateString) {
    final date = DateTime.parse(dateString);
    return DateFormat('EEEE, MMMM d, yyyy • h:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          entry['title'] ?? 'Journal Entry',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: const Text('Delete Entry'),
                  content: const Text(
                    'Are you sure you want to delete this journal entry?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                        onDelete();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: AppColors.bgSecondary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _formatFullDate(entry['created_at']),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Content
            Text(
              entry['content'] ?? '',
              style: const TextStyle(
                fontSize: 15,
                height: 1.6,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),

            // Images
            if (imageUrls.isNotEmpty) ...[
              const Text(
                'Photos',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                ),
                itemCount: imageUrls.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          backgroundColor: Colors.transparent,
                          child: InteractiveViewer(
                            child: Image.network(
                              imageUrls[index],
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrls[index],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.bgSecondary,
                          child: const Center(
                            child: Icon(
                              Icons.broken_image,
                              size: 30,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Full Screen Editor
class FullScreenEditor extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic>) onSave;

  const FullScreenEditor({super.key, required this.onSave});

  @override
  State<FullScreenEditor> createState() => _FullScreenEditorState();
}

class _FullScreenEditorState extends State<FullScreenEditor> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final List<XFile> _selectedImages = [];
  bool _isSaving = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      setState(() {
        _selectedImages.addAll(images);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking images: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImages.add(image);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error taking photo: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _saveEntry() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please write something'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.onSave({
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'image_files': _selectedImages,
      });

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Add Photos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandPrimary,
                ),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.photo_library,
                  color: AppColors.brandPrimary,
                ),
              ),
              title: const Text('Choose from Gallery'),
              subtitle: const Text('Select multiple images'),
              onTap: () {
                Navigator.pop(context);
                _pickImages();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.blue),
              ),
              title: const Text('Take a Photo'),
              subtitle: const Text('Capture new image'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'New Journal Entry',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveEntry,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Save',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Title Field
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                hintText: 'Give your entry a title...',
                labelStyle: TextStyle(
                  color: AppColors.brandPrimary,
                  fontWeight: FontWeight.w600,
                ),
                floatingLabelBehavior: FloatingLabelBehavior.always,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppColors.borderPrimary,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppColors.borderPrimary,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppColors.brandPrimary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),

            // Content Field
            TextField(
              controller: _contentController,
              maxLines: null,
              minLines: 10,
              decoration: InputDecoration(
                labelText: 'Journal Entry',
                hintText: 'Write your thoughts, feelings, and experiences...',
                labelStyle: TextStyle(
                  color: AppColors.textSecondary,
                ),
                floatingLabelBehavior: FloatingLabelBehavior.always,
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppColors.borderPrimary,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppColors.borderPrimary,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppColors.brandPrimary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              style: const TextStyle(
                fontSize: 15,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),

            // Image Picker Button
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.borderPrimary,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  InkWell(
                    onTap: _showImageSourceDialog,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_rounded,
                            color: AppColors.brandPrimary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _selectedImages.isEmpty
                                ? 'Add Photos'
                                : 'Add More Photos',
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.brandPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_selectedImages.isNotEmpty) ...[
                    const Divider(height: 1),
                    Container(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text(
                                '${_selectedImages.length} photo${_selectedImages.length > 1 ? 's' : ''} selected',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 80,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _selectedImages.length,
                              itemBuilder: (context, index) {
                                return Stack(
                                  children: [
                                    Container(
                                      width: 80,
                                      height: 80,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppColors.borderPrimary,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(_selectedImages[index].path),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: -4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () => _removeImage(index),
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: AppColors.error,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}