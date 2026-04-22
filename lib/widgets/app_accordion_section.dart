import 'package:flutter/material.dart';

class AppAccordionSection extends StatelessWidget {
  const AppAccordionSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.leading,
    this.initiallyExpanded = false,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? leading;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading:
            leading ??
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        children: children,
      ),
    );
  }
}
