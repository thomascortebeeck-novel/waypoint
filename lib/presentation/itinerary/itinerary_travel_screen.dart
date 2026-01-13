import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/trip_model.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/services/trip_service.dart';
import 'package:waypoint/theme.dart';
import 'package:waypoint/components/itinerary/step_indicator.dart';
import 'package:waypoint/components/itinerary/itinerary_bottom_bar.dart';

class ItineraryTravelScreen extends StatefulWidget {
  final String planId;
  final String tripId;
  const ItineraryTravelScreen({super.key, required this.planId, required this.tripId});

  @override
  State<ItineraryTravelScreen> createState() => _ItineraryTravelScreenState();
}

class _ItineraryTravelScreenState extends State<ItineraryTravelScreen> {
  final _plans = PlanService();
  final _trips = TripService();
  Plan? _plan;
  Trip? _trip;
  PlanVersion? _version;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final plan = await _plans.getPlanById(widget.planId);
    final trip = await _trips.getTripById(widget.tripId);
    final version = plan?.versions.firstWhere(
      (v) => v.id == trip?.versionId,
      orElse: () => plan!.versions.first,
    );
    setState(() {
      _plan = plan;
      _trip = trip;
      _version = version;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_version == null || _plan == null || _trip == null) {
      return const Scaffold(body: Center(child: Text('Failed to load travel info')));
    }

    final options = _version!.transportationOptions;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/itinerary/${widget.planId}/pack/${widget.tripId}'),
        ),
        title: const Text('How to get there'),
      ),
      body: options.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_outlined, size: 64, color: context.colors.outline),
                  const SizedBox(height: 16),
                  Text(
                    'No transportation info available',
                    style: context.textStyles.bodyLarge?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This version doesn\'t have travel options defined',
                    style: context.textStyles.bodyMedium?.copyWith(color: context.colors.outline),
                  ),
                ],
              ),
            )
          : ListView(
              padding: AppSpacing.paddingLg,
              children: [
                StepIndicator(currentStep: 3, totalSteps: 3, labels: const ['Setup', 'Pack', 'Travel']),
                const SizedBox(height: 16),
                Text('How to get there', style: context.textStyles.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: context.colors.onSurface)),
                const SizedBox(height: 8),
                Text('Transportation options to reach your destination', style: context.textStyles.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
                const SizedBox(height: 24),
                // Transportation options as timeline
                ...options.asMap().entries.map((entry) {
                  final i = entry.key;
                  final o = entry.value;
                  final isLast = i == options.length - 1;
                  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // timeline rail
                    Column(children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: context.colors.primary, shape: BoxShape.circle)),
                      if (!isLast)
                        Container(width: 2, height: 28, color: context.colors.outlineVariant),
                    ]),
                    const SizedBox(width: 12),
                    Expanded(child: TransportationOptionCard(option: o)),
                  ]);
                }).toList(),
              ],
            ),
      bottomNavigationBar: ItineraryBottomBar(
        onBack: () => context.go('/itinerary/${widget.planId}/pack/${widget.tripId}'),
        backLabel: 'Back',
        onNext: () => context.go('/itinerary/${widget.planId}/day/${widget.tripId}/0'),
        nextLabel: 'Day 1',
        nextIcon: Icons.arrow_forward,
      ),
    );
  }
}

class TransportationOptionCard extends StatelessWidget {
  final TransportationOption option;

  const TransportationOptionCard({super.key, required this.option});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.colors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: context.colors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getTransportIcon(option.title),
                color: context.colors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: context.textStyles.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  MarkdownBody(
                    data: option.description,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: context.textStyles.bodyMedium?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                      a: context.textStyles.bodyMedium?.copyWith(
                        color: context.colors.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    onTapLink: (text, href, title) async {
                      if (href != null) {
                        final uri = Uri.tryParse(href);
                        if (uri != null && await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTransportIcon(String title) {
    final t = title.toLowerCase();
    if (t.contains('plane') || t.contains('flight') || t.contains('air')) return Icons.flight;
    if (t.contains('train') || t.contains('rail')) return Icons.train;
    if (t.contains('bus') || t.contains('coach')) return Icons.directions_bus;
    if (t.contains('car') || t.contains('drive') || t.contains('rental')) return Icons.directions_car;
    if (t.contains('taxi') || t.contains('uber') || t.contains('lyft')) return Icons.local_taxi;
    if (t.contains('ferry') || t.contains('boat') || t.contains('ship')) return Icons.directions_boat;
    if (t.contains('bike') || t.contains('cycle')) return Icons.directions_bike;
    if (t.contains('walk') || t.contains('foot')) return Icons.directions_walk;
    if (t.contains('metro') || t.contains('subway')) return Icons.subway;
    return Icons.directions;
  }
}
