import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Legacy packing screen - now redirects to personal member packing
/// 
/// This screen previously showed a shared packing checklist stored in the trip document.
/// It's now replaced by MemberPackingScreen which provides individual packing progress
/// per member using the member_packing subcollection.
class ItineraryPackScreen extends StatefulWidget {
  final String planId;
  final String tripId;
  const ItineraryPackScreen({super.key, required this.planId, required this.tripId});

  @override
  State<ItineraryPackScreen> createState() => _ItineraryPackScreenState();
}

class _ItineraryPackScreenState extends State<ItineraryPackScreen> {
  @override
  void initState() {
    super.initState();
    // Redirect to personal packing screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.go('/trip/${widget.tripId}/packing');
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while redirecting
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

// Legacy classes removed - packing now uses MemberPackingScreen with individual progress
