import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About HavaPaw'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App info header
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.lightTeal,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(Icons.pets, color: AppColors.primaryTeal, size: 44),
                  ),
                  const SizedBox(height: 12),
                  const Text('HavaPaw v1.0', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.slateDark)),
                  const Text('Smart Pet Collar App', style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Key features
            _SectionTitle('🐾 Key Features'),
            const SizedBox(height: 12),
            ..._features.map((f) => _FeatureTile(icon: f['icon'] as IconData, title: f['title'] as String, desc: f['desc'] as String)),
            const SizedBox(height: 20),

            // Supported platforms
            _SectionTitle('📱 Supported Platforms'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  _PlatformRow('Android', 'Android 8.0 and above'),
                  _PlatformRow('iOS', 'iOS 14.0 and above'),
                  _PlatformRow('Backend', 'Firebase'),
                  _PlatformRow('Maps', 'Google Maps API'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // FAQ
            _SectionTitle('❓ Frequently Asked Questions'),
            const SizedBox(height: 12),
            ..._faqs.map((f) => _FaqTile(question: f['q'] as String, answer: f['a'] as String)),
            const SizedBox(height: 20),

            // Contact & support
            _SectionTitle('📞 Contact & Support'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: const [
                  _ContactRow(icon: Icons.email_outlined, label: 'Email', value: 'SWE2309441@xmu.edu.my'),
                  SizedBox(height: 12),
                  _ContactRow(icon: Icons.phone_outlined, label: 'Contact No', value: '+60 103960584'),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

// Data
const _features = [
  {'icon': Icons.location_on_rounded, 'title': 'GPS Tracking & Geofencing', 'desc': 'Real-time location with customisable safe zone radius and instant exit alerts'},
  {'icon': Icons.favorite_rounded, 'title': 'Health & Temperature Monitoring', 'desc': 'Continuous physiological tracking with threshold-based and context-aware alerts'},
  {'icon': Icons.directions_walk_rounded, 'title': 'Activity & Calorie Tracking', 'desc': 'Step count, distance travelled, and daily calorie summary'},
  {'icon': Icons.warning_rounded, 'title': 'Context-Aware Smart Alerts', 'desc': 'Detects stress patterns, lethargy, and critical health conditions automatically'},
  {'icon': Icons.insights_rounded, 'title': 'Behaviour Pattern Learning', 'desc': 'Compares daily activity against a 3-day personal baseline to flag anomalies'},
];

const _faqs = [
  {'q': 'How do I connect my pet\'s collar?', 'a': 'Go to the Map screen and tap "Connect Collar". Make sure Bluetooth is enabled on your device and the collar is powered on.'},
  {'q': 'Can I add multiple pets?', 'a': 'Yes! Tap "Add Pet" on the Profile screen to add as many pets as you need. You can switch between them using the arrow buttons.'},
  {'q': 'How do I set up a safe zone?', 'a': 'Go to the Map screen, then tap "Safe Zone Settings". You can draw a custom radius on the map around your home or any location.'},
  {'q': 'What does the health score mean?', 'a': 'The health score (0–100) is calculated from your pet\'s heart rate, temperature, activity level, and sleep patterns over the past 24 hours.'},
];

// Widgets
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.slateDark));
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const _FeatureTile({required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.lightTeal, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: AppColors.primaryTeal, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.slateDark)),
                const SizedBox(height: 3),
                Text(desc, style: const TextStyle(fontSize: 12, color: AppColors.textGrey, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final String question;
  final String answer;
  const _FaqTile({required this.question, required this.answer});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _expanded ? AppColors.primaryTeal.withOpacity(0.4) : AppColors.divider),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(widget.question, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slateDark)),
          trailing: Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: AppColors.primaryTeal),
          onExpansionChanged: (v) => setState(() => _expanded = v),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(widget.answer, style: const TextStyle(fontSize: 13, color: AppColors.textGrey, height: 1.5)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlatformRow extends StatelessWidget {
  final String platform;
  final String value;
  const _PlatformRow(this.platform, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(platform, style: const TextStyle(fontSize: 13, color: AppColors.textGrey))),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slateDark)),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ContactRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryTeal, size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slateDark)),
          ],
        ),
      ],
    );
  }
}
