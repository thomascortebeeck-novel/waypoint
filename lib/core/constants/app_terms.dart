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
const String kTripRolePackingLead = 'packing_lead';
const String kTripRoleTreasurer = 'treasurer';
const String kTripRoleFootprinter = 'footprinter';
const String kTripRoleMember = 'member';

const List<String> kTripRoleOptions = [
  kTripRoleMember,
  kTripRoleNavigator,
  kTripRolePackingLead,
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
    case kTripRolePackingLead:
      return 'Quartermaster';
    case kTripRoleTreasurer:
      return 'Treasurer';
    case kTripRoleFootprinter:
      return 'Footprinter';
    case kTripRoleMember:
    default:
      return 'Insider';
  }
}
