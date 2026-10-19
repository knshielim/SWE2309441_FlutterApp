import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';

/// Bump this when the data use described below changes; users are asked again.
const int kConsentVersion = 1;

/// Shows the consent screen once per account (and again if [kConsentVersion]
/// changes), then continues to the home screen. The decision is stored at
/// users/{uid}.consent so it follows the account across devices.
class ConsentGate extends StatefulWidget {
  const ConsentGate({super.key});

  @override
  State<ConsentGate> createState() => _ConsentGateState();
}

class _ConsentGateState extends State<ConsentGate> {
  bool? _consented;
  bool _agreeTerms = false;
  bool _agreeData = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _consented = true); // not signed in: nothing to gate
      return;
    }
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final consent = doc.data()?['consent'];
      final version = consent is Map ? (consent['version'] as num?)?.toInt() : null;
      if (!mounted) return;
      setState(() {
        _consented = version != null && version >= kConsentVersion;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _consented = false;
        _error = 'Could not check your consent status. Check your connection and try again.';
      });
    }
  }

  Future<void> _accept() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'consent': {
          'version': kConsentVersion,
          'acceptedAt': FieldValue.serverTimestamp(),
          'termsAndPrivacy': true,
          'healthLocationData': true,
          'aiProcessing': true,
        },
      }, SetOptions(merge: true));
      if (!mounted) return;
      setState(() => _consented = true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save your choice. Please try again.';
      });
    }
  }

  Future<void> _decline() async {
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_consented == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryTeal)),
      );
    }
    if (_consented == true) return const HomeScreen();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 8),
            const Icon(Icons.verified_user_rounded, size: 48, color: AppColors.primaryTeal),
            const SizedBox(height: 16),
            const Text(
              'Your data, your choice',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.slateDark),
            ),
            const SizedBox(height: 12),
            const Text(
              'HavaPaw collects readings from your pet\'s collar (heart rate, temperature, '
              'blood oxygen, movement and GPS location) together with your pet\'s profile '
              '(species, breed, birthday and weight). This is used to show your pet\'s health '
              'and location, to send alerts, and to learn what is normal for your pet.',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'When you use the Virtual Vet, a short summary of your pet\'s profile and latest '
              'readings is sent to an AI service (OpenAI) to write the advice. It is guidance only '
              'and does not replace a veterinarian.',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your data is stored in your own account, in line with the Personal Data '
              'Protection Act 2010 (Malaysia). You can withdraw consent at any time by '
              'signing out and asking for your account to be deleted.',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 16),
            Wrap(
              children: [
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                  ),
                  child: const Text('Privacy Policy'),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
                  ),
                  child: const Text('Terms of Service'),
                ),
              ],
            ),
            CheckboxListTile(
              value: _agreeTerms,
              onChanged: _saving ? null : (v) => setState(() => _agreeTerms = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text('I have read and agree to the Privacy Policy and Terms of Service.'),
            ),
            CheckboxListTile(
              value: _agreeData,
              onChanged: _saving ? null : (v) => setState(() => _agreeData = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'I consent to HavaPaw collecting and processing my pet\'s health and location '
                'data, including sending summaries to an AI service for the Virtual Vet.',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: (_agreeTerms && _agreeData && !_saving) ? _accept : null,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Agree and continue'),
            ),
            TextButton(
              onPressed: _saving ? null : _decline,
              child: const Text('Decline and sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
