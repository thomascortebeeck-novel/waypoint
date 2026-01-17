import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/auth/firebase_auth_manager.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/presentation/widgets/adventure_card.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/services/user_service.dart';
import 'package:waypoint/theme.dart';

/// Screen for creating a new itinerary by selecting from available plans
class CreateItineraryScreen extends StatefulWidget {
  const CreateItineraryScreen({super.key});

  @override
  State<CreateItineraryScreen> createState() => _CreateItineraryScreenState();
}

class _CreateItineraryScreenState extends State<CreateItineraryScreen> {
  final _auth = FirebaseAuthManager();
  final _userService = UserService();
  final _planService = PlanService();

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUserId;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/mytrips'),
        ),
        title: Text('Create Itinerary', style: context.textStyles.titleLarge),
        backgroundColor: context.colors.surface,
        elevation: 0,
      ),
      body: uid == null
          ? _buildSignedOutState(context)
          : _buildContent(context, uid, isDesktop),
    );
  }

  Widget _buildSignedOutState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: context.colors.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Sign in to create itineraries',
              style: context.textStyles.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You need to be signed in to create personalized trip itineraries',
              style: context.textStyles.bodyMedium?.copyWith(
                color: context.colors.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/profile'),
              child: const Text('Go to Profile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, String uid, bool isDesktop) {
    return StreamBuilder(
      stream: _userService.streamUser(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = snapshot.data;
        final planIds = <String>{
          ...?user?.purchasedPlanIds,
          ...?user?.invitedPlanIds,
        }.toList();

        if (planIds.isEmpty) {
          return _buildEmptyState(context);
        }

        return FutureBuilder<List<Plan>>(
          future: _planService.getPlansByIds(planIds),
          builder: (context, plansSnapshot) {
            if (!plansSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final plans = plansSnapshot.data ?? [];
            if (plans.isEmpty) {
              return _buildEmptyState(context);
            }

            return _buildPlanSelectionContent(context, plans, isDesktop);
          },
        );
      },
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
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.colors.primaryContainer.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.explore_outlined,
                size: 48,
                color: context.colors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No plans available',
              style: context.textStyles.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Purchase or get invited to an adventure plan to create your personalized itinerary',
              style: context.textStyles.bodyMedium?.copyWith(
                color: context.colors.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.explore, size: 18),
              label: const Text('Explore Adventures'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanSelectionContent(BuildContext context, List<Plan> plans, bool isDesktop) {
    final cardWidth = isDesktop ? 300.0 : 280.0;
    final cardHeight = isDesktop ? 380.0 : 350.0;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : 16,
        vertical: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section
          Text(
            'Choose a plan',
            style: context.textStyles.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select the adventure plan you want to create an itinerary for',
            style: context.textStyles.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Plan cards grid - matching explore page style
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              int crossAxisCount;
              if (width >= 1024) {
                crossAxisCount = 3;
              } else if (width >= 640) {
                crossAxisCount = 2;
              } else {
                crossAxisCount = 1;
              }

              return GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 24,
                  crossAxisSpacing: 24,
                  childAspectRatio: cardWidth / cardHeight,
                ),
                itemCount: plans.length,
                itemBuilder: (context, index) {
                  final plan = plans[index];
                  return SizedBox(
                    width: cardWidth,
                    height: cardHeight,
                    child: AdventureCard(
                      plan: plan,
                      variant: AdventureCardVariant.standard,
                      onTap: () => _selectPlan(context, plan),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _selectPlan(BuildContext context, Plan plan) {
    // Navigate to the onboarding flow step 2 (name)
    context.push('/mytrips/onboarding/${plan.id}/name');
  }
}
