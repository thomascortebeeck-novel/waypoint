import 'package:flutter/material.dart';
import 'package:waypoint/theme/waypoint_colors.dart';
import 'package:waypoint/theme/waypoint_typography.dart';
import 'package:waypoint/theme/waypoint_spacing.dart';
import 'package:waypoint/components/common/price_display_widget.dart';
import 'package:waypoint/models/plan_model.dart';

/// Buy Plan card component
/// 
/// Sidebar CTA card for purchasing/viewing adventure plans.
/// Builder mode: Shows price editor
/// Viewer mode: Shows buy button with price

class BuyPlanCard extends StatefulWidget {
  final double? price; // null or 0 = FREE
  final bool isBuilder;
  final String adventureTitle;
  final VoidCallback? onBuyTap;
  final TextEditingController? priceController; // builder mode only
  final ActivityCategory? activityCategory;
  final AccommodationType? accommodationType;
  final int? durationDays;
  
  const BuyPlanCard({
    super.key,
    this.price,
    this.isBuilder = false,
    required this.adventureTitle,
    this.onBuyTap,
    this.priceController,
    this.activityCategory,
    this.accommodationType,
    this.durationDays,
  });
  
  @override
  State<BuyPlanCard> createState() => _BuyPlanCardState();
}

class _BuyPlanCardState extends State<BuyPlanCard> {
  bool _whatsIncludedExpanded = false;
  
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: WaypointColors.surface,
        border: Border.all(color: WaypointColors.border, width: 1.0),
        borderRadius: BorderRadius.circular(WaypointSpacing.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: widget.isBuilder ? _buildBuilderMode() : _buildViewerMode(),
    );
  }
  
  Widget _buildBuilderMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('💰', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              'Set your price',
              style: WaypointTypography.headlineMedium,
            ),
          ],
        ),
        const SizedBox(height: WaypointSpacing.subsectionGap),
        if (widget.priceController != null)
          TextField(
            controller: widget.priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              prefixText: '€ ',
              hintText: '0.00',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: WaypointColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: WaypointColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: WaypointColors.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            style: WaypointTypography.bodyLarge.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          )
        else
          PriceDisplayWidget(
            price: widget.price,
            fontSize: 28,
          ),
        const SizedBox(height: WaypointSpacing.fieldGap),
        Text(
          'Leave at 0 for a free plan',
          style: WaypointTypography.bodyMedium.copyWith(
            color: WaypointColors.textSecondary,
          ),
        ),
        const SizedBox(height: WaypointSpacing.fieldGap),
        Row(
          children: [
            Text(
              'Preview: ',
              style: WaypointTypography.bodyMedium.copyWith(
                color: WaypointColors.textTertiary,
                fontStyle: FontStyle.italic,
              ),
            ),
            PriceDisplayWidget(
              price: widget.price,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: WaypointColors.textTertiary,
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildViewerMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('🏔️', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Get this adventure',
                style: WaypointTypography.headlineMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: WaypointSpacing.subsectionGap),
        PriceDisplayWidget(
          price: widget.price,
          fontSize: 28,
        ),
        const SizedBox(height: WaypointSpacing.subsectionGap),
        if (widget.onBuyTap != null)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: widget.onBuyTap,
              style: FilledButton.styleFrom(
                backgroundColor: WaypointColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Buy this plan',
                style: WaypointTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        const SizedBox(height: WaypointSpacing.subsectionGap),
        _buildWhatsIncludedSection(),
      ],
    );
  }
  
  Widget _buildWhatsIncludedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _whatsIncludedExpanded = !_whatsIncludedExpanded;
            });
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'What\'s Included',
                style: WaypointTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(
                _whatsIncludedExpanded
                    ? Icons.expand_less
                    : Icons.expand_more,
                size: 20,
                color: WaypointColors.textSecondary,
              ),
            ],
          ),
        ),
        if (_whatsIncludedExpanded) ...[
          const SizedBox(height: 12),
          _buildFeatureList(),
        ],
      ],
    );
  }
  
  Widget _buildFeatureList() {
    final items = <String>[];
    
    // Add items based on plan data
    if (widget.durationDays != null && widget.durationDays! > 0) {
      items.add('${widget.durationDays} day${widget.durationDays! > 1 ? 's' : ''} detailed itinerary');
    } else {
      items.add('Detailed itinerary');
    }
    
    if (widget.activityCategory != null) {
      items.add('${_getActivityName(widget.activityCategory!)} route');
    }
    
    if (widget.accommodationType != null) {
      items.add('${widget.accommodationType == AccommodationType.comfort ? 'Comfort' : 'Adventure'} accommodation guide');
    }
    
    items.add('GPX tracks for navigation');
    items.add('Local tips & cultural information');
    items.add('Packing lists & gear recommendations');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) => _buildFeatureItem(item)).toList(),
    );
  }
  
  String _getActivityName(ActivityCategory category) {
    switch (category) {
      case ActivityCategory.hiking:
        return 'Hiking';
      case ActivityCategory.cycling:
        return 'Cycling';
      case ActivityCategory.skis:
        return 'Skiing';
      case ActivityCategory.climbing:
        return 'Climbing';
      case ActivityCategory.cityTrips:
        return 'City trip';
      case ActivityCategory.tours:
        return 'Tour';
      case ActivityCategory.roadTripping:
        return 'Road trip';
    }
  }
  
  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 16,
            color: WaypointColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: WaypointTypography.bodyMedium.copyWith(
                fontSize: 13,
                color: WaypointColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

