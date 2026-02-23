import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:waypoint/models/user_model.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/creator_stats_model.dart';
import 'package:waypoint/services/user_service.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/services/follow_service.dart';
import 'package:waypoint/components/creator/creator_stats_widget.dart';
import 'package:waypoint/components/creator/follow_button.dart';
import 'package:waypoint/presentation/widgets/adventure_card.dart';
import 'package:waypoint/theme/waypoint_colors.dart';
import 'package:waypoint/theme/waypoint_typography.dart';
import 'package:waypoint/theme/waypoint_spacing.dart';

/// Creator profile screen displaying creator info, stats, and adventures
class CreatorProfileScreen extends StatefulWidget {
  final String creatorId;

  const CreatorProfileScreen({
    super.key,
    required this.creatorId,
  });

  @override
  State<CreatorProfileScreen> createState() => _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends State<CreatorProfileScreen> {
  final UserService _userService = UserService();
  final PlanService _planService = PlanService();
  final FollowService _followService = FollowService();

  UserModel? _creator;
  List<Plan> _plans = [];
  CreatorStats? _stats;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCreatorData();
  }

  Future<void> _loadCreatorData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load creator user
      final creator = await _userService.getUserById(widget.creatorId);
      if (creator == null) {
        setState(() {
          _errorMessage = 'Creator not found';
          _isLoading = false;
        });
        return;
      }

      // Load creator's plans
      final plans = await _planService.getPlansByCreator(widget.creatorId);

      // Calculate stats
      final stats = CreatorStats(
        adventuresCreated: plans.length,
        followersCount: creator.followerIds.length,
        totalDistanceKm: plans.fold<double>(
          0.0,
          (sum, plan) => sum + plan.totalDistanceKm,
        ),
      );

      if (mounted) {
        setState(() {
          _creator = creator;
          _plans = plans;
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load creator: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Creator Profile'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null || _creator == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Creator Profile'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: WaypointColors.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'Creator not found',
                style: WaypointTypography.bodyLarge?.copyWith(
                  color: WaypointColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Creator Profile'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: WaypointColors.borderLight,
                    backgroundImage: _creator!.photoUrl != null
                        ? NetworkImage(_creator!.photoUrl!)
                        : null,
                    child: _creator!.photoUrl == null
                        ? Text(
                            _creator!.displayName.isNotEmpty
                                ? _creator!.displayName[0].toUpperCase()
                                : '?',
                            style: WaypointTypography.headlineMedium?.copyWith(
                              color: WaypointColors.textSecondary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  // Name
                  Text(
                    _creator!.displayName,
                    style: WaypointTypography.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  // Bio
                  if (_creator!.shortBio != null && _creator!.shortBio!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _creator!.shortBio!,
                      style: WaypointTypography.bodyMedium?.copyWith(
                        color: WaypointColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Follow Button
                  FollowButton(
                    creatorId: widget.creatorId,
                    currentUserId: currentUserId,
                    followService: _followService,
                  ),
                  // Social Links
                  if (_creator!.socialLinks != null &&
                      _creator!.socialLinks!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      alignment: WrapAlignment.center,
                      children: _creator!.socialLinks!.entries.map((entry) {
                        return _SocialLink(
                          platform: entry.key,
                          url: entry.value,
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            // Stats
            if (_stats != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: CreatorStatsWidget(stats: _stats!),
              ),
              const SizedBox(height: 24),
            ],
            // Adventures Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Adventures',
                    style: WaypointTypography.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_plans.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'No adventures yet',
                          style: WaypointTypography.bodyMedium?.copyWith(
                            color: WaypointColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: _plans.length,
                      itemBuilder: (context, index) {
                        final plan = _plans[index];
                        return AdventureCard(
                          plan: plan,
                          onTap: () {
                            context.push('/details/${plan.id}');
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SocialLink extends StatelessWidget {
  final String platform;
  final String url;

  const _SocialLink({
    required this.platform,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (platform.toLowerCase()) {
      case 'instagram':
        icon = Icons.camera_alt;
        break;
      case 'youtube':
        icon = Icons.play_circle_outline;
        break;
      case 'blog':
      case 'website':
        icon = Icons.language;
        break;
      default:
        icon = Icons.link;
    }

    return InkWell(
      onTap: () {
        // TODO: Launch URL
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: WaypointColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(
              platform,
              style: WaypointTypography.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

