import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/event.dart';

class EventTimelineItem extends StatelessWidget {
  const EventTimelineItem({
    super.key,
    required this.event,
    required this.onTap,
    required this.onDelete,
  });

  final BabyEvent event;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(event.id ?? event.timestamp.toIso8601String()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade300,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 10,
          ),
          leading: CircleAvatar(
            backgroundColor: event.type.accentColor.withValues(alpha: 0.35),
            child: Icon(event.type.icon, color: Colors.black87),
          ),
          title: Text(
            event.type.label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(DateFormat('hh:mm a').format(event.timestamp)),
              if (_detailsLabel().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_detailsLabel()),
                ),
              if ((event.notes ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    event.notes!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          trailing: const Icon(Icons.edit_rounded),
        ),
      ),
    );
  }

  String _detailsLabel() {
    return switch (event.type) {
      EventType.feeding =>
        '${event.feedingSide ?? 'Unknown side'}${event.feedingDuration != null ? ' • ${event.feedingDuration} min' : ''}',
      EventType.diaper => event.diaperType ?? '',
      EventType.sleep =>
        event.sleepDuration == null
            ? ''
            : '${(event.sleepDuration! / 60).toStringAsFixed(1)} hrs',
      EventType.medicine => [
        if ((event.medicineDose ?? '').isNotEmpty) event.medicineDose,
        if ((event.medicineUnit ?? '').isNotEmpty) event.medicineUnit,
      ].whereType<String>().join(' '),
    };
  }
}
