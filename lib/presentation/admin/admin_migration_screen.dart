import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/services/migration_service.dart';
import 'package:waypoint/theme.dart';

/// Admin screen for running database migrations
/// Only accessible to users with isAdmin = true
class AdminMigrationScreen extends StatefulWidget {
  const AdminMigrationScreen({super.key});

  @override
  State<AdminMigrationScreen> createState() => _AdminMigrationScreenState();
}

class _AdminMigrationScreenState extends State<AdminMigrationScreen> {
  final MigrationService _migrationService = MigrationService();

  MigrationStats? _stats;
  bool _loadingStats = true;
  bool _isMigrating = false;
  bool _isVerifying = false;
  int _migratedCount = 0;
  int _totalCount = 0;
  List<MigrationResult> _results = [];
  List<MigrationVerification> _verifications = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loadingStats = true;
      _error = null;
    });

    try {
      final stats = await _migrationService.getMigrationStats();
      setState(() {
        _stats = stats;
        _loadingStats = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load stats: $e';
        _loadingStats = false;
      });
    }
  }

  Future<void> _runMigration() async {
    if (_isMigrating) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Run Migration'),
        content: const Text(
          'This will migrate all plans to the new subcollection architecture. '
          'This is a one-time operation and may take several minutes for large datasets.\n\n'
          'Are you sure you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Run Migration'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isMigrating = true;
      _migratedCount = 0;
      _totalCount = _stats?.totalPlans ?? 0;
      _results = [];
      _error = null;
    });

    try {
      final results = await _migrationService.migrateAllPlans(
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _migratedCount = current;
              _totalCount = total;
            });
          }
        },
      );

      setState(() {
        _results = results;
        _isMigrating = false;
      });

      // Reload stats
      await _loadStats();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Migration complete: ${results.where((r) => r.success).length}/${results.length} successful',
            ),
            backgroundColor: results.every((r) => r.success) ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Migration failed: $e';
        _isMigrating = false;
      });
    }
  }

  Future<void> _verifyMigrations() async {
    if (_isVerifying) return;

    setState(() {
      _isVerifying = true;
      _verifications = [];
      _error = null;
    });

    try {
      final plans = await _migrationService.getMigrationStats();
      final verifications = <MigrationVerification>[];

      // Get all plan IDs and verify each
      // Note: This is simplified - in production you'd get the actual plan IDs
      for (final result in _results) {
        final verification = await _migrationService.verifyMigration(result.planId);
        verifications.add(verification);
      }

      setState(() {
        _verifications = verifications;
        _isVerifying = false;
      });

      if (mounted) {
        final validCount = verifications.where((v) => v.isValid).length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification complete: $validCount/${verifications.length} valid'),
            backgroundColor: validCount == verifications.length ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Verification failed: $e';
        _isVerifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(FontAwesomeIcons.shieldHalved, size: 16, color: Colors.red),
            ),
            const SizedBox(width: 12),
            const Text('Admin Console'),
          ],
        ),
      ),
      body: _loadingStats
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _buildContent(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: context.colors.error),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: context.textStyles.bodyLarge?.copyWith(color: context.colors.error),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadStats,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: AppSpacing.paddingMd,
      children: [
        _buildStatsCard(),
        const SizedBox(height: 24),
        _buildActionsCard(),
        if (_isMigrating) ...[
          const SizedBox(height: 24),
          _buildProgressCard(),
        ],
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildResultsCard(),
        ],
        if (_verifications.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildVerificationCard(),
        ],
        const SizedBox(height: 32),
        _buildWarningCard(),
      ],
    );
  }

  Widget _buildStatsCard() {
    final stats = _stats;
    if (stats == null) return const SizedBox.shrink();

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: context.colors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(FontAwesomeIcons.database, size: 20, color: context.colors.primary),
              const SizedBox(width: 12),
              Text(
                'Migration Status',
                style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _loadStats,
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatRow('Total Plans', stats.totalPlans.toString(), FontAwesomeIcons.layerGroup),
          const SizedBox(height: 12),
          _buildStatRow(
            'Migrated',
            stats.migratedPlans.toString(),
            FontAwesomeIcons.circleCheck,
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _buildStatRow(
            'Pending',
            stats.notMigratedPlans.toString(),
            FontAwesomeIcons.clock,
            color: stats.notMigratedPlans > 0 ? Colors.orange : Colors.grey,
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: stats.migrationProgress,
              minHeight: 8,
              backgroundColor: context.colors.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(
                stats.migrationProgress >= 1.0 ? Colors.green : context.colors.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(stats.migrationProgress * 100).toStringAsFixed(1)}% complete',
            style: context.textStyles.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? context.colors.onSurface),
        const SizedBox(width: 12),
        Text(label, style: context.textStyles.bodyMedium),
        const Spacer(),
        Text(
          value,
          style: context.textStyles.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildActionsCard() {
    final hasPending = (_stats?.notMigratedPlans ?? 0) > 0;

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: context.colors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(FontAwesomeIcons.gears, size: 20, color: context.colors.primary),
              const SizedBox(width: 12),
              Text(
                'Actions',
                style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isMigrating || !hasPending ? null : _runMigration,
              icon: _isMigrating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(FontAwesomeIcons.arrowsRotate, size: 16),
              label: Text(_isMigrating ? 'Migrating...' : 'Run Migration'),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.primary,
                foregroundColor: context.colors.onPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isVerifying || _results.isEmpty ? null : _verifyMigrations,
              icon: _isVerifying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(FontAwesomeIcons.clipboardCheck, size: 16),
              label: Text(_isVerifying ? 'Verifying...' : 'Verify Migrations'),
            ),
          ),
          if (!hasPending) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(FontAwesomeIcons.circleCheck, size: 16, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'All plans have been migrated!',
                      style: context.textStyles.bodyMedium?.copyWith(color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: context.colors.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.colors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                'Migration in Progress',
                style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _totalCount > 0 ? _migratedCount / _totalCount : 0,
              minHeight: 12,
              backgroundColor: context.colors.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Migrated $_migratedCount of $_totalCount plans',
            style: context.textStyles.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildResultsCard() {
    final successCount = _results.where((r) => r.success).length;
    final failedCount = _results.length - successCount;

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: context.colors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(FontAwesomeIcons.listCheck, size: 20, color: context.colors.primary),
              const SizedBox(width: 12),
              Text(
                'Results',
                style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: failedCount == 0 ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$successCount/${_results.length} success',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: failedCount == 0 ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final result = _results[index];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    result.success ? FontAwesomeIcons.circleCheck : FontAwesomeIcons.circleXmark,
                    size: 16,
                    color: result.success ? Colors.green : Colors.red,
                  ),
                  title: Text(
                    result.planId,
                    style: context.textStyles.bodySmall?.copyWith(fontFamily: 'monospace'),
                  ),
                  subtitle: Text(
                    result.message,
                    style: context.textStyles.bodySmall?.copyWith(color: Colors.grey),
                  ),
                  trailing: result.success
                      ? Text(
                          '+${result.versionsCreated}v/${result.daysCreated}d',
                          style: context.textStyles.bodySmall?.copyWith(color: Colors.green),
                        )
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationCard() {
    final validCount = _verifications.where((v) => v.isValid).length;

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: context.colors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(FontAwesomeIcons.clipboardCheck, size: 20, color: context.colors.primary),
              const SizedBox(width: 12),
              Text(
                'Verification Results',
                style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: validCount == _verifications.length
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$validCount/${_verifications.length} valid',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: validCount == _verifications.length ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _verifications.length,
              itemBuilder: (context, index) {
                final verification = _verifications[index];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    verification.isValid ? FontAwesomeIcons.circleCheck : FontAwesomeIcons.triangleExclamation,
                    size: 16,
                    color: verification.isValid ? Colors.green : Colors.orange,
                  ),
                  title: Text(
                    verification.planId,
                    style: context.textStyles.bodySmall?.copyWith(fontFamily: 'monospace'),
                  ),
                  subtitle: verification.issues.isNotEmpty
                      ? Text(
                          verification.issues.join(', '),
                          style: context.textStyles.bodySmall?.copyWith(color: Colors.orange),
                        )
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningCard() {
    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(FontAwesomeIcons.triangleExclamation, size: 20, color: Colors.orange),
              const SizedBox(width: 12),
              Text(
                'Important Notes',
                style: context.textStyles.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '• Migration creates subcollection documents from flat documents\n'
            '• Original documents are preserved for backwards compatibility\n'
            '• Run verification after migration to ensure data integrity\n'
            '• This is a one-time operation per plan',
            style: context.textStyles.bodyMedium,
          ),
        ],
      ),
    );
  }
}
