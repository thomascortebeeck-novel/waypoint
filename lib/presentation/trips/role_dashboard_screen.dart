import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/core/constants/app_terms.dart';
import 'package:waypoint/models/trip_model.dart';
import 'package:waypoint/models/trip_selection_model.dart';
import 'package:waypoint/models/expense_model.dart';
import 'package:waypoint/models/trip_waypoint_override_model.dart';
import 'package:waypoint/services/expense_service.dart';
import 'package:waypoint/services/invite_service.dart';
import 'package:waypoint/models/mood_vote_model.dart';
import 'package:waypoint/services/mood_service.dart';
import 'package:waypoint/services/trip_analytics_service.dart';
import 'package:waypoint/services/trip_service.dart';
import 'package:waypoint/theme.dart';

/// Role-specific dashboard: Quartermaster, Navigator, Treasurer, Insider, Footprinter.
/// Entry from Trip Members screen when the user has a special role.
class RoleDashboardScreen extends StatefulWidget {
  final String tripId;

  const RoleDashboardScreen({super.key, required this.tripId});

  @override
  State<RoleDashboardScreen> createState() => _RoleDashboardScreenState();
}

class _RoleDashboardScreenState extends State<RoleDashboardScreen> {
  final TripService _tripService = TripService();
  Trip? _trip;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final trip = await _tripService.getTripById(widget.tripId);
      if (mounted) {
        setState(() {
          _trip = trip;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('My role')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _trip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My role')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'Trip not found', style: context.textStyles.bodyMedium),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.pop(),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      );
    }

    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (!_trip!.hasSpecialRole(currentUserId)) {
      return Scaffold(
        appBar: AppBar(title: const Text('My role')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'You don\'t have a role for this trip.',
                style: context.textStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.pop(),
                child: const Text('Back to members'),
              ),
            ],
          ),
        ),
      );
    }

    final role = _trip!.memberRoles?[currentUserId] ?? kTripRoleMember;
    final roleLabel = tripRoleDisplayLabel(role);

    return Scaffold(
      appBar: AppBar(
        title: Text('$roleLabel dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTrip,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildRoleContent(role, currentUserId),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleContent(String role, String currentUserId) {
    if (role == kTripRoleQuartermaster || role == kTripRolePackingLeadLegacy) {
      return _buildQuartermasterContent();
    }
    if (role == kTripRoleNavigator) {
      return _buildNavigatorContent();
    }
    if (role == kTripRoleTreasurer) {
      return _buildTreasurerContent();
    }
    if (role == kTripRoleInsider) {
      return _buildInsiderContent();
    }
    if (role == kTripRoleFootprinter) {
      return _buildFootprinterContent();
    }
    return const SizedBox.shrink();
  }

  Future<Map<String, dynamic>> _loadQuartermasterData() async {
    final overrides = await _tripService.getWaypointOverrides(widget.tripId);
    final packings = await _tripService.getAllMemberPackings(widget.tripId);
    final docCount = await _tripService.getWaypointDocumentsCount(widget.tripId);
    final membersList = await InviteService().getMembersDetails(widget.tripId);
    final memberNames = <String, String>{};
    for (final m in membersList) {
      final name = [m.firstName, m.lastName].where((e) => e != null && e.isNotEmpty).join(' ').trim();
      memberNames[m.id] = name.isNotEmpty ? name : (m.displayName ?? m.id);
    }
    final bookedCount = overrides.where((o) => o.status == 'booked').length;
    return {
      'overrides': overrides,
      'packings': packings,
      'docCount': docCount,
      'memberNames': memberNames,
      'bookedCount': bookedCount,
      'totalWithStatus': overrides.where((o) => o.status != null && o.status!.isNotEmpty).length,
    };
  }

  Widget _buildQuartermasterContent() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadQuartermasterData(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ));
        }
        final data = snapshot.data!;
        final overrides = data['overrides'] as List<TripWaypointOverride>;
        final packings = data['packings'] as List<MemberPacking>;
        final docCount = data['docCount'] as int;
        final memberNames = data['memberNames'] as Map<String, String>;
        final bookedCount = data['bookedCount'] as int;
        final totalWithStatus = data['totalWithStatus'] as int;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tripRoleDescription(kTripRoleQuartermaster),
              style: context.textStyles.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            _quartermasterStatCard(
              'Waypoint bookings',
              '$bookedCount booked',
              totalWithStatus > 0 ? '${(100 * bookedCount / totalWithStatus).round()}% of waypoints with status' : 'No overrides yet',
              Icons.book_online_outlined,
            ),
            const SizedBox(height: 12),
            _quartermasterStatCard(
              'Documents uploaded',
              '$docCount',
              'Documents on waypoints (e.g. confirmations)',
              Icons.insert_drive_file_outlined,
            ),
            const SizedBox(height: 20),
            Text(
              'Expedition list by member',
              style: context.textStyles.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            if (packings.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No packing data yet.',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              )
            else
              ...packings.map((p) {
                final name = memberNames[p.memberId] ?? p.memberId;
                final progress = (p.progress * 100).round();
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(name),
                    subtitle: Text('${p.checkedCount}/${p.totalCount} items · $progress%'),
                    trailing: p.isComplete
                        ? Icon(Icons.check_circle, color: context.colors.primary)
                        : null,
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _quartermasterStatCard(String title, String value, String subtitle, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 32, color: context.colors.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.textStyles.labelMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    value,
                    style: context.textStyles.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: context.textStyles.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _loadNavigatorData() async {
    final overrides = await _tripService.getWaypointOverrides(widget.tripId);
    final getDirectionsCount = await TripAnalyticsService().getGetDirectionsCount(widget.tripId);
    final travelModeCounts = <String, int>{};
    for (final o in overrides) {
      if (o.travelMode != null && o.travelMode!.isNotEmpty) {
        travelModeCounts[o.travelMode!] = (travelModeCounts[o.travelMode!] ?? 0) + 1;
      }
    }
    return {
      'travelModeCounts': travelModeCounts,
      'getDirectionsCount': getDirectionsCount,
      'segmentsWithTransport': overrides.where((o) => o.travelMode != null && o.travelMode!.isNotEmpty).length,
    };
  }

  Widget _buildNavigatorContent() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadNavigatorData(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ));
        }
        final data = snapshot.data!;
        final travelModeCounts = data['travelModeCounts'] as Map<String, int>;
        final getDirectionsCount = data['getDirectionsCount'] as int;
        final segmentsWithTransport = data['segmentsWithTransport'] as int;

        final modeLabels = <String, String>{
          'walking': 'Walk',
          'driving': 'Car',
          'bicycling': 'Bike',
          'transit': 'Transit',
        };

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tripRoleDescription(kTripRoleNavigator),
              style: context.textStyles.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            _navigatorStatCard(
              'Get directions',
              '$getDirectionsCount',
              'Times directions were opened',
              Icons.directions,
            ),
            const SizedBox(height: 12),
            _navigatorStatCard(
              'Transport segments',
              '$segmentsWithTransport',
              'Segments with transport mode set',
              Icons.route,
            ),
            const SizedBox(height: 20),
            Text(
              'Transport types chosen',
              style: context.textStyles.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            if (travelModeCounts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No transport choices recorded yet.',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              )
            else
              ...travelModeCounts.entries.map((e) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(modeLabels[e.key] ?? e.key),
                  trailing: Text('${e.value}', style: context.textStyles.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  )),
                ),
              )),
          ],
        );
      },
    );
  }

  Widget _navigatorStatCard(String title, String value, String subtitle, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 32, color: context.colors.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.textStyles.labelMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    value,
                    style: context.textStyles.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: context.textStyles.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _loadTreasurerData() async {
    final expenses = await ExpenseService().streamExpenses(widget.tripId).first;
    final byDate = <String, List<TripExpense>>{};
    double totalAmount = 0;
    for (final e in expenses) {
      final key = e.date.toIso8601String().split('T').first;
      byDate.putIfAbsent(key, () => []).add(e);
      totalAmount += e.amount;
    }
    final daysWithExpenses = byDate.length;
    return {
      'expenses': expenses,
      'totalCount': expenses.length,
      'daysWithExpenses': daysWithExpenses,
      'totalAmount': totalAmount,
      'currencyCode': expenses.isNotEmpty ? expenses.first.currencyCode : 'EUR',
    };
  }

  Widget _buildTreasurerContent() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadTreasurerData(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ));
        }
        final data = snapshot.data!;
        final totalCount = data['totalCount'] as int;
        final daysWithExpenses = data['daysWithExpenses'] as int;
        final totalAmount = data['totalAmount'] as double;
        final currencyCode = data['currencyCode'] as String;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tripRoleDescription(kTripRoleTreasurer),
              style: context.textStyles.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            _treasurerStatCard(
              'Expenses logged',
              '$totalCount',
              '$daysWithExpenses days with expenses',
              Icons.receipt_long_outlined,
            ),
            const SizedBox(height: 12),
            _treasurerStatCard(
              'Total amount',
              _formatCurrency(currencyCode, totalAmount),
              'Across all expenses',
              Icons.payments_outlined,
            ),
          ],
        );
      },
    );
  }

  String _formatCurrency(String code, double amount) {
    if (code == 'EUR') return '€${amount.toStringAsFixed(2)}';
    if (code == 'USD') return '\$${amount.toStringAsFixed(2)}';
    return '$code ${amount.toStringAsFixed(2)}';
  }

  Widget _treasurerStatCard(String title, String value, String subtitle, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 32, color: context.colors.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.textStyles.labelMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    value,
                    style: context.textStyles.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: context.textStyles.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsiderContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tripRoleDescription(kTripRoleInsider),
          style: context.textStyles.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Daily mood summary',
          style: context.textStyles.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.colors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<MoodVoteDoc>>(
          stream: MoodService().streamMoodVotes(widget.tripId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final docs = snapshot.data!;
            if (docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No mood votes yet. Members can vote once per day when the mood pop-up is enabled.',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              );
            }
            final byDate = <String, List<MapEntry<String, String>>>{};
            for (final doc in docs) {
              for (final e in doc.votes.entries) {
                byDate.putIfAbsent(e.key, () => []).add(MapEntry(doc.userId, e.value));
              }
            }
            final dates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...dates.take(7).map((date) {
                  final entries = byDate[date]!;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              date,
                              style: context.textStyles.labelMedium?.copyWith(
                                color: context.colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...entries.map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '${e.value}',
                                style: context.textStyles.bodyMedium,
                              ),
                            )),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Insights',
          style: context.textStyles.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.colors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Add and edit trip insights (local tips) in the Insights tab of your trip.',
            style: context.textStyles.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Future<int> _loadFootprinterPoints() async {
    return TripAnalyticsService().getFootprinterPoints(widget.tripId);
  }

  Widget _buildFootprinterContent() {
    return FutureBuilder<int>(
      future: _loadFootprinterPoints(),
      builder: (context, snapshot) {
        final points = snapshot.hasData ? snapshot.data! : 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tripRoleDescription(kTripRoleFootprinter),
              style: context.textStyles.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.eco, size: 32, color: context.colors.primary),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Green points',
                            style: context.textStyles.labelMedium?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '$points',
                            style: context.textStyles.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Times the Navigator chose lower-footprint transport than suggested',
                            style: context.textStyles.bodySmall?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Daily footprint',
              style: context.textStyles.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'View the Footprint tab in the trip for full CO2 breakdown and daily comparison.',
                style: context.textStyles.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
