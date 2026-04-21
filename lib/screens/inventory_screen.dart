import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../models/event.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({
    super.key,
    required this.refreshTick,
    required this.onChanged,
  });

  final int refreshTick;
  final Future<void> Function() onChanged;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  bool _isLoading = true;
  List<InventoryItem> _items = const [];
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void didUpdateWidget(covariant InventoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) {
      _loadItems();
    }
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final items = await DatabaseHelper.instance.getInventoryItems();
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      _showError(error);
    }
  }

  Future<void> _openEditor([InventoryItem? item]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _InventoryItemBottomSheet(item: item),
    );
    if (saved == true) {
      await _loadItems();
      await widget.onChanged();
    }
  }

  Future<void> _adjustQuantity(InventoryItem item, int delta) async {
    if (item.id == null) {
      return;
    }
    try {
      await DatabaseHelper.instance.adjustInventoryQuantity(item.id!, delta);
      await _loadItems();
      await widget.onChanged();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _deleteItem(InventoryItem item) async {
    if (item.id == null) {
      return;
    }
    try {
      await DatabaseHelper.instance.deleteInventoryItem(item.id!);
      await _loadItems();
      await widget.onChanged();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Inventory item deleted')));
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }

  @override
  Widget build(BuildContext context) {
    final lowStockCount = _items.where((item) => item.isLowStock).length;
    final categories =
        _items.map((item) => item.category).toSet().toList()..sort();
    final categoryOptions = ['All', ...categories];
    final visibleItems =
        _selectedCategory == 'All'
            ? _items
            : _items
                .where((item) => item.category == _selectedCategory)
                .toList();

    return RefreshIndicator(
      onRefresh: _loadItems,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          _InventoryHero(
            totalItems: _items.length,
            lowStockCount: lowStockCount,
            onAdd: () => _openEditor(),
          ),
          const SizedBox(height: 18),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _SectionHeader(
              title: 'Inventory Overview',
              subtitle: 'Quick visibility into supplies that matter most.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _InventoryStatCard(
                  title: 'Items tracked',
                  value: '${_items.length}',
                  icon: Icons.list_alt_rounded,
                  tint: const Color(0xFFD9ECFF),
                ),
                _InventoryStatCard(
                  title: 'Low stock',
                  value: '$lowStockCount',
                  icon: Icons.warning_amber_rounded,
                  tint: const Color(0xFFFDE7C8),
                  alert: lowStockCount > 0,
                ),
                _InventoryStatCard(
                  title: 'Categories',
                  value: '${categories.length}',
                  icon: Icons.category_rounded,
                  tint: const Color(0xFFDDF5E8),
                ),
                _InventoryStatCard(
                  title: 'Healthy stock',
                  value: '${_items.length - lowStockCount}',
                  icon: Icons.check_circle_outline_rounded,
                  tint: const Color(0xFFE8E3FF),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _SectionHeader(
              title: 'Browse Supplies',
              subtitle:
                  'Filter by category and tap edit or use quick plus/minus actions.',
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    categoryOptions.map((category) {
                      final selected = category == _selectedCategory;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: selected,
                          onSelected: (_) {
                            setState(() {
                              _selectedCategory = category;
                            });
                          },
                        ),
                      );
                    }).toList(),
              ),
            ),
            const SizedBox(height: 14),
            if (_items.isEmpty)
              const _InventoryEmptyState(
                title: 'No inventory items yet',
                description:
                    'Start with diapers, wipes, formula, bottles, medicine, or bath supplies.',
              )
            else if (visibleItems.isEmpty)
              const _InventoryEmptyState(
                title: 'No items in this category',
                description: 'Try another category filter or add a new item.',
              )
            else
              ...visibleItems.map(
                (item) => _InventorySupplyCard(
                  item: item,
                  onEdit: () => _openEditor(item),
                  onDelete: () => _deleteItem(item),
                  onDecrease: () => _adjustQuantity(item, -1),
                  onIncrease: () => _adjustQuantity(item, 1),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _InventoryHero extends StatelessWidget {
  const _InventoryHero({
    required this.totalItems,
    required this.lowStockCount,
    required this.onAdd,
  });

  final int totalItems;
  final int lowStockCount;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [Color(0xFFE3F1FF), Color(0xFFFFF2E5), Color(0xFFE7F8EF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFA8E6CF).withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.inventory_2_rounded, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inventory',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Stay ahead of diaper runs, feeding supplies, and medicine refills.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroBadge(
                label: '$totalItems tracked',
                icon: Icons.auto_awesome_mosaic_rounded,
              ),
              _HeroBadge(
                label: '$lowStockCount low stock',
                icon: Icons.notification_important_rounded,
                warn: lowStockCount > 0,
              ),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Supply'),
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({
    required this.label,
    required this.icon,
    this.warn = false,
  });

  final String label;
  final IconData icon;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color:
            warn
                ? const Color(0xFFFFE4C7)
                : Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _InventoryStatCard extends StatelessWidget {
  const _InventoryStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.tint,
    this.alert = false,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color tint;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 52) / 2;
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: alert ? Colors.orange.shade800 : null),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InventorySupplyCard extends StatelessWidget {
  const _InventorySupplyCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onDecrease,
    required this.onIncrease,
  });

  final InventoryItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final statusColor =
        item.isLowStock ? const Color(0xFFFFE4C7) : const Color(0xFFDDF5E8);
    final statusText = item.isLowStock ? 'Low stock' : 'Healthy stock';

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: _dismissBackground(),
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.category} • Updated ${DateFormat('MMM d, h:mm a').format(item.updatedAt)}',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.quantity} ${item.unit}',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusText,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: onDecrease,
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: onIncrease,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value:
                    item.lowStockThreshold <= 0
                        ? null
                        : (item.quantity / (item.lowStockThreshold * 3)).clamp(
                          0.0,
                          1.0,
                        ),
                minHeight: 10,
                borderRadius: BorderRadius.circular(999),
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              const SizedBox(height: 8),
              Text(
                'Low-stock threshold: ${item.lowStockThreshold} ${item.unit}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if ((item.notes ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  item.notes!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InventoryEmptyState extends StatelessWidget {
  const _InventoryEmptyState({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.8),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inventory_2_rounded, size: 34),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

Widget _dismissBackground() {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    alignment: Alignment.centerRight,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    decoration: BoxDecoration(
      color: Colors.red.shade300,
      borderRadius: BorderRadius.circular(24),
    ),
    child: const Icon(Icons.delete_rounded, color: Colors.white),
  );
}

class _InventoryItemBottomSheet extends StatefulWidget {
  const _InventoryItemBottomSheet({this.item});

  final InventoryItem? item;

  @override
  State<_InventoryItemBottomSheet> createState() =>
      _InventoryItemBottomSheetState();
}

class _InventoryItemBottomSheetState extends State<_InventoryItemBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _thresholdController = TextEditingController();
  final _notesController = TextEditingController();

  String _category = 'Diapers';
  String _unit = 'pcs';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      _nameController.text = item.name;
      _quantityController.text = item.quantity.toString();
      _thresholdController.text = item.lowStockThreshold.toString();
      _notesController.text = item.notes ?? '';
      _category = item.category;
      _unit = item.unit;
    } else {
      _quantityController.text = '1';
      _thresholdController.text = '3';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _thresholdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    final item = InventoryItem(
      id: widget.item?.id,
      name: _nameController.text.trim(),
      category: _category,
      quantity: int.parse(_quantityController.text.trim()),
      unit: _unit,
      lowStockThreshold: int.parse(_thresholdController.text.trim()),
      notes:
          _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
      updatedAt: DateTime.now(),
    );
    try {
      if (widget.item == null) {
        await DatabaseHelper.instance.insertInventoryItem(item);
      } else {
        await DatabaseHelper.instance.updateInventoryItem(item);
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  widget.item == null
                      ? 'Add inventory item'
                      : 'Edit inventory item',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Item name'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter an item name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items:
                      const [
                            'Diapers',
                            'Wipes',
                            'Feeding',
                            'Medicine',
                            'Bath',
                            'Clothing',
                            'Other',
                          ]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _category = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                        ),
                        validator: (value) {
                          if (value == null || int.tryParse(value) == null) {
                            return 'Enter a number';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _unit,
                        decoration: const InputDecoration(labelText: 'Unit'),
                        items:
                            const ['pcs', 'packs', 'bottles', 'boxes', 'ml']
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(value),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _unit = value;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _thresholdController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Low-stock threshold',
                  ),
                  validator: (value) {
                    if (value == null || int.tryParse(value) == null) {
                      return 'Enter a number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
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
                            : const Icon(Icons.save_rounded),
                    label: Text(_isSaving ? 'Saving...' : 'Save item'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
