import 'package:flutter/material.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/trip_model.dart';
import 'package:waypoint/presentation/reviews/trip_review_dialog.dart';
import 'package:waypoint/services/review_service.dart';

/// Tries to show the trip review dialog when conditions are met.
/// Call after the trip plan screen has loaded (e.g. in initState after _load).
///
/// Flow: if in review window, member, not already shown, not already reviewed
/// → mark "shown" in Firestore first (avoids double dialog) → wait 2.5s →
/// dismiss keyboard → show dialog.
void tryShowTripReviewPrompt({
  required BuildContext context,
  required Trip trip,
  required Plan plan,
  required String userId,
}) {
  final reviewService = ReviewService();

  Future<void> checkAndShow() async {
    if (trip.endDate == null) return;
    if (!trip.isMember(userId)) return;
    if (!ReviewService.isInReviewWindow(trip)) return;
    final alreadyShown = await reviewService.hasBeenShownReviewPrompt(userId, trip.id);
    if (alreadyShown) return;
    final alreadyReviewed = await reviewService.hasUserReviewed(userId, plan.id);
    if (alreadyReviewed) return;

    // Set "shown" before showing dialog to avoid race with another screen
    await reviewService.markReviewPromptShown(userId, trip.id);

    // Delay so it feels natural; then dismiss keyboard and show dialog
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    if (!context.mounted) return;
    FocusScope.of(context).unfocus();
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => TripReviewDialog(
        trip: trip,
        plan: plan,
        userId: userId,
      ),
    );
  }

  checkAndShow();
}
