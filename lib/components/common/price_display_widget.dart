import 'package:flutter/material.dart';
import 'package:waypoint/theme/waypoint_colors.dart';
import 'package:waypoint/theme/waypoint_typography.dart';

/// Reusable price display widget
/// 
/// Formats and displays price consistently across the app.
/// Shows "FREE" for 0 or null, otherwise formats as currency.

class PriceDisplayWidget extends StatelessWidget {
  final double? price;
  final double fontSize;
  final FontWeight fontWeight;
  final Color? color;
  final String currencySymbol;
  
  const PriceDisplayWidget({
    super.key,
    this.price,
    this.fontSize = 28.0,
    this.fontWeight = FontWeight.w700,
    this.color,
    this.currencySymbol = '€',
  });
  
  String get _formattedPrice {
    final priceValue = price ?? 0.0;
    if (priceValue == 0) return 'FREE';
    return '$currencySymbol${priceValue.toStringAsFixed(2)}';
  }
  
  @override
  Widget build(BuildContext context) {
    return Text(
      _formattedPrice,
      style: WaypointTypography.bodyLarge.copyWith(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color ?? WaypointColors.primary,
      ),
    );
  }
}

