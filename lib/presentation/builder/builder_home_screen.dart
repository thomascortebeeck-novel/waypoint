import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:waypoint/auth/firebase_auth_manager.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/user_model.dart';
import 'package:waypoint/presentation/widgets/adventure_card.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/services/user_service.dart';
import 'package:waypoint/components/waypoint/waypoint_shared_components.dart';
import 'package:waypoint/nav.dart' show kDesktopNavHeight;
import 'package:waypoint/theme.dart';

class BuilderHomeScreen extends StatefulWidget {
  const BuilderHomeScreen({super.key});

  @override
  State<BuilderHomeScreen> createState() => _BuilderHomeScreenState();
}

class _BuilderHomeScreenState extends State<BuilderHomeScreen> {
  final _auth = FirebaseAuthManager();
  final _plans = PlanService();
  final _users = UserService();
  String? _deletingPlanId;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    return Scaffold(
      body: StreamBuilder(
        stream: _auth.authStateChanges,
        builder: (context, authSnapshot) {
          // Wait for auth state to load
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return CustomScrollView(
              slivers: [
                if (isDesktop) SliverToBoxAdapter(child: SizedBox(height: kDesktopNavHeight)),
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 32 : 16,
                    vertical: 8,
                  ),
                  sliver: SliverToBoxAdapter(child: _LoadingState()),
                ),
              ],
            );
          }
          
          final uid = authSnapshot.data?.uid;
          if (uid == null) {
            return CustomScrollView(
              slivers: [
                if (isDesktop) SliverToBoxAdapter(child: SizedBox(height: kDesktopNavHeight)),
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 32 : 16,
                    vertical: 8,
                  ),
                  sliver: const SliverToBoxAdapter(child: _SignedOutState()),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          }
          return StreamBuilder(
            stream: _users.streamUser(uid),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return CustomScrollView(
                  slivers: [
                    if (isDesktop) SliverToBoxAdapter(child: SizedBox(height: kDesktopNavHeight)),
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 32 : 16,
                        vertical: 8,
                      ),
                      sliver: SliverToBoxAdapter(child: _LoadingState()),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                );
              }
              final user = userSnapshot.data;
              final canAccessBuilder = (user?.isInfluencer ?? false) || (user?.isAdmin ?? false);
              final isAdmin = user?.isAdmin ?? false;
              return CustomScrollView(
                slivers: [
                  if (isDesktop) SliverToBoxAdapter(child: SizedBox(height: kDesktopNavHeight)),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 32 : 16,
                      vertical: 8,
                    ),
                    sliver: canAccessBuilder
                        ? _buildPlansContent(context, uid!, user, isDesktop, isAdmin)
                        : const SliverToBoxAdapter(child: _RestrictedInfluencerState()),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: StreamBuilder(
        stream: _auth.authStateChanges,
        builder: (context, authSnapshot) {
          final uid = authSnapshot.data?.uid;
          if (uid == null) return _buildFAB(context, null);
          return StreamBuilder(
            stream: _users.streamUser(uid),
            builder: (context, userSnapshot) {
              final user = userSnapshot.data;
              final canAccessBuilder = (user?.isInfluencer ?? false) || (user?.isAdmin ?? false);
              return canAccessBuilder ? _buildFAB(context, uid) : const SizedBox.shrink();
            },
          );
        },
      ),
    );
  }

  Widget _buildFAB(BuildContext context, String? uid) {
    return WaypointFAB(
      icon: Icons.add,
      label: 'New Adventure',
      onPressed: uid == null ? () => context.go('/profile') : () => _createNewDraft(context),
    );
  }

