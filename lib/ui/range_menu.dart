import 'package:flutter/material.dart';
import 'package:shai_hills_farm/domain/farm_visuals.dart';

/// Shared field style for every dropdown in the app.
InputDecoration farmDropdownDecoration(String label) {
  return InputDecoration(
    labelText: label,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}

/// A short date menu. Custom dates open the date picker from the menu.
class RangeMenu extends StatelessWidget {
  const RangeMenu({
    super.key,
    required this.preset,
    required this.custom,
    required this.customLabel,
    required this.onPreset,
    required this.onCustom,
    required this.keyPrefix,
  });

  final ChartPreset preset;
  final bool custom;
  final String customLabel;
  final ValueChanged<ChartPreset> onPreset;
  final VoidCallback onCustom;

  /// Key prefix, such as `chart-period` or `animal-period`.
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final label = custom ? customLabel : presetLabel(preset);
    return DropdownButtonFormField<String>(
      key: ValueKey('$keyPrefix-$label'),
      initialValue: custom ? 'custom' : preset.name,
      isExpanded: true,
      decoration: farmDropdownDecoration('When'),
      items: [
        for (final item in ChartPreset.values)
          DropdownMenuItem(
            key: Key('$keyPrefix-${item.name}'),
            value: item.name,
            child: Text(presetLabel(item)),
          ),
        DropdownMenuItem(
          key: Key('$keyPrefix-custom'),
          value: 'custom',
          child: Text(custom ? customLabel : 'Custom dates'),
        ),
      ],
      onChanged: (value) {
        if (value == null) {
          return;
        }
        if (value == 'custom') {
          onCustom();
          return;
        }
        onPreset(ChartPreset.values.byName(value));
      },
    );
  }
}

String presetLabel(ChartPreset preset) {
  return switch (preset) {
    ChartPreset.today => 'Today',
    ChartPreset.yesterday => 'Yesterday',
    ChartPreset.week => 'This week',
    ChartPreset.lastWeek => 'Last week',
    ChartPreset.month => 'This month',
    ChartPreset.lastMonth => 'Last month',
    ChartPreset.quarter => 'Quarter',
    ChartPreset.year => 'This year',
    ChartPreset.threeMonths => 'Last 3 months',
  };
}
