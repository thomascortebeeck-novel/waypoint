# Waypoint App Architecture

## Overview
Waypoint is a premium multi-day trekking and travel navigation app built with Flutter and Firebase. It provides offline-first navigation with curated premium plans and user-generated content.

## Tech Stack
- **Framework**: Flutter (cross-platform: iOS, Android, Web)
- **Backend**: Firebase (Authentication, Firestore)
- **Routing**: go_router
- **State Management**: Provider
- **Maps**: flutter_map with Mapbox tiles

## Project Structure

### Data Layer
- **Models** (`lib/models/`)
  - `user_model.dart`: User profile with purchased/created plans
  - `plan_model.dart`: Plans, versions, itineraries, and stays
  
- **Services** (`lib/services/`)
  - `user_service.dart`: User CRUD operations and Firebase queries
  - `plan_service.dart`: Plan CRUD operations, filtering by featured/creator/purchased
  
- **Data** (`lib/data/`)
  - `mock_data.dart`: Sample plans for development/testing

### Authentication Layer (`lib/auth/`)
- `auth_manager.dart`: Abstract auth interface with mixins for different auth methods
- `firebase_auth_manager.dart`: Firebase implementation with email/password auth

### Presentation Layer (`lib/presentation/`)
- **Marketplace** (`marketplace/`): Browse and discover plans
- **My Trips** (`mytrips/`): User's purchased and created plans
- **Builder** (`builder/`): Create new custom plans
- **Profile** (`profile/`): User settings and account management
- **Details** (`details/`): Plan details with versions and itinerary
- **Map** (`map/`): Offline-capable navigation view
- **Widgets** (`widgets/`): Shared components like `plan_card.dart`

### Core Files
- `main.dart`: App initialization, Firebase setup
- `nav.dart`: go_router configuration with bottom tabs
- `theme.dart`: Premium design system (Montserrat + Inter, Deep Slate palette)

## Firebase Integration

### Collections
1. **users**
   - User profiles
   - Purchased plan IDs
   - Created plan IDs
   - Security: Private (owner-only access)

2. **plans**
   - All trek plans with versions and itineraries
   - Featured flag for curated content
   - Published flag for visibility control
   - Security: Public read for published, creator-only write

### Security Rules
- Users can only read/write their own profile
- Anyone can read published plans
- Only creators can modify their own plans
- Must be authenticated to create plans

### Indexes
- `plans`: `is_published + created_at` (descending)
- `plans`: `is_published + is_featured + created_at` (descending)
- `plans`: `creator_id + created_at` (descending)

## Key Features
1. **Plan Marketplace**: Browse featured and all plans
2. **Offline-First**: Download plans for offline use
3. **Custom Plans**: Users create and publish their own routes
4. **Premium Content**: Admin-curated €2 plans
5. **Detailed Itineraries**: Day-by-day breakdown with stays, distances, photos

## Navigation Flow
- Bottom tabs: Marketplace → My Trips → Builder → Profile
- Deep navigation: Marketplace → Plan Details → Map View
- Context actions: Empty state buttons navigate to relevant tabs

## Design System
- **Fonts**: Montserrat (headings), Inter (body)
- **Colors**: Deep Slate, Muted Terra Cotta, Clean Whites
- **Style**: Premium/Adventure aesthetic with generous whitespace
- **Components**: Material 3 with custom elevation and rounded corners

## Next Steps for Firebase Integration
1. **Deploy Rules & Indexes**: User must deploy via Firebase panel
2. **Enable Authentication**: User must enable Email/Password auth in Firebase Console
3. **Replace Mock Data**: Update screens to use PlanService instead of mockPlans
4. **Add Auth UI**: Create login/signup screens with FirebaseAuthManager
5. **User State**: Add Provider for auth state management across app
