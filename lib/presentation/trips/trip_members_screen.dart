import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/trip_model.dart';
import 'package:waypoint/models/user_model.dart';
import 'package:waypoint/services/invite_service.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/services/trip_analytics_service.dart';
import 'package:waypoint/services/trip_insight_service.dart';
import 'package:waypoint/services/trip_service.dart';
import 'package:waypoint/services/waypoint_vote_service.dart';
import 'package:waypoint/theme.dart';
import 'package:waypoint/core/constants/app_terms.dart';
import 'package:waypoint/presentation/trips/invite_share_sheet.dart';

/// Screen for managing trip members and inviting adventurers.
/// Uses deep links (/join/:inviteCode) and existing invite validation
/// (e.g. plan ownership) via [InviteService] and [JoinTripScreen].
class TripMembersScreen extends StatefulWidget {
  final String tripId;

  const TripMembersScreen({super.key, required this.tripId});

  @override
  State<TripMembersScreen> createState() => _TripMembersScreenState();
}

class _TripMembersScreenState extends State<TripMembersScreen> {
  final TripService _tripService = TripService();
  final InviteService _inviteService = InviteService();
  final PlanService _planService = PlanService();
  final WaypointVoteService _voteService = WaypointVoteService();

  Trip? _trip;
  Plan? _plan;
  List<UserModel> _members = [];
  bool _isLoading = true;
  int? _footprinterPoints;
  int? _getDirectionsCount;
  Map<String, int> _insightCountByUserId = const {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final trip = await _tripService.getTripById(widget.tripId);
    if (trip != null) {
      final members = await _inviteService.getMembersDetails(trip.id);
      final plan = await _planService.getPlanById(trip.planId);
      final analytics = TripAnalyticsService();
      final footprinterPoints = await analytics.getFootprinterPoints(trip.id);
      final getDirectionsCount = await analytics.getGetDirectionsCount(trip.id);
      final insights = await TripInsightService().getTripInsights(trip.id);
      final insightCountByUserId = <String, int>{};
      for (final i in insights) {
        if (i.createdBy != null && i.createdBy!.isNotEmpty) {
          insightCountByUserId[i.createdBy!] = (insightCountByUserId[i.createdBy!] ?? 0) + 1;
        }
      }
      if (mounted) {
        setState(() {
          _trip = trip;
          _plan = plan;
          _members = members;
          _footprinterPoints = footprinterPoints;
          _getDirectionsCount = getDirectionsCount;
          _insightCountByUserId = insightCountByUserId;
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
              backgroundColor: Theme.of(context).colorScheme.error,
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
              backgroundColor: Theme.of(context).colorScheme.error,
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

  void _copyInviteCode() {
    if (_trip == null) return;
    Clipboard.setData(ClipboardData(text: _trip!.shareLink));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite link copied'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _copyShareLink() {
    if (_trip == null) return;
    Clipboard.setData(ClipboardData(text: _trip!.shareLink));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite link copied'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareLink() {
    if (_trip == null) return;
    final tripName = _trip!.title ?? _plan?.name ?? 'Trip';
    Share.share(
      'Join me on "$tripName"!\n\n${_trip!.shareLink}',
      subject: 'Join my trip on Waypoint',
    );
  }

  void _shareEmail() {
    if (_trip == null) return;
    final tripName = _trip!.title ?? _plan?.name ?? 'Trip';
    Share.share(
      'Join me on "$tripName"!\n\nUse this link to join: ${_trip!.shareLink}\n\nOr enter the trip code: ${_trip!.inviteCode}',
      subject: 'Invitation: $tripName',
    );
  }

  void _showQrCode() {
    if (_trip == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InviteShareSheet(trip: _trip!),
    );
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
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: BrandingLightTokens.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/trip/${widget.tripId}'),
          tooltip: 'Back',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trip Members',
              style: context.textStyles.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.colors.onSurface,
              ),
            ),
            if (_trip != null) ...[
              const SizedBox(height: 2),
              Text(
                _trip!.title ?? _plan?.name ?? 'Trip',
                style: context.textStyles.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        titleSpacing: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trip == null
              ? _buildError()
              : _buildContent(isOwner, currentUserId ?? '', primary),
      floatingActionButton: isOwner && _trip != null
          ? FloatingActionButton.extended(
              heroTag: 'trip_members_invite_fab',
              onPressed: _showInviteSheet,
              backgroundColor: primary,
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text(
                'Add Member',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
      bottomNavigationBar: !isOwner && _trip != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton.icon(
                  onPressed: _leaveTrip,
                  icon: Icon(Icons.exit_to_app, color: context.colors.error),
                  label: Text(
                    'Leave Trip',
                    style: TextStyle(
                      color: context.colors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: context.colors.error),
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
          Icon(Icons.error_outline, size: 48, color: context.colors.error),
          const SizedBox(height: 16),
          Text(
            'Failed to load trip',
            style: context.textStyles.titleMedium,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.go('/mytrips'),
            child: const Text('Go to My Trips'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isOwner, String currentUserId, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Invite Adventurers card (brand green)
          _buildInviteCard(primary),
          const SizedBox(height: 16),
          // Role dashboard entry (if user has a special role) or empty state
          _buildRoleDashboardEntry(currentUserId),
          const SizedBox(height: 20),
          if (isOwner) ...[
            _buildWaypointChoiceSection(),
            const SizedBox(height: 20),
          ],
          // Participants section
          _buildParticipantsHeader(),
          const SizedBox(height: 12),
          _buildParticipantsList(isOwner, currentUserId),
          const SizedBox(height: 16),
          _buildInfoBox(),
        ],
      ),
    );
  }

  Widget _buildRoleDashboardEntry(String currentUserId) {
    if (_trip == null) return const SizedBox.shrink();
    final hasSpecial = _trip!.hasSpecialRole(currentUserId);
    if (hasSpecial) {
      final role = _trip!.memberRoles?[currentUserId] ?? kTripRoleMember;
      final roleLabel = tripRoleDisplayLabel(role);
      return Material(
        color: context.colors.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => context.push('/trip/${widget.tripId}/role'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.dashboard_outlined, color: context.colors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'View my role',
                        style: context.textStyles.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.colors.onSurface,
                        ),
                      ),
                      Text(
                        '$roleLabel dashboard',
                        style: context.textStyles.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: context.colors.onSurfaceVariant),
              ],
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        'You don\'t have a role yet — the organizer can assign one.',
        style: context.textStyles.bodySmall?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildInviteCard(Color primary) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Invite your ${kCrewLabel.toLowerCase()}',
            style: context.textStyles.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Share this code with your $kCrewLabel to start planning together.',
            style: context.textStyles.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TRIP CODE',
                        style: context.textStyles.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _trip!.inviteCode,
                        style: context.textStyles.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: _copyInviteCode,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.copy_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'COPY',
                            style: context.textStyles.labelMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaypointChoiceSection() {
    final isVote = _trip?.isWaypointVoteMode ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Waypoint choices',
          style: context.textStyles.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.colors.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'owner', label: Text('Owner decides'), icon: Icon(Icons.person_outline, size: 18)),
            ButtonSegment(value: 'vote', label: Text('Members vote'), icon: Icon(Icons.how_to_vote_outlined, size: 18)),
          ],
          selected: {isVote ? 'vote' : 'owner'},
          onSelectionChanged: (Set<String> selected) async {
            final mode = selected.first;
            if (_trip == null) return;
            final previousMode = _trip!.waypointDecisionMode;
            setState(() {
              _trip = _trip!.copyWith(waypointDecisionMode: mode);
            });
            try {
              if (mode == 'vote') {
                final hasState = await _voteService.hasVoteState(_trip!.id);
                if (!hasState && _plan != null) {
                  final version = _plan!.versions.firstWhere(
                  (v) => v.id == _trip!.versionId,
                  orElse: () => _plan!.versions.first,
                );
                  await _voteService.createVoteState(tripId: _trip!.id, version: version);
                }
              }
              await _tripService.updateWaypointDecisionMode(tripId: _trip!.id, mode: mode);
              if (mounted) await _loadData();
            } catch (e) {
              if (mounted) {
                setState(() {
                  _trip = _trip?.copyWith(waypointDecisionMode: previousMode);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not update: $e'), behavior: SnackBarBehavior.floating),
                );
              }
            }
          },
        ),
      ],
    );
  }

  Widget _buildParticipantsHeader() {
    return Row(
      children: [
        Text(
          '$kCrewLabel (${_members.length})',
          style: context.textStyles.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.colors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantsList(bool isOwner, String currentUserId) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _members.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final member = _members[index];
        final isMemberOwner = member.id == _trip!.ownerId;
        final isSelf = member.id == currentUserId;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: BrandingLightTokens.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: BrandingLightTokens.surfaceVariant,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: _avatarColor(member.id),
                backgroundImage: member.photoUrl != null
                    ? CachedNetworkImageProvider(member.photoUrl!)
                    : null,
                child: member.photoUrl == null
                    ? Text(
                        _initials(member.displayName),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            member.displayName,
                            style: context.textStyles.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: context.colors.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelf) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
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
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (isMemberOwner) ...[
                          Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Organizer',
                            style: context.textStyles.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          isMemberOwner
                              ? tripRoleDisplayLabel(kTripRoleOwner)
                              : tripRoleDisplayLabel(
                                  _trip?.memberRoles?[member.id] ?? kTripRoleMember,
                                ),
                          style: context.textStyles.labelSmall?.copyWith(
                            color: BrandColors.secondaryDark,
                          ),
                        ),
                      ],
                    ),
                    if (_memberRoleStatLine(member) != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _memberRoleStatLine(member)!,
                        style: context.textStyles.labelSmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isOwner)
                FilledButton(
                  onPressed: () => _showMemberMenu(member),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Add role'),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Returns a short stat line for the member card when the member has a role with a stat (e.g. Footprinter, Navigator, Insider), or null.
  String? _memberRoleStatLine(UserModel member) {
    final role = _trip?.memberRoles?[member.id] ?? kTripRoleMember;
    if (role == kTripRoleFootprinter && _footprinterPoints != null) {
      return 'Green points: $_footprinterPoints';
    }
    if (role == kTripRoleNavigator && _getDirectionsCount != null) {
      return 'Get directions: $_getDirectionsCount';
    }
    if (role == kTripRoleInsider) {
      final count = _insightCountByUserId[member.id] ?? 0;
      return 'Insights: $count';
    }
    return null;
  }

  Color _avatarColor(String userId) {
    final index = userId.hashCode % 4;
    const colors = [
      Color(0xFF5D3A1A),
      Color(0xFF4A90A4),
      Color(0xFFE6A82E),
      Color(0xFF2F7D32),
    ];
    return colors[index.abs() % colors.length];
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
    }
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  /// True if [role] is already assigned to another member (not [excludeMemberId]).
  bool _isRoleAssignedToOther(String role, String excludeMemberId) {
    final roles = _trip?.memberRoles;
    if (roles == null) return false;
    return roles.entries.any((e) => e.key != excludeMemberId && e.value == role);
  }

  void _showMemberMenu(UserModel member) {
    final currentRole = _trip?.memberRoles?[member.id] ?? kTripRoleMember;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...kTripRoleOptions.map((role) {
                  final isAssignedToOther = _isRoleAssignedToOther(role, member.id);
                  return ListTile(
                  leading: Icon(
                    role == currentRole ? Icons.check_circle : Icons.circle_outlined,
                    size: 22,
                    color: role == currentRole
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(tripRoleDisplayLabel(role)),
                  subtitle: Text(
                    tripRoleDescription(role),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  enabled: !isAssignedToOther,
                  onTap: isAssignedToOther ? null : () async {
                    Navigator.pop(context);
                    final previousRoles = Map<String, String>.from(_trip?.memberRoles ?? {});
                    try {
                      await _tripService.updateMemberRole(
                        tripId: widget.tripId,
                        memberId: member.id,
                        role: role,
                      );
                      if (mounted) {
                        final updated = Map<String, String>.from(previousRoles);
                        if (role.isEmpty || role == kTripRoleMember) {
                          updated.remove(member.id);
                        } else {
                          updated[member.id] = role;
                        }
                        setState(() {
                          _trip = _trip?.copyWith(memberRoles: updated);
                        });
                        _loadData();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not update role: $e')),
                        );
                      }
                    }
                  },
                );
                }),
            if (member.id != FirebaseAuth.instance.currentUser?.uid) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.person_remove_outlined),
                title: const Text('Remove from trip'),
                textColor: Theme.of(context).colorScheme.error,
                onTap: () {
                  Navigator.pop(context);
                  _removeMember(member);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBox() {
    final hasAnyAssignedRole = _trip != null &&
        _members.any((m) => m.id != _trip!.ownerId && _trip!.hasSpecialRole(m.id));
    final message = hasAnyAssignedRole
        ? 'Only the Organizer can remove members or change the trip code.'
        : 'Add roles so your crew can contribute.';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BrandingLightTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: BrandingLightTokens.surfaceVariant,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: context.colors.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: context.textStyles.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
