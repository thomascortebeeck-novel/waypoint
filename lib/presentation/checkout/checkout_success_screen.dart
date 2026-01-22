import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waypoint/theme.dart';

/// Full-page success screen after successful checkout
class CheckoutSuccessScreen extends StatefulWidget {
  final String planId;
  final String? orderId;
  final String? planName;
  final bool isFree;
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
    
    // Check if user came from invite flow and auto-redirect after animation
    if (widget.returnToJoin && widget.inviteCode != null) {
      _scheduleAutoRedirect();
    }
  }

  void _scheduleAutoRedirect() {
    Future.delayed(const Duration(seconds: 2), () async {
      if (!mounted) return;
      
      final inviteCode = widget.inviteCode;
      debugPrint('CheckoutSuccessScreen: Auto-redirecting to join with inviteCode: $inviteCode');
      
      // Clear any pending invite code from storage
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('pending_invite_code');
      } catch (e) {
        debugPrint('CheckoutSuccessScreen: Failed to clear pending invite: $e');
      }
      
      if (!mounted) return;
      
      // Ensure we have a valid invite code before redirecting
      if (inviteCode != null && inviteCode.isNotEmpty) {
        debugPrint('CheckoutSuccessScreen: Navigating to /join/$inviteCode');
        context.go('/join/$inviteCode', extra: {'fromAuth': true});
      } else {
        debugPrint('CheckoutSuccessScreen: No invite code, going to explore');
        context.go('/');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go('/');
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Success animation
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

                // Success message
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      Text(
                        widget.isFree ? 'You\'re All Set!' : 'Purchase Complete!',
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
                if (widget.returnToJoin && widget.inviteCode != null)
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
                              'Redirecting you to join the trip...',
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
                      // Show "Join Trip" button if user came from invite flow
                      if (widget.returnToJoin && widget.inviteCode != null) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              debugPrint('CheckoutSuccessScreen: Manual navigation to /join/${widget.inviteCode}');
                              context.go('/join/${widget.inviteCode}', extra: {'fromAuth': true});
                            },
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
        ),
      ),
    );
  }
}
