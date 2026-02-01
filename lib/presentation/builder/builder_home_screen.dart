import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/auth/firebase_auth_manager.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/presentation/widgets/adventure_card.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/services/user_service.dart';
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
  bool _deleting = false;

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
                _buildHeader(context, isDesktop),
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
          
          return CustomScrollView(
            slivers: [
              _buildHeader(context, isDesktop),
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : 16,
                  vertical: 8,
                ),
                sliver: uid == null
                    ? SliverToBoxAdapter(child: _SignedOutState())
                    : _buildPlansContent(context, uid, isDesktop),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
      floatingActionButton: StreamBuilder(
        stream: _auth.authStateChanges,
        builder: (context, snapshot) {
          final uid = snapshot.data?.uid;
          return _buildFAB(context, uid);
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDesktop) {
    return SliverAppBar(
      expandedHeight: isDesktop ? 140 : 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: context.colors.surface,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                context.colors.primary.withValues(alpha: 0.08),
                context.colors.surface,
              ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 32 : 20,
                isDesktop ? 24 : 16,
                isDesktop ? 32 : 20,
                24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Builder',
                    style: context.textStyles.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Create & manage your adventures',
                    style: context.textStyles.bodyLarge?.copyWith(
                      color: context.colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        title: LayoutBuilder(
          builder: (context, constraints) {
            final isCollapsed = constraints.biggest.height < 80;
            return AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isCollapsed ? 1.0 : 0.0,
              child: Text(
                'Builder',
                style: context.textStyles.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFAB(BuildContext context, String? uid) {
    return FloatingActionButton.extended(
      onPressed: uid == null ? () => context.go('/profile') : () => _createNewDraft(context),
      elevation: 4,
      label: Text(
        'New Adventure',
        style: context.textStyles.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      icon: const Icon(Icons.add, size: 22, color: Colors.white),
    );
  }

  Widget _buildPlansContent(BuildContext context, String uid, bool isDesktop) {
    return StreamBuilder<List<Plan>>(
      stream: _plans.streamPlansByCreator(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverToBoxAdapter(
            child: _LoadingState(),
          );
        }
        final plans = snapshot.data ?? [];
        if (plans.isEmpty) {
          return SliverToBoxAdapter(child: _EmptyBuilderState());
        }
        return _buildPlansGrid(context, plans, isDesktop);
      },
    );
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
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

      Navigator.of(context).pop();
      context.go('/builder/$planId');
    } catch (e) {
      debugPrint('Failed to create draft: $e');
      if (!mounted) return;

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to create draft. Try again.'),
          backgroundColor: context.colors.error,
        ),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, Plan plan) async {
    if (_deleting) return;
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
      setState(() => _deleting = true);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to delete. Try again.'),
            backgroundColor: context.colors.error,
          ),
        );
      } finally {
        if (mounted) setState(() => _deleting = false);
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
