import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:waypoint/presentation/marketplace/marketplace_screen.dart';
import 'package:waypoint/presentation/mytrips/my_trips_screen.dart';
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
import 'package:waypoint/presentation/itinerary/itinerary_home_screen.dart';
import 'package:waypoint/presentation/itinerary/itinerary_setup_screen.dart';
import 'package:waypoint/presentation/itinerary/itinerary_pack_screen.dart';
import 'package:waypoint/presentation/itinerary/itinerary_travel_screen.dart';
import 'package:waypoint/presentation/itinerary/itinerary_define_screen.dart';
import 'package:waypoint/presentation/itinerary/itinerary_day_screen.dart';
import 'package:waypoint/services/plan_service.dart';
import 'theme.dart';
import 'package:waypoint/utils/logger.dart';

// Route constants
class AppRoutes {
  static const String marketplace = '/';
  static const String myTrips = '/mytrips';
  static const String builder = '/builder';
  static const String profile = '/profile';
  static const String planDetails = 'details/:planId';
  static const String map = 'map';
  static const String tracking = 'tracking';
  static const String checkout = '/checkout/:planId';
  static const String checkoutSuccess = '/checkout/success/:planId';
  static const String checkoutError = '/checkout/error/:planId';
  static const String itineraryHome = '/itinerary/:planId';
  static const String itineraryNew = '/itinerary/:planId/new';
  static const String itinerarySetup = '/itinerary/:planId/setup/:tripId';
  static const String itineraryPack = '/itinerary/:planId/pack/:tripId';
  static const String itineraryTravel = '/itinerary/:planId/travel/:tripId';
  static const String itineraryDay = '/itinerary/:planId/day/:tripId/:dayIndex';
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

class AppRouter {
  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.marketplace,
    debugLogDiagnostics: true,
    routes: [
      // Full-screen builder routes (no bottom nav)
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/builder/create',
        builder: (context, state) => const builder.BuilderScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/builder/edit/:planId',
        builder: (context, state) => EditPlanScreen(planId: state.pathParameters['planId'] ?? ''),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/builder/edit/:planId/route-builder/:versionIndex/:dayNum',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return RouteBuilderScreen(
            start: extra?['start'],
            end: extra?['end'],
            initial: extra?['initial'],
          );
        },
      ),
      // Deep link route for shared plan URLs (redirects to nested route)
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/plan/:planId',
        redirect: (context, state) {
          final planId = state.pathParameters['planId'] ?? '';
          return '/details/$planId';
        },
      ),
      
      // Checkout routes (full-screen, no bottom nav)
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/checkout/:planId',
        builder: (context, state) {
          final planId = state.pathParameters['planId'] ?? '';
          final extra = state.extra as Map<String, dynamic>?;
          final plan = extra?['plan'];
          final buyerId = FirebaseAuth.instance.currentUser?.uid ?? '';
          
          if (plan != null) {
            return CheckoutScreen(plan: plan, buyerId: buyerId);
          }
          
          // If plan not passed, load it
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
              return CheckoutScreen(plan: snapshot.data!, buyerId: buyerId);
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
      // Itinerary routes (full-screen)
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.itineraryHome,
        builder: (context, state) {
          final planId = state.pathParameters['planId'] ?? '';
          return ItineraryHomeScreen(planId: planId);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.itineraryNew,
        builder: (context, state) {
          final planId = state.pathParameters['planId'] ?? '';
          return ItineraryDefineScreen(planId: planId);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.itinerarySetup,
        builder: (context, state) {
          final planId = state.pathParameters['planId'] ?? '';
          final tripId = state.pathParameters['tripId'] ?? '';
          return ItinerarySetupScreen(planId: planId, tripId: tripId);
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
      
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          // Marketplace Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.marketplace,
                builder: (context, state) => const MarketplaceScreen(),
                routes: [
                  GoRoute(
                    path: AppRoutes.planDetails,
                    builder: (context, state) {
                      final planId = state.pathParameters['planId'] ?? '';
                      return PlanDetailsScreen(planId: planId);
                    },
                    routes: [
                      GoRoute(
                        path: AppRoutes.map,
                        builder: (context, state) => const MapScreen(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          
          // My Trips Branch
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

          // Builder Branch (only home screen, create/edit are full-screen)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.builder,
                builder: (context, state) => const BuilderHomeScreen(),
              ),
            ],
          ),

          // Profile Branch
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

class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, -2),
            ),
          ],
          border: Border(
            top: BorderSide(
              color: context.colors.outlineVariant,
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) {
              Log.i('router', 'Switching branch to index=$index');
              navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              );
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(FontAwesomeIcons.compass),
                selectedIcon: Icon(FontAwesomeIcons.solidCompass),
                label: 'Explore',
              ),
              NavigationDestination(
                icon: Icon(FontAwesomeIcons.map),
                selectedIcon: Icon(FontAwesomeIcons.solidMap),
                label: 'My Trips',
              ),
              NavigationDestination(
                icon: Icon(FontAwesomeIcons.penRuler),
                selectedIcon: Icon(FontAwesomeIcons.penRuler),
                label: 'Builder',
              ),
              NavigationDestination(
                icon: Icon(FontAwesomeIcons.user),
                selectedIcon: Icon(FontAwesomeIcons.solidUser),
                label: 'Profile',
              ),
            ],
            backgroundColor: Colors.transparent,
            elevation: 0,
            indicatorColor: context.colors.primary.withValues(alpha: 0.12),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            height: 64,
          ),
        ),
      ),
    );
  }
}
