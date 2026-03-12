import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/models/trip_model.dart';
import 'package:waypoint/models/waypoint_vote_model.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/services/trip_service.dart';
import 'package:waypoint/services/waypoint_vote_service.dart';
import 'package:waypoint/theme.dart';

/// Screen for members to vote on waypoint options per slot. Owner can close voting.
class WaypointVoteScreen extends StatefulWidget {
  final String tripId;

  const WaypointVoteScreen({super.key, required this.tripId});

  @override
  State<WaypointVoteScreen> createState() => _WaypointVoteScreenState();
}

class _WaypointVoteScreenState extends State<WaypointVoteScreen> {
  final WaypointVoteService _voteService = WaypointVoteService();
  final TripService _tripService = TripService();
  final PlanService _planService = PlanService();

  Trip? _trip;
  bool _loading = true;
  String? _userId;
  final Map<String, String> _pendingVotes = {};

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    final trip = await _tripService.getTripById(widget.tripId);
    if (mounted) {
      setState(() {
        _trip = trip;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _trip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vote on waypoints')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isOwner = _trip!.isOwner(_userId ?? '');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Vote on waypoints'),
      ),
      body: StreamBuilder<List<WaypointVoteDoc>>(
        stream: _voteService.streamAllVoteDocs(widget.tripId),
        builder: (context, snapshot) {
          final slots = snapshot.data ?? [];
          if (slots.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No vote slots yet. Owner can enable "Members vote" in trip settings.',
                  style: context.textStyles.bodyLarge?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final openSlots = slots.where((s) => !s.isClosed).toList();
          final closedSlots = slots.where((s) => s.isClosed).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isOwner && openSlots.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: FilledButton.icon(
                      onPressed: _closeVoting,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Close voting'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ...openSlots.map((doc) => _buildSlotCard(doc, isOwner)),
                if (closedSlots.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Closed',
                    style: context.textStyles.titleSmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...closedSlots.map((doc) => _buildSlotCard(doc, isOwner)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlotCard(WaypointVoteDoc doc, bool isOwner) {
    final slotLabel = _slotDisplayName(doc.slotKey);
    final myVote = _pendingVotes[doc.slotKey] ?? doc.votes[_userId];
    final isClosed = doc.isClosed;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isClosed ? Icons.check_circle : Icons.how_to_vote_outlined,
                  size: 20,
                  color: isClosed ? context.colors.primary : context.colors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    slotLabel,
                    style: context.textStyles.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (doc.options.isEmpty)
              Text(
                'No options',
                style: context.textStyles.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: doc.options.map((opt) {
                  final selected = (isClosed ? doc.resolvedOptionId == opt.id : myVote == opt.id);
                  return ChoiceChip(
                    label: Text(opt.label),
                    selected: selected,
                    onSelected: isClosed || isOwner
                        ? null
                        : (sel) => _submitVote(doc.slotKey, opt.id, sel),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  String _slotDisplayName(String slotKey) {
    final parts = slotKey.split('_');
    if (parts.length < 3) return slotKey;
    final day = parts[1];
    final type = parts.length > 3 ? parts.sublist(2).join(' ') : parts[2];
    return 'Day $day · ${type.replaceAll('_', ' ')}';
  }

  Future<void> _submitVote(String slotKey, String optionId, bool selected) async {
    if (_userId == null || !selected) return;
    setState(() => _pendingVotes[slotKey] = optionId);
    try {
      await _voteService.submitVote(
        tripId: widget.tripId,
        slotKey: slotKey,
        userId: _userId!,
        optionId: optionId,
      );
      if (mounted) setState(() => _pendingVotes.remove(slotKey));
    } catch (e) {
      if (mounted) {
        setState(() => _pendingVotes.remove(slotKey));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vote failed: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _closeVoting() async {
    if (_trip == null) return;
    final plan = await _planService.getPlanById(_trip!.planId);
    if (plan == null) return;
    final version = plan.versions.firstWhere(
      (v) => v.id == _trip!.versionId,
      orElse: () => plan.versions.first,
    );
    try {
      await _voteService.closeVoting(
        tripId: widget.tripId,
        plan: plan,
        version: version,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voting closed. Selections updated.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not close: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }
}
