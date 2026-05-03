import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/exercise_item.dart';
import '../providers/routine_edit_provider.dart';

class RoutineEditPage extends ConsumerStatefulWidget {
  final String? routineId;

  const RoutineEditPage({super.key, required this.routineId});

  @override
  ConsumerState<RoutineEditPage> createState() => _RoutineEditPageState();
}

class _RoutineEditPageState extends ConsumerState<RoutineEditPage> {
  late final TextEditingController _titleController;
  bool _titleInitialized = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(routineEditProvider(widget.routineId));
    final notifier = ref.read(routineEditProvider(widget.routineId).notifier);

    // Sync title controller once after async load.
    if (!_titleInitialized && state.title.isNotEmpty) {
      _titleController.text = state.title;
      _titleInitialized = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.routineId == null ? l10n.addRoutine : l10n.edit),
        actions: [
          if (state.isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: l10n.save,
              onPressed: () => _onSave(context, notifier, l10n),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Title
          TextField(
            controller: _titleController,
            maxLength: 80,
            decoration: InputDecoration(
              labelText: l10n.routineTitle,
              border: const OutlineInputBorder(),
            ),
            onChanged: notifier.setTitle,
          ),
          const SizedBox(height: 20),

          // Prep time slider
          _SliderRow(
            label: l10n.prepTime,
            value: state.prepTime.toDouble(),
            min: 0,
            max: 60,
            divisions: 60,
            suffix: l10n.seconds,
            onChanged: (v) => notifier.setPrepTime(v.round()),
          ),

          // Cooldown time slider
          _SliderRow(
            label: l10n.cooldownTime,
            value: state.cooldownTime.toDouble(),
            min: 0,
            max: 120,
            divisions: 120,
            suffix: l10n.seconds,
            onChanged: (v) => notifier.setCooldownTime(v.round()),
          ),

          // Cycles slider
          _SliderRow(
            label: l10n.totalCycles,
            value: state.totalCycles.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            suffix: '',
            onChanged: (v) => notifier.setTotalCycles(v.round()),
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),

          // Exercise items header
          Text(
            'Items',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),

          // Reorderable items
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.items.length,
            onReorder: notifier.reorderItems,
            itemBuilder: (context, index) {
              final item = state.items[index];
              return _ExerciseItemRow(
                key: ValueKey(item.id),
                item: item,
                index: index,
                l10n: l10n,
                onUpdate: (updated) => notifier.updateItem(index, updated),
                onDelete: () => notifier.removeItem(index),
              );
            },
          ),

          const SizedBox(height: 8),
          // Add item button
          OutlinedButton.icon(
            onPressed: notifier.addItem,
            icon: const Icon(Icons.add),
            label: Text(l10n.addItem),
          ),

          if (state.error != null) ...[
            const SizedBox(height: 12),
            Text(
              l10n.errorSave,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _onSave(
    BuildContext context,
    RoutineEditNotifier notifier,
    AppLocalizations l10n,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final errorMsg = l10n.errorSave;

    final success = await notifier.save();
    if (!mounted) return;
    if (success) {
      navigator.pop();
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
    }
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String suffix;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.suffix,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text('$label: ${value.round()}$suffix'),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: '${value.round()}$suffix',
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _ExerciseItemRow extends StatefulWidget {
  final ExerciseItem item;
  final int index;
  final AppLocalizations l10n;
  final ValueChanged<ExerciseItem> onUpdate;
  final VoidCallback onDelete;

  const _ExerciseItemRow({
    super.key,
    required this.item,
    required this.index,
    required this.l10n,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<_ExerciseItemRow> createState() => _ExerciseItemRowState();
}

class _ExerciseItemRowState extends State<_ExerciseItemRow> {
  late final TextEditingController _nameController;
  late final TextEditingController _durationController;
  late final TextEditingController _repsController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _durationController =
        TextEditingController(text: widget.item.duration.toString());
    _repsController =
        TextEditingController(text: widget.item.targetReps?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final item = widget.item;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                // Drag handle (ReorderableListView provides it via ReorderableDragStartListener)
                ReorderableDragStartListener(
                  index: widget.index,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.drag_handle),
                  ),
                ),
                // Name field
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    maxLength: 50,
                    decoration: InputDecoration(
                      labelText: l10n.exerciseName,
                      border: const OutlineInputBorder(),
                      isDense: true,
                      counterText: '',
                    ),
                    onChanged: (v) =>
                        widget.onUpdate(item.copyWith(name: v)),
                  ),
                ),
                const SizedBox(width: 8),
                // Type dropdown
                DropdownButton<ExerciseType>(
                  value: item.type,
                  onChanged: (type) {
                    if (type != null) {
                      widget.onUpdate(item.copyWith(type: type));
                    }
                  },
                  items: [
                    DropdownMenuItem(
                      value: ExerciseType.WORK_TIME,
                      child: Text(l10n.typeWorkTime),
                    ),
                    DropdownMenuItem(
                      value: ExerciseType.WORK_REPS,
                      child: Text(l10n.typeWorkReps),
                    ),
                    DropdownMenuItem(
                      value: ExerciseType.REST,
                      child: Text(l10n.typeRest),
                    ),
                  ],
                ),
                // Delete
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 48), // align under name field
                // Duration field
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _durationController,
                    decoration: InputDecoration(
                      labelText: l10n.duration,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final d = int.tryParse(v) ?? 0;
                      widget.onUpdate(item.copyWith(duration: d));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Reps field — only for WORK_REPS
                if (item.type == ExerciseType.WORK_REPS)
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _repsController,
                      decoration: InputDecoration(
                        labelText: l10n.targetReps,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        final r = int.tryParse(v);
                        widget.onUpdate(item.copyWith(targetReps: r));
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
