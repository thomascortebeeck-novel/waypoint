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
import 'package:waypoint/services/trip_service.dart';
import 'package:waypoint/theme.dart';
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

  Trip? _trip;
  Plan? _plan;
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
      final plan = await _planService.getPlanById(trip.planId);
      if (mounted) {
        setState(() {
          _trip = trip;
          _plan = plan;
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
    Clipboard.setData(ClipboardData(text: _trip!.inviteCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Trip code copied'),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trip == null
              ? _buildError()
              : _buildContent(isOwner, currentUserId ?? '', primary),
      floatingActionButton: isOwner && _trip != null
          ? FloatingActionButton.extended(
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
          const SizedBox(height: 20),
          // Share options row
          _buildShareOptions(),
          const SizedBox(height: 28),
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
            'Invite Adventurers',
            style: context.textStyles.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Share this code with your group to start planning together.',
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

  Widget _buildShareOptions() {
    return Row(
      children: [
        Expanded(
          child: _ShareOptionTile(
            icon: Icons.link_rounded,
            label: 'Share Link',
            color: const Color(0xFF4A90A4),
            onTap: () {
              _copyShareLink();
              _shareLink();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ShareOptionTile(
            icon: Icons.qr_code_2_rounded,
            label: 'QR Code',
            color: const Color(0xFF7C3AED),
            onTap: _showQrCode,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ShareOptionTile(
            icon: Icons.email_outlined,
            label: 'Email',
            color: BrandColors.secondaryDark,
            onTap: _shareEmail,
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantsHeader() {
    return Row(
      children: [
        Text(
          'Participants',
          style: context.textStyles.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.colors.onSurface,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${_members.length}',
            style: context.textStyles.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
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
                            'Trip Leader',
                            style: context.textStyles.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          isMemberOwner ? 'Owner' : 'Member',
                          style: context.textStyles.labelSmall?.copyWith(
                            color: BrandColors.secondaryDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isOwner && !isSelf && !isMemberOwner)
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showMemberMenu(member),
                  tooltip: 'Options',
                ),
            ],
          ),
        );
      },
    );
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

  void _showMemberMenu(UserModel member) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
        ),
      ),
    );
  }

  Widget _buildInfoBox() {
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
              'Only the Trip Leader can remove members or change the trip code. '
              'New members need to use the invite link or code to join.',
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

class _ShareOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShareOptionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BrandingLightTokens.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: BrandingLightTokens.surfaceVariant,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
