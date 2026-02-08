import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/core/constants/breakpoints.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/presentation/widgets/adventure_card.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/theme.dart';

class LocationSearchResultsPage extends StatefulWidget {
  final String location;

  const LocationSearchResultsPage({
    super.key,
    required this.location,
  });

  @override
  State<LocationSearchResultsPage> createState() => _LocationSearchResultsPageState();
}

class _LocationSearchResultsPageState extends State<LocationSearchResultsPage> {
  final _planService = PlanService();
  List<Plan> _plans = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);

    try {
      // Get all published plans and filter by location
      final allPlans = await _planService.getAllPlans();
      final matchingPlans = allPlans
          .where((plan) => plan.location.toLowerCase().contains(widget.location.toLowerCase()))
          .toList();

      // Sort by creation date (newest first)
      matchingPlans.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _plans = matchingPlans;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading plans: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.colors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Adventures in ${widget.location}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _plans.isEmpty
              ? _buildEmptyState()
              : _buildPlansList(isDesktop),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: context.colors.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No adventures found in ${widget.location}',
              style: context.textStyles.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try searching for a different location',
              style: context.textStyles.bodyMedium?.copyWith(
                color: context.colors.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlansList(bool isDesktop) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: WaypointBreakpoints.contentMaxWidth),
        padding: EdgeInsets.all(isDesktop ? 48 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_plans.length} ${_plans.length == 1 ? 'adventure' : 'adventures'} found',
              style: context.textStyles.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.colors.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  int crossAxisCount;
                  double childAspectRatio;
                  if (width >= 1024) {
                    crossAxisCount = 3;
                    childAspectRatio = 0.75;
                  } else if (width >= 640) {
                    crossAxisCount = 2;
                    childAspectRatio = 0.75;
                  } else {
                    crossAxisCount = 1;
                    childAspectRatio = 0.8;
                  }

                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: childAspectRatio,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _plans.length,
                    itemBuilder: (context, index) {
                      final plan = _plans[index];
                      return AdventureCard(
                        plan: plan,
                        variant: AdventureCardVariant.standard,
                        showFavoriteButton: true,
                        onTap: () {
                          context.push('/details/${plan.id}');
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

