import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:waypoint/models/expense_model.dart';
import 'package:waypoint/models/user_model.dart';
import 'package:waypoint/services/expense_service.dart';
import 'package:waypoint/services/invite_service.dart';
import 'package:waypoint/theme/waypoint_spacing.dart';
import 'package:waypoint/theme/waypoint_typography.dart';

const List<String> _kCurrencyCodes = ['EUR', 'USD', 'GBP'];

/// Add or edit a trip expense (Tricount-style).
class AddEditExpenseScreen extends StatefulWidget {
  final String tripId;
  /// If null or empty, screen will load members via [InviteService].
  final List<UserModel>? members;
  final TripExpense? existing;

  const AddEditExpenseScreen({
    super.key,
    required this.tripId,
    this.members,
    this.existing,
  });

  @override
  State<AddEditExpenseScreen> createState() => _AddEditExpenseScreenState();
}

class _AddEditExpenseScreenState extends State<AddEditExpenseScreen> {
  final ExpenseService _expenseService = ExpenseService();
  final InviteService _inviteService = InviteService();
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  String _currencyCode = 'EUR';
  String? _paidByUserId;
  DateTime _date = DateTime.now();
  ExpenseSplitType _splitType = ExpenseSplitType.equal;
  final Map<String, bool> _participantIncluded = {};
  final Map<String, TextEditingController> _amountControllers = {};
  final Map<String, TextEditingController> _partsControllers = {};
  bool _saving = false;
  List<UserModel> _members = [];
  bool _membersLoading = true;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleController = TextEditingController(text: e?.title ?? '');
    _amountController = TextEditingController(
      text: e != null ? _formatAmount(e.amount) : '0,00',
    );
    _currencyCode = e?.currencyCode ?? 'EUR';
    _paidByUserId = e?.paidByUserId ?? FirebaseAuth.instance.currentUser?.uid;
    _date = e?.date ?? DateTime.now();
    _splitType = e?.splitType ?? ExpenseSplitType.equal;
    _members = List.from(widget.members ?? []);
    if (_members.isEmpty) {
      _inviteService.getMembersDetails(widget.tripId).then((list) {
        if (mounted) {
          setState(() {
            _members = list;
            _membersLoading = false;
            for (final m in _members) {
              _participantIncluded[m.id] = e?.participantIds.contains(m.id) ?? true;
              if (_splitType == ExpenseSplitType.amounts) {
                _amountControllers[m.id] = TextEditingController(
                  text: e?.splitAmounts[m.id] != null
                      ? _formatAmount(e!.splitAmounts[m.id]!)
                      : '0,00',
                );
              } else if (_splitType == ExpenseSplitType.parts) {
                _partsControllers[m.id] = TextEditingController(
                  text: e?.splitParts[m.id]?.toString() ?? '1',
                );
              }
            }
          });
        }
      });
    } else {
      _membersLoading = false;
      for (final m in _members) {
        _participantIncluded[m.id] = e?.participantIds.contains(m.id) ?? true;
        if (_splitType == ExpenseSplitType.amounts) {
          _amountControllers[m.id] = TextEditingController(
            text: e?.splitAmounts[m.id] != null
                ? _formatAmount(e!.splitAmounts[m.id]!)
                : '0,00',
          );
        } else if (_splitType == ExpenseSplitType.parts) {
          _partsControllers[m.id] = TextEditingController(
            text: e?.splitParts[m.id]?.toString() ?? '1',
          );
        }
      }
    }
  }

  String _formatAmount(double v) {
    return NumberFormat('#,##0.00', 'en_US').format(v).replaceAll(',', ',');
  }

  double? _parseAmount(String s) {
    final normalized = s.replaceAll(',', '.').replaceAll(RegExp(r'\s'), '');
    return double.tryParse(normalized);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    for (final c in _amountControllers.values) {
      c.dispose();
    }
    for (final c in _partsControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Expense' : 'Add Expense'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _membersLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(WaypointSpacing.pagePaddingMobile),
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'E.g. Drinks',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
            ),
            const SizedBox(height: WaypointSpacing.fieldGap),
            // Amount + currency
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 80,
                  child: DropdownButtonFormField<String>(
                    value: _currencyCode,
                    decoration: const InputDecoration(labelText: 'Currency'),
                    items: _kCurrencyCodes
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(_currencySymbol(c)),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _currencyCode = v ?? 'EUR'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(labelText: 'Amount'),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: false),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter amount';
                      final n = _parseAmount(v);
                      if (n == null || n < 0) return 'Invalid amount';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: WaypointSpacing.fieldGap),
            // Paid by
            DropdownButtonFormField<String>(
              value: _paidByUserId ?? (_members.isNotEmpty ? _members.first.id : null),
              decoration: const InputDecoration(labelText: 'Paid by'),
              items: _members.map((m) {
                final uid = FirebaseAuth.instance.currentUser?.uid;
                final label =
                    uid != null && m.id == uid ? '${m.displayName} (Me)' : m.displayName;
                return DropdownMenuItem(
                  value: m.id,
                  child: Text(label),
                );
              }).toList(),
              onChanged: (v) => setState(() => _paidByUserId = v),
            ),
            const SizedBox(height: WaypointSpacing.fieldGap),
            // When
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('When'),
              subtitle: Text(DateFormat('d MMM yyyy').format(_date)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: WaypointSpacing.subsectionGap),
            // Split type
            Text('Split', style: WaypointTypography.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<ExpenseSplitType>(
              segments: const [
                ButtonSegment(
                  value: ExpenseSplitType.equal,
                  label: Text('Equally'),
                  icon: Icon(Icons.balance),
                ),
                ButtonSegment(
                  value: ExpenseSplitType.parts,
                  label: Text('As parts'),
                  icon: Icon(Icons.pie_chart_outline),
                ),
                ButtonSegment(
                  value: ExpenseSplitType.amounts,
                  label: Text('As amounts'),
                  icon: Icon(Icons.list),
                ),
              ],
              selected: {_splitType},
              onSelectionChanged: (s) {
                setState(() {
                  _splitType = s.first;
                  if (_splitType == ExpenseSplitType.amounts) {
                    for (final m in _members) {
                      _amountControllers[m.id] ??=
                          TextEditingController(text: '0,00');
                    }
                  } else if (_splitType == ExpenseSplitType.parts) {
                    for (final m in _members) {
                      _partsControllers[m.id] ??=
                          TextEditingController(text: '1');
                    }
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            // Participants
            ..._members.map((m) {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              final label =
                  uid != null && m.id == uid ? '${m.displayName} (Me)' : m.displayName;
              final included = _participantIncluded[m.id] ?? true;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Checkbox(
                      value: included,
                      onChanged: (v) =>
                          setState(() => _participantIncluded[m.id] = v ?? true),
                    ),
                    Expanded(child: Text(label)),
                    if (included && _splitType == ExpenseSplitType.amounts)
                      SizedBox(
                        width: 100,
                        child: TextFormField(
                          controller: _amountControllers[m.id],
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ),
                    if (included && _splitType == ExpenseSplitType.parts)
                      SizedBox(
                        width: 60,
                        child: TextFormField(
                          controller: _partsControllers[m.id],
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEdit ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  String _currencySymbol(String code) {
    switch (code) {
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = _parseAmount(_amountController.text);
    if (amount == null || amount < 0) return;
    final paidBy = _paidByUserId ?? (_members.isNotEmpty ? _members.first.id : '');
    if (paidBy.isEmpty) return;
    final participantIds = _members
        .where((m) => _participantIncluded[m.id] ?? true)
        .map((m) => m.id)
        .toList();
    if (participantIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Select at least one participant'),
            behavior: SnackBarBehavior.floating),
      );
      return;
    }

    Map<String, double> splitAmounts = {};
    Map<String, int> splitParts = {};
    if (_splitType == ExpenseSplitType.amounts) {
      for (final m in _members) {
        if (!participantIds.contains(m.id)) continue;
        final c = _amountControllers[m.id];
        final v = c != null ? _parseAmount(c.text) : null;
        splitAmounts[m.id] = v ?? 0;
      }
    } else if (_splitType == ExpenseSplitType.parts) {
      for (final m in _members) {
        if (!participantIds.contains(m.id)) continue;
        final c = _partsControllers[m.id];
        final v = c != null ? int.tryParse(c.text) : null;
        splitParts[m.id] = v ?? 1;
      }
    }

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      if (widget.existing != null) {
        final exp = widget.existing!.copyWith(
          title: _titleController.text.trim(),
          amount: amount,
          currencyCode: _currencyCode,
          paidByUserId: paidBy,
          date: _date,
          splitType: _splitType,
          participantIds: participantIds,
          splitAmounts: splitAmounts,
          splitParts: splitParts,
          updatedAt: now,
        );
        await _expenseService.updateExpense(exp);
        if (mounted) Navigator.of(context).pop(exp);
      } else {
        final exp = TripExpense(
          id: '',
          tripId: widget.tripId,
          title: _titleController.text.trim(),
          amount: amount,
          currencyCode: _currencyCode,
          paidByUserId: paidBy,
          date: _date,
          splitType: _splitType,
          participantIds: participantIds,
          splitAmounts: splitAmounts,
          splitParts: splitParts,
          createdAt: now,
          updatedAt: now,
        );
        await _expenseService.createExpense(exp);
        if (mounted) Navigator.of(context).pop(exp);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to save: $e'),
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }
}
