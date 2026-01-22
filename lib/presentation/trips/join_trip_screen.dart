import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waypoint/auth/firebase_auth_manager.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/trip_model.dart';
import 'package:waypoint/models/user_model.dart';
import 'package:waypoint/services/invite_service.dart';
import 'package:waypoint/services/user_service.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/services/trip_service.dart';
import 'package:waypoint/theme.dart';

/// Screen for joining a trip via invite code
class JoinTripScreen extends StatefulWidget {
  final String inviteCode;
  /// If true, user was just redirected here after authentication
  final bool fromAuthRedirect;
  
  const JoinTripScreen({
    super.key,
    required this.inviteCode,
    this.fromAuthRedirect = false,
  });

  @override
  State<JoinTripScreen> createState() => _JoinTripScreenState();
}

class _JoinTripScreenState extends State<JoinTripScreen> {
  final InviteService _inviteService = InviteService();
  final UserService _userService = UserService();
  final FirebaseAuthManager _auth = FirebaseAuthManager();
  
  bool _isLoading = true;
  bool _isJoining = false;
  InviteValidationResult? _validationResult;
  List<UserModel> _members = [];
  UserModel? _owner;

  @override
  void initState() {
    super.initState();
    _validateInvite();
    
    // Auto-process invite if user just authenticated and plan already owned
    if (widget.fromAuthRedirect) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoProcessIfReady());
    }
  }

  Future<void> _autoProcessIfReady() async {
    // Wait for validation to complete
    while (_isLoading) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    if (_validationResult?.status == InviteStatus.valid) {
      // User authenticated and owns the plan - auto join
      await _joinTrip();
    } else if (_validationResult?.status == InviteStatus.planNotOwned) {
      // User authenticated but doesn't own the plan - show purchase screen
      // The UI will automatically show the "needs purchase" state
    }
  }

  Future<void> _validateInvite() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    debugPrint('JoinTripScreen: Validating invite code: ${widget.inviteCode}, userId: $userId');
    
    if (userId == null) {
      debugPrint('JoinTripScreen: No user logged in, showing sign-in required');
      setState(() => _isLoading = false);
      return;
    }

    final result = await _inviteService.validateInvite(widget.inviteCode, userId);
    debugPrint('JoinTripScreen: Validation result: ${result.status}, error: ${result.errorMessage}');
    
    // Fetch member details if we have a trip
    if (result.trip != null) {
      _members = await _inviteService.getMembersDetails(result.trip!.id);
      _owner = await _userService.getUserById(result.trip!.ownerId);
    }
    
    if (mounted) {
      setState(() {
        _validationResult = result;
        _isLoading = false;
      });
    }
  }

  Future<void> _joinTrip() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || _validationResult?.trip == null) return;

    setState(() => _isJoining = true);
    
    try {
      await _inviteService.processInvite(widget.inviteCode, userId);
      
      // Initialize member packing for the new member
      final trip = _validationResult!.trip!;
      final plan = _validationResult!.plan;
      if (plan != null && trip.versionId != null) {
        final version = plan.versions.firstWhere(
          (v) => v.id == trip.versionId,
          orElse: () => plan.versions.first,
        );
        
        // Gather all packing item IDs
        final allItemIds = <String>[];
        for (final category in version.packingCategories) {
          for (final item in category.items) {
            allItemIds.add(item.id);
          }
        }
        
        if (allItemIds.isNotEmpty) {
          await TripService().initializeMemberPacking(
            tripId: trip.id,
            memberId: userId,
            itemIds: allItemIds,
          );
        }
      }
      
      if (mounted) {
        // Navigate to the trip
        context.go('/itinerary/${trip.planId}/setup/${trip.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join trip: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  void _navigateToPurchase() {
    final trip = _validationResult?.trip;
    if (trip == null) return;
    
    // Navigate to checkout with return info
    context.push(
      '/checkout/${trip.planId}',
      extra: {
        'plan': _validationResult?.plan,
        'returnToJoin': true,
        'inviteCode': widget.inviteCode,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : userId == null
                ? _buildSignInRequired()
                : _buildContent(),
      ),
    );
  }

  Widget _buildSignInRequired() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: context.colors.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Sign In Required',
              style: context.textStyles.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Please sign in to join this trip',
              style: context.textStyles.bodyLarge?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => _showAuthSheet(isSignUp: false),
              icon: const Icon(Icons.login),
              label: const Text('Sign In'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _showAuthSheet(isSignUp: true),
              icon: const Icon(Icons.person_add),
              label: const Text('Create Account'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAuthSheet({required bool isSignUp}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _JoinTripAuthSheet(
        isSignUp: isSignUp,
        auth: _auth,
        onAuthSuccess: _handleAuthSuccess,
      ),
    );
  }

  Future<void> _handleAuthSuccess() async {
    debugPrint('JoinTripScreen: Auth success, re-validating invite');
    // Re-validate the invite now that user is logged in
    setState(() => _isLoading = true);
    await _validateInvite();
    
    // Auto-process if valid
    if (_validationResult?.status == InviteStatus.valid) {
      await _joinTrip();
    }
  }

  Widget _buildContent() {
    if (_validationResult == null) {
      return _buildError('Failed to validate invite');
    }

    switch (_validationResult!.status) {
      case InviteStatus.valid:
        return _buildReadyToJoin();
      case InviteStatus.alreadyMember:
        return _buildAlreadyMember();
      case InviteStatus.planNotOwned:
        return _buildNeedsPurchase();
      case InviteStatus.groupFull:
        return _buildGroupFull();
      case InviteStatus.invalid:
      case InviteStatus.tripCancelled:
        return _buildError(_validationResult!.errorMessage ?? 'Invalid invite');
    }
  }

  Widget _buildReadyToJoin() {
    final trip = _validationResult!.trip!;
    final plan = _validationResult!.plan!;
    final remainingSpots = trip.getRemainingSpots(plan);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Close button
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.close),
            ),
          ),
          const SizedBox(height: 16),
          
          // Trip image
          _buildTripImage(trip, plan),
          const SizedBox(height: 24),
          
          // Trip title
          Text(
            trip.title ?? plan.name,
            style: context.textStyles.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          
          // Plan name
          Text(
            plan.name,
            style: context.textStyles.bodyLarge?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // Owner info
          if (_owner != null) _buildOwnerInfo(),
          const SizedBox(height: 24),
          
          // Members preview
          if (_members.isNotEmpty) _buildMembersPreview(),
          const SizedBox(height: 16),
          
          // Spots remaining
          if (remainingSpots != null) ...[
            _buildSpotsInfo(remainingSpots, plan.maxGroupSize!),
            const SizedBox(height: 24),
          ],
          
          // Join button
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _isJoining ? null : _joinTrip,
              icon: _isJoining
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.group_add),
              label: Text(_isJoining ? 'Joining...' : 'Join Trip'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlreadyMember() {
    final trip = _validationResult!.trip!;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                size: 64,
                color: Colors.blue.shade600,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Already a Member',
              style: context.textStyles.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You\'re already part of this trip!',
              style: context.textStyles.bodyLarge?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.go('/itinerary/${trip.planId}/setup/${trip.id}'),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Go to Trip'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNeedsPurchase() {
    final plan = _validationResult!.plan!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Close button
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.close),
            ),
          ),
          const SizedBox(height: 16),
          
          // Info notification
          Container(
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
                    'Purchase this plan to join the trip. You\'ll be automatically redirected after checkout.',
                    style: context.textStyles.bodyMedium?.copyWith(
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Warning icon
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: Colors.orange.shade700,
            ),
          ),
          const SizedBox(height: 24),
          
          Text(
            'Plan Required',
            style: context.textStyles.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          
          Text(
            'You need to purchase "${plan.name}" to join this trip.',
            style: context.textStyles.bodyLarge?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          // Plan card preview
          _buildPlanPreview(plan),
          const SizedBox(height: 24),
          
          // Purchase button
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _navigateToPurchase,
              icon: const Icon(Icons.shopping_cart),
              label: Text(
                plan.basePrice == 0
                    ? 'Get Free Plan'
                    : 'Purchase for €${plan.basePrice.toStringAsFixed(2)}',
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          TextButton(
            onPressed: () => context.go('/'),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupFull() {
    final trip = _validationResult!.trip!;
    final plan = _validationResult!.plan!;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.group_off,
                size: 64,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Trip Full',
              style: context.textStyles.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This trip has reached its maximum of ${plan.maxGroupSize} members.',
              style: context.textStyles.bodyLarge?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.go('/details/${trip.planId}'),
              icon: const Icon(Icons.explore),
              label: const Text('Browse Plan'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Invalid Invite',
              style: context.textStyles.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: context.textStyles.bodyLarge?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.home),
              label: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripImage(Trip trip, Plan plan) {
    final imageUrl = trip.usePlanImage || trip.customImages == null
        ? plan.heroImageUrl
        : (trip.customImages!['large'] ?? trip.customImages!['original'] ?? plan.heroImageUrl);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: context.colors.surfaceContainerHighest),
          errorWidget: (_, __, ___) => Container(
            color: context.colors.surfaceContainerHighest,
            child: const Icon(Icons.image, size: 48),
          ),
        ),
      ),
    );
  }

  Widget _buildOwnerInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: _owner!.photoUrl != null
                ? CachedNetworkImageProvider(_owner!.photoUrl!)
                : null,
            child: _owner!.photoUrl == null
                ? Text(_owner!.displayName[0].toUpperCase())
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Created by',
                  style: context.textStyles.labelMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                Text(
                  _owner!.displayName,
                  style: context.textStyles.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Organizer',
              style: context.textStyles.labelSmall?.copyWith(
                color: context.colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersPreview() {
    const maxAvatars = 5;
    final showCount = _members.length > maxAvatars;
    final displayMembers = showCount ? _members.take(maxAvatars).toList() : _members;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_members.length} member${_members.length != 1 ? 's' : ''} so far',
          style: context.textStyles.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            ...displayMembers.asMap().entries.map((entry) {
              final index = entry.key;
              final member = entry.value;
              return Transform.translate(
                offset: Offset(-8.0 * index, 0),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.colors.surface,
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundImage: member.photoUrl != null
                        ? CachedNetworkImageProvider(member.photoUrl!)
                        : null,
                    child: member.photoUrl == null
                        ? Text(
                            member.displayName[0].toUpperCase(),
                            style: const TextStyle(fontSize: 12),
                          )
                        : null,
                  ),
                ),
              );
            }),
            if (showCount)
              Transform.translate(
                offset: Offset(-8.0 * maxAvatars, 0),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.colors.surfaceContainerHighest,
                    border: Border.all(
                      color: context.colors.surface,
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.transparent,
                    child: Text(
                      '+${_members.length - maxAvatars}',
                      style: context.textStyles.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSpotsInfo(int remaining, int total) {
    final fillPercentage = (total - remaining) / total;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: remaining <= 2 ? Colors.orange.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: remaining <= 2 ? Colors.orange.shade200 : Colors.green.shade200,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.group,
                color: remaining <= 2 ? Colors.orange.shade700 : Colors.green.shade700,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '$remaining of $total spots available',
                style: context.textStyles.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: remaining <= 2 ? Colors.orange.shade700 : Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fillPercentage,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(
                remaining <= 2 ? Colors.orange.shade400 : Colors.green.shade400,
              ),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanPreview(Plan plan) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.colors.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: CachedNetworkImage(
                imageUrl: plan.heroImageUrl,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.name,
                  style: context.textStyles.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: context.colors.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      plan.location,
                      style: context.textStyles.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
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
}

/// Auth sheet for join trip screen
class _JoinTripAuthSheet extends StatefulWidget {
  final bool isSignUp;
  final FirebaseAuthManager auth;
  final VoidCallback onAuthSuccess;

  const _JoinTripAuthSheet({
    required this.isSignUp,
    required this.auth,
    required this.onAuthSuccess,
  });

  @override
  State<_JoinTripAuthSheet> createState() => _JoinTripAuthSheetState();
}

class _JoinTripAuthSheetState extends State<_JoinTripAuthSheet> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late bool _isSignUp;
  bool _loading = false;
  bool _agreedToTerms = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.isSignUp;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isSignUp ? 'Create Account' : 'Sign In',
                    style: context.textStyles.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _isSignUp = !_isSignUp),
                    child: Text(
                      _isSignUp ? 'Have an account?' : 'Create account',
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: context.colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              if (_isSignUp) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'First Name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Last Name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              
              TextFormField(
                controller: _emailCtrl,
                autocorrect: false,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) => (v == null || v.isEmpty || !v.contains('@')) ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
              ),
              
              if (_isSignUp) ...[
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _agreedToTerms,
                            onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              text: 'I agree to the ',
                              style: context.textStyles.bodySmall,
                              children: [
                                TextSpan(
                                  text: 'Terms and Conditions',
                                  style: context.textStyles.bodySmall?.copyWith(
                                    color: context.colors.primary,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_isSignUp ? 'Create Account' : 'Sign In'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_isSignUp && !_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please agree to the Terms and Conditions'),
          backgroundColor: context.colors.error,
        ),
      );
      return;
    }
    
    setState(() => _loading = true);
    
    try {
      if (_isSignUp) {
        final user = await widget.auth.createAccountWithEmail(
          context,
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          agreedToTerms: _agreedToTerms,
          marketingOptIn: false,
        );
        
        if (user == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Failed to create account. Please try again.'),
                backgroundColor: context.colors.error,
              ),
            );
          }
          return;
        }
      } else {
        final user = await widget.auth.signInWithEmail(
          context,
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );
        
        if (user == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Incorrect email or password. Please try again.'),
                backgroundColor: context.colors.error,
              ),
            );
          }
          return;
        }
      }
      
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onAuthSuccess();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}
