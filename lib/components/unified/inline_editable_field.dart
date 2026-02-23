import 'package:flutter/material.dart';

/// Text field component that works in both editable and read-only modes
/// Used everywhere text needs to be displayed (viewer) or edited (builder)
class InlineEditableField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;  // Builder mode
  final String? displayValue;               // Viewer mode
  final bool isEditable;
  final int maxLines;
  final String? hint;
  final FormFieldValidator<String>? validator;
  final VoidCallback? onEditComplete;       // Triggers auto-save
  final TextInputType? keyboardType;
  
  const InlineEditableField({
    super.key,
    required this.label,
    this.controller,
    this.displayValue,
    this.isEditable = false,
    this.maxLines = 1,
    this.hint,
    this.validator,
    this.onEditComplete,
    this.keyboardType,
  });
  
  @override
  Widget build(BuildContext context) {
    if (!isEditable) {
      // Read-only display
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
            displayValue ?? '',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      );
    }
    
    // Editable mode
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      onEditingComplete: onEditComplete,
    );
  }
}

