import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:waypoint/utils/app_urls.dart';
import 'package:waypoint/utils/url_launcher_helper.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:waypoint/auth/firebase_auth_manager.dart';
import 'package:waypoint/presentation/marketplace/marketplace_screen.dart';
import 'package:waypoint/presentation/mytrips/my_trips_screen.dart';
import 'package:waypoint/presentation/mytrips/create_itinerary_screen.dart';
import 'package:waypoint/presentation/builder/builder_home_screen.dart';
import 'package:waypoint/presentation/builder/route_builder_screen.dart';
import 'package:waypoint/presentation/builder/travel_expert_apply_screen.dart';
import 'package:waypoint/presentation/builder/waypoint_edit_page.dart';
import 'package:waypoint/presentation/adventure/adventure_detail_screen.dart';
import 'package:waypoint/presentation/adventure/waypoint_detail_page.dart';
import 'package:waypoint/presentation/profile/profile_screen.dart';
import 'package:waypoint/presentation/creator/creator_profile_screen.dart';
import 'package:waypoint/presentation/explore/explore_screen.dart';
import 'package:waypoint/presentation/map/map_screen.dart';
import 'package:waypoint/presentation/tracking/tracking_screen.dart';
import 'package:waypoint/presentation/checkout/checkout_screen.dart';
import 'package:waypoint/presentation/checkout/checkout_success_screen.dart';
import 'package:waypoint/presentation/checkout/checkout_error_screen.dart';
import 'package:waypoint/presentation/itinerary/itinerary_pack_screen.dart';
import 'package:waypoint/presentation/itinerary/itinerary_travel_screen.dart';
import 'package:waypoint/presentation/itinerary/itinerary_define_screen.dart';
import 'package:waypoint/presentation/itinerary/itinerary_day_screen.dart';
import 'package:waypoint/presentation/itinerary/itinerary_select_screen.dart';
import 'package:waypoint/presentation/itinerary/itinerary_review_screen.dart';
import 'package:waypoint/presentation/trips/member_packing_screen.dart';
import 'package:waypoint/presentation/trips/checklist_screen.dart';
import 'package:waypoint/presentation/mytrips/onboarding/onboarding_name_screen.dart';
import 'package:waypoint/presentation/mytrips/onboarding/onboarding_version_screen.dart';
import 'package:waypoint/presentation/mytrips/onboarding/onboarding_date_screen.dart';
import 'package:waypoint/presentation/mytrips/onboarding/onboarding_image_screen.dart';
import 'package:waypoint/presentation/trips/join_trip_screen.dart';
import 'package:waypoint/presentation/trips/trip_members_screen.dart';
import 'package:waypoint/presentation/trips/role_dashboard_screen.dart';
import 'package:waypoint/presentation/trips/waypoint_vote_screen.dart';
import 'package:waypoint/presentation/trips/trip_day_map_fullscreen.dart';
import 'package:waypoint/presentation/admin/admin_screen.dart';
import 'package:waypoint/presentation/contact/contact_page.dart';
import 'package:waypoint/presentation/marketplace/location_search_results_page.dart';
import 'package:waypoint/presentation/auth/auth_screen.dart';
import 'package:waypoint/services/plan_service.dart';
import 'package:waypoint/integrations/google_places_service.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/models/trip_model.dart';
import 'package:waypoint/services/user_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'theme.dart';
import 'package:waypoint/utils/logger.dart';

class AppRoutes {
  static const String marketplace = '/';
  static const String explore = '/explore';
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
  static const String checklist = '/trip/:tripId/checklist';
  // Trip sharing routes
  static const String joinTrip = '/join/:inviteCode';
  static const String tripMembers = '/trip/:tripId/members';
  static const String admin = '/admin';
  static const String adminMigration = '/admin/migration';
  static const String contact = '/contact';
  static const String locationSearch = '/search/location/:location';
  /// Login/register screen for iOS/Android when user is not signed in. No bottom nav.
  static const String login = '/login';
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

/// Height of the transparent desktop top nav bar. Use for top padding on screens without a hero.
const double kDesktopNavHeight = 64.0;

/// Notifies when auth state changes so the router can re-run redirect (e.g. after login).
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier() {
    FirebaseAuthManager().authStateChanges.listen((_) {
      notifyListeners();
    });
  }
}

final _authRefreshNotifier = _AuthRefreshNotifier();

/// True on iOS and Android only. On web/desktop we do not gate the shell on auth.
bool get _isMobilePlatform =>
    defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android;

