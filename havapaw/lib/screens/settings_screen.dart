import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'manual_collar_data_screen.dart';
import 'account_settings_screen.dart';
import 'language_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';
import 'notification_settings_screen.dart';
import 'sound_settings_screen.dart';
import 'pet_location_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _isLoading = false;
  
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = _auth.currentUser?.displayName ?? '';
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          _userData = doc.data();
          _phoneCtrl.text = _userData?['phone'] ?? '';
          _dobCtrl.text = _userData?['dob'] ?? '';
          _addressCtrl.text = _userData?['address'] ?? '';
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      // Update display name in Firebase Auth
      await user.updateDisplayName(_nameCtrl.text.trim());
      
      // Save additional data to Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'displayName': _nameCtrl.text.trim(),
        'email': user.email,
        'phone': _phoneCtrl.text.trim(),
        'dob': _dobCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.pop(context);
        _loadUserData(); // Reload data
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dobCtrl.text.isNotEmpty
          ? DateTime.tryParse(_dobCtrl.text) ?? DateTime.now()
          : DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        _dobCtrl.text = picked.toIso8601String().split('T')[0];
      });
    }
  }

  void _showEditProfileModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.only(
          top: 24, left: 24, right: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'edit_profile'.tr(),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.slateDark),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'display_name'.tr(),
                  hintText: 'e.g. John Doe',
                  prefixIcon: const Icon(Icons.person_rounded, color: AppColors.textGrey),
                ),
                validator: (v) => v == null || v.isEmpty ? 'required'.tr() : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'phone_number'.tr(),
                  hintText: 'e.g. +60123456789',
                  prefixIcon: const Icon(Icons.phone_rounded, color: AppColors.textGrey),
                ),
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'date_of_birth'.tr(),
                    prefixIcon: const Icon(Icons.cake_rounded, color: AppColors.textGrey),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  child: Text(
                    _dobCtrl.text.isEmpty ? 'YYYY-MM-DD' : _dobCtrl.text,
                    style: TextStyle(
                      color: _dobCtrl.text.isEmpty ? AppColors.textGrey : AppColors.slateDark,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _addressCtrl,
                decoration: InputDecoration(
                  labelText: 'address'.tr(),
                  hintText: 'Your address',
                  prefixIcon: const Icon(Icons.location_on_rounded, color: AppColors.textGrey),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                child: _isLoading
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text('save_changes'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final fullName = user?.displayName ?? 'User';
    final firstName = fullName.split(' ')[0];
    
    return Scaffold(
      appBar: AppBar(
        title: Text('settings'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Account section with user profile inline
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.lightTeal,
                      radius: 30,
                      child: Text(
                        firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          color: AppColors.primaryTeal,
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.slateDark),
                          ),
                          Text(
                            user?.email ?? '',
                            style: const TextStyle(fontSize: 14, color: AppColors.textGrey),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _showEditProfileModal,
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Edit'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.primaryTeal),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                _ProfileRow(Icons.phone_rounded, 'phone_number'.tr(), _userData?['phone'] ?? 'not_set'.tr()),
                const SizedBox(height: 12),
                _ProfileRow(Icons.cake_rounded, 'date_of_birth'.tr(), _userData?['dob'] ?? 'not_set'.tr()),
                const SizedBox(height: 12),
                _ProfileRow(Icons.location_on_rounded, 'address'.tr(), _userData?['address'] ?? 'not_set'.tr()),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Account section
          _SectionHeader('account_settings'.tr()),
          _SettingsTile(
            icon: Icons.admin_panel_settings_rounded,
            label: 'edit_account_credentials'.tr(),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountSettingsScreen()));
            },
          ),
          const SizedBox(height: 20),

          // Data Management
          _SectionHeader('data_management'.tr()),
          _SettingsTile(
            icon: Icons.location_on_rounded,
            label: 'set_pet_location'.tr(),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PetLocationScreen()));
            },
          ),
          _SettingsTile(
            icon: Icons.edit_note_rounded,
            label: 'manual_watch_data'.tr(),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ManualCollarDataScreen()));
            },
          ),
          const SizedBox(height: 20),

          // Preferences
          _SectionHeader('preferences'.tr()),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            label: 'notification_settings'.tr(),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()));
            },
          ),
          _SettingsTile(
            icon: Icons.volume_up_rounded,
            label: 'sound_settings'.tr(),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SoundSettingsScreen()));
            },
          ),
          _SettingsTile(
            icon: Icons.language_rounded,
            label: 'language'.tr(),
            trailing: Text(context.locale.languageCode == 'id' ? 'Indonesian' : 
                          context.locale.languageCode == 'ms' ? 'Malay' : 
                          context.locale.languageCode == 'zh' ? 'Chinese' : 'English', 
                          style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const LanguageScreen()));
            },
          ),
          const SizedBox(height: 20),

          // About
          _SectionHeader('about'.tr()),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            label: 'app_version'.tr(),
            trailing: const Text('v1.0.0', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            label: 'privacy_policy'.tr(),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
            },
          ),
          _SettingsTile(
            icon: Icons.description_outlined,
            label: 'terms_of_service'.tr(),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()));
            },
          ),
          const SizedBox(height: 20),

          // Sign out
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout_rounded, color: AppColors.alertRed, size: 18),
              label: Text('logout'.tr(), style: const TextStyle(color: AppColors.alertRed, fontSize: 15)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                side: const BorderSide(color: AppColors.alertRed),
              ),
              onPressed: () async {
                await AuthService.signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textGrey,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.slateDark, size: 22),
        title: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.slateDark)),
        trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.textGrey, size: 20),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textGrey, size: 18),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slateDark),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}