import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../models/event.dart';

class AddEventBottomSheet extends StatefulWidget {
  const AddEventBottomSheet({super.key, required this.initialType, this.event});

  final EventType initialType;
  final BabyEvent? event;

  @override
  State<AddEventBottomSheet> createState() => _AddEventBottomSheetState();
}

class _AddEventBottomSheetState extends State<AddEventBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _medicineDoseController = TextEditingController();

  late EventType _selectedType;
  DateTime _selectedTimestamp = DateTime.now();
  DateTime _rangeStart = DateTime.now();
  DateTime _rangeEnd = DateTime.now().add(const Duration(minutes: 15));
  String _feedingSide = 'Left';
  String _diaperType = 'Wet';
  String _medicineUnit = 'ml';
  bool _isSaving = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _selectedType = event?.type ?? widget.initialType;
    if (event != null) {
      _selectedTimestamp = event.timestamp;
      _rangeStart = event.timestamp;
      _notesController.text = event.notes ?? '';
      _feedingSide = event.feedingSide ?? _feedingSide;
      _diaperType = event.diaperType ?? _diaperType;
      final totalMinutes =
          event.type == EventType.feeding
              ? (event.feedingDuration ?? 15)
              : (event.sleepDuration ?? 60);
      _rangeEnd = _rangeStart.add(Duration(minutes: totalMinutes));
      _medicineDoseController.text = event.medicineDose ?? '';
      _medicineUnit = event.medicineUnit ?? _medicineUnit;
    } else {
      _rangeStart = _selectedTimestamp;
      _rangeEnd =
          _selectedType == EventType.sleep
              ? _rangeStart.add(const Duration(hours: 1))
              : _rangeStart.add(const Duration(minutes: 15));
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _medicineDoseController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _selectedTimestamp,
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedTimestamp),
    );
    if (time == null) {
      return;
    }
    setState(() {
      _selectedTimestamp = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _pickRangeDateTime({required bool isStart}) async {
    final initial = isStart ? _rangeStart : _rangeEnd;
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: initial,
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) {
      return;
    }

    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      if (isStart) {
        final duration = _computedDurationMinutes;
        _rangeStart = picked;
        if (!_rangeEnd.isAfter(_rangeStart)) {
          _rangeEnd = _rangeStart.add(
            Duration(minutes: duration <= 0 ? 15 : duration),
          );
        }
      } else {
        _rangeEnd = picked;
        if (!_rangeEnd.isAfter(_rangeStart)) {
          _rangeEnd = _rangeEnd.add(const Duration(days: 1));
        }
      }
    });
  }

  int get _computedDurationMinutes {
    final minutes = _rangeEnd.difference(_rangeStart).inMinutes;
    return minutes <= 0 ? 1 : minutes;
  }

  String get _computedDurationLabel {
    final minutes = _computedDurationMinutes;
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours > 0 && remainingMinutes > 0) {
      return '${hours}h ${remainingMinutes}m';
    }
    if (hours > 0) {
      return '${hours}h';
    }
    return '${remainingMinutes}m';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isSaving = true;
    });

    final event = BabyEvent(
      type: _selectedType,
      timestamp:
          _selectedType == EventType.feeding || _selectedType == EventType.sleep
              ? _rangeStart
              : _selectedTimestamp,
      notes:
          _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
      feedingDuration:
          _selectedType == EventType.feeding ? _computedDurationMinutes : null,
      feedingSide: _selectedType == EventType.feeding ? _feedingSide : null,
      diaperType: _selectedType == EventType.diaper ? _diaperType : null,
      sleepDuration:
          _selectedType == EventType.sleep ? _computedDurationMinutes : null,
      medicineDose:
          _selectedType == EventType.medicine
              ? _medicineDoseController.text.trim()
              : null,
      medicineUnit: _selectedType == EventType.medicine ? _medicineUnit : null,
    );

    try {
      if (widget.event == null) {
        await DatabaseHelper.instance.insertEvent(event);
      } else {
        await DatabaseHelper.instance.updateEvent(
          event.copyWith(id: widget.event!.id),
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _delete() async {
    final existingEvent = widget.event;
    if (existingEvent?.id == null) {
      return;
    }
    setState(() {
      _isDeleting = true;
    });
    try {
      await DatabaseHelper.instance.deleteEvent(existingEvent!.id!);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      setState(() {
        _isDeleting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  widget.event == null ? 'Add event' : 'Edit event',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<EventType>(
                  value: _selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items:
                      EventType.values
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type.label),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedType = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (_selectedType == EventType.feeding ||
                    _selectedType == EventType.sleep) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickRangeDateTime(isStart: true),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(
                            DateFormat('MMM d • hh:mm a').format(_rangeStart),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickRangeDateTime(isStart: false),
                          icon: const Icon(Icons.stop_rounded),
                          label: Text(
                            DateFormat('MMM d • hh:mm a').format(_rangeEnd),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Duration: $_computedDurationLabel',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  OutlinedButton.icon(
                    onPressed: _pickDateTime,
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text(
                      DateFormat(
                        'MMM d, y • hh:mm a',
                      ).format(_selectedTimestamp),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _buildTypeSpecificFields(),
                TextFormField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 20),
                if (widget.event != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: (_isSaving || _isDeleting) ? null : _delete,
                      icon:
                          _isDeleting
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.delete_outline_rounded),
                      label: Text(_isDeleting ? 'Deleting...' : 'Delete event'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon:
                        _isSaving
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.check_rounded),
                    label: Text(
                      _isSaving
                          ? 'Saving...'
                          : widget.event == null
                          ? 'Save event'
                          : 'Update event',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSpecificFields() {
    switch (_selectedType) {
      case EventType.feeding:
        return Column(
          children: [
            DropdownButtonFormField<String>(
              value: _feedingSide,
              decoration: const InputDecoration(labelText: 'Side'),
              items:
                  const ['Left', 'Right', 'Bottle']
                      .map(
                        (side) =>
                            DropdownMenuItem(value: side, child: Text(side)),
                      )
                      .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _feedingSide = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        );
      case EventType.diaper:
        return Column(
          children: [
            DropdownButtonFormField<String>(
              value: _diaperType,
              decoration: const InputDecoration(labelText: 'Diaper type'),
              items:
                  const ['Wet', 'Dirty', 'Both']
                      .map(
                        (type) =>
                            DropdownMenuItem(value: type, child: Text(type)),
                      )
                      .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _diaperType = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        );
      case EventType.sleep:
        return const SizedBox.shrink();
      case EventType.medicine:
        return Column(
          children: [
            TextFormField(
              controller: _medicineDoseController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Dose'),
              validator: (value) {
                if (_selectedType != EventType.medicine) {
                  return null;
                }
                if (value == null || value.trim().isEmpty) {
                  return 'Enter a dose';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _medicineUnit,
              decoration: const InputDecoration(labelText: 'Unit'),
              items:
                  const ['ml', 'mg', 'drops']
                      .map(
                        (unit) =>
                            DropdownMenuItem(value: unit, child: Text(unit)),
                      )
                      .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _medicineUnit = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        );
    }
  }
}
