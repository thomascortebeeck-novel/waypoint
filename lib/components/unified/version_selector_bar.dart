import 'package:flutter/material.dart';

/// Type-agnostic version selector — accepts display names and indices
/// Appears between tab bar and tab content for version-dependent tabs
class VersionSelectorBar extends StatelessWidget {
  final List<({String name, int index})> versions;
  final int activeIndex;
  final ValueChanged<int> onChanged;
  final bool isEditable;
  
  const VersionSelectorBar({
    super.key,
    required this.versions,
    required this.activeIndex,
    required this.onChanged,
    this.isEditable = false,
  });
  
  /// Factory constructor from form states (builder mode)
  factory VersionSelectorBar.fromFormStates({
    required List<dynamic> versions, // VersionFormState list
    required int activeIndex,
    required ValueChanged<int> onChanged,
    bool isEditable = false,
  }) {
    final versionList = versions.asMap().entries.map((e) {
      // Access nameCtrl.text from VersionFormState
      final nameCtrl = e.value.nameCtrl;
      final name = (nameCtrl.text.isEmpty 
          ? 'Version ${e.key + 1}' 
          : nameCtrl.text) as String;
      return (
        name: name,
        index: e.key,
      );
    }).toList();
    
    return VersionSelectorBar(
      versions: versionList,
      activeIndex: activeIndex,
      onChanged: onChanged,
      isEditable: isEditable,
    );
  }
  
  /// Factory constructor from plan versions (viewer mode)
  factory VersionSelectorBar.fromPlanVersions({
    required List<dynamic> versions, // PlanVersion list
    required int activeIndex,
    required ValueChanged<int> onChanged,
    bool isEditable = false,
  }) {
    final versionList = versions.asMap().entries.map((e) {
      // Access name from PlanVersion
      final name = e.value.name;
      final nameStr = name.isEmpty 
          ? 'Version ${e.key + 1}' 
          : name.toString();
      return (
        name: nameStr,
        index: e.key,
      );
    }).toList();
    
    return VersionSelectorBar(
      versions: versionList,
      activeIndex: activeIndex,
      onChanged: onChanged,
      isEditable: isEditable,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (versions.length <= 1) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Version:',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SegmentedButton<int>(
              segments: [
                for (final v in versions)
                  ButtonSegment(
                    value: v.index,
                    label: Text(v.name),
                  ),
              ],
              selected: {activeIndex},
              onSelectionChanged: isEditable
                  ? (Set<int> selection) => onChanged(selection.first)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

