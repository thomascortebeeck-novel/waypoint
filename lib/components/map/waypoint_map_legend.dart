import 'package:flutter/material.dart';
import 'package:waypoint/core/theme/colors.dart';

class WaypointMapLegend extends StatelessWidget {
  const WaypointMapLegend({super.key});

  // Using Dart 3.0+ record syntax (project uses SDK ^3.6.0, so this is safe)
  // Colors are declared as static const in BrandColors and SemanticColors, so this works
  // Alternative for older Dart versions: use a simple class instead
  static const _items = [
    (type: 'stay', label: 'Stay', color: BrandColors.primary),
    (type: 'eat', label: 'Eat', color: SemanticColors.error),
    (type: 'do', label: 'Do', color: BrandColors.secondary),
    (type: 'move', label: 'Move', color: SemanticColors.info),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.color,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                item.label,
                style: const TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF212529), // Always dark for readability
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }
}

