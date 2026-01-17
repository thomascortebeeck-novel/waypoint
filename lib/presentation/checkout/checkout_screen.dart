import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/services/order_service.dart';
import 'package:waypoint/theme.dart';

/// Modern, professional checkout screen with two-column layout
class CheckoutScreen extends StatefulWidget {
  final Plan plan;
  final String buyerId;
  final bool returnToJoin;
  final String? inviteCode;

  const CheckoutScreen({
    super.key,
    required this.plan,
    required this.buyerId,
    this.returnToJoin = false,
    this.inviteCode,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final OrderService _orderService = OrderService();
  bool _isProcessing = false;
  final ScrollController _scrollController = ScrollController();

  bool get _isFree => widget.plan.basePrice == 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final isTablet = MediaQuery.of(context).size.width >= 768 && MediaQuery.of(context).size.width < 1024;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: const Text('Checkout'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          if (isDesktop || isTablet)
            _buildDesktopLayout()
          else
            _buildMobileLayout(),
          
          // Mobile sticky bottom bar
          if (isMobile)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildMobileBottomBar(),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          padding: const EdgeInsets.all(32),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column (60%)
              Expanded(
                flex: 60,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEnhancedPlanPreview(),
                    const SizedBox(height: 24),
                    _buildWhatsIncludedSection(),
                    const SizedBox(height: 24),
                    _buildTrustSignalsSection(),
                    const SizedBox(height: 24),
                    _buildFAQSection(),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              // Right column (40%, sticky)
              Expanded(
                flex: 40,
                child: _buildStickyOrderSummary(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOrderSummaryCard(mobile: true),
          const SizedBox(height: 24),
          _buildEnhancedPlanPreview(),
          const SizedBox(height: 24),
          _buildWhatsIncludedSection(),
          const SizedBox(height: 24),
          _buildTrustSignalsSection(),
          const SizedBox(height: 24),
          _buildFAQSection(),
        ],
      ),
    );
  }

  Widget _buildEnhancedPlanPreview() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Image with Price Badge
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: CachedNetworkImage(
                  imageUrl: widget.plan.heroImageUrl,
                  width: double.infinity,
                  height: 300,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    height: 300,
                    color: Colors.grey.shade200,
                  ),
                  errorWidget: (_, __, ___) => Container(
                    height: 300,
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Icon(Icons.image, size: 80, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              // Price Badge
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: _isFree ? Colors.green.shade600 : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    _isFree ? 'FREE' : '€${widget.plan.basePrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _isFree ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Badges
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (widget.plan.activityCategory != null)
                      _buildCategoryBadge(
                        _getActivityCategoryLabel(widget.plan.activityCategory!),
                        Icons.hiking_outlined,
                      ),
                    if (widget.plan.accommodationType != null)
                      _buildCategoryBadge(
                        _getAccommodationTypeLabel(widget.plan.accommodationType!),
                        Icons.hotel_outlined,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Plan Title
                Text(
                  widget.plan.name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Location
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.plan.location,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Stats Row
                if (widget.plan.versions.isNotEmpty)
                  Wrap(
                    spacing: 24,
                    runSpacing: 8,
                    children: [
                      _buildStatItem(
                        Icons.calendar_today_outlined,
                        '${widget.plan.versions.first.durationDays} days',
                      ),
                      _buildStatItem(
                        Icons.layers_outlined,
                        '${widget.plan.versions.length} version${widget.plan.versions.length != 1 ? 's' : ''}',
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                
                // Rating (placeholder - can be updated when real ratings exist)
                Row(
                  children: [
                    ...List.generate(5, (index) => const Icon(
                      Icons.star,
                      size: 16,
                      color: Color(0xFFFFB020),
                    )),
                    const SizedBox(width: 8),
                    const Text(
                      '4.8',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(${widget.plan.salesCount} purchases)',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Creator Info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.grey.shade300,
                      child: Text(
                        widget.plan.creatorName.isNotEmpty 
                          ? widget.plan.creatorName[0].toUpperCase() 
                          : 'U',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'By ${widget.plan.creatorName}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
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

  Widget _buildCategoryBadge(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF428A13).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF428A13).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF428A13)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF428A13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildWhatsIncludedSection() {
    final features = [
      _FeatureItem(
        icon: Icons.map_outlined,
        title: 'Complete day-by-day itinerary',
        description: 'Detailed route with all stops',
      ),
      _FeatureItem(
        icon: Icons.location_on_outlined,
        title: 'GPS waypoints & navigation',
        description: 'Never get lost on your adventure',
      ),
      _FeatureItem(
        icon: Icons.photo_library_outlined,
        title: 'Photos & location details',
        description: 'Visual guides for every location',
      ),
      _FeatureItem(
        icon: Icons.inventory_2_outlined,
        title: 'Packing lists & tips',
        description: 'Everything you need to bring',
      ),
      _FeatureItem(
        icon: Icons.all_inclusive,
        title: 'Access to all ${widget.plan.versions.length} version${widget.plan.versions.length != 1 ? 's' : ''}',
        description: 'Choose your difficulty level',
      ),
      _FeatureItem(
        icon: Icons.update,
        title: 'Future updates included',
        description: 'Get improvements at no extra cost',
      ),
      _FeatureItem(
        icon: Icons.cloud_off_outlined,
        title: 'Offline access',
        description: 'Works without internet',
      ),
      _FeatureItem(
        icon: Icons.devices_outlined,
        title: 'Mobile & desktop compatible',
        description: 'Access anywhere',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.green.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'What\'s Included',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width >= 768 ? 2 : 1,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 3.5,
            ),
            itemCount: features.length,
            itemBuilder: (context, index) => _buildFeatureCard(features[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(_FeatureItem feature) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(
            feature.icon,
            size: 24,
            color: const Color(0xFF428A13),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  feature.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (feature.description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    feature.description!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustSignalsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: MediaQuery.of(context).size.width >= 768 ? 2 : 1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 5,
        children: [
          _buildTrustSignal(
            Icons.lock_outline,
            'Secure checkout - Your data is protected',
          ),
          _buildTrustSignal(
            Icons.shield_outlined,
            _isFree ? 'No payment required' : '30-day money-back guarantee',
          ),
          _buildTrustSignal(
            Icons.headset_mic_outlined,
            '24/7 customer support available',
          ),
          _buildTrustSignal(
            Icons.people_outline,
            'Join ${widget.plan.salesCount + 50000}+ adventurers',
          ),
        ],
      ),
    );
  }

  Widget _buildTrustSignal(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF428A13)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildFAQSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Questions?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _buildFAQItem(
            'How do I access my plan after purchase?',
            'You\'ll get instant access. Find it in "My Trips" section.',
          ),
          _buildFAQItem(
            'Can I share this with others?',
            'Yes! Invite friends to join your trip and collaborate.',
          ),
          _buildFAQItem(
            'What if I need help during my trip?',
            'Our support team is available 24/7 to assist you.',
          ),
          _buildFAQItem(
            'Do I get updates?',
            'Yes! All future updates are included at no extra cost.',
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              // TODO: Open support chat or email
            },
            child: const Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 18,
                  color: Color(0xFF428A13),
                ),
                SizedBox(width: 8),
                Text(
                  'Still have questions? Contact support',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF428A13),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            answer,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyOrderSummary() {
    return _buildOrderSummaryCard(mobile: false);
  }

  Widget _buildOrderSummaryCard({required bool mobile}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Order Summary',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          
          // Plan Summary Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: widget.plan.heroImageUrl,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey.shade200,
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image, size: 30),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.plan.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.plan.location,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          Divider(color: Colors.grey.shade200),
          const SizedBox(height: 16),
          
          // Versions Included
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Versions Included',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              Text(
                'All ${widget.plan.versions.length} version${widget.plan.versions.length != 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          Divider(color: Colors.grey.shade200),
          const SizedBox(height: 16),
          
          // Price Breakdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Subtotal',
                style: TextStyle(fontSize: 16),
              ),
              Text(
                _isFree ? 'FREE' : '€${widget.plan.basePrice.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Total Row
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFBFA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _isFree ? 'FREE' : '€${widget.plan.basePrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: _isFree ? Colors.green.shade700 : const Color(0xFF428A13),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Free Plan Banner
          if (_isFree)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF10B981)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.celebration,
                    size: 24,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No payment required!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF047857),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Get instant access. No credit card needed.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF065F46),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          
          if (_isFree) const SizedBox(height: 20),
          
          // CTA Button
          if (!mobile)
            _buildCTAButton(),
          
          const SizedBox(height: 16),
          
          // Legal Text
          Text(
            'By continuing, you agree to our Terms of Service',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          // Security Badges
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 20, color: Colors.grey.shade400),
              const SizedBox(width: 8),
              Icon(Icons.shield_outlined, size: 20, color: Colors.grey.shade400),
              const SizedBox(width: 8),
              Icon(Icons.verified_user_outlined, size: 20, color: Colors.grey.shade400),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCTAButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _processCheckout,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF428A13),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          shadowColor: const Color(0xFF428A13).withValues(alpha: 0.3),
        ),
        child: _isProcessing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isFree ? 'Get Free Access' : 'Complete Purchase',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isFree ? Icons.arrow_forward : Icons.lock_open,
                    size: 20,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildMobileBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Price Display
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  _isFree ? 'FREE' : '€${widget.plan.basePrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _isFree ? Colors.green.shade700 : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            // CTA Button
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _processCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF428A13),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isFree ? 'Get Free Access' : 'Purchase',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processCheckout() async {
    setState(() => _isProcessing = true);

    try {
      final order = await _orderService.createOrder(
        planId: widget.plan.id,
        buyerId: widget.buyerId,
        sellerId: widget.plan.creatorId,
        amount: widget.plan.basePrice,
      );

      await _orderService.setOrderProcessing(order.id);
      await Future.delayed(Duration(seconds: _isFree ? 1 : 2));
      await _orderService.completeOrder(order.id);

      if (mounted) {
        context.go('/checkout/success/${widget.plan.id}', extra: {
          'orderId': order.id,
          'planName': widget.plan.name,
          'isFree': _isFree,
          'returnToJoin': widget.returnToJoin,
          'inviteCode': widget.inviteCode,
        });
      }
    } catch (e) {
      if (mounted) {
        context.go('/checkout/error/${widget.plan.id}', extra: {
          'errorMessage': e.toString(),
          'planName': widget.plan.name,
        });
      }
    }
  }

  String _getActivityCategoryLabel(ActivityCategory category) {
    switch (category) {
      case ActivityCategory.hiking:
        return 'Hiking';
      case ActivityCategory.cycling:
        return 'Cycling';
      case ActivityCategory.skis:
        return 'Skiing';
      case ActivityCategory.climbing:
        return 'Climbing';
      case ActivityCategory.cityTrips:
        return 'City Trips';
      case ActivityCategory.tours:
        return 'Tours';
      default:
        return 'Adventure';
    }
  }

  String _getAccommodationTypeLabel(AccommodationType type) {
    switch (type) {
      case AccommodationType.comfort:
        return 'Comfort Stay';
      case AccommodationType.adventure:
        return 'Adventure';
      default:
        return 'Accommodation';
    }
  }
}

class _FeatureItem {
  final IconData icon;
  final String title;
  final String? description;

  _FeatureItem({
    required this.icon,
    required this.title,
    this.description,
  });
}
