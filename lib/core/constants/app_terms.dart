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
