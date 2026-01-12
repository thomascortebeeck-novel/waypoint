import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/theme.dart';

/// Full-page error screen after failed checkout
class CheckoutErrorScreen extends StatelessWidget {
  final String planId;
  final String? errorMessage;
  final String? planName;

  const CheckoutErrorScreen({
    super.key,
    required this.planId,
    this.errorMessage,
    this.planName,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go('/details/$planId');
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Error icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline,
                    size: 80,
                    color: Colors.red.shade600,
                  ),
                ),

                const SizedBox(height: 40),

                // Error message
                Text(
                  'Something Went Wrong',
                  style: context.textStyles.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'We couldn\'t complete your purchase for "${planName ?? 'this adventure'}". Please try again.',
                    style: context.textStyles.bodyLarge?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 24),

                // Error details
                if (errorMessage != null && errorMessage!.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: Colors.red.shade700,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _formatErrorMessage(errorMessage!),
                            style: context.textStyles.bodySmall?.copyWith(
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const Spacer(flex: 2),

                // Help section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.help_outline,
                        color: context.colors.primary,
                        size: 28,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Need Help?',
                        style: context.textStyles.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'If the problem persists, please check your internet connection or contact our support team.',
                        style: context.textStyles.bodyMedium?.copyWith(
                          color: context.colors.onSurface.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Action buttons
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () => context.go('/checkout/$planId'),
                        icon: const Icon(Icons.refresh, size: 20),
                        label: const Text(
                          'Try Again',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: TextButton(
                        onPressed: () => context.go('/details/$planId'),
                        child: Text(
                          'Back to Adventure',
                          style: TextStyle(
                            color: context.colors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.go('/'),
                      child: Text(
                        'Browse Other Adventures',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatErrorMessage(String error) {
    // Clean up common error prefixes
    String cleaned = error
        .replaceAll('[cloud_firestore/permission-denied]', '')
        .replaceAll('Exception:', '')
        .trim();

    if (cleaned.isEmpty) {
      return 'An unexpected error occurred.';
    }

    return cleaned;
  }
}
