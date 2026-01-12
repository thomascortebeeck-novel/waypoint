import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/services/order_service.dart';
import 'package:waypoint/theme.dart';

/// Full-page checkout screen following e-commerce best practices
class CheckoutScreen extends StatefulWidget {
  final Plan plan;
  final String buyerId;

  const CheckoutScreen({
    super.key,
    required this.plan,
    required this.buyerId,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final OrderService _orderService = OrderService();
  bool _isProcessing = false;

  bool get _isFree => widget.plan.basePrice == 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: const Text('Checkout'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Plan info header
                    _buildPlanHeader(context),
                    const SizedBox(height: 32),

                    // Order summary
                    _buildOrderSummary(context),
                    const SizedBox(height: 24),

                    // What's included
                    _buildWhatsIncluded(context),
                    const SizedBox(height: 24),

                    // Free/Paid info banner
                    if (_isFree)
                      _buildFreeBanner(context)
                    else
                      _buildSecureBanner(context),
                  ],
                ),
              ),
            ),

            // Bottom action bar
            _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: widget.plan.heroImageUrl,
            width: 100,
            height: 100,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: Colors.grey.shade200),
            errorWidget: (_, __, ___) => Container(
              color: Colors.grey.shade200,
              child: const Icon(Icons.image, color: Colors.grey),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.plan.name,
                style: context.textStyles.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.plan.location,
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'By ${widget.plan.creatorName}',
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderSummary(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.colors.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildSummaryRow(
                  context,
                  'Adventure Plan',
                  widget.plan.name,
                  isTitle: true,
                ),
                const SizedBox(height: 12),
                _buildSummaryRow(
                  context,
                  'Versions Included',
                  '${widget.plan.versions.length} version${widget.plan.versions.length != 1 ? 's' : ''}',
                ),
                const SizedBox(height: 12),
                _buildSummaryRow(
                  context,
                  'Location',
                  widget.plan.location,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.colors.outline),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(11),
                bottomRight: Radius.circular(11),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: context.textStyles.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    if (_isFree)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'FREE',
                          style: context.textStyles.labelSmall?.copyWith(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Text(
                      _isFree ? 'Free' : '€${widget.plan.basePrice.toStringAsFixed(2)}',
                      style: context.textStyles.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _isFree ? Colors.green.shade700 : context.colors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context, String label, String value, {bool isTitle = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.textStyles.bodyMedium?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            style: context.textStyles.bodyMedium?.copyWith(
              fontWeight: isTitle ? FontWeight.w600 : FontWeight.normal,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildWhatsIncluded(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: context.colors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'What\'s Included',
                style: context.textStyles.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildIncludedItem(context, Icons.map_outlined, 'Complete day-by-day itinerary'),
          _buildIncludedItem(context, Icons.location_on_outlined, 'GPS waypoints & navigation'),
          _buildIncludedItem(context, Icons.photo_library_outlined, 'Photos & location details'),
          _buildIncludedItem(context, Icons.inventory_2_outlined, 'Packing lists & tips'),
          _buildIncludedItem(context, Icons.all_inclusive, 'Access to all ${widget.plan.versions.length} version${widget.plan.versions.length != 1 ? 's' : ''}'),
          _buildIncludedItem(context, Icons.update, 'Future updates included'),
        ],
      ),
    );
  }

  Widget _buildIncludedItem(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: context.textStyles.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.celebration, color: Colors.green.shade700, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No payment required!',
                  style: context.textStyles.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Get instant access to this adventure guide. No credit card needed.',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecureBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, color: context.colors.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure Payment',
                  style: context.textStyles.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your payment is protected by industry-standard encryption.',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: context.colors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _processCheckout,
              child: _isProcessing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _isFree ? 'Get Free Access' : 'Complete Purchase',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'By continuing, you agree to our Terms of Service',
            style: context.textStyles.bodySmall?.copyWith(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _processCheckout() async {
    setState(() => _isProcessing = true);

    try {
      // Create order
      final order = await _orderService.createOrder(
        planId: widget.plan.id,
        buyerId: widget.buyerId,
        sellerId: widget.plan.creatorId,
        amount: widget.plan.basePrice,
      );

      // Set to processing
      await _orderService.setOrderProcessing(order.id);

      // Simulate payment processing
      await Future.delayed(Duration(seconds: _isFree ? 1 : 2));

      // Complete the order
      await _orderService.completeOrder(order.id);

      if (mounted) {
        // Navigate to thank you page
        context.go('/checkout/success/${widget.plan.id}', extra: {
          'orderId': order.id,
          'planName': widget.plan.name,
          'isFree': _isFree,
        });
      }
    } catch (e) {
      if (mounted) {
        // Navigate to error page
        context.go('/checkout/error/${widget.plan.id}', extra: {
          'errorMessage': e.toString(),
          'planName': widget.plan.name,
        });
      }
    }
  }
}
