import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:waypoint/models/check_in_model.dart';
import 'package:waypoint/services/check_in_service.dart';

/// Compact row: "Check in" button or "Checked in #N" for a waypoint on the current trip day.
class CheckInButton extends StatefulWidget {
  final String tripId;
  final int dayNum;
  final String waypointId;
  final String waypointName;
  final ll.LatLng? waypointLatLng;
  final String userId;
  final DateTime? tripStartDate;

  const CheckInButton({
    super.key,
    required this.tripId,
    required this.dayNum,
    required this.waypointId,
    required this.waypointName,
    this.waypointLatLng,
    required this.userId,
    required this.tripStartDate,
  });

  @override
  State<CheckInButton> createState() => _CheckInButtonState();
}

class _CheckInButtonState extends State<CheckInButton> {
  final CheckInService _checkInService = CheckInService();
  int? _optimisticRank;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    if (!CheckInService.isTodayTripDay(widget.tripStartDate, widget.dayNum)) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<CheckIn>>(
      stream: _checkInService.streamCheckInsForWaypoint(widget.tripId, widget.waypointId),
      builder: (context, snapshot) {
        final checkIns = snapshot.data ?? [];
        CheckIn? myCheckIn;
        for (final c in checkIns) {
          if (c.userId == widget.userId) {
            myCheckIn = c;
            break;
          }
        }
        final rank = _optimisticRank ?? (myCheckIn != null ? _rankOf(checkIns, widget.userId) : null);
        final checkedIn = rank != null && rank > 0;

        if (checkedIn) {
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Icon(Icons.check_circle, size: 18, color: Colors.green.shade700),
                const SizedBox(width: 6),
                Text(
                  "You're #$rank to check in",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: OutlinedButton.icon(
            onPressed: _loading ? null : () => _performCheckIn(context),
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.location_on, size: 18),
            label: Text(_loading ? 'Checking in…' : 'Check in'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(0, 36),
            ),
          ),
        );
      },
    );
  }

  int _rankOf(List<CheckIn> checkIns, String userId) {
    int r = 1;
    for (final c in checkIns) {
      if (c.userId == userId) return r;
      r++;
    }
    return 0;
  }

  Future<void> _performCheckIn(BuildContext context) async {
    setState(() => _loading = true);
    try {
      // Try with location first if we have coordinates
      var result = await _checkInService.checkIn(
        tripId: widget.tripId,
        dayNum: widget.dayNum,
        waypointId: widget.waypointId,
        userId: widget.userId,
        tripStartDate: widget.tripStartDate,
        waypointLatLng: widget.waypointLatLng,
        useLocation: widget.waypointLatLng != null,
        note: null,
      );

      if (!result.success && widget.waypointLatLng != null) {
        final useManual = await _showManualFallbackDialog(context);
        if (useManual == true && mounted) {
          result = await _checkInService.checkIn(
            tripId: widget.tripId,
            dayNum: widget.dayNum,
            waypointId: widget.waypointId,
            userId: widget.userId,
            tripStartDate: widget.tripStartDate,
            waypointLatLng: widget.waypointLatLng,
            useLocation: false,
            note: null,
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        if (result.success) _optimisticRank = result.rank;
      });

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("You're #${result.rank} to check in at ${widget.waypointName}"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (!result.success && _loading == false) {
        final msg = result.distanceM != null
            ? 'You’re ${result.distanceM!.toStringAsFixed(0)} m away. Check in manually?'
            : 'Check-in failed. Try again or check in manually.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Check-in failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<bool?> _showManualFallbackDialog(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Check in manually?'),
        content: const Text(
          "You're not within range of this waypoint. Do you want to check in manually anyway?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Check in manually'),
          ),
        ],
      ),
    );
  }
}
