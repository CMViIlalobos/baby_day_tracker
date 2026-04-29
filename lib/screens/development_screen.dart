import 'package:flutter/material.dart';

import '../models/baby_profile.dart';
import '../widgets/home_style.dart';

class DevelopmentScreen extends StatefulWidget {
  const DevelopmentScreen({
    super.key,
    required this.refreshTick,
    required this.profile,
  });

  final int refreshTick;
  final BabyProfile profile;

  @override
  State<DevelopmentScreen> createState() => _DevelopmentScreenState();
}

class _DevelopmentScreenState extends State<DevelopmentScreen> {
  final Set<String> _checkedMilestones = {};

  @override
  Widget build(BuildContext context) {
    final ageMonth = _ageInMonths(widget.profile.birthDate).clamp(1, 12);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        HomeStylePageHeader(
          eyebrow: 'Milestones',
          title: 'Monthly Checklist',
          subtitle: 'Local checkboxes only',
          icon: Icons.checklist_rounded,
          badge:
              widget.profile.birthDate == null
                  ? 'Age not set'
                  : 'Month $ageMonth',
          gradient: const [
            Color(0xFFE7F8EF),
            Color(0xFFFFF4E8),
            Color(0xFFEAF6FF),
          ],
        ),
        const SizedBox(height: 20),
        for (final month in _milestoneMonths)
          _MilestoneMonthCard(
            month: month,
            isCurrentMonth:
                widget.profile.birthDate != null && month.month == ageMonth,
            checkedMilestones: _checkedMilestones,
            onChanged: (id, checked) {
              setState(() {
                if (checked) {
                  _checkedMilestones.add(id);
                } else {
                  _checkedMilestones.remove(id);
                }
              });
            },
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

class _MilestoneMonthCard extends StatelessWidget {
  const _MilestoneMonthCard({
    required this.month,
    required this.isCurrentMonth,
    required this.checkedMilestones,
    required this.onChanged,
  });

  final _MilestoneMonth month;
  final bool isCurrentMonth;
  final Set<String> checkedMilestones;
  final void Function(String id, bool checked) onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return HomeStyleSurfaceCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Month ${month.month}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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
          const SizedBox(height: 8),
          for (var index = 0; index < month.items.length; index++)
            CheckboxListTile(
              value: checkedMilestones.contains(month._idFor(index)),
              onChanged:
                  (value) => onChanged(month._idFor(index), value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: Text(month.items[index]),
              dense: true,
            ),
        ],
      ),
    );
  }
}

class _MilestoneMonth {
  const _MilestoneMonth({required this.month, required this.items});

  final int month;
  final List<String> items;

  String _idFor(int index) => '$month-$index';
}

const _milestoneMonths = [
  _MilestoneMonth(
    month: 1,
    items: [
      'Turns toward familiar voices',
      'Briefly lifts head during tummy time',
      'Looks at faces at close range',
    ],
  ),
  _MilestoneMonth(
    month: 2,
    items: [
      'Begins social smiling',
      'Coos or makes soft sounds',
      'Tracks movement with eyes',
    ],
  ),
  _MilestoneMonth(
    month: 3,
    items: [
      'Holds head steadier',
      'Opens and closes hands',
      'Pushes up on forearms during tummy time',
    ],
  ),
  _MilestoneMonth(
    month: 4,
    items: [
      'Laughs or squeals',
      'Brings hands to mouth',
      'Rolls from tummy toward back',
    ],
  ),
  _MilestoneMonth(
    month: 5,
    items: [
      'Reaches for toys',
      'Rolls with more control',
      'Recognizes familiar people',
    ],
  ),
  _MilestoneMonth(
    month: 6,
    items: [
      'Sits with support',
      'Responds to own name',
      'Passes objects between hands',
    ],
  ),
  _MilestoneMonth(
    month: 7,
    items: [
      'Sits briefly without support',
      'Explores objects with hands and mouth',
      'Enjoys simple back-and-forth play',
    ],
  ),
  _MilestoneMonth(
    month: 8,
    items: [
      'May start crawling or scooting',
      'Looks for dropped objects',
      'Uses more varied sounds',
    ],
  ),
  _MilestoneMonth(
    month: 9,
    items: [
      'Pulls toward standing',
      'Uses gestures like reaching up',
      'Shows stranger awareness',
    ],
  ),
  _MilestoneMonth(
    month: 10,
    items: [
      'Cruises along furniture',
      'Picks up small items with fingers',
      'Copies simple sounds or actions',
    ],
  ),
  _MilestoneMonth(
    month: 11,
    items: [
      'Stands briefly',
      'Understands simple words like no',
      'Points or reaches to request',
    ],
  ),
  _MilestoneMonth(
    month: 12,
    items: [
      'May take first steps',
      'Says mama or dada with meaning',
      'Plays simple games like peekaboo',
    ],
  ),
];
