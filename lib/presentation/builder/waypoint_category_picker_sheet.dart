import 'package:flutter/material.dart';
import 'package:waypoint/models/route_waypoint.dart';

/// Modal content for picking a single waypoint category (Sleep, Eat & Drink, etc.).
/// Used from WaypointEditPage Category row; pops with selected [WaypointType].
class WaypointCategoryPickerSheet extends StatelessWidget {
  final WaypointType currentType;

  const WaypointCategoryPickerSheet({
    super.key,
    required this.currentType,
  });

  static String _label(WaypointType type) {
    switch (type) {
      case WaypointType.accommodation:
        return 'Sleep';
      case WaypointType.restaurant:
        return 'Eat & Drink';
      case WaypointType.attraction:
        return 'Do & See';
      case WaypointType.viewingPoint:
        return 'See';
      case WaypointType.service:
        return 'Move';
      case WaypointType.bar:
        return 'Bar';
      default:
        return type.name;
    }
  }

  static const List<WaypointType> _pickerTypes = [
    WaypointType.accommodation,
    WaypointType.restaurant,
    WaypointType.attraction,
    WaypointType.viewingPoint,
    WaypointType.service,
    WaypointType.bar,
  ];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Category',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Flexible(
              child: ListView.builder(
                controller: scrollController,
                shrinkWrap: true,
                itemCount: _pickerTypes.length,
                itemBuilder: (context, index) {
                  final type = _pickerTypes[index];
                  final selected = type == currentType;
                  final color = getWaypointColor(type);
                  return ListTile(
                    leading: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                      ),
                    ),
                    title: Text(_label(type)),
                    trailing: selected
                        ? Icon(Icons.check_circle, color: color, size: 24)
                        : Icon(Icons.circle_outlined, color: Colors.grey.shade400, size: 24),
                    onTap: () => Navigator.of(context).pop<WaypointType>(type),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
