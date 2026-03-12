import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:waypoint/models/expense_model.dart';
import 'package:waypoint/models/user_model.dart';
import 'package:waypoint/services/expense_service.dart';
import 'package:waypoint/services/invite_service.dart';
import 'package:waypoint/theme/waypoint_spacing.dart';
import 'package:waypoint/theme/waypoint_typography.dart';
import 'package:waypoint/layout/responsive_content_layout.dart';
import 'package:waypoint/presentation/trips/add_edit_expense_screen.dart';

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

/// Treasure (expenses) tab content for the trip page: list by date, totals, FAB to add.
class TreasureTab extends StatefulWidget {
  final String tripId;
  final String? tripTitle;

  const TreasureTab({
    super.key,
    required this.tripId,
    this.tripTitle,
  });

  @override
  State<TreasureTab> createState() => _TreasureTabState();
}

class _TreasureTabState extends State<TreasureTab> {
  final ExpenseService _expenseService = ExpenseService();
  final InviteService _inviteService = InviteService();
  List<UserModel> _members = [];
  bool _membersLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final list = await _inviteService.getMembersDetails(widget.tripId);
    if (mounted) {
      setState(() {
        _members = list;
        _membersLoaded = true;
      });
    }
  }

  String _userDisplayName(String userId) {
    final me = FirebaseAuth.instance.currentUser?.uid;
    final u = _members.where((m) => m.id == userId).firstOrNull;
    if (u == null) return 'Unknown';
    if (me != null && u.id == me) return '${u.displayName} (Me)';
    return u.displayName;
  }

  String _formatCurrency(String code, double amount) {
    final symbol = _currencySymbol(code);
    return '$symbol ${NumberFormat('#,##0.00', 'en_US').format(amount)}';
  }

  String _currencySymbol(String code) {
    switch (code.toUpperCase()) {
      case 'EUR':
        return '€';
      case 'USD':
        return '\$';
      case 'GBP':
        return '£';
      default:
        return code;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height,
        ),
        child: ResponsiveContentLayout(
          content: StreamBuilder<List<TripExpense>>(
            stream: _expenseService.streamExpenses(widget.tripId),
            builder: (context, snapshot) {
              final expenses = snapshot.data ?? [];
              final hasData = snapshot.hasData;
              final isLoading = snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData;

              if (isLoading) {
                return const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final currentUserId = FirebaseAuth.instance.currentUser?.uid;
              double myTotal = 0;
              double totalAll = 0;
              for (final e in expenses) {
                totalAll += e.amount;
                if (currentUserId != null && e.participantIds.contains(currentUserId)) {
                  final share = _shareForUser(e, currentUserId);
                  myTotal += share;
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: WaypointSpacing.sectionGap),
                  // Summary row
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryChip(
                          label: 'My expenses',
                          amount: myTotal,
                          currencyCode: expenses.isNotEmpty ? expenses.first.currencyCode : 'EUR',
                          format: _formatCurrency,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _SummaryChip(
                          label: 'Total expenses',
                          amount: totalAll,
                          currencyCode: expenses.isNotEmpty ? expenses.first.currencyCode : 'EUR',
                          format: _formatCurrency,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: WaypointSpacing.subsectionGap),
                  if (!hasData || expenses.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.savings_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
                            const SizedBox(height: 16),
                            Text(
                              'No expenses yet',
                              style: WaypointTypography.titleMedium.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap + to add your first expense',
                              style: WaypointTypography.bodyMedium.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._buildGroupedExpenses(expenses),
                  const SizedBox(height: 80),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  double _shareForUser(TripExpense e, String userId) {
    if (!e.participantIds.contains(userId)) return 0;
    switch (e.splitType) {
      case ExpenseSplitType.equal:
        return e.participantIds.isEmpty ? 0 : e.amount / e.participantIds.length;
      case ExpenseSplitType.amounts:
        return e.splitAmounts[userId] ?? 0;
      case ExpenseSplitType.parts:
        final totalParts = e.splitParts.values.fold<int>(0, (a, b) => a + b);
        if (totalParts == 0) return 0;
        final parts = e.splitParts[userId] ?? 0;
        return e.amount * (parts / totalParts);
    }
  }

  List<Widget> _buildGroupedExpenses(List<TripExpense> expenses) {
    final byDate = <String, List<TripExpense>>{};
    for (final e in expenses) {
      final key = DateFormat('d MMM yyyy').format(e.date);
      byDate.putIfAbsent(key, () => []).add(e);
    }
    final sortedDates = byDate.keys.toList()..sort((a, b) {
      final d1 = byDate[a]!.first.date;
      final d2 = byDate[b]!.first.date;
      return d2.compareTo(d1);
    });

    return sortedDates.map((dateKey) {
      final list = byDate[dateKey]!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              dateKey,
              style: WaypointTypography.titleSmall.copyWith(
                color: Theme.of(context).colorScheme.outline,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...list.map((e) => _ExpenseTile(
                expense: e,
                paidByName: _userDisplayName(e.paidByUserId),
                formatCurrency: (code, amount) => _formatCurrency(code, amount),
                onTap: () => _openEditExpense(e),
                onDelete: () => _deleteExpense(e),
              )),
        ],
      );
    }).toList();
  }

  Future<void> _openEditExpense(TripExpense expense) async {
    if (!_membersLoaded) return;
    final updated = await Navigator.of(context).push<TripExpense>(
      MaterialPageRoute(
        builder: (context) => AddEditExpenseScreen(
          tripId: widget.tripId,
          members: _members,
          existing: expense,
        ),
      ),
    );
    if (updated != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense updated'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _deleteExpense(TripExpense expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete expense'),
        content: Text('Delete "${expense.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _expenseService.deleteExpense(widget.tripId, expense.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense deleted'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

}

class _SummaryChip extends StatelessWidget {
  final String label;
  final double amount;
  final String currencyCode;
  final String Function(String code, double amount) format;

  const _SummaryChip({
    required this.label,
    required this.amount,
    required this.currencyCode,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(WaypointSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: WaypointTypography.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            format(currencyCode, amount),
            style: WaypointTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  final TripExpense expense;
  final String paidByName;
  final String Function(String code, double amount) formatCurrency;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ExpenseTile({
    required this.expense,
    required this.paidByName,
    required this.formatCurrency,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: WaypointSpacing.cardGap),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(WaypointSpacing.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(WaypointSpacing.cardPadding),
          child: Row(
            children: [
              Icon(
                _iconForExpense(expense),
                size: 28,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.title,
                      style: WaypointTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Paid by $paidByName',
                      style: WaypointTypography.bodySmall.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formatCurrency(expense.currencyCode, expense.amount),
                style: WaypointTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 20, color: theme.colorScheme.onSurface),
                onSelected: (v) {
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForExpense(TripExpense e) {
    if (e.iconKey != null && e.iconKey!.isNotEmpty) {
      if (e.iconKey == 'restaurant') return Icons.restaurant;
      if (e.iconKey == 'transport') return Icons.directions_car;
      if (e.iconKey == 'drinks') return Icons.local_bar;
    }
    return Icons.payments_outlined;
  }
}
