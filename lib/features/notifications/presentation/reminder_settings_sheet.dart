import 'package:jewellery_business_manager/core/localization/copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/notice.dart';
import 'notification_providers.dart';

Future<void> openReminderSettings(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 620),
      builder: (_) => const FractionallySizedBox(
        heightFactor: .92,
        child: _SettingsLoader(),
      ),
    );

class _SettingsLoader extends ConsumerWidget {
  const _SettingsLoader();

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(reminderRulesProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(reminderRulesProvider),
            child: const Text('Could not load reminder rules. Retry'),
          ),
        ),
        data: (rules) => _ReminderForm(initial: rules),
      );
}

class _ReminderForm extends ConsumerStatefulWidget {
  const _ReminderForm({required this.initial});
  final ReminderRules initial;

  @override
  ConsumerState<_ReminderForm> createState() => _ReminderFormState();
}

class _ReminderFormState extends ConsumerState<_ReminderForm> {
  final _form = GlobalKey<FormState>();
  late bool _enabled = widget.initial.enabled;
  late bool _stock = widget.initial.lowStock;
  late bool _daily = widget.initial.dailyDigest;
  late bool _weekly = widget.initial.weeklyDigest;
  late final _values = {
    'Pending order hours': TextEditingController(
      text: widget.initial.pendingHours.toString(),
    ),
    'Confirmed order hours': TextEditingController(
      text: widget.initial.confirmedHours.toString(),
    ),
    'Packed order hours': TextEditingController(
      text: widget.initial.packedHours.toString(),
    ),
    'Transit days': TextEditingController(
      text: widget.initial.transitDays.toString(),
    ),
    'COD settlement days': TextEditingController(
      text: widget.initial.codDays.toString(),
    ),
    'Digest hour (Sri Lanka, 24-hour clock)': TextEditingController(
      text: widget.initial.digestHour.toString(),
    ),
  };
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in _values.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final inputs = _values.values
        .map((field) => int.parse(field.text.trim()))
        .toList();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(notificationRepositoryProvider)
          .saveRules(
            ReminderRules(
              enabled: _enabled,
              lowStock: _stock,
              dailyDigest: _daily,
              weeklyDigest: _weekly,
              pendingHours: inputs[0],
              confirmedHours: inputs[1],
              packedHours: inputs[2],
              transitDays: inputs[3],
              codDays: inputs[4],
              digestHour: inputs[5],
            ),
          );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save reminder rules. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      children: [
        Copy(
          'Reminder rules',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Scheduled reminders'),
          value: _enabled,
          onChanged: _saving
              ? null
              : (value) => setState(() => _enabled = value),
        ),
        const SizedBox(height: 8),
        for (final (index, entry) in _values.entries.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              controller: entry.value,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: entry.key),
              validator: (value) {
                final minimum = index == 5 ? 0 : 1;
                final maximum = index < 3
                    ? 720
                    : index == 5
                    ? 23
                    : 90;
                final count = int.tryParse(value?.trim() ?? '');
                return count == null || count < minimum || count > maximum
                    ? 'Enter $minimum to $maximum.'
                    : null;
              },
            ),
          ),
        _toggle('Low stock reminders', _stock, (value) => _stock = value),
        _toggle('Daily dispatch digest', _daily, (value) => _daily = value),
        _toggle(
          'Weekly delivered sales summary',
          _weekly,
          (value) => _weekly = value,
        ),
        if (_error case final message?)
          Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save rules'),
        ),
      ],
    ),
  );

  Widget _toggle(String label, bool value, ValueChanged<bool> change) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: value,
        onChanged: _saving ? null : (value) => setState(() => change(value)),
      );
}
