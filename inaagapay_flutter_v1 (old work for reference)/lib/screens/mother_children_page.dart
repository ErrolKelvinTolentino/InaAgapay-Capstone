import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/main_header.dart';
import '../widgets/main_bottom_navigation.dart';
import '../widgets/small_description.dart';
import '../widgets/app_input_field.dart';
import '../widgets/child_card.dart';
import '../widgets/vaccine_schedule_status.dart';
import '../screens/mother_child_stack.dart';

import '../services/api_service.dart';
import '../utils/session.dart';
import '../models/child_model.dart';

class MotherChildrenPage extends StatefulWidget {
  const MotherChildrenPage({super.key});

  @override
  State<MotherChildrenPage> createState() => _MotherChildrenPageState();
}

class _MotherChildrenPageState extends State<MotherChildrenPage> {
  final TextEditingController _searchController = TextEditingController();

  List<ChildModel> _children = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchChildren();
  }

  Future<void> _fetchChildren() async {
    final res = await ApiService.get(
      'mother/children_list.php',
      token: Session.token,
    );

    if (!res['success']) {
      setState(() => _loading = false);
      return;
    }

    setState(() {
      _children = (res['children'] as List)
          .map((e) => ChildModel.fromJson(e))
          .toList();
      _loading = false;
    });
  }

 void _openChildProfile(ChildModel child) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => MotherChildStack(
        childId: child.id,
        childName: child.fullName,
        childAge: child.ageText,
      ),
    ),
  );
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,

      // 🔝 Header
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: MainHeader(
          title: 'CHILDREN',
          onNotificationTap: () {},
          onAvatarTap: () {},
        ),
      ),

      // 🔽 Body
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🧸 TOP INFO CARD
              Container(
                height: 96,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: const DecorationImage(
                    image: AssetImage('assets/images/pinkbg.png'),
                    fit: BoxFit.cover,
                    opacity: 0.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            children: [
                              const TextSpan(
                                text: 'You have\n',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                  height: 1.4,
                                ),
                              ),
                              TextSpan(
                                text:
                                    '${_children.length} Beautiful Children!',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brandText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      Image.asset(
                        'assets/images/baby.png',
                        height: 72,
                        width: 72,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 🔍 Search (UI unchanged – logic later)
              AppInputField(
                hintText: 'Search Child',
                controller: _searchController,
                trailingIcon: Icons.search,
                onTrailingTap: () {},
                onChanged: (value) {},
              ),

              const SizedBox(height: 8),

              const SmallDescription(
                text: 'Tap a child to view health records',
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              // 👶 CHILD LIST
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_children.isEmpty)
                const Center(
                  child: Text(
                    'No children found',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              else
                Column(
                  children: _children.map((child) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ChildCard(
                        fullName: child.fullName,
                        ageText: child.ageText,
                        vaccineStatus:
                            VaccineScheduleStatus.onSchedule, // dynamic later
                        image:
                            const AssetImage('assets/images/child.png'),
                 onTap: () => _openChildProfile(child),
                      ),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),

      // 🔻 Bottom Nav
      bottomNavigationBar: const MainBottomNavigation(
        currentIndex: 2,
      ),
    );
  }
}
