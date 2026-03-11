import 'package:flutter/material.dart';
// Change these:
import '../../theme/app_colors.dart';
import '../../widgets/main_button.dart';
import '../../widgets/page_title.dart';
import '../../widgets/app_input_field.dart';
import '../../models/due_date_mode.dart';

class DueDateSetter extends StatefulWidget {
  final DueDateMode mode;

  const DueDateSetter({super.key, required this.mode});

  @override
  State<DueDateSetter> createState() => _DueDateSetterState();
}

class _DueDateSetterState extends State<DueDateSetter> {
  DateTime? _selectedDate;
  final TextEditingController _dateController = TextEditingController();

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
                color: AppColors.textPrimary,
              ),
              const SizedBox(height: 20),
              PageTitle(
                title: widget.mode == DueDateMode.pregnant
                    ? 'When is your due date?'
                    : 'When is the due date?',
                leadingIcon: Icons.calendar_today,
              ),
              const SizedBox(height: 32),
              AppInputField(
                hintText: 'Select Date',
                controller: _dateController,
                leadingIcon: Icons.calendar_today,
                readOnly: true,
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 280)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  
                  if (pickedDate != null) {
                    setState(() {
                      _selectedDate = pickedDate;
                      _dateController.text =
                          '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              Text(
                'You can always update this later',
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              MainButton(
                label: 'Continue',
                onPressed: _selectedDate != null
                    ? () {
                        Navigator.pushNamed(
                          context,
                          '/congrats',
                          arguments: widget.mode,
                        );
                      }
                    : null,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}