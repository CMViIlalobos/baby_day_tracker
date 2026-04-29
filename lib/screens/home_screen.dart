import 'package:flutter/material.dart';

import '../models/baby_profile.dart';
import '../widgets/home_style.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.profile});

  final BabyProfile profile;

  @override
  Widget build(BuildContext context) {
    final ageMonth = _ageInMonths(profile.birthDate).clamp(1, 12);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        HomeStylePageHeader(
          eyebrow: 'Monthly Guide',
          title: 'What to Expect',
          subtitle: 'Months 1-12',
          icon: Icons.menu_book_rounded,
          badge:
              profile.birthDate == null ? 'Start month 1' : 'Month $ageMonth',
          gradient: const [
            Color(0xFFFFF4E8),
            Color(0xFFE7F8EF),
            Color(0xFFEAF6FF),
          ],
        ),
        const SizedBox(height: 20),
        for (final month in _monthlyGuides)
          _GuideMonthCard(
            guide: month,
            isCurrentMonth:
                profile.birthDate != null && month.month == ageMonth,
          ),
      ],
    );
  }

  int _ageInMonths(DateTime? birthDate) {
    if (birthDate == null) {
      return 1;
    }
    final now = DateTime.now();
    var months = (now.year - birthDate.year) * 12 + now.month - birthDate.month;
    if (now.day < birthDate.day) {
      months--;
    }
    return months < 1 ? 1 : months;
  }
}

class _GuideMonthCard extends StatelessWidget {
  const _GuideMonthCard({required this.guide, required this.isCurrentMonth});

  final _MonthlyGuide guide;
  final bool isCurrentMonth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return HomeStyleSurfaceCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color:
                      isCurrentMonth ? scheme.primary : scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  guide.icon,
                  color:
                      isCurrentMonth
                          ? scheme.onPrimary
                          : scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Month ${guide.month}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      guide.focus,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isCurrentMonth)
                HomeStylePill(
                  label: 'Current',
                  icon: Icons.today_rounded,
                  backgroundColor: scheme.primaryContainer,
                ),
            ],
          ),
          const SizedBox(height: 14),
          for (final item in guide.items) _GuideBullet(text: item),
        ],
      ),
    );
  }
}

class _GuideBullet extends StatelessWidget {
  const _GuideBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _MonthlyGuide {
  const _MonthlyGuide({
    required this.month,
    required this.focus,
    required this.icon,
    required this.items,
  });

  final int month;
  final String focus;
  final IconData icon;
  final List<String> items;
}

const _monthlyGuides = [
  _MonthlyGuide(
    month: 1,
    focus: 'First month home',
    icon: Icons.home_rounded,
    items: [
      'Sleep is irregular. Short wake windows and frequent naps are normal.',
      'Crying often peaks in the evening. Try feeding, burping, diaper checks, rocking, dim light, and skin-to-skin.',
      'Feeding cues include rooting, hand-to-mouth movement, lip smacking, and increased alertness before crying.',
      'Bonding grows through eye contact, holding, talking, gentle touch, and responding consistently.',
      'Call the doctor for fever, poor feeding, fewer wet diapers, hard-to-wake behavior, breathing trouble, or worsening jaundice.',
      'Parent self-care matters: trade shifts when possible, eat simple meals, hydrate, and ask for practical help.',
    ],
  ),
  _MonthlyGuide(
    month: 2,
    focus: 'More alert time',
    icon: Icons.visibility_rounded,
    items: [
      'Social smiles and cooing may begin.',
      'Tummy time can happen in short, repeated sessions.',
      'Day-night rhythm may slowly become easier to notice.',
    ],
  ),
  _MonthlyGuide(
    month: 3,
    focus: 'Head control',
    icon: Icons.face_rounded,
    items: [
      'Baby may hold the head steadier and watch faces closely.',
      'Hands open more often and may bat at toys.',
      'Keep floor play simple, supervised, and frequent.',
    ],
  ),
  _MonthlyGuide(
    month: 4,
    focus: 'Playful sounds',
    icon: Icons.record_voice_over_rounded,
    items: [
      'Laughing, squealing, and louder vocal play may appear.',
      'Rolling can begin, so avoid leaving baby unattended on raised surfaces.',
      'Sleep patterns may shift during developmental changes.',
    ],
  ),
  _MonthlyGuide(
    month: 5,
    focus: 'Reaching and rolling',
    icon: Icons.toys_rounded,
    items: [
      'Baby may reach, grasp, and bring toys to the mouth.',
      'Rolling practice can make diaper changes more active.',
      'Familiar routines can help with naps and bedtime.',
    ],
  ),
  _MonthlyGuide(
    month: 6,
    focus: 'Sitting support',
    icon: Icons.event_seat_rounded,
    items: [
      'Many babies sit with support and respond to their name.',
      'Your clinician may discuss readiness for solids.',
      'Keep small objects out of reach as grasping improves.',
    ],
  ),
  _MonthlyGuide(
    month: 7,
    focus: 'Exploring',
    icon: Icons.explore_rounded,
    items: [
      'Baby may sit longer and explore toys with both hands.',
      'Back-and-forth play becomes more rewarding.',
      'Separation reactions may start to show.',
    ],
  ),
  _MonthlyGuide(
    month: 8,
    focus: 'Movement practice',
    icon: Icons.directions_run_rounded,
    items: [
      'Scooting, pivoting, or crawling attempts may begin.',
      'Baby may search for dropped or hidden objects.',
      'Review floor safety and anchor unstable furniture.',
    ],
  ),
  _MonthlyGuide(
    month: 9,
    focus: 'Pulling up',
    icon: Icons.accessibility_new_rounded,
    items: [
      'Pulling to stand and stronger sitting balance may develop.',
      'Gestures like reaching up become clearer.',
      'Offer simple words during everyday routines.',
    ],
  ),
  _MonthlyGuide(
    month: 10,
    focus: 'Cruising',
    icon: Icons.transfer_within_a_station_rounded,
    items: [
      'Baby may move along furniture while holding on.',
      'Fine finger control improves for picking up small food pieces.',
      'Copying claps, waves, or sounds may become a favorite game.',
    ],
  ),
  _MonthlyGuide(
    month: 11,
    focus: 'Standing confidence',
    icon: Icons.front_hand_rounded,
    items: [
      'Baby may stand briefly and lower down with more control.',
      'Pointing and reaching help communicate wants.',
      'Simple limits and routines become more understandable.',
    ],
  ),
  _MonthlyGuide(
    month: 12,
    focus: 'First birthday range',
    icon: Icons.cake_rounded,
    items: [
      'Some babies take steps now; others need more time.',
      'Words, gestures, and imitation continue to build quickly.',
      'Ask your clinician about nutrition, dental care, sleep, and safety for the next stage.',
    ],
  ),
];