bool _isShellRoute(String location) =>
    location == AppRoutes.marketplace ||
    location == AppRoutes.explore ||
    location == AppRoutes.myTrips ||
    location == AppRoutes.builder ||
    location == AppRoutes.profile;

class AppRouter {
  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.marketplace,
    debugLogDiagnostics: true,
    refreshListenable: _authRefreshNotifier,
    redirect: (context, state) {
      if (!_isMobilePlatform) return null;
      final loggedIn = FirebaseAuth.instance.currentUser != null;
      final location = state.matchedLocation;
      final isJoinRoute = state.uri.path.startsWith('/join/');
      if (!loggedIn && _isShellRoute(location)) return AppRoutes.login;
      if (!loggedIn && isJoinRoute) return null;
      if (loggedIn && location == AppRoutes.login) return AppRoutes.marketplace;
      return null;
    },
    routes: [
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/builder/create',
        redirect: (context, state) {
          // Create a temporary ID for new plans
          return '/builder/new';
        },
      ),
      // More specific /builder paths must come before /builder/:planId so they are matched first.
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
            location: extra?['location'],
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/builder/:planId/waypoint/:versionIndex/:dayNum',
        builder: (context, state) {
          final planId = state.pathParameters['planId'] ?? '';
          final versionIndex = state.pathParameters['versionIndex'] ?? '0';
          final dayNum = state.pathParameters['dayNum'] ?? '0';
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return WaypointEditPage(
            planId: planId,
            versionIndex: int.tryParse(versionIndex.toString()) ?? 0,
            dayNum: int.tryParse(dayNum.toString()) ?? 1,
            mode: extra['mode'] as String? ?? 'add',
            initialRoute: extra['initialRoute'] as DayRoute?,
            existingWaypoint: extra['existingWaypoint'] as RouteWaypoint?,
            tripName: extra['tripName'] as String? ?? '',
            preselectedPlace: extra['preselectedPlace'] as PlaceDetails?,
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/builder/apply',
        builder: (context, state) => const TravelExpertApplyScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/builder/:planId',
        builder: (context, state) {
          final planId = state.pathParameters['planId'] ?? '';
          if (planId == 'new') {
            return const AdventureDetailScreen(
              mode: AdventureMode.builder,
              planId: null,
            );
          }
          return AdventureDetailScreen(
            mode: AdventureMode.builder,
            planId: planId,
          );
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
          // On app (iOS/Android) open web checkout and leave this route immediately
          if (!kIsWeb && planId.isNotEmpty) {
            SchedulerBinding.instance.addPostFrameCallback((_) async {
              final uri = Uri.parse(AppUrls.getCheckoutWebUrl(planId));
              await UrlLauncherHelper.launchUrlSafe(context, uri);
              if (context.mounted) context.go('/');
            });
            return const Scaffold(
              body: Center(child: Text('Opening browser…')),
            );
          }
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
            alreadyPurchased: extra?['alreadyPurchased'] ?? false,
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
          return AdventureDetailScreen(
            mode: AdventureMode.trip,
            tripId: tripId,
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/trip/:tripId/waypoint/:dayNum/:waypointId',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final waypoint = extra['waypoint'] as RouteWaypoint?;
          if (waypoint == null) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Waypoint not found'),
                    TextButton(
                      onPressed: () => GoRouter.of(context).pop(),
                      child: const Text('Back'),
                    ),
                  ],
                ),
              ),
            );
          }
          final dayNum = int.tryParse(state.pathParameters['dayNum'] ?? '1') ?? 1;
          return WaypointDetailPage(
            waypoint: waypoint,
            dayNum: dayNum,
            tripId: state.pathParameters['tripId'],
            planId: extra['planId'] as String?,
            versionIndex: extra['versionIndex'] as int? ?? 0,
            isTripOwner: extra['isTripOwner'] as bool? ?? false,
            isBuilder: extra['isBuilder'] as bool? ?? false,
            trip: extra['trip'] as Trip?,
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/plan/:planId/waypoint-view/:versionIndex/:dayNum/:waypointId',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final waypoint = extra['waypoint'] as RouteWaypoint?;
          if (waypoint == null) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Waypoint not found'),
                    TextButton(
                      onPressed: () => GoRouter.of(context).pop(),
                      child: const Text('Back'),
                    ),
                  ],
                ),
              ),
            );
          }
          final dayNum = int.tryParse(state.pathParameters['dayNum'] ?? '1') ?? 1;
          final versionIndex = int.tryParse(state.pathParameters['versionIndex'] ?? '0') ?? 0;
          return WaypointDetailPage(
            waypoint: waypoint,
            dayNum: dayNum,
            planId: state.pathParameters['planId'],
            versionIndex: versionIndex,
            isTripOwner: false,
            isBuilder: extra['isBuilder'] as bool? ?? false,
          );
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
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.checklist,
        builder: (context, state) {
          final tripId = state.pathParameters['tripId'] ?? '';
          return ChecklistScreen(tripId: tripId);
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
        path: '/trip/:tripId/role',
        builder: (context, state) {
          final tripId = state.pathParameters['tripId'] ?? '';
          return RoleDashboardScreen(tripId: tripId);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/trip/:tripId/vote',
        builder: (context, state) {
          final tripId = state.pathParameters['tripId'] ?? '';
          return WaypointVoteScreen(tripId: tripId);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.admin,
        builder: (context, state) => const AdminScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.adminMigration,
        redirect: (context, state) => AppRoutes.admin,
        builder: (context, state) => const AdminScreen(), // Shown only if redirect is skipped
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.contact,
        builder: (context, state) => const ContactPage(),
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
        path: AppRoutes.locationSearch,
        builder: (context, state) {
          final location = Uri.decodeComponent(state.pathParameters['location'] ?? '');
          return LocationSearchResultsPage(location: location);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.login,
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/creator/:creatorId',
        builder: (context, state) {
          final creatorId = state.pathParameters['creatorId'] ?? '';
          return CreatorProfileScreen(creatorId: creatorId);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/details/:planId',
        builder: (context, state) {
          final planId = state.pathParameters['planId'] ?? '';
          final q = state.uri.queryParameters;
          return AdventureDetailScreen(
            mode: AdventureMode.viewer,
            planId: planId,
            inviteCode: q['inviteCode'],
            returnToJoin: q['returnToJoin'] == '1',
          );
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
                path: AppRoutes.explore,
                builder: (context, state) => const ExploreScreen(),
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
      return _ScrollAwareDesktopShell(
        navigationShell: navigationShell,
        onDestinationSelected: _onDestinationSelected,
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
        return AppRoutes.explore;
      case 2:
        return AppRoutes.myTrips;
      case 3:
        return AppRoutes.builder;
      case 4:
        return AppRoutes.profile;
      default:
        return AppRoutes.marketplace;
    }
  }
}

/// Wraps desktop scaffold in scroll listener so nav bar can switch to solid when marketplace hero is scrolled past.
class _ScrollAwareDesktopShell extends StatefulWidget {
  const _ScrollAwareDesktopShell({
    required this.navigationShell,
    required this.onDestinationSelected,
  });

  final StatefulNavigationShell navigationShell;
  final ValueChanged<int> onDestinationSelected;

  @override
  State<_ScrollAwareDesktopShell> createState() => _ScrollAwareDesktopShellState();
}

class _ScrollAwareDesktopShellState extends State<_ScrollAwareDesktopShell> {
  double _scrollOffset = 0;

  bool get _scrolledPastHero => _scrollOffset > _kMarketplaceHeroScrollThreshold;

  @override
  void didUpdateWidget(covariant _ScrollAwareDesktopShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When switching to marketplace (index 0), reset so the bar is transparent over the hero.
    // Otherwise we'd keep the previous page's scroll offset and show a solid bar incorrectly.
    final nowOnMarketplace = widget.navigationShell.currentIndex == 0;
    final wasNotOnMarketplace = oldWidget.navigationShell.currentIndex != 0;
    if (nowOnMarketplace && wasNotOnMarketplace) {
      setState(() => _scrollOffset = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        // Only use scroll position when on marketplace (index 0); other branches' scrollables would otherwise set a high offset and force a solid bar on home.
        if (widget.navigationShell.currentIndex != 0) return false;
        if (notification is ScrollUpdateNotification || notification is ScrollEndNotification) {
          final pixels = notification.metrics.pixels;
          // Ignore an initial high value (e.g. from another tab or restored state) so the bar stays transparent above the hero on first paint.
          if (_scrollOffset == 0 && pixels > _kMarketplaceHeroScrollThreshold) return false;
          if (pixels != _scrollOffset) {
            setState(() => _scrollOffset = pixels);
          }
        }
        return false;
      },
      child: StreamBuilder(
        stream: FirebaseAuthManager().authStateChanges,
        builder: (context, authSnapshot) {
          final firebaseUser = authSnapshot.data;
          final isLoggedIn = firebaseUser != null;
          final isMarketplace = widget.navigationShell.currentIndex == 0;
          if (!isLoggedIn) {
            return Scaffold(
              backgroundColor: isMarketplace ? Colors.transparent : null,
              body: Stack(
                children: [
                  Positioned.fill(child: widget.navigationShell),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: DesktopTopNavBar(
                      currentIndex: widget.navigationShell.currentIndex,
                      onDestinationSelected: widget.onDestinationSelected,
                      isLoggedIn: false,
                      profileImageUrl: null,
                      scrolledPastHero: _scrolledPastHero,
                    ),
                  ),
                ],
              ),
            );
          }
          return StreamBuilder(
            stream: UserService().streamUser(firebaseUser!.uid),
            builder: (context, userSnapshot) {
              final user = userSnapshot.data;
              final profileImageUrl = user?.photoUrl ?? firebaseUser.photoURL;
              return Scaffold(
                backgroundColor: isMarketplace ? Colors.transparent : null,
                body: Stack(
                  children: [
                    Positioned.fill(child: widget.navigationShell),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: DesktopTopNavBar(
                        currentIndex: widget.navigationShell.currentIndex,
                        onDestinationSelected: widget.onDestinationSelected,
                        isLoggedIn: true,
                        profileImageUrl: profileImageUrl,
                        scrolledPastHero: _scrolledPastHero,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// When true and on marketplace (index 0), nav bar uses solid background + dark text.
/// When false/null on marketplace, uses transparent bar + white text over hero.
const double _kMarketplaceHeroScrollThreshold = 450;

class DesktopTopNavBar extends StatelessWidget {
  const DesktopTopNavBar({
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.isLoggedIn,
    this.profileImageUrl,
    this.scrolledPastHero,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool isLoggedIn;
  /// Profile image URL (UserModel.photoUrl or Firebase User.photoURL). When set, shown in the top-right circle.
  final String? profileImageUrl;
  /// On marketplace (index 0): when true, show solid bar + dark text; when false, transparent + white.
  final bool? scrolledPastHero;

  @override
  Widget build(BuildContext context) {
    final isOverHero = (currentIndex == 0) && (scrolledPastHero != true);
    final bar = Container(
      height: kDesktopNavHeight,
      color: isOverHero ? Colors.transparent : context.colors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
          children: [
            _DesktopLogo(
              lightStyle: isOverHero,
              onTap: () => onDestinationSelected(0),
            ),
            const Spacer(),
            _DesktopNavTab(
              label: 'Home',
              index: 0,
              current: currentIndex,
              onTap: onDestinationSelected,
              lightStyle: isOverHero,
            ),
            _DesktopNavTab(
              label: 'Explore',
              index: 1,
              current: currentIndex,
              onTap: onDestinationSelected,
              lightStyle: isOverHero,
            ),
            if (isLoggedIn) ...[
              _DesktopNavTab(
                label: 'Your trips',
                index: 2,
                current: currentIndex,
                onTap: onDestinationSelected,
                lightStyle: isOverHero,
              ),
              _DesktopNavTab(
                label: 'Build',
                index: 3,
                current: currentIndex,
                onTap: onDestinationSelected,
                lightStyle: isOverHero,
              ),
            ],
            _DesktopProfileIcon(
              index: 4,
              onTap: onDestinationSelected,
              imageUrl: profileImageUrl,
              lightStyle: isOverHero,
            ),
          ],
        ),
    );
    // When over hero, use transparent Material so no theme/surface bleeds through.
    if (isOverHero) {
      return Material(type: MaterialType.transparency, child: bar);
    }
    return bar;
  }
}

class _DesktopLogo extends StatelessWidget {
  const _DesktopLogo({this.lightStyle = true, this.onTap});

  final bool lightStyle;
  final VoidCallback? onTap;

  static const _logoAsset = 'assets/images/logo-waypoint.png';

  @override
  Widget build(BuildContext context) {
    final color = lightStyle ? Colors.white : context.colors.primary;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: Image.asset(
            _logoAsset,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.terrain,
              color: color,
              size: 42,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'WAYPOINT',
          style: (context.textStyles.titleLarge ?? const TextStyle(fontSize: 18)).copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: color,
          ),
        ),
      ],
    );
    if (onTap == null) return content;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }
}

class _DesktopNavTab extends StatelessWidget {
  const _DesktopNavTab({
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
    this.lightStyle = true,
  });

  final String label;
  final int index;
  final int current;
  final ValueChanged<int> onTap;
  final bool lightStyle;

  @override
  Widget build(BuildContext context) {
    final isSelected = index == current;
    final color = lightStyle ? Colors.white : context.colors.onSurface;
    final accentColor = lightStyle ? Colors.white : context.colors.primary;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? accentColor : color.withValues(alpha: 0.85),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 2),
                height: 2,
                width: 16,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DesktopProfileIcon extends StatelessWidget {
  const _DesktopProfileIcon({
    required this.index,
    required this.onTap,
    this.imageUrl,
    this.lightStyle = true,
  });

  final int index;
  final ValueChanged<int> onTap;
  final String? imageUrl;
  final bool lightStyle;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    final borderColor = lightStyle ? Colors.white : context.colors.outline;
    final iconColor = lightStyle ? Colors.white : context.colors.onSurface;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: hasImage
            ? ClipOval(
                child: CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  width: 36,
                  height: 36,
                  placeholder: (_, __) => Icon(Icons.person, color: iconColor, size: 20),
                  errorWidget: (_, __, ___) => Icon(Icons.person, color: iconColor, size: 20),
                ),
              )
            : Icon(Icons.person, color: iconColor, size: 20),
      ),
    );
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
                      icon: FontAwesomeIcons.house,
                      label: 'Home',
                      isSelected: currentIndex == 0,
                      onTap: () => onDestinationSelected(0),
                    ),
                    _SidebarNavItem(
                      icon: FontAwesomeIcons.compass,
                      label: 'Explore',
                      isSelected: currentIndex == 1,
                      onTap: () => onDestinationSelected(1),
                    ),
                    if (isLoggedIn) ...[
                      _SidebarNavItem(
                        icon: FontAwesomeIcons.map,
                        label: 'My Trips',
                        isSelected: currentIndex == 2,
                        onTap: () => onDestinationSelected(2),
                      ),
                      _SidebarNavItem(
                        icon: FontAwesomeIcons.penRuler,
                        label: 'Builder',
                        isSelected: currentIndex == 3,
                        onTap: () => onDestinationSelected(3),
                      ),
                    ],
                    _SidebarNavItem(
                      icon: FontAwesomeIcons.user,
                      label: 'Profile',
                      isSelected: currentIndex == 4,
                      onTap: () => onDestinationSelected(4),
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
      child: SizedBox(
        width: 40,
        height: 40,
        child: Image.asset(
          'assets/images/logo-waypoint.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(Icons.terrain, color: context.colors.primary, size: 28),
        ),
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
                // Add subtle background tint for selected state
                color: widget.isSelected 
                    ? context.colors.primary.withValues(alpha: 0.08)
                    : null,
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
    return KeyedSubtree(
      key: const ValueKey<String>('modern_bottom_nav'),
      child: Container(
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
        clipBehavior: Clip.none,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 88,
            child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                key: const ValueKey<String>('nav_home'),
                icon: FontAwesomeIcons.house,
                selectedIcon: FontAwesomeIcons.house,
                label: 'Home',
                isSelected: currentIndex == 0,
                onTap: () => onDestinationSelected(0),
              ),
              _NavItem(
                key: const ValueKey<String>('nav_explore'),
                icon: FontAwesomeIcons.compass,
                selectedIcon: FontAwesomeIcons.solidCompass,
                label: 'Explore',
                isSelected: currentIndex == 1,
                onTap: () => onDestinationSelected(1),
              ),
              _NavItem(
                key: const ValueKey<String>('nav_mytrips'),
                icon: FontAwesomeIcons.map,
                selectedIcon: FontAwesomeIcons.solidMap,
                label: 'My Trips',
                isSelected: currentIndex == 2,
                onTap: () => onDestinationSelected(2),
              ),
              _BuilderNavItem(
                key: const ValueKey<String>('nav_builder'),
                isSelected: currentIndex == 3,
                onTap: () => onDestinationSelected(3),
              ),
              _NavItem(
                key: const ValueKey<String>('nav_profile'),
                icon: FontAwesomeIcons.user,
                selectedIcon: FontAwesomeIcons.solidUser,
                label: 'Profile',
                isSelected: currentIndex == 4,
                onTap: () => onDestinationSelected(4),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    super.key,
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
                    style: (context.textStyles.labelSmall ?? const TextStyle()).copyWith(
                      inherit: false,
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
    super.key,
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
                    style: (context.textStyles.labelSmall ?? const TextStyle()).copyWith(
                      inherit: false,
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
