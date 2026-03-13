import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';
import '../widgets/main_header.dart';
import '../widgets/main_bottom_navigation.dart';
import '../services/journal_service.dart';
import '../models/journal_model.dart';
import 'add_journal_page.dart';
import 'journal_details_page.dart';

class JournalListPage extends StatefulWidget {
  JournalListPage({super.key});

  @override
  State<JournalListPage> createState() => _JournalListPageState();
}

class _JournalListPageState extends State<JournalListPage> {
  late Future<List<JournalEntry>> _journalsFuture;

  @override
  void initState() {
    super.initState();
    _loadJournals();
  }

  void _loadJournals() {
    _journalsFuture = JournalService.fetchJournals();
  }

  Future<void> _openAddJournal() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddJournalPage()),
    );

    if (result == true) {
      setState(() {
        _loadJournals();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,

      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: MainHeader(
          title: 'MY JOURNAL',
          onNotificationTap: () {},
          onAvatarTap: () {},
        ),
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              const Text(
                'Your personal space 🌷',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Write your thoughts, feelings, and pregnancy moments.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 20),

              Expanded(
                child: FutureBuilder<List<JournalEntry>>(
                  future: _journalsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return _EmptyJournalState(onAdd: _openAddJournal);
                    }

                    final journals = snapshot.data!;

                    return ListView.separated(
                      itemCount: journals.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final entry = journals[index];
                        final date = DateFormat('MMMM d, y')
                            .format(entry.createdAt);

                        return GestureDetector(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    JournalDetailsPage(entry: entry),
                              ),
                            );
                            setState(() => _loadJournals());
                          },
                          child: Container(
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.title != null &&
                                          entry.title!.isNotEmpty
                                      ? entry.title!
                                      : 'Untitled Entry',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),

                                const SizedBox(height: 6),

                                Text(
                                  date,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),

                                const SizedBox(height: 10),

                                Text(
                                  entry.content,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),

                                const SizedBox(height: 10),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: const [
                                    Icon(
                                      Icons.chevron_right,
                                      size: 20,
                                      color: AppColors.textSecondary,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.brandPrimary,
        onPressed: _openAddJournal,
        child: const Icon(Icons.add),
      ),

      bottomNavigationBar: const MainBottomNavigation(currentIndex: 1),
    );
  }
}

/// 🌸 Empty State Widget
class _EmptyJournalState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyJournalState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.menu_book_outlined,
              size: 64,
              color: AppColors.textSecondary,
            ),

            const SizedBox(height: 16),

            const Text(
              'No journal entries yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Start writing about your pregnancy journey.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Write your first entry'),
            ),
          ],
        ),
      ),
    );
  }
}
