import 'package:flutter/material.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/utils/activity_config.dart';

/// Breadcrumb item for navigation
class BreadcrumbItem {
  final String label;
  final int step;
  final String? icon;
  final bool isClickable;
  final bool isActive;

  BreadcrumbItem({
    required this.label,
    required this.step,
    this.icon,
    this.isClickable = true,
    this.isActive = false,
  });
}

/// Builder breadcrumb widget with conditional rendering
class BuilderBreadcrumb extends StatelessWidget {
  final int currentStep;
  final ActivityCategory? activityCategory;
  final List<LocationInfo> locations;
  final Function(int) onStepTap;
  final bool isMobile;

  const BuilderBreadcrumb({
    super.key,
    required this.currentStep,
    this.activityCategory,
    this.locations = const [],
    required this.onStepTap,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    final items = _buildBreadcrumbItems();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: isMobile
          ? _buildMobileBreadcrumb(context, items)
          : _buildDesktopBreadcrumb(context, items),
    );
  }

  List<BreadcrumbItem> _buildBreadcrumbItems() {
    final items = <BreadcrumbItem>[];
    
    // Builder (always shown, not clickable)
    items.add(BreadcrumbItem(
      label: 'Builder',
      step: -1,
      isClickable: false,
    ));
    
    // Activity Type (if selected)
    if (activityCategory != null) {
      final config = getActivityConfig(activityCategory);
      items.add(BreadcrumbItem(
        label: config?.displayName ?? activityCategory!.name,
        step: 0,
        icon: config?.icon,
        isActive: currentStep == 0,
      ));
    }
    
    // Locations (conditional display)
    if (locations.isNotEmpty) {
      if (locations.length <= 2) {
        // Show all locations (use shortName for breadcrumb)
        for (var loc in locations) {
          items.add(BreadcrumbItem(
            label: loc.shortName,
            step: 1,
            isActive: currentStep == 1,
          ));
        }
      } else {
        // Show first + count (use shortName to prevent truncation)
        items.add(BreadcrumbItem(
          label: '${locations.first.shortName} + ${locations.length - 1} more',
          step: 1,
          isActive: currentStep == 1,
        ));
      }
    }
    
    // Current step (if not already shown)
    if (currentStep >= 2) {
      final stepLabels = [
        'Activity Type',
        'Locations',
        'General Info',
        'Versions',
        'Prepare',
        'Local Tips',
        'Days',
        'Overview',
      ];
      
      if (currentStep < stepLabels.length) {
        items.add(BreadcrumbItem(
          label: stepLabels[currentStep],
          step: currentStep,
          isActive: true,
        ));
      }
    }
    
    return items;
  }

  Widget _buildDesktopBreadcrumb(BuildContext context, List<BreadcrumbItem> items) {
    return Row(
      children: items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final isLast = index == items.length - 1;
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBreadcrumbItem(context, item),
            if (!isLast) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: Colors.grey.shade400,
              ),
              const SizedBox(width: 8),
            ],
          ],
        );
      }).toList(),
    );
  }

  Widget _buildMobileBreadcrumb(BuildContext context, List<BreadcrumbItem> items) {
    // Steppers-lite: scrollable horizontal list of icons
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == items.length - 1;
          
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMobileBreadcrumbItem(context, item),
              if (!isLast) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  size: 14,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 8),
              ],
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBreadcrumbItem(BuildContext context, BreadcrumbItem item) {
    final isActive = item.isActive;
    final isClickable = item.isClickable && !isActive;
    
    return GestureDetector(
      onTap: isClickable ? () => onStepTap(item.step) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF428A13).withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.icon != null) ...[
              Text(
                item.icon!,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              item.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive
                    ? const Color(0xFF428A13)
                    : isClickable
                        ? Colors.black87
                        : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileBreadcrumbItem(BuildContext context, BreadcrumbItem item) {
    final isActive = item.isActive;
    final isClickable = item.isClickable && !isActive;
    
    return GestureDetector(
      onTap: isClickable ? () => onStepTap(item.step) : null,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF428A13) : Colors.grey.shade200,
          shape: BoxShape.circle,
        ),
        child: item.icon != null
            ? Text(
                item.icon!,
                style: TextStyle(
                  fontSize: 18,
                  color: isActive ? Colors.white : Colors.grey.shade700,
                ),
              )
            : Icon(
                _getStepIcon(item.step),
                size: 18,
                color: isActive ? Colors.white : Colors.grey.shade700,
              ),
      ),
    );
  }

  IconData _getStepIcon(int step) {
    switch (step) {
      case 0:
        return Icons.category;
      case 1:
        return Icons.place;
      case 2:
        return Icons.info;
      case 3:
        return Icons.list;
      case 4:
        return Icons.checklist;
      case 5:
        return Icons.lightbulb;
      case 6:
        return Icons.calendar_today;
      case 7:
        return Icons.preview;
      default:
        return Icons.circle;
    }
  }
}

