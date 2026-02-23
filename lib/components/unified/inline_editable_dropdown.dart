import 'package:flutter/material.dart';

/// Dropdown component that works in both editable and read-only modes
/// Displays as a chip in read-only mode, full dropdown in edit mode
class InlineEditableDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;  // Builder mode
  final bool isEditable;
  final String Function(T)? displayText;
  
  const InlineEditableDropdown({
    super.key,
    required this.label,
    this.value,
    required this.items,
    this.onChanged,
    this.isEditable = false,
    this.displayText,
  });
  
  String _getDisplayText(T? val) {
    if (val == null) return '';
    if (displayText != null) return displayText!(val);
    return val.toString();
  }
  
  @override
  Widget build(BuildContext context) {
    if (!isEditable) {
      // Read-only display as chip
      if (value == null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Not set',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade400,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        );
      }
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Chip(
            label: Text(_getDisplayText(value)),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            labelStyle: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      );
    }
    
    // Editable mode
    return DropdownButtonFormField<T>(
      decoration: InputDecoration(labelText: label),
      value: value,
      items: items,
      onChanged: onChanged,
    );
  }
}

