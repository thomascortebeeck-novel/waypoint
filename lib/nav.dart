import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:waypoint/auth/firebase_auth_manager.dart';
import 'package:waypoint/presentation/marketplace/marketplace_screen.dart';
import 'package:waypoint/presentation/mytrips/my_trips_screen.dart';
import 'package:waypoint/presentation/mytrips/create_itinerary_screen.dart';
import 'package:waypoint/presentation/builder/builder_screen.dart' as builder;
import 'package:waypoint/presentation/builder/builder_home_screen.dart';
import 'package:waypoint/presentation/builder/edit_plan_screen.dart';
import 'package:waypoint/presentation/builder/route_builder_screen.dart';
import 'package:waypoint/presentation/profile/profile_screen.dart';
import 'package:waypoint/presentation/details/plan_details_screen.dart';
import 'package:waypoint/presentation/map/map_screen.dart';
import 'package:waypoint/presentation/tracking/tracking_screen.dart';
import 'package:waypoint/presentation/checkout/checkout_screen.dart';
import 'package:waypoint/presentation/checkout/checkout_success_screen.dart';
import 'package:waypoint/presentation/checkout/checkout_error_screen.dart';
import 'package:waypoint/presentation/itinerary/itinerary_setup_screen.dart';
import 'package:waypoint/presentation/trips/trip_details_screen.dart';
import 'package:waypoint/presentation/itinerary/itinerary_pack_screen.dart';
import 'package:waypoint/presentation/itinerary/itinerary_travel_screen.dart';
import 'package:waypoint/presentation/itinerary/itinerary_define_screen.dart';
import 'package:waypoint/presentation/itinerary/itinerary_day_screen.dart';
import 'package:waypoint/presentation/itinerary/itinerary_select_screen.dart';
import 'package:waypoint/presentation/itinerary/itinerary_review_screen.dart';
import 'package:waypoint/presentation/trips/member_packing_screen.dart';
import 'package:waypoint/presentation/mytrips/onboarding/onboarding_name_screen.dart';
import 'package:waypoint/presentation/mytrips/onboarding/onboarding_version_screen.dart';
import 'package:waypoint/presentation/mytrips/onboarding/onboarding_date_screen.dart';
import 'package:waypoint/presentation/mytrips/onboarding/onboarding_image_screen.dart';
import 'package:waypoint/presentation/trips/join_trip_screen.dart';
import 'package:waypoint/presentation/trips/trip_members_screen.dart';
import 'package:waypoint/presentation/trips/trip_day_map_fullscreen.dart';
import 'package:waypoint/presentation/admin/admin_migration_screen.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/models/plan_model.dart';
import 'theme.dart';
import 'package:waypoint/utils/logger.dart';

