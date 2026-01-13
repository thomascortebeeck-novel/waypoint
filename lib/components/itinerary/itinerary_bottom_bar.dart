import 'package:flutter/material.dart';
import 'package:waypoint/theme.dart';

/// Sticky bottom action bar with Back/Next actions
class ItineraryBottomBar extends StatelessWidget {
  final VoidCallback? onBack;
  final String backLabel;
  final VoidCallback? onNext;
  final String nextLabel;
  final IconData? nextIcon;
  final bool nextEnabled;

  const ItineraryBottomBar({
    super.key,
    this.onBack,
    this.backLabel = 'Back',
    this.onNext,
    required this.nextLabel,
    this.nextIcon,
    this.nextEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, -4)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (onBack != null)
              TextButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, size: 20),
                label: Text(backLabel),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  foregroundColor: context.colors.onSurfaceVariant,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            const Spacer(),
            ElevatedButton(
              onPressed: !nextEnabled ? null : onNext,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                backgroundColor: context.colors.primary,
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: context.colors.primary.withValues(alpha: 0.25),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(120, 48),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(nextLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (nextIcon != null) const SizedBox(width: 8),
                if (nextIcon != null) Icon(nextIcon, size: 18),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
