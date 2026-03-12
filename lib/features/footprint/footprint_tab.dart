import 'package:flutter/material.dart';
import 'package:waypoint/core/theme/spacing.dart';
import 'package:waypoint/features/footprint/footprint_calculator.dart';
import 'package:waypoint/features/footprint/footprint_input_builder.dart';
import 'package:waypoint/features/footprint/footprint_result.dart';
import 'package:waypoint/features/footprint/widgets/category_breakdown_row.dart';
import 'package:waypoint/features/footprint/widgets/co2_donut_chart.dart';
import 'package:waypoint/features/footprint/widgets/eco_tips.dart';
import 'package:waypoint/features/footprint/widgets/footprint_equivalents.dart';
import 'package:waypoint/features/footprint/widgets/offset_project_card.dart';
import 'package:waypoint/features/footprint/widgets/transport_leg_tile.dart';
import 'package:waypoint/features/footprint/widgets/co2_donut_chart.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/trip_selection_model.dart';

/// Data needed to build the footprint tab (plan or trip).
class FootprintTabData {
  final Plan plan;
  final PlanVersion version;
  final Map<int, TripDaySelection>? daySelections;
  final int personCount;

  FootprintTabData({
    required this.plan,
    required this.version,
    this.daySelections,
    this.personCount = 1,
  });

  bool get isTrip => daySelections != null;
}

/// Footprint tab: CO2 summary, breakdown, equivalents, offset CTA, tips.
class FootprintTab extends StatelessWidget {
  final FootprintTabData data;
  final List<OffsetProjectCardData>? offsetProjects;

  const FootprintTab({
    super.key,
    required this.data,
    this.offsetProjects,
  });

  @override
  Widget build(BuildContext context) {
    final input = data.isTrip
        ? FootprintInputBuilder.fromTrip(
            data.version,
            data.daySelections!,
            personCount: data.personCount,
          )
        : FootprintInputBuilder.fromPlanVersion(
            data.version,
            personCount: data.personCount,
          );
    final result = FootprintCalculator().calculate(input);
    final tips = FootprintCalculator().generateTips(result);
    final projects = offsetProjects ?? _defaultOffsetProjects();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(WaypointSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeaderCard(result: result),
          const SizedBox(height: WaypointSpacing.lg),
          _BreakdownSection(result: result),
          if (result.transportLegs.isNotEmpty) ...[
            const SizedBox(height: WaypointSpacing.lg),
            _TransportLegsSection(legs: result.transportLegs),
          ],
          const SizedBox(height: WaypointSpacing.lg),
          _GiveBackSection(
            result: result,
            locationName: data.plan.locations.isNotEmpty
                ? data.plan.locations.first.shortName
                : data.plan.location,
          ),
          const SizedBox(height: WaypointSpacing.lg),
          _OffsetSection(projects: projects),
          if (tips.isNotEmpty) ...[
            const SizedBox(height: WaypointSpacing.lg),
            EcoTips(tips: tips),
          ],
          const SizedBox(height: WaypointSpacing.xxl),
        ],
      ),
    );
  }

  static List<OffsetProjectCardData> _defaultOffsetProjects() {
    return [
      const OffsetProjectCardData(
        title: 'Wildlife & Rainforest',
        country: 'Cambodia',
      ),
      const OffsetProjectCardData(
        title: 'Safe Water Nepal',
        country: 'Nepal',
      ),
    ];
  }
}

class _HeaderCard extends StatelessWidget {
  final FootprintResult result;

  const _HeaderCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalStr = result.totalKgCO2 >= 1000
        ? '${(result.totalKgCO2 / 1000).toStringAsFixed(1)} t CO2'
        : '${result.totalKgCO2.toStringAsFixed(1)} kg CO2';
    final perPersonStr = result.personCount > 1
        ? '${result.perPersonKgCO2.toStringAsFixed(1)} kg per person'
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(WaypointSpacing.md),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        totalStr,
                        style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                      ),
                      if (perPersonStr != null) ...[
                        const SizedBox(height: WaypointSpacing.xs),
                        Text(
                          perPersonStr,
                          style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                Co2DonutChart(result: result, size: 120),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownSection extends StatelessWidget {
  final FootprintResult result;

  const _BreakdownSection({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Breakdown',
          style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
        ),
        const SizedBox(height: WaypointSpacing.sm),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(WaypointSpacing.md),
            child: Column(
              children: [
                CategoryBreakdownRow(
                  icon: Icons.directions_car_outlined,
                  label: 'Transport',
                  share: result.transportShare,
                  kgCO2: result.transportKgCO2,
                  color: FootprintChartColors.transport,
                ),
                CategoryBreakdownRow(
                  icon: Icons.hotel_outlined,
                  label: 'Accommodation',
                  share: result.accommodationShare,
                  kgCO2: result.accommodationKgCO2,
                  color: FootprintChartColors.accommodation,
                ),
                CategoryBreakdownRow(
                  icon: Icons.restaurant_outlined,
                  label: 'Restaurants',
                  share: result.restaurantShare,
                  kgCO2: result.restaurantKgCO2,
                  color: FootprintChartColors.restaurants,
                ),
                CategoryBreakdownRow(
                  icon: Icons.hiking_outlined,
                  label: 'Activities',
                  share: result.activityShare,
                  kgCO2: result.activityKgCO2,
                  color: FootprintChartColors.activities,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TransportLegsSection extends StatelessWidget {
  final List<FootprintLeg> legs;

  const _TransportLegsSection({required this.legs});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transport legs',
          style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
        ),
        const SizedBox(height: WaypointSpacing.sm),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: WaypointSpacing.md,
              vertical: WaypointSpacing.sm,
            ),
            child: Column(
              children: legs.map((l) => TransportLegTile(leg: l)).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _GiveBackSection extends StatelessWidget {
  final FootprintResult result;
  final String locationName;

  const _GiveBackSection({
    required this.result,
    required this.locationName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Give back to nature',
          style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
        ),
        const SizedBox(height: WaypointSpacing.sm),
        Text(
          'Your trip to $locationName produces an average of ${result.totalKgCO2.toStringAsFixed(1)} kg of CO2. This is equivalent to:',
          style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
        ),
        const SizedBox(height: WaypointSpacing.sm),
        FootprintEquivalents(
          equivalents: result.equivalents,
          introText: '',
        ),
      ],
    );
  }
}

/// Static data for an offset project card (no callbacks).
class OffsetProjectCardData {
  final String title;
  final String country;
  final String? imageUrl;

  const OffsetProjectCardData({
    required this.title,
    required this.country,
    this.imageUrl,
  });
}

class _OffsetSection extends StatelessWidget {
  final List<OffsetProjectCardData> projects;

  const _OffsetSection({required this.projects});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contribute to these projects and receive a guarantee certificate.',
          style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
        ),
        const SizedBox(height: WaypointSpacing.sm),
        ...projects.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: WaypointSpacing.md),
            child: OffsetProjectCard(
              title: p.title,
              country: p.country,
              imageUrl: p.imageUrl,
              onMoreInfo: () {},
              onContribute: () {},
            ),
          ),
        ),
      ],
    );
  }
}
