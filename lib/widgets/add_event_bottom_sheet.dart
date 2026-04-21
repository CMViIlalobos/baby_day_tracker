import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../models/event.dart';

class AddEventBottomSheet extends StatefulWidget {
  const AddEventBottomSheet({super.key, required this.initialType});

  final EventType initialType;

  @override
  State<AddEventBottomSheet> createState() => _AddEventBottomSheetState();
}

class _AddEventBottomSheetState extends State<AddEventBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _medicineDoseController = TextEditingController();

  late EventType _selectedType;
  DateTime _selectedTimestamp = DateTime.now();
  int _feedingDuration = 15;
  String _feedingSide = 'Left';
  String _diaperType = 'Wet';
  int _sleepHours = 1;
  int _sleepMinutes = 0;
  String _medicineUnit = 'ml';
  bool _isSaving = false;

  final List<int> _feedingDurationOptions = List<int>.generate(
    24,
    (index) => (index + 1) * 5,
  );
  final List<int> _hourOptions = List<int>.generate(13, (index) => index);
  final List<int> _minuteOptions = List<int>.generate(12, (index) => index * 5);

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isSaving = true;
    });

    final event = BabyEvent(
      type: _selectedType,
      timestamp: _selectedTimestamp,
      notes:
          _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
      feedingDuration:
          _selectedType == EventType.feeding ? _feedingDuration : null,
      feedingSide: _selectedType == EventType.feeding ? _feedingSide : null,
      diaperType: _selectedType == EventType.diaper ? _diaperType : null,
      sleepDuration:
          _selectedType == EventType.sleep
              ? (_sleepHours * 60) + _sleepMinutes
              : null,
      medicineDose:
          _selectedType == EventType.medicine
              ? _medicineDoseController.text.trim()
              : null,
      medicineUnit: _selectedType == EventType.medicine ? _medicineUnit : null,
    );

    try {
      await DatabaseHelper.instance.insertEvent(event);
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
                  'Add event',
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
                OutlinedButton.icon(
                  onPressed: _pickDateTime,
                  icon: const Icon(Icons.schedule_rounded),
                  label: Text(
                    DateFormat('MMM d, y • hh:mm a').format(_selectedTimestamp),
                  ),
                ),
                const SizedBox(height: 16),
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
                    label: Text(_isSaving ? 'Saving...' : 'Save event'),
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
            DropdownButtonFormField<int>(
              value: _feedingDuration,
              decoration: const InputDecoration(
                labelText: 'Duration (minutes)',
              ),
              items:
                  _feedingDurationOptions
                      .map(
                        (minutes) => DropdownMenuItem(
                          value: minutes,
                          child: Text('$minutes min'),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _feedingDuration = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
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
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _sleepHours,
                    decoration: const InputDecoration(labelText: 'Hours'),
                    items:
                        _hourOptions
                            .map(
                              (hours) => DropdownMenuItem(
                                value: hours,
                                child: Text('$hours h'),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _sleepHours = value;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _sleepMinutes,
                    decoration: const InputDecoration(labelText: 'Minutes'),
                    items:
                        _minuteOptions
                            .map(
                              (minutes) => DropdownMenuItem(
                                value: minutes,
                                child: Text('$minutes m'),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _sleepMinutes = value;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        );
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
