import 'package:flutter/material.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/trip_model.dart';
import 'package:waypoint/services/app_review_service.dart';
import 'package:waypoint/services/review_service.dart';
import 'package:waypoint/theme/waypoint_colors.dart';
import 'package:waypoint/theme/waypoint_typography.dart';

/// Two-page modal: (1) plan/creator review, (2) Waypoint app review.
/// Shown on last day (or grace window) when user opens the trip plan.
/// Caller must have already marked the prompt as "shown" in Firestore before showing.
class TripReviewDialog extends StatefulWidget {
  const TripReviewDialog({
    super.key,
    required this.trip,
    required this.plan,
    required this.userId,
  });

  final Trip trip;
  final Plan plan;
  final String userId;

  @override
  State<TripReviewDialog> createState() => _TripReviewDialogState();
}

class _TripReviewDialogState extends State<TripReviewDialog> {
  final ReviewService _reviewService = ReviewService();
  final AppReviewService _appReviewService = AppReviewService();

  int _page = 0;
  int _planRating = 0;
  final TextEditingController _planCommentController = TextEditingController();
  int _appRating = 0;
  final TextEditingController _appCommentController = TextEditingController();
  bool _allowShowOnWebsite = false;

  bool _savingPlan = false;
  bool _savingApp = false;
  String? _errorMessage;

  String get _versionId =>
      widget.trip.versionId ?? (widget.plan.versions.isNotEmpty ? widget.plan.versions.first.id : '');

  @override
  void dispose() {
    _planCommentController.dispose();
    _appCommentController.dispose();
    super.dispose();
  }

  Future<void> _savePlanReviewAndGoToPage2() async {
    if (_planRating < 1 || _planRating > 5) return;
    setState(() {
      _errorMessage = null;
      _savingPlan = true;
    });
    try {
      await _reviewService.createReview(
        planId: widget.plan.id,
        tripId: widget.trip.id,
        versionId: _versionId,
        rating: _planRating,
        text: _planCommentController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _page = 1;
          _savingPlan = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _savingPlan = false;
          _errorMessage = 'Could not save review. Please try again.';
        });
      }
    }
  }

  Future<void> _submitAppReview() async {
    if (_appRating < 1 || _appRating > 5) return;
    setState(() {
      _errorMessage = null;
      _savingApp = true;
    });
    final comment = _appCommentController.text.trim();
    final allowShowOnWebsite = _appRating >= 4 && comment.isNotEmpty && _allowShowOnWebsite;
    try {
      await _appReviewService.createAppReview(
        rating: _appRating,
        comment: comment,
        tripId: widget.trip.id,
        allowShowOnWebsite: allowShowOnWebsite,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _savingApp = false;
          _errorMessage = 'Could not save. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _page == 0 ? _buildPlanPage() : _buildAppPage(),
        ),
      ),
    );
  }

  Widget _buildPlanPage() {
    final canNext = _planRating >= 1 && _planRating <= 5 && !_savingPlan;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Score for the plan',
          style: WaypointTypography.titleMedium.copyWith(color: WaypointColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          'How was your trip with ${widget.plan.name}?',
          style: WaypointTypography.bodySmall?.copyWith(color: WaypointColors.textSecondary),
        ),
        const SizedBox(height: 20),
        _StarRating(
          value: _planRating,
          onChanged: (v) => setState(() => _planRating = v),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _planCommentController,
          decoration: const InputDecoration(
            hintText: 'Add a comment (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          onChanged: (_) => setState(() {}),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: WaypointTypography.bodySmall.copyWith(color: Colors.red),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _savingPlan ? null : () => Navigator.of(context).pop(),
              child: const Text('Skip'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: canNext ? _savePlanReviewAndGoToPage2 : null,
              child: _savingPlan
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Next'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAppPage() {
    final canSubmit = _appRating >= 1 && _appRating <= 5 && !_savingApp;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Score for the Waypoint app',
          style: WaypointTypography.titleMedium.copyWith(color: WaypointColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          'How did you like using Waypoint?',
          style: WaypointTypography.bodySmall?.copyWith(color: WaypointColors.textSecondary),
        ),
        const SizedBox(height: 20),
        _StarRating(
          value: _appRating,
          onChanged: (v) => setState(() => _appRating = v),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _appCommentController,
          decoration: const InputDecoration(
            hintText: 'Add a comment (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          onChanged: (_) => setState(() {}),
        ),
        if (_appRating >= 4 && _appCommentController.text.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _allowShowOnWebsite,
            onChanged: (v) => setState(() => _allowShowOnWebsite = v ?? false),
            title: Text(
              'May we show your review on our website?',
              style: WaypointTypography.bodySmall.copyWith(
                color: WaypointColors.textPrimary,
              ),
            ),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: WaypointTypography.bodySmall.copyWith(color: Colors.red),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _savingApp ? null : () => Navigator.of(context).pop(),
              child: const Text('Skip'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: canSubmit ? _submitAppReview : null,
              child: _savingApp
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Tappable 1–5 star row.
class _StarRating extends StatelessWidget {
  const _StarRating({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final star = i + 1;
        final selected = star <= value;
        return GestureDetector(
          onTap: () => onChanged(star),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              Icons.star,
              size: 40,
              color: selected ? WaypointColors.gold : WaypointColors.border,
            ),
          ),
        );
      }),
    );
  }
}
