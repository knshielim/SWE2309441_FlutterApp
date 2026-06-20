import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  
  // Password fields
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  
  // Email fields
  final _emailCtrl = TextEditingController();
  final _emailPasswordCtrl = TextEditingController();
  
  bool _isLoading = false;
  String _selectedTab = 'password'; // 'password' or 'email'

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = _auth.currentUser?.email ?? '';
  }

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _emailCtrl.dispose();
    _emailPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      // Reauthenticate
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordCtrl.text,
      );
      await user.reauthenticateWithCredential(credential);
      
      // Update password
      await user.updatePassword(_newPasswordCtrl.text);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('password_updated_success'.tr())),
        );
        _clearPasswordFields();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'error'.tr()}: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changeEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      // Reauthenticate
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _emailPasswordCtrl.text,
      );
      await user.reauthenticateWithCredential(credential);
      
      // Update email
      await user.verifyBeforeUpdateEmail(_emailCtrl.text.trim());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('email_updated_success'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'error'.tr()}: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearPasswordFields() {
    _currentPasswordCtrl.clear();
    _newPasswordCtrl.clear();
    _confirmPasswordCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('account_settings'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Tab selector
          Container(
            decoration: BoxDecoration(
              color: AppColors.lightTeal,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 'password'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedTab == 'password' ? AppColors.primaryTeal : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'change_password'.tr(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.slateDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 'email'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedTab == 'email' ? AppColors.primaryTeal : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'change_email'.tr(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.slateDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (_selectedTab == 'password') _buildPasswordForm() else _buildEmailForm(),
        ],
      ),
    );
  }

  Widget _buildPasswordForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'change_password'.tr(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.slateDark),
          ),
          const SizedBox(height: 8),
          Text(
            'change_password_desc'.tr(),
            style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
          ),
          const SizedBox(height: 24),

          TextFormField(
            controller: _currentPasswordCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'current_password'.tr(),
              prefixIcon: const Icon(Icons.lock_rounded, color: AppColors.textGrey),
            ),
            validator: (v) => v == null || v.isEmpty ? 'required'.tr() : null,
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _newPasswordCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'new_password'.tr(),
              prefixIcon: const Icon(Icons.lock_rounded, color: AppColors.textGrey),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'required'.tr();
              if (v == _currentPasswordCtrl.text) return 'New password must be different from current password';
              if (v.length < 8) return 'Password must be at least 8 characters';
              if (!v.contains(RegExp(r'[A-Z]'))) return 'Password must contain at least one uppercase letter';
              if (!v.contains(RegExp(r'[a-z]'))) return 'Password must contain at least one lowercase letter';
              if (!v.contains(RegExp(r'[0-9]'))) return 'Password must contain at least one number';
              return null;
            },
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _confirmPasswordCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'confirm_new_password'.tr(),
              prefixIcon: const Icon(Icons.lock_rounded, color: AppColors.textGrey),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'required'.tr();
              if (v != _newPasswordCtrl.text) return 'passwords_not_match'.tr();
              return null;
            },
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _isLoading ? null : _changePassword,
            child: _isLoading
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Text('update_password'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'change_email'.tr(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.slateDark),
          ),
          const SizedBox(height: 8),
          Text(
            'change_email_desc'.tr(),
            style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
          ),
          const SizedBox(height: 24),

          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'new_email'.tr(),
              prefixIcon: const Icon(Icons.email_rounded, color: AppColors.textGrey),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'required'.tr();
              final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
              if (!emailRegex.hasMatch(v.trim())) return 'invalid_email'.tr();
              if (v.trim() == _auth.currentUser?.email) return 'New email must be different from current email';
              return null;
            },
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _emailPasswordCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'current_password'.tr(),
              prefixIcon: const Icon(Icons.lock_rounded, color: AppColors.textGrey),
            ),
            validator: (v) => v == null || v.isEmpty ? 'required'.tr() : null,
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _isLoading ? null : _changeEmail,
            child: _isLoading
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Text('update_email'.tr()),
          ),
        ],
      ),
    );
  }
}
