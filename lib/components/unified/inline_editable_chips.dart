import 'package:flutter/material.dart';

/// Multi-select chips component that works in both editable and read-only modes
/// Displays as read-only chips in viewer mode, editable chips in builder mode
class InlineEditableChips<T> extends StatelessWidget {
  final String label;
  final List<T> selectedValues;
  final List<ChipOption<T>> options;
  final ValueChanged<List<T>>? onChanged;  // Builder mode
  final bool isEditable;
  final String Function(T)? displayText;
  
  const InlineEditableChips({
    super.key,
    required this.label,
    required this.selectedValues,
    required this.options,
    this.onChanged,
    this.isEditable = false,
    this.displayText,
  });
  
  String _getDisplayText(T value) {
    if (displayText != null) return displayText!(value);
    return value.toString();
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selectedValues.contains(option.value);
            
            if (!isEditable) {
              // Read-only: only show selected items
              if (!isSelected) return const SizedBox.shrink();
              
              return Chip(
                label: Text(_getDisplayText(option.value)),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                labelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              );
            }
            
            // Editable mode: show all options, toggle on tap
            return FilterChip(
              label: Text(_getDisplayText(option.value)),
              selected: isSelected,
              onSelected: (selected) {
                if (onChanged == null) return;
                final newList = List<T>.from(selectedValues);
                if (selected) {
                  if (!newList.contains(option.value)) {
                    newList.add(option.value);
                  }
                } else {
                  newList.remove(option.value);
                }
                onChanged!(newList);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Option for chips component
class ChipOption<T> {
  final T value;
  final String? label;
  
  const ChipOption({
    required this.value,
    this.label,
  });
}

