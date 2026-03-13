/// Single source for app-wide terms (Back, Crew) per product/copy decisions.
/// Use these everywhere so one change updates the whole app.

/// Label for the group of people on a trip (replaces "members", "group", etc.).
const String kCrewLabel = 'Crew';

/// CTA for backing a plan. Prefer [creatorName] when available.
String backPlanButtonLabel(String? creatorName) {
  if (creatorName != null && creatorName.trim().isNotEmpty) {
    return 'Back $creatorName';
  }
  return 'Back this plan';
}

/// "X people have backed this" using plan.salesCount. Handles 0 and 1 for grammar.
String backedCountLabel(int salesCount) {
  if (salesCount == 0) return 'Be the first to back this';
  if (salesCount == 1) return '1 person has backed this';
  return '$salesCount people have backed this';
}

// ---------------------------------------------------------------------------
// Trip member roles (for member_roles map on Trip)
// ---------------------------------------------------------------------------

const String kTripRoleOwner = 'owner';
const String kTripRoleNavigator = 'navigator';
const String kTripRoleQuartermaster = 'quartermaster';
const String kTripRoleTreasurer = 'treasurer';
const String kTripRoleFootprinter = 'footprinter';
const String kTripRoleInsider = 'insider';
const String kTripRoleMember = 'member';

/// Legacy value: treat as Quartermaster for backward compatibility.
const String kTripRolePackingLeadLegacy = 'packing_lead';

const List<String> kTripRoleOptions = [
  kTripRoleMember,
  kTripRoleInsider,
  kTripRoleNavigator,
  kTripRoleQuartermaster,
  kTripRoleTreasurer,
  kTripRoleFootprinter,
];

/// Display label for a role value.
String tripRoleDisplayLabel(String role) {
  switch (role) {
    case kTripRoleOwner:
      return 'Owner';
    case kTripRoleNavigator:
      return 'Navigator';
    case kTripRoleQuartermaster:
    case kTripRolePackingLeadLegacy:
      return 'Quartermaster';
    case kTripRoleTreasurer:
      return 'Treasurer';
    case kTripRoleFootprinter:
      return 'Footprinter';
    case kTripRoleInsider:
      return 'Insider';
    case kTripRoleMember:
    default:
      return 'Member';
  }
}

/// Short description for role picker / members page.
String tripRoleDescription(String role) {
  switch (role) {
    case kTripRoleOwner:
      return 'Organizer; can assign roles and manage the trip.';
    case kTripRoleNavigator:
      return 'Responsible for navigation and timing; can edit transport between waypoints.';
    case kTripRoleQuartermaster:
    case kTripRolePackingLeadLegacy:
      return 'Responsible for waypoint bookings, ensuring the Expedition list is completed before the trip, and waypoint documents (e.g. confirmations).';
    case kTripRoleTreasurer:
      return 'Responsible for tracking trip expenses in Treasure.';
    case kTripRoleFootprinter:
      return 'Responsible for the trip\'s footprint; sees daily footprint and earns points when the Navigator chooses lower-footprint transport.';
    case kTripRoleInsider:
      return 'Can add and edit Insights (local tips) for the trip; sees daily mood summaries.';
    case kTripRoleMember:
    default:
      return 'Crew member with no special role.';
  }
}
