import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/bhc_model.dart';
import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';

class AccountCreationPage extends StatefulWidget {
  const AccountCreationPage({super.key});

  @override
  State<AccountCreationPage> createState() => _AccountCreationPageState();
}

class _AccountCreationPageState extends State<AccountCreationPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _firstCtrl = TextEditingController();
  final _middleCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _extCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  String _accountType = 'midwife';
  int? _selectedBhcId;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;
  String? _success;

  List<BhcModel> _bhcs = [];
  bool _bhcsLoading = false;
  String? _bhcsError;

  @override
  void initState() {
    super.initState();
    _loadBHCs();
  }

  Future<void> _loadBHCs() async {
    setState(() {
      _bhcsLoading = true;
      _bhcsError = null;
    });
    try {
      final bhcs = await AdminService.getBHCs();
      if (mounted)
        setState(() {
          _bhcs = bhcs;
          _bhcsLoading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _bhcsError = e.toString().replaceAll('Exception: ', '');
          _bhcsLoading = false;
        });
    }
  }

  @override
  void dispose() {
    for (final c in [
      _firstCtrl,
      _middleCtrl,
      _lastCtrl,
      _extCtrl,
      _emailCtrl,
      _phoneCtrl,
      _passCtrl,
      _confirmPassCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_accountType == 'midwife' && _selectedBhcId == null) {
      setState(() => _error = 'Please select a Barangay Health Center.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      await AdminService.createAccount(
        accountType: _accountType,
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        firstName: _firstCtrl.text.trim(),
        middleName: _middleCtrl.text.trim().isEmpty
            ? null
            : _middleCtrl.text.trim(),
        lastName: _lastCtrl.text.trim(),
        extensionName: _extCtrl.text.trim().isEmpty
            ? null
            : _extCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim().isEmpty
            ? null
            : _phoneCtrl.text.trim(),
        bhcId: _accountType == 'midwife' ? _selectedBhcId : null,
      );

      if (!mounted) return;
      setState(() {
        _success = 'Account created successfully!';
        _loading = false;
      });
      _clearForm();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    for (final c in [
      _firstCtrl,
      _middleCtrl,
      _lastCtrl,
      _extCtrl,
      _emailCtrl,
      _phoneCtrl,
      _passCtrl,
      _confirmPassCtrl,
    ]) {
      c.clear();
    }
    setState(() {
      _accountType = 'midwife';
      _selectedBhcId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = constraints.maxWidth < 600
            ? 16.0
            : constraints.maxWidth < 900
            ? 20.0
            : 24.0;
        return SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildForm(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/admin/accounts'),
          style: IconButton.styleFrom(
            backgroundColor: AppTheme.softPink,
            foregroundColor: AppTheme.primaryPink,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create Account',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                'Create a new admin or midwife account',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: AppTheme.cardDecoration(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Account type selector ──────────────────────────────────
            _sectionTitle('Account Type', Icons.person_rounded),
            const SizedBox(height: 12),
            _buildTypeSelector(),

            const SizedBox(height: 24),
            _divider('Personal Information'),
            const SizedBox(height: 16),

            // ── Name row ───────────────────────────────────────────────
            _buildNameRow(),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildField(
                    label: 'Extension Name',
                    hint: 'Jr., Sr., III…',
                    controller: _extCtrl,
                    icon: Icons.badge_outlined,
                    required: false,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildField(
                    label: 'Phone Number',
                    hint: '09XX-XXX-XXXX',
                    controller: _phoneCtrl,
                    icon: Icons.phone_outlined,
                    required: false,
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            _divider('Login Credentials'),
            const SizedBox(height: 16),

            _buildField(
              label: 'Email Address *',
              hint: 'user@example.com',
              controller: _emailCtrl,
              icon: Icons.email_outlined,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (!v.contains('@')) return 'Invalid email';
                return null;
              },
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildPasswordField(
                    label: 'Password *',
                    controller: _passCtrl,
                    obscure: _obscurePass,
                    onToggle: () =>
                        setState(() => _obscurePass = !_obscurePass),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v.length < 8) return 'Min 8 characters';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildPasswordField(
                    label: 'Confirm Password *',
                    controller: _confirmPassCtrl,
                    obscure: _obscureConfirm,
                    onToggle: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v != _passCtrl.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                ),
              ],
            ),

            // ── BHC selector (midwife only) ────────────────────────────
            if (_accountType == 'midwife') ...[
              const SizedBox(height: 24),
              _divider('BHC Assignment'),
              const SizedBox(height: 16),
              _buildBhcSelector(),
            ],

            const SizedBox(height: 28),

            // ── Alerts ────────────────────────────────────────────────
            if (_error != null) ...[
              _alertBanner(_error!, isError: true),
              const SizedBox(height: 16),
            ],
            if (_success != null) ...[
              _alertBanner(_success!, isError: false),
              const SizedBox(height: 16),
            ],

            // ── Buttons ───────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _loading ? null : _clearForm,
                  child: const Text('Clear'),
                ),
                const SizedBox(width: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: _loading
                        ? const LinearGradient(
                            colors: [Color(0xFFB0899D), Color(0xFFB0899D)],
                          )
                        : AppTheme.heroGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _submit,
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.person_add_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                    label: Text(
                      _loading ? 'Creating…' : 'Create Account',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Row(
      children: [
        _typeCard(
          label: 'Midwife',
          icon: Icons.medical_services_rounded,
          value: 'midwife',
          description: 'Manages prenatal care & patients',
        ),
        const SizedBox(width: 12),
        _typeCard(
          label: 'Admin',
          icon: Icons.admin_panel_settings_rounded,
          value: 'admin',
          description: 'Full system management access',
        ),
      ],
    );
  }

  Widget _typeCard({
    required String label,
    required IconData icon,
    required String value,
    required String description,
  }) {
    final selected = _accountType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _accountType = value;
          _selectedBhcId = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: selected ? AppTheme.heroGradient : null,
            color: selected ? null : AppTheme.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppTheme.primaryPink : AppTheme.borderColor,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryPink.withAlpha(50),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withAlpha(30)
                      : AppTheme.softPink,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: selected ? Colors.white : AppTheme.primaryPink,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: selected ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      description,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: selected
                            ? Colors.white.withAlpha(200)
                            : AppTheme.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameRow() {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            children: [
              _buildField(
                label: 'First Name *',
                hint: 'Maria',
                controller: _firstCtrl,
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 12),
              _buildField(
                label: 'Middle Name',
                hint: 'Santos',
                controller: _middleCtrl,
                icon: Icons.person_outline_rounded,
                required: false,
              ),
              const SizedBox(height: 12),
              _buildField(
                label: 'Last Name *',
                hint: 'Dela Cruz',
                controller: _lastCtrl,
                icon: Icons.person_outline_rounded,
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(
              child: _buildField(
                label: 'First Name *',
                hint: 'Maria',
                controller: _firstCtrl,
                icon: Icons.person_outline_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildField(
                label: 'Middle Name',
                hint: 'Santos',
                controller: _middleCtrl,
                icon: Icons.person_outline_rounded,
                required: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildField(
                label: 'Last Name *',
                hint: 'Dela Cruz',
                controller: _lastCtrl,
                icon: Icons.person_outline_rounded,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    bool required = true,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: AppTheme.textLight),
      ),
      validator:
          validator ??
          (required
              ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
              : null),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
          size: 18,
          color: AppTheme.textLight,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: 18,
            color: AppTheme.textLight,
          ),
          onPressed: onToggle,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildBhcSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _labelText('Barangay Health Center *'),
            const Spacer(),
            if (_bhcsLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryPink,
                ),
              )
            else
              InkWell(
                onTap: _loadBHCs,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.refresh_rounded,
                        size: 14,
                        color: AppTheme.primaryPink,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Reload',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppTheme.primaryPink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (_bhcsError != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.dangerLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.danger.withAlpha(80)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 16,
                  color: AppTheme.danger,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Failed to load BHCs: $_bhcsError',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.danger,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          DropdownButtonFormField<int>(
            value: _selectedBhcId,
            isExpanded: true,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textPrimary,
            ),
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.location_on_outlined,
                size: 18,
                color: AppTheme.textLight,
              ),
              suffixIcon: _bhcsLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryPink,
                        ),
                      ),
                    )
                  : null,
            ),
            hint: Text(
              _bhcsLoading ? 'Loading BHCs…' : 'Select BHC',
              style: GoogleFonts.poppins(color: AppTheme.textLight),
            ),
            items: _bhcs
                .map(
                  (b) => DropdownMenuItem<int>(
                    value: b.bhcId,
                    child: Text(
                      b.bhcName,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (int? v) => setState(() => _selectedBhcId = v),
            validator: (v) => v == null ? 'Required' : null,
          ),
      ],
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryPink, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _divider(String label) {
    return Row(
      children: [
        Expanded(child: Divider(color: AppTheme.borderColor.withAlpha(180))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.textLight,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppTheme.borderColor.withAlpha(180))),
      ],
    );
  }

  Widget _labelText(String label) => Text(
    label,
    style: GoogleFonts.poppins(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: AppTheme.textSecondary,
    ),
  );

  Widget _alertBanner(String msg, {required bool isError}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError ? AppTheme.dangerLight : AppTheme.successLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError ? AppTheme.dangerBg : AppTheme.successBg,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: isError ? AppTheme.danger : AppTheme.success,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: GoogleFonts.poppins(
                color: isError ? AppTheme.danger : AppTheme.success,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
