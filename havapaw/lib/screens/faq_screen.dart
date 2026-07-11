import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FAQ'),
        backgroundColor: AppColors.primaryTeal,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Frequently Asked Questions',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.slateDark,
              ),
            ),
            const SizedBox(height: 20),

            _FAQItem(
              question: 'What is HavaPaw?',
              answer: 'HavaPaw is a smart pet tracking application that helps you monitor your pet\'s health, activity, and location. You can manually enter collar data and set your pet\'s location to track your pet\'s wellness journey.',
            ),
            _FAQItem(
              question: 'How do I add a pet?',
              answer: 'Go to the Profile tab and tap the "Add Pet" button. Fill in your pet\'s details including name, type, breed, birthday, and measurements.',
            ),
            _FAQItem(
              question: 'Can I track multiple pets?',
              answer: 'Yes! You can add and manage multiple pets. Use the navigation arrows in the pet card to switch between your pets.',
            ),
            _FAQItem(
              question: 'How do I add collar health data?',
              answer: 'Go to Settings → Manual Data Entry. Enter steps, heart rate, distance, and temperature, then save. The data will be stored in Firebase and shown on the Home and Health screens.',
            ),
            _FAQItem(
              question: 'How do I set my pet\'s location?',
              answer: 'Go to Settings → Set Pet Location. Pick a spot on the map or use your current location, then save. You can also set a safe zone from the Map tab.',
            ),
            _FAQItem(
              question: 'How is my data stored?',
              answer: 'All your data is securely stored in Firebase. This includes user profiles, pet information, and watch data. You can access it from any device by logging in.',
            ),
            _FAQItem(
              question: 'Can I edit my pet\'s information?',
              answer: 'Yes. Go to the Profile tab, tap the edit icon on your pet\'s card, and update any information. Changes will be saved immediately.',
            ),
            _FAQItem(
              question: 'How do I delete a pet?',
              answer: 'In the Profile tab, scroll down and tap the "Remove Pet" button. Confirm the deletion to permanently remove the pet from your account.',
            ),
            _FAQItem(
              question: 'Is my data private?',
              answer: 'Yes, your data is private and secure. Only you can access your account and pet information. We use Firebase\'s security features to protect your data.',
            ),
            _FAQItem(
              question: 'How do I contact support?',
              answer: 'You can reach our support team at support@havapaw.com or visit our website at www.havapaw.com for more information.',
            ),
          ],
        ),
      ),
    );
  }
}

class _FAQItem extends StatefulWidget {
  final String question;
  final String answer;

  const _FAQItem({
    required this.question,
    required this.answer,
  });

  @override
  State<_FAQItem> createState() => _FAQItemState();
}

class _FAQItemState extends State<_FAQItem> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        iconColor: AppColors.primaryTeal,
        collapsedIconColor: AppColors.textGrey,
        title: Text(
          widget.question,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.slateDark,
          ),
        ),
        children: [
          Text(
            widget.answer,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textGrey,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
