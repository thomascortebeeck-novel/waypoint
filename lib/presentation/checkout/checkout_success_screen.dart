import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/services/invite_service.dart';
import 'package:waypoint/services/order_service.dart';
import 'package:waypoint/services/trip_service.dart';
import 'package:waypoint/theme.dart';

/// Full-page success screen after successful checkout
class CheckoutSuccessScreen extends StatefulWidget {
  final String planId;
  final String? orderId;
  final String? planName;
  final bool isFree;
  /// True when createPaymentIntent returned alreadyPurchased
  final bool alreadyPurchased;
  /// If true, user came from invite flow and should return to join
  final bool returnToJoin;
  /// Invite code to redirect back to
  final String? inviteCode;

  const CheckoutSuccessScreen({
    super.key,
    required this.planId,
    this.orderId,
    this.planName,
    this.isFree = false,
    this.alreadyPurchased = false,
    this.returnToJoin = false,
    this.inviteCode,
  });

  @override
  State<CheckoutSuccessScreen> createState() => _CheckoutSuccessScreenState();
}

class _CheckoutSuccessScreenState extends State<CheckoutSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  final OrderService _orderService = OrderService();
  final InviteService _inviteService = InviteService();
  final TripService _tripService = TripService();
  bool _purchaseConfirmed = false;
  bool _timeoutReached = false;
  bool _joinStarted = false;
  bool _joinScheduled = false;
  bool _isJoiningTrip = false;
  String? _joinTripError;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();

    if (!widget.isFree && !widget.alreadyPurchased) {
      Future.delayed(const Duration(seconds: 30), () {
        if (mounted) setState(() => _timeoutReached = true);
      });
    }
  }

  /// Join the trip and go straight to trip detail (one redirect, no intermediate join page).
  Future<void> _joinAndGoToTrip() async {
    if (_joinStarted) return;
    final inviteCode = widget.inviteCode;
    if (inviteCode == null || inviteCode.isEmpty) {
      if (mounted) context.go('/');
      return;
    }

    _joinStarted = true;
    if (mounted) setState(() {
      _isJoiningTrip = true;
      _joinTripError = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_invite_code');
    } catch (_) {}

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || !mounted) return;

    final result = await _inviteService.validateInvite(inviteCode, userId);
    if (!mounted) return;

    if (result.status != InviteStatus.valid) {
      setState(() {
        _isJoiningTrip = false;
        _joinTripError = result.errorMessage ?? 'Could not join trip';
      });
      return;
    }

    final trip = result.trip!;
    final plan = result.plan;

    try {
      await _inviteService.processInvite(inviteCode, userId);
      if (plan != null && trip.versionId != null) {
        final version = plan.versions.firstWhere(
          (v) => v.id == trip.versionId,
          orElse: () => plan.versions.first,
        );
        final allItemIds = <String>[];
        for (final category in version.packingCategories) {
          for (final item in category.items) allItemIds.add(item.id);
        }
        if (allItemIds.isNotEmpty) {
          await _tripService.initializeMemberPacking(
            tripId: trip.id,
            memberId: userId,
            itemIds: allItemIds,
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() {
        _isJoiningTrip = false;
        _joinTripError = e.toString();
      });
      return;
    }

    if (!mounted) return;
    context.go('/trip/${trip.id}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isPaidWaiting => !widget.isFree && !widget.alreadyPurchased;

  @override
  Widget build(BuildContext context) {
    if (_isPaidWaiting) {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) context.go('/');
        },
        child: Scaffold(
          body: SafeArea(
            child: StreamBuilder<bool>(
              stream: uid.isEmpty ? null : _orderService.streamPurchaseStatus(uid, widget.planId),
              builder: (context, snapshot) {
                if (snapshot.data == true && !_purchaseConfirmed) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _purchaseConfirmed = true);
                  });
                }
                if (_purchaseConfirmed) return _buildSuccessContent();
                if (_timeoutReached) return _buildTimeoutFallback();
                return _buildConfirming();
              },
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go('/');
        }
      },
      child: Scaffold(
        body: SafeArea(child: _buildSuccessContent()),
      ),
    );
  }

  Widget _buildConfirming() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(),
            ),
            const SizedBox(height: 24),
            Text(
              'Confirming your purchase…',
              style: context.textStyles.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your plan will be available in a moment.',
              style: context.textStyles.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeoutFallback() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade600),
          const SizedBox(height: 24),
          Text(
            'Payment received',
            style: context.textStyles.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Your plan will be available shortly. Check your purchases in My Trips.',
            style: context.textStyles.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => context.go('/mytrips'),
              icon: const Icon(Icons.list, size: 20),
              label: const Text(
                'Go to My Trips',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.go('/details/${widget.planId}'),
            child: Text(
              'View adventure details',
              style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessContent() {
    // One-shot: after purchase with invite, join trip and go straight to trip detail
    if (widget.returnToJoin && widget.inviteCode != null && !_joinStarted && !_joinScheduled) {
      _joinScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _joinAndGoToTrip());
    }

    final title = widget.alreadyPurchased
        ? 'You already own this plan'
        : (widget.isFree ? 'You\'re All Set!' : 'Purchase Complete!');

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
        children: [
          const Spacer(flex: 2),

          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    size: 80,
                    color: Colors.green.shade600,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 40),

          FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                Text(
                  title,
                  style: context.textStyles.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'You now have full access to "${widget.planName ?? 'this adventure'}". Start exploring and plan your next trip!',
                    style: context.textStyles.bodyLarge?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

                const SizedBox(height: 24),

                // Invite flow notification
                if (widget.returnToJoin && widget.inviteCode != null && !_isJoiningTrip && _joinTripError == null)
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Adding you to the trip…',
                              style: context.textStyles.bodyMedium?.copyWith(
                                color: Colors.blue.shade900,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Order confirmation
                if (widget.orderId != null)
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: context.colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.confirmation_number_outlined,
                            size: 18,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Order #${widget.orderId!.length > 8 ? widget.orderId!.substring(0, 8).toUpperCase() : widget.orderId!.toUpperCase()}',
                            style: context.textStyles.bodyMedium?.copyWith(
                              fontFamily: 'monospace',
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const Spacer(flex: 2),

                // What's next section
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: context.colors.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: context.colors.primary,
                          size: 28,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'What\'s Next?',
                          style: context.textStyles.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Choose a version that fits your schedule, explore the detailed itinerary, and start your adventure!',
                          style: context.textStyles.bodyMedium?.copyWith(
                            color: context.colors.onSurface.withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Action buttons
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      // Show "Join Trip" button if user came from invite flow (only when not auto-joining and no error yet)
                      if (widget.returnToJoin && widget.inviteCode != null && !_isJoiningTrip && _joinTripError == null) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: () => context.go('/join/${widget.inviteCode}', extra: {'fromAuth': true}),
                            icon: const Icon(Icons.group_add, size: 20),
                            label: const Text(
                              'Continue to Join Trip',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: TextButton(
                            onPressed: () => context.go('/itinerary/${widget.planId}/new'),
                            child: Text(
                              'Start Your Own Adventure Instead',
                              style: TextStyle(
                                color: context.colors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: () => context.go('/itinerary/${widget.planId}/new'),
                            icon: const Icon(Icons.explore, size: 20),
                            label: const Text(
                              'Start Adventure',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: TextButton(
                            onPressed: () => context.go('/details/${widget.planId}'),
                            child: Text(
                              'View Adventure Details',
                              style: TextStyle(
                                color: context.colors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => context.go('/'),
                        child: Text(
                          'Browse More Adventures',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
        ),
        if (_isJoiningTrip)
          Container(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Adding you to the trip…',
                    style: context.textStyles.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_joinTripError != null && !_isJoiningTrip)
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _joinTripError!,
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => context.go('/join/${widget.inviteCode}', extra: {'fromAuth': true}),
                      child: const Text('Continue to Join Trip'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
