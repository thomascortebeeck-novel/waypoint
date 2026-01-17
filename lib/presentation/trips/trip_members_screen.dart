import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/models/trip_model.dart';
import 'package:waypoint/models/user_model.dart';
import 'package:waypoint/services/invite_service.dart';
import 'package:waypoint/services/trip_service.dart';
import 'package:waypoint/theme.dart';
import 'package:waypoint/presentation/trips/invite_share_sheet.dart';

/// Screen for managing trip members
class TripMembersScreen extends StatefulWidget {
  final String tripId;
  
  const TripMembersScreen({super.key, required this.tripId});

  @override
  State<TripMembersScreen> createState() => _TripMembersScreenState();
}

class _TripMembersScreenState extends State<TripMembersScreen> {
  final TripService _tripService = TripService();
  final InviteService _inviteService = InviteService();
  
  Trip? _trip;
  List<UserModel> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final trip = await _tripService.getTripById(widget.tripId);
    if (trip != null) {
      final members = await _inviteService.getMembersDetails(trip.id);
      if (mounted) {
        setState(() {
          _trip = trip;
          _members = members;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeMember(UserModel member) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || _trip == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Remove ${member.displayName} from this trip?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _tripService.removeMemberByOwner(
        tripId: _trip!.id,
        memberUserId: member.id,
        requesterId: currentUserId,
      );
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${member.displayName} removed from trip')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove member: $e')),
        );
      }
    }
  }

  Future<void> _leaveTrip() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || _trip == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Trip'),
        content: const Text('Are you sure you want to leave this trip?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _tripService.leaveTrip(tripId: _trip!.id, userId: currentUserId);
      if (mounted) {
        context.go('/mytrips');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have left the trip')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to leave trip: $e')),
        );
      }
    }
  }

  void _showInviteSheet() {
    if (_trip == null) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InviteShareSheet(trip: _trip!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = _trip?.isOwner(currentUserId ?? '') ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Members'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _showInviteSheet,
            tooltip: 'Invite Members',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trip == null
              ? _buildError()
              : _buildMembersList(isOwner, currentUserId ?? ''),
      bottomNavigationBar: !isOwner && _trip != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton.icon(
                  onPressed: _leaveTrip,
                  icon: const Icon(Icons.exit_to_app, color: Colors.red),
                  label: const Text(
                    'Leave Trip',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 16),
          const Text('Failed to load trip'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.pop(),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersList(bool isOwner, String currentUserId) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _members.length,
      itemBuilder: (context, index) {
        final member = _members[index];
        final isMemberOwner = member.id == _trip!.ownerId;
        final isSelf = member.id == currentUserId;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: CircleAvatar(
            radius: 24,
            backgroundImage: member.photoUrl != null
                ? CachedNetworkImageProvider(member.photoUrl!)
                : null,
            child: member.photoUrl == null
                ? Text(
                    member.displayName[0].toUpperCase(),
                    style: const TextStyle(fontSize: 18),
                  )
                : null,
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  member.displayName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSelf) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'You',
                    style: context.textStyles.labelSmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(member.email),
          trailing: isMemberOwner
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star,
                        size: 16,
                        color: context.colors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Owner',
                        style: context.textStyles.labelSmall?.copyWith(
                          color: context.colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              : isOwner && !isSelf
                  ? IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                      onPressed: () => _removeMember(member),
                      tooltip: 'Remove member',
                    )
                  : null,
        );
      },
    );
  }
}
