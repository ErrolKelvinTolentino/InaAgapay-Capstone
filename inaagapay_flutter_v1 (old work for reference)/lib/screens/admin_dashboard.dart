import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/page_title.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              PageTitle(
                title: 'Admin Dashboard',
                leadingIcon: Icons.admin_panel_settings,
                trailingIcon: Icons.security,
              ),
              SizedBox(height: 12),
              Text(
                'Logged in as: Admin',
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
