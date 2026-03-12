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
import 'package:waypoint/theme.dart';
import 'package:waypoint/core/constants/level_names.dart';
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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
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
                style: context.textStyles.bodyLarge?.copyWith(
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Creator Profile'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header Section — centered (image, name, tag, description)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
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
                            style: context.textStyles.headlineMedium?.copyWith(
                              color: WaypointColors.textSecondary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  // Name
                  Text(
                    ([_creator!.firstName, _creator!.lastName]
                                .where((e) => e != null && e.isNotEmpty)
                                .join(' ')
                                .trim()
                                .isNotEmpty
                            ? [_creator!.firstName, _creator!.lastName]
                                .where((e) => e != null && e.isNotEmpty)
                                .join(' ')
                                .trim()
                            : _creator!.displayName),
                    style: context.textStyles.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  // Role chips (ADMIN / CREATOR)
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (_creator!.isAdmin)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: context.colors.primaryContainer,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            'ADMIN',
                            style: context.textStyles.labelSmall?.copyWith(
                              color: context.colors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (_creator!.isInfluencer)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: context.colors.primaryContainer,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            'CREATOR',
                            style: context.textStyles.labelSmall?.copyWith(
                              color: context.colors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: WaypointColors.textSecondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          getCreatorLevelName(_creator!.totalPlansSold),
                          style: context.textStyles.labelSmall?.copyWith(
                            color: WaypointColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Location
                  if (_creator!.location != null && _creator!.location!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 16, color: WaypointColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          _creator!.location!,
                          style: context.textStyles.bodyMedium?.copyWith(
                            color: WaypointColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Bio
                  if (_creator!.shortBio != null && _creator!.shortBio!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _creator!.shortBio!,
                      style: context.textStyles.bodyMedium?.copyWith(
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
            // Stats — centered
            if (_stats != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Center(child: CreatorStatsWidget(stats: _stats!)),
              ),
              const SizedBox(height: 24),
            ],
            // Adventures Section (horizontal list; cards clipped to prevent overflow)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'Created plans'),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 420,
                    child: _plans.isEmpty
                        ? Center(
                            child: Text(
                              'No adventures yet',
                              style: context.textStyles.bodyMedium?.copyWith(
                                color: WaypointColors.textSecondary,
                              ),
                            ),
                          )
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.zero,
                            clipBehavior: Clip.hardEdge,
                            itemCount: _plans.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 24),
                            itemBuilder: (context, index) {
                              final plan = _plans[index];
                              return SizedBox(
                                width: 280,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: AdventureCard(
                                    key: ValueKey(plan.id),
                                    plan: plan,
                                    variant: AdventureCardVariant.standard,
                                    onTap: () => context.push('/details/${plan.id}'),
                                  ),
                                ),
                              );
                            },
                          ),
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
              style: context.textStyles.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