  Widget _buildPlansContent(BuildContext context, String uid, UserModel? user, bool isDesktop, bool isAdmin) {
    return StreamBuilder<List<Plan>>(
      stream: isAdmin ? _plans.streamAllPlansForAdmin() : _plans.streamPlansByCreator(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverToBoxAdapter(
            child: _LoadingState(),
          );
        }
        final plans = snapshot.data ?? [];
        final filteredPlans = _deletingPlanId != null
            ? plans.where((plan) => plan.id != _deletingPlanId).toList()
            : plans;
        if (filteredPlans.isEmpty) {
          return SliverToBoxAdapter(child: _EmptyBuilderState());
        }
        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: _buildStatsAndPayoutCTA(
                plansBuilt: filteredPlans.length,
                plansSold: filteredPlans.fold<int>(0, (sum, p) => sum + p.salesCount),
                user: user,
              ),
            ),
            SliverToBoxAdapter(child: const SizedBox(height: 16)),
            _buildPlansGrid(context, filteredPlans, isDesktop),
          ],
        );
      },
    );
  }

  Widget _buildStatsAndPayoutCTA({
    required int plansBuilt,
    required int plansSold,
    required UserModel? user,
  }) {
    final isInfluencer = user?.isInfluencer ?? false;
    final chargesEnabled = user?.chargesEnabled == true;
    final showPayoutCTA = isInfluencer && !chargesEnabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _StatChip(
              label: 'Plans built',
              value: plansBuilt.toString(),
            ),
            const SizedBox(width: 16),
            _StatChip(
              label: 'Plans sold',
              value: plansSold.toString(),
            ),
          ],
        ),
        if (showPayoutCTA) ...[
          const SizedBox(height: 16),
          _PayoutCTA(onTap: _openConnectOnboarding),
        ],
      ],
    );
  }

  Future<void> _openConnectOnboarding() async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final result = await functions.httpsCallable('createConnectAccountLink').call<Map<Object?, Object?>>({});
      final url = result.data?['url'] as String?;
      if (url != null && url.isNotEmpty && mounted) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      debugPrint('Connect onboarding error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPlansGrid(BuildContext context, List<Plan> plans, bool isDesktop) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final crossAxisCount = width > 1200 ? 4 : (width > 900 ? 3 : (width > 600 ? 2 : 1));
        final aspectRatio = crossAxisCount == 1 ? 16 / 12 : 4 / 5;

        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: aspectRatio,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final plan = plans[index];
              return AdventureCard(
                plan: plan,
                variant: AdventureCardVariant.builder,
                onTap: () => context.go('/builder/${plan.id}'),
                onDelete: () => _confirmDelete(context, plan),
                isDeleting: _deletingPlanId == plan.id,
              );
            },
            childCount: plans.length,
          ),
        );
      },
    );
  }


  Future<void> _createNewDraft(BuildContext context) async {
    final uid = _auth.currentUserId;
    if (uid == null) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: context.colors.primary),
              const SizedBox(height: 16),
              Text(
                'Creating adventure...',
                style: context.textStyles.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final user = await _users.getUserById(uid);
      final now = DateTime.now();

      final draftPlan = Plan(
        id: '',
        name: 'Untitled Adventure',
        description: '',
        heroImageUrl: 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800',
        location: '',
        basePrice: 0,
        creatorId: uid,
        creatorName: user?.displayName ?? 'Unknown',
        versions: [],
        isPublished: false,
        createdAt: now,
        updatedAt: now,
      );

      final planId = await _plans.createPlan(draftPlan);
      await _users.addCreatedPlan(uid, planId);

      if (!mounted) return;

      // Close the dialog first
      Navigator.of(context, rootNavigator: true).pop();
      
      // Use SchedulerBinding to ensure dialog is dismissed before navigating
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Navigate to the builder screen
        context.go('/builder/$planId');
      });
    } catch (e) {
      debugPrint('Failed to create draft: $e');
      if (!mounted) return;

      // Close the dialog on error
      Navigator.of(context, rootNavigator: true).pop();
      
      // Use SchedulerBinding to ensure dialog is dismissed before showing snackbar
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to create draft. Try again.'),
            backgroundColor: context.colors.error,
          ),
        );
      });
    }
  }

  Future<void> _confirmDelete(BuildContext context, Plan plan) async {
    if (_deletingPlanId != null) return;
    final uid = _auth.currentUserId;
    if (uid == null) return;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
        return Padding(
          padding: AppSpacing.paddingLg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: Colors.red.shade400,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delete Adventure',
                          style: context.textStyles.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          plan.name,
                          style: context.textStyles.bodyMedium?.copyWith(
                            color: context.colors.onSurface.withValues(alpha: 0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'This will permanently remove this adventure for all participants. This action cannot be undone.',
                style: context.textStyles.bodyMedium?.copyWith(
                  color: context.colors.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade400,
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (confirmed == true) {
      // Optimistically update UI immediately
      setState(() => _deletingPlanId = plan.id);
      try {
        await _plans.deletePlan(plan.id);
        await _users.removeCreatedPlan(uid, plan.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Adventure deleted'),
            backgroundColor: context.colors.primary,
          ),
        );
      } catch (e) {
        debugPrint('Delete failed: $e');
        if (!mounted) return;
        // Revert optimistic update on error
        setState(() => _deletingPlanId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to delete. Try again.'),
            backgroundColor: context.colors.error,
          ),
        );
      } finally {
        if (mounted) setState(() => _deletingPlanId = null);
      }
    }
  }
}

class _SignedOutState extends StatelessWidget {
  const _SignedOutState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.colors.primaryContainer.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_outline,
                size: 48,
                color: context.colors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Restricted Access',
              style: context.textStyles.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This page is restricted to certain users. You need to apply to become a builder for now.',
              style: context.textStyles.bodyMedium?.copyWith(
                color: context.colors.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.go('/profile'),
                child: const Text('Sign In to Start'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestrictedInfluencerState extends StatelessWidget {
  const _RestrictedInfluencerState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.colors.primaryContainer.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_outline,
                size: 48,
                color: context.colors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Builder access',
              style: context.textStyles.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Please apply to become a builder via here.',
              style: context.textStyles.bodyMedium?.copyWith(
                color: context.colors.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.go('/profile'),
                child: const Text('Apply to become a builder'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBuilderState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.colors.primaryContainer.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.create_outlined,
                size: 48,
                color: context.colors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your builder awaits',
              style: context.textStyles.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first adventure route with our intuitive builder',
              style: context.textStyles.bodyMedium?.copyWith(
                color: context.colors.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _FeatureChip(icon: Icons.route, label: 'Route Builder'),
                _FeatureChip(icon: Icons.calendar_today, label: 'Day Planner'),
                _FeatureChip(icon: Icons.backpack, label: 'Packing Lists'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: context.colors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: context.colors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: context.textStyles.bodySmall?.copyWith(
              color: context.colors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.colors.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: context.textStyles.bodySmall?.copyWith(
              color: context.colors.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: context.textStyles.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PayoutCTA extends StatelessWidget {
  final VoidCallback onTap;

  const _PayoutCTA({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.amber.shade50,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.payment, color: Colors.amber.shade800, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Add payment details to receive earnings',
                      style: context.textStyles.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Complete Stripe Connect onboarding to get paid when your plans are sold.',
                      style: context.textStyles.bodySmall?.copyWith(
                        color: Colors.amber.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.amber.shade800),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: context.colors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading your adventures...',
              style: context.textStyles.bodyMedium?.copyWith(
                color: context.colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