class AppRoutes {
  static const String marketplace = '/';
  static const String myTrips = '/mytrips';
  static const String builder = '/builder';
  static const String profile = '/profile';
  static const String planDetails = '/details/:planId';
  static const String map = '/map';
  static const String tracking = 'tracking';
  static const String checkout = '/checkout/:planId';
  static const String checkoutSuccess = '/checkout/success/:planId';
  static const String checkoutError = '/checkout/error/:planId';
  static const String itineraryNew = '/itinerary/:planId/new';
  static const String itinerarySetup = '/itinerary/:planId/setup/:tripId';
  static const String tripDetails = '/trip/:tripId';
  static const String itineraryPack = '/itinerary/:planId/pack/:tripId';
  static const String itineraryTravel = '/itinerary/:planId/travel/:tripId';
  static const String itineraryDay = '/itinerary/:planId/day/:tripId/:dayIndex';
  static const String itineraryDayMap = '/itinerary/:planId/day/:tripId/:dayIndex/map';
  // Trip customization routes
  static const String itinerarySelect = '/itinerary/:planId/select/:tripId';
  static const String itineraryReview = '/itinerary/:planId/review/:tripId';
  static const String memberPacking = '/trip/:tripId/packing';
  // Trip sharing routes
  static const String joinTrip = '/join/:inviteCode';
  static const String tripMembers = '/trip/:tripId/members';
  static const String adminMigration = '/admin/migration';
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

class AppRouter {
  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.marketplace,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/builder/create',
        redirect: (context, state) {
          // Create a temporary ID for new plans
          return '/builder/new';
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/builder/:planId',
        builder: (context, state) {
          final planId = state.pathParameters['planId'] ?? '';
          if (planId == 'new') {
            return const builder.BuilderScreen();
          }
          return builder.BuilderScreen(editPlanId: planId);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/builder/edit/:planId',
        redirect: (context, state) {
          final planId = state.pathParameters['planId'] ?? '';
          return '/builder/$planId';
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/builder/route-builder/:planId/:versionIndex/:dayNum',
        builder: (context, state) {
          final planId = state.pathParameters['planId'] ?? '';
          final versionIndex = state.pathParameters['versionIndex'] ?? '0';
          final dayNum = state.pathParameters['dayNum'] ?? '0';
          final extra = state.extra as Map<String, dynamic>?;
          return RouteBuilderScreen(
            planId: planId,
            versionIndex: versionIndex,
            dayNum: dayNum,
            start: extra?['start'],
            end: extra?['end'],
            initial: extra?['initial'],
            activityCategory: extra?['activityCategory'],
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/plan/:planId',
        redirect: (context, state) {
          final planId = state.pathParameters['planId'] ?? '';
          return '/details/$planId';
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/checkout/:planId',
        builder: (context, state) {
          final planId = state.pathParameters['planId'] ?? '';
          final extra = state.extra as Map<String, dynamic>?;
          final plan = extra?['plan'];
          final buyerId = FirebaseAuth.instance.currentUser?.uid ?? '';
          final returnToJoin = extra?['returnToJoin'] as bool? ?? false;
          final inviteCode = extra?['inviteCode'] as String?;
          
          if (plan != null) {
            return CheckoutScreen(
              plan: plan,
              buyerId: buyerId,
              returnToJoin: returnToJoin,
              inviteCode: inviteCode,
            );
          }
          
          return FutureBuilder(
            future: PlanService().getPlanById(planId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError || snapshot.data == null) {
                return Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('Failed to load plan'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => context.pop(),
                          child: const Text('Go Back'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return CheckoutScreen(
                plan: snapshot.data!,
                buyerId: buyerId,
                returnToJoin: returnToJoin,
                inviteCode: inviteCode,
              );
            },
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/checkout/success/:planId',
        builder: (context, state) {
          final planId = state.pathParameters['planId'] ?? '';
          final extra = state.extra as Map<String, dynamic>?;
          return CheckoutSuccessScreen(
            planId: planId,
            orderId: extra?['orderId'],
            planName: extra?['planName'],
            isFree: extra?['isFree'] ?? false,
            returnToJoin: extra?['returnToJoin'] ?? false,
            inviteCode: extra?['inviteCode'],
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/checkout/error/:planId',
        builder: (context, state) {
          final planId = state.pathParameters['planId'] ?? '';
          final extra = state.extra as Map<String, dynamic>?;
          return CheckoutErrorScreen(
            planId: planId,
            errorMessage: extra?['errorMessage'],
            planName: extra?['planName'],
          );
        },
      ),
      // Removed legacy ItineraryHome route
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.itineraryNew,
        builder: (context, state) {
          final planId = state.pathParameters['planId'] ?? '';
          return ItineraryDefineScreen(planId: planId);
        },
      ),
      // Legacy route - redirect to new trip details
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.itinerarySetup,
        redirect: (context, state) {
          final tripId = state.pathParameters['tripId'] ?? '';
          return '/trip/$tripId';
        },
      ),
      // New trip details route
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.tripDetails,
        builder: (context, state) {
          final tripId = state.pathParameters['tripId'] ?? '';
          return TripDetailsScreen(tripId: tripId);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.itineraryPack,
        builder: (context, state) {
          final planId = state.pathParameters['planId'] ?? '';
          final tripId = state.pathParameters['tripId'] ?? '';
          return ItineraryPackScreen(planId: planId, tripId: tripId);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.itineraryTravel,
        builder: (context, state) {
          final planId = state.pathParameters['planId'] ?? '';
          final tripId = state.pathParameters['tripId'] ?? '';
          return ItineraryTravelScreen(planId: planId, tripId: tripId);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.itineraryDay,
        builder: (context, state) {
          final planId = state.pathParameters['planId'] ?? '';
          final tripId = state.pathParameters['tripId'] ?? '';
          final dayIndex = int.tryParse(state.pathParameters['dayIndex'] ?? '0') ?? 0;
          return ItineraryDayScreen(planId: planId, tripId: tripId, dayIndex: dayIndex);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.itineraryDayMap,
        builder: (context, state) {
          final planId = state.pathParameters['planId'] ?? '';
          final tripId = state.pathParameters['tripId'] ?? '';
          final dayIndex = int.tryParse(state.pathParameters['dayIndex'] ?? '0') ?? 0;
          final day = state.extra as DayItinerary?;
          if (day == null) {
            return const Scaffold(
              body: Center(child: Text('Day data not provided')),
            );
          }
          return TripDayMapFullscreen(day: day, dayNumber: dayIndex + 1);
        },
      ),
      // Trip customization routes
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.itinerarySelect,
        builder: (context, state) {
          final planId = state.pathParameters['planId'] ?? '';
          final tripId = state.pathParameters['tripId'] ?? '';
          return ItinerarySelectScreen(planId: planId, tripId: tripId);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.itineraryReview,
        builder: (context, state) {
          final planId = state.pathParameters['planId'] ?? '';
          final tripId = state.pathParameters['tripId'] ?? '';
          return ItineraryReviewScreen(planId: planId, tripId: tripId);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.memberPacking,
        builder: (context, state) {
          final tripId = state.pathParameters['tripId'] ?? '';
          return MemberPackingScreen(tripId: tripId);
        },
      ),
      // Trip sharing routes
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.joinTrip,
        builder: (context, state) {
          final inviteCode = state.pathParameters['inviteCode'] ?? '';
          // Check if user came from auth redirect
          final extra = state.extra as Map<String, dynamic>?;
          final fromAuth = extra?['fromAuth'] as bool? ?? false;
          return JoinTripScreen(
            inviteCode: inviteCode,
            fromAuthRedirect: fromAuth,
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.tripMembers,
        builder: (context, state) {
          final tripId = state.pathParameters['tripId'] ?? '';
          return TripMembersScreen(tripId: tripId);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.adminMigration,
        builder: (context, state) => const AdminMigrationScreen(),
      ),
      // Onboarding routes without nav bar
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/mytrips/create',
        builder: (context, state) => const CreateItineraryScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/mytrips/onboarding/:planId/name',
        builder: (context, state) {
          final planId = state.pathParameters['planId'] ?? '';
          return OnboardingNameScreen(planId: planId);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/mytrips/onboarding/:planId/version',
        builder: (context, state) {
          final planId = state.pathParameters['planId'] ?? '';
          final tripName = state.extra as String? ?? '';
          return OnboardingVersionScreen(planId: planId, tripName: tripName);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/mytrips/onboarding/:planId/date',
        builder: (context, state) {
          final planId = state.pathParameters['planId'] ?? '';
          final extra = state.extra as Map<String, dynamic>?;
          final tripName = extra?['tripName'] as String? ?? '';
          final versionId = extra?['versionId'] as String? ?? '';
          return OnboardingDateScreen(
            planId: planId,
            tripName: tripName,
            versionId: versionId,
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/mytrips/onboarding/:planId/image',
        builder: (context, state) {
          final planId = state.pathParameters['planId'] ?? '';
          final extra = state.extra as Map<String, dynamic>?;
          final tripId = extra?['tripId'] as String? ?? '';
          return OnboardingImageScreen(
            planId: planId,
            tripId: tripId,
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/details/:planId',
        builder: (context, state) {
          final planId = state.pathParameters['planId'] ?? '';
          return PlanDetailsScreen(planId: planId);
        },
        routes: [
          GoRoute(
            path: 'map',
            builder: (context, state) => const MapScreen(),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ResponsiveScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.marketplace,
                builder: (context, state) => const MarketplaceScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.myTrips,
                builder: (context, state) => const MyTripsScreen(),
                routes: [
                  GoRoute(
                    path: AppRoutes.tracking,
                    builder: (context, state) {
                      final extra = state.extra;
                      if (extra is! Map || !extra.containsKey('day')) {
                        return const Scaffold(body: Center(child: Text('Missing day')));
                      }
                      return TrackingScreen(day: extra['day']);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.builder,
                builder: (context, state) => const BuilderHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const double _desktopBreakpoint = 1024;
  static const double _sidebarWidth = 240;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= _desktopBreakpoint;
    final auth = FirebaseAuthManager();

    if (isDesktop) {
      return StreamBuilder(
        stream: auth.authStateChanges,
        builder: (context, snapshot) {
          final isLoggedIn = snapshot.data != null;
          return Scaffold(
            body: Row(
              children: [
                DesktopSidebar(
                  currentIndex: navigationShell.currentIndex,
                  onDestinationSelected: _onDestinationSelected,
                  isLoggedIn: isLoggedIn,
                ),
                Expanded(child: navigationShell),
              ],
            ),
          );
        },
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: ModernBottomNav(
        currentIndex: navigationShell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
      ),
    );
  }

  void _onDestinationSelected(int index) {
    Log.i('router', 'Switching branch to index=$index');
    
    // Use a microtask to ensure navigation happens even if errors are occurring
    // This prevents mouse tracker errors from blocking navigation
    Future.microtask(() {
      try {
        // Always call goBranch, even if already on the same index
        // This ensures navigation state is properly updated
        navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        );
        Log.i('router', 'Navigation to index=$index completed successfully');
      } catch (e, stack) {
        Log.e('router', 'Failed to switch branch to index=$index', e, stack);
        // Fallback: try using GoRouter directly
        try {
          final route = _getRouteForIndex(index);
          AppRouter.router.go(route);
          Log.i('router', 'Fallback navigation to $route succeeded');
        } catch (e2, stack2) {
          Log.e('router', 'Fallback navigation also failed', e2, stack2);
          // Last resort: try push instead of go
          try {
            final route = _getRouteForIndex(index);
            AppRouter.router.push(route);
            Log.i('router', 'Push navigation to $route succeeded');
          } catch (e3) {
            Log.e('router', 'All navigation methods failed for index=$index', e3);
          }
        }
      }
    });
  }
  
  String _getRouteForIndex(int index) {
    switch (index) {
      case 0:
        return AppRoutes.marketplace;
      case 1:
        return AppRoutes.myTrips;
      case 2:
        return AppRoutes.builder;
      case 3:
        return AppRoutes.profile;
      default:
        return AppRoutes.marketplace;
    }
  }
}

class DesktopSidebar extends StatelessWidget {
  const DesktopSidebar({
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.isLoggedIn,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool isLoggedIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: context.colors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            _buildLogo(context),
            const SizedBox(height: 32),
            Divider(height: 1, color: context.colors.outline),
            const SizedBox(height: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    _SidebarNavItem(
                      icon: FontAwesomeIcons.compass,
                      label: 'Explore',
                      isSelected: currentIndex == 0,
                      onTap: () => onDestinationSelected(0),
                    ),
                    if (isLoggedIn) ...[
                      _SidebarNavItem(
                        icon: FontAwesomeIcons.map,
                        label: 'My Trips',
                        isSelected: currentIndex == 1,
                        onTap: () => onDestinationSelected(1),
                      ),
                      _SidebarNavItem(
                        icon: FontAwesomeIcons.penRuler,
                        label: 'Builder',
                        isSelected: currentIndex == 2,
                        onTap: () => onDestinationSelected(2),
                      ),
                    ],
                    _SidebarNavItem(
                      icon: FontAwesomeIcons.user,
                      label: 'Profile',
                      isSelected: currentIndex == 3,
                      onTap: () => onDestinationSelected(3),
                    ),
                    const Spacer(),
                    Divider(height: 1, color: context.colors.outline),
                    const SizedBox(height: 12),
                    _SidebarNavItem(
                      icon: FontAwesomeIcons.gear,
                      label: 'Settings',
                      isSelected: false,
                      onTap: () {},
                    ),
                    _SidebarNavItem(
                      icon: FontAwesomeIcons.circleQuestion,
                      label: 'Help',
                      isSelected: false,
                      onTap: () {},
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Icon(Icons.terrain, color: context.colors.primary, size: 28),
          const SizedBox(width: 10),
          Text(
            'WAYPOINT',
            style: context.textStyles.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: context.colors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarNavItem extends StatefulWidget {
  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isSelected || _isHovered;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Material(
          // Remove green tint for the selected state on desktop sidebar.
          // Keep a very subtle hover background only.
          color: _isHovered
              ? context.colors.surfaceContainerHighest.withValues(alpha: 0.5)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            onTap: () {
              Log.i('nav', 'Navigation item tapped: ${widget.label}');
              // Use microtask to defer execution and avoid blocking from mouse tracker errors
              Future.microtask(() {
                try {
                  widget.onTap();
                  Log.i('nav', 'Navigation callback executed successfully for: ${widget.label}');
                } catch (e, stack) {
                  Log.e('nav', 'Error in navigation tap handler for ${widget.label}', e, stack);
                  // Retry after a short delay
                  Future.delayed(const Duration(milliseconds: 100), () {
                    try {
                      widget.onTap();
                      Log.i('nav', 'Navigation retry succeeded for: ${widget.label}');
                    } catch (e2) {
                      Log.e('nav', 'Navigation retry also failed for ${widget.label}', e2);
                    }
                  });
                }
              });
            },
            borderRadius: BorderRadius.circular(AppRadius.md),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                // Remove the left selection border to match mobile/tablet behavior
                // where only the label/icon color changes when active.
                border: null,
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      widget.icon,
                      size: 18,
                      color: isActive
                          ? context.colors.primary
                          : context.colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: context.textStyles.bodyLarge?.copyWith(
                        fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isActive
                            ? context.colors.primary
                            : context.colors.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ModernBottomNav extends StatelessWidget {
  const ModernBottomNav({
    required this.currentIndex,
    required this.onDestinationSelected,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: FontAwesomeIcons.compass,
                selectedIcon: FontAwesomeIcons.solidCompass,
                label: 'Explore',
                isSelected: currentIndex == 0,
                onTap: () => onDestinationSelected(0),
              ),
              _NavItem(
                icon: FontAwesomeIcons.map,
                selectedIcon: FontAwesomeIcons.solidMap,
                label: 'My Trips',
                isSelected: currentIndex == 1,
                onTap: () => onDestinationSelected(1),
              ),
              _BuilderNavItem(
                isSelected: currentIndex == 2,
                onTap: () => onDestinationSelected(2),
              ),
              _NavItem(
                icon: FontAwesomeIcons.user,
                selectedIcon: FontAwesomeIcons.solidUser,
                label: 'Profile',
                isSelected: currentIndex == 3,
                onTap: () => onDestinationSelected(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isSelected || _isHovered;

    return Expanded(
      child: MouseRegion(
        onEnter: (_) {
          setState(() => _isHovered = true);
          _controller.forward();
        },
        onExit: (_) {
          setState(() => _isHovered = false);
          _controller.reverse();
        },
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isHovered ? _scaleAnimation.value : 1.0,
                child: child,
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: Icon(
                      widget.isSelected ? widget.selectedIcon : widget.icon,
                      size: 22,
                      color: isActive
                          ? context.colors.primary
                          : context.colors.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: context.textStyles.labelSmall!.copyWith(
                      color: isActive
                          ? context.colors.primary
                          : context.colors.onSurface.withValues(alpha: 0.5),
                      fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                    child: Text(widget.label),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BuilderNavItem extends StatefulWidget {
  const _BuilderNavItem({
    required this.isSelected,
    required this.onTap,
  });

  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_BuilderNavItem> createState() => _BuilderNavItemState();
}

class _BuilderNavItemState extends State<_BuilderNavItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _liftAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _liftAnimation = Tween<double>(begin: 0, end: -2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isSelected || _isHovered;
    
    return Expanded(
      child: MouseRegion(
        onEnter: (_) {
          setState(() => _isHovered = true);
          _controller.forward();
        },
        onExit: (_) {
          setState(() => _isHovered = false);
          _controller.reverse();
        },
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: _liftAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _isHovered ? _liftAnimation.value : 0),
                child: child,
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: Icon(
                      FontAwesomeIcons.penRuler,
                      size: 22,
                      color: isActive
                          ? context.colors.primary
                          : context.colors.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: context.textStyles.labelSmall!.copyWith(
                      color: isActive
                          ? context.colors.primary
                          : context.colors.onSurface.withValues(alpha: 0.5),
                      fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                    child: const Text('Builder'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Keep old ScaffoldWithNavBar for backwards compatibility if needed
class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(navigationShell: navigationShell);
  }
}
