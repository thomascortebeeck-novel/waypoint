import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/auth/firebase_auth_manager.dart';
import 'package:waypoint/models/plan_model.dart';
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
    final uid = _auth.currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Builder', style: context.textStyles.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
            Text('Create & manage your adventures', style: context.textStyles.bodySmall?.copyWith(color: context.colors.onSurface.withValues(alpha: 0.6))),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: uid == null ? _showSignInRequired : () => _createNewDraft(context),
        label: Text('New Adventure', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        icon: const Icon(Icons.add, size: 24),
        elevation: 4,
      ),
      body: uid == null
          ? _buildSignedOut(context)
          : StreamBuilder<List<Plan>>(
              stream: _plans.streamPlansByCreator(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text('Loading your adventures...', style: context.textStyles.bodyMedium?.copyWith(color: context.colors.onSurface.withValues(alpha: 0.6))),
                      ],
                    ),
                  );
                }
                final plans = snapshot.data ?? [];
                if (plans.isEmpty) return _buildEmptyState(context);
                return GridView.builder(
                  padding: AppSpacing.paddingMd,
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: plans.length,
                  itemBuilder: (context, index) => _BuilderPlanCard(
                    plan: plans[index],
                    onTap: () => context.push('/builder/edit/${plans[index].id}'),
                    onDelete: () => _confirmDelete(context, plans[index]),
                  ),
                );
              },
            ),
    );
  }

  void _showSignInRequired() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sign In Required', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'You need to sign in to create and manage adventures.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                context.push('/profile');
              },
              child: const Text('Go to Profile'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createNewDraft(BuildContext context) async {
    final uid = _auth.currentUserId;
    if (uid == null) return;

    // Show loading dialog while creating draft
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final user = await _users.getUserById(uid);
      final now = DateTime.now();
      
      final draftPlan = Plan(
        id: '', // Will be set by createPlan
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
      
      // Close loading dialog
      Navigator.of(context).pop();
      
      // Navigate to builder using go (replaces current route)
      context.go('/builder/edit/$planId');
    } catch (e) {
      debugPrint('Failed to create draft: $e');
      if (!mounted) return;
      
      // Close loading dialog
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create draft. Try again.')),
      );
    }
  }

  Widget _buildSignedOut(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.colors.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.edit_road, size: 56, color: context.colors.primary),
            ),
            const SizedBox(height: 20),
            Text('Design your dream adventure', style: context.textStyles.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Create detailed itineraries with routes, accommodations, and packing lists. Sign in when you\'re ready to publish.',
              style: context.textStyles.bodyMedium?.copyWith(color: context.colors.onSurface.withValues(alpha: 0.6)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _showSignInRequired,
              icon: const Icon(Icons.add_circle),
              label: const Text('Start Creating'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.colors.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.create_outlined, size: 56, color: context.colors.primary),
            ),
            const SizedBox(height: 20),
            Text('Your builder awaits', style: context.textStyles.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Create your first adventure route with our intuitive builder. Add waypoints, plan itineraries, and share with travelers.',
              style: context.textStyles.bodyMedium?.copyWith(color: context.colors.onSurface.withValues(alpha: 0.6)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                Chip(
                  avatar: Icon(Icons.check_circle, size: 16, color: context.colors.primary),
                  label: const Text('Route Builder'),
                  backgroundColor: context.colors.primaryContainer.withValues(alpha: 0.3),
                ),
                Chip(
                  avatar: Icon(Icons.check_circle, size: 16, color: context.colors.primary),
                  label: const Text('Day Planner'),
                  backgroundColor: context.colors.primaryContainer.withValues(alpha: 0.3),
                ),
                Chip(
                  avatar: Icon(Icons.check_circle, size: 16, color: context.colors.primary),
                  label: const Text('Packing Lists'),
                  backgroundColor: context.colors.primaryContainer.withValues(alpha: 0.3),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Plan plan) async {
    if (_deleting) return;
    final uid = _auth.currentUserId;
    if (uid == null) return;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.colors.surface,
      builder: (context) {
        return Padding(
          padding: AppSpacing.paddingMd,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Delete “${plan.name}”?', style: context.textStyles.titleLarge),
              const SizedBox(height: 8),
              Text('This will remove the plan for all participants. This action cannot be undone.', style: context.textStyles.bodyMedium),
              const SizedBox(height: 16),
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
                    child: FilledButton.tonal(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(backgroundColor: Colors.red.withValues(alpha: 0.15)),
                      child: Text('Delete', style: TextStyle(color: Colors.red.shade400)),
                    ),
                  ),
                ],
              )
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plan deleted')));
      } catch (e) {
        debugPrint('Delete failed: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete. Try again.')));
      } finally {
        if (mounted) setState(() => _deleting = false);
      }
    }
  }
}

/// Builder-specific plan card that reuses PlanCard design with edit/delete actions
class _BuilderPlanCard extends StatelessWidget {
  final Plan plan;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _BuilderPlanCard({
    required this.plan,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Stack(
            children: [
              // Background Image
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: plan.heroImageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: context.colors.surface,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: context.colors.surface,
                    child: const Icon(Icons.error),
                  ),
                ),
              ),
              
              // Gradient Overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.2),
                        Colors.black.withValues(alpha: 0.8),
                      ],
                      stops: const [0.5, 0.7, 1.0],
                    ),
                  ),
                ),
              ),

              // Content
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: AppSpacing.paddingMd,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Location or "Draft" indicator
                      if (plan.location.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.white70, size: 12),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                plan.location.toUpperCase(),
                                style: context.textStyles.labelSmall?.copyWith(
                                  color: Colors.white70,
                                  letterSpacing: 1.0,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          'NO LOCATION SET',
                          style: context.textStyles.labelSmall?.copyWith(
                            color: Colors.white70,
                            letterSpacing: 1.0,
                          ),
                        ),
                      const SizedBox(height: 4),
                      
                      // Title
                      Text(
                        plan.name,
                        style: context.textStyles.titleLarge?.copyWith(color: Colors.white),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // Footer Info
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Status + Difficulty Chips
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _buildChip(
                                  context,
                                  plan.isPublished ? 'Published' : 'Draft',
                                  plan.isPublished ? context.colors.primary : Colors.orange,
                                ),
                                if (plan.versions.isNotEmpty && plan.difficultyRange.isNotEmpty)
                                  _buildChip(context, plan.difficultyRange, null),
                              ],
                            ),
                          ),
                          
                          // Price
                          Text(
                            plan.minPrice == 0 ? "FREE" : "€${plan.minPrice.toStringAsFixed(0)}",
                            style: context.textStyles.titleMedium?.copyWith(
                              color: context.colors.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Delete Button (top right)
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: onDelete,
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(Icons.delete, color: Colors.red.shade300, size: 20),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(BuildContext context, String label, Color? bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor?.withValues(alpha: 0.25) ?? Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: bgColor?.withValues(alpha: 0.5) ?? Colors.white.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        label,
        style: context.textStyles.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
