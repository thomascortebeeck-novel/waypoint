import 'package:flutter/material.dart';
import 'package:waypoint/theme/waypoint_colors.dart';
import 'package:waypoint/theme/waypoint_spacing.dart';
import 'package:waypoint/theme/waypoint_typography.dart';
import 'package:waypoint/layout/waypoint_breakpoints.dart';
import 'poi_card.dart';

/// POI grid component
/// 
/// Responsive grid layout for POI cards.
/// Mobile: 1 column
/// Tablet+: 2-3 columns
/// Last card in builder mode: dashed "Add" card

class POIGrid extends StatelessWidget {
  final List<POICard> cards;
  final bool isBuilder;
  final VoidCallback? onAdd;
  final String addLabel;
  
  const POIGrid({
    super.key,
    required this.cards,
    this.isBuilder = false,
    this.onAdd,
    this.addLabel = 'Add',
  });
  
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = WaypointBreakpoints.isMobile(screenWidth);
    final isTablet = WaypointBreakpoints.isTablet(screenWidth);
    
    // Calculate crossAxisCount
    int crossAxisCount;
    if (isMobile) {
      crossAxisCount = 1;
    } else if (isTablet) {
      crossAxisCount = 2;
    } else {
      crossAxisCount = 3;
    }
    
    final allCards = [
      ...cards,
      if (isBuilder && onAdd != null)
        _AddPOICard(
          label: addLabel,
          onTap: onAdd!,
        ),
    ];
    
    // Responsive aspect ratio: mobile cards are taller, desktop wider
    final aspectRatio = isMobile ? 1.3 : (isTablet ? 1.25 : 1.2);
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: WaypointSpacing.cardGap,
        mainAxisSpacing: WaypointSpacing.cardGap,
        childAspectRatio: aspectRatio,
      ),
      itemCount: allCards.length,
      itemBuilder: (context, index) => allCards[index],
    );
  }
}

class _AddPOICard extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  
  const _AddPOICard({
    required this.label,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: WaypointColors.surface,
          border: Border.all(
            color: WaypointColors.border,
            width: 1.5,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(WaypointSpacing.cardRadius),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add,
              size: 24.0,
              color: WaypointColors.textTertiary,
            ),
            const SizedBox(height: 6.0),
            Text(
              label,
              style: WaypointTypography.bodyMedium.copyWith(
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
                color: WaypointColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

