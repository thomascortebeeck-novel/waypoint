/// User and creator level names and thresholds.
/// Single source of truth for level badges and copy.

// ---------------------------------------------------------------------------
// User levels (by completed trips)
// ---------------------------------------------------------------------------

enum UserLevel {
  firstSteps,
  explorer,
  adventurer,
  wayfinder,
  trailVeteran,
}

const Map<UserLevel, String> kUserLevelNames = {
  UserLevel.firstSteps: 'First steps',
  UserLevel.explorer: 'Explorer',
  UserLevel.adventurer: 'Adventurer',
  UserLevel.wayfinder: 'Wayfinder',
  UserLevel.trailVeteran: 'Trail veteran',
};

/// Returns user level from completed trip count.
UserLevel getUserLevel(int completedTripCount) {
  if (completedTripCount >= 10) return UserLevel.trailVeteran;
  if (completedTripCount >= 5) return UserLevel.wayfinder;
  if (completedTripCount >= 3) return UserLevel.adventurer;
  if (completedTripCount >= 1) return UserLevel.explorer;
  return UserLevel.firstSteps;
}

/// Display name for user level.
String getUserLevelName(int completedTripCount) {
  return kUserLevelNames[getUserLevel(completedTripCount)]!;
}

/// Next threshold for progress (e.g. "2 more trips to Adventurer"). Returns null if max level.
int? getNextUserLevelThreshold(int completedTripCount) {
  if (completedTripCount >= 10) return null;
  if (completedTripCount >= 5) return 10;
  if (completedTripCount >= 3) return 5;
  if (completedTripCount >= 1) return 3;
  return 1;
}

// ---------------------------------------------------------------------------
// Creator levels (by total plans sold)
// ---------------------------------------------------------------------------

enum CreatorLevel {
  newCreator,
  rising,
  localExpert,
  topCreator,
  trailLegend,
}

const Map<CreatorLevel, String> kCreatorLevelNames = {
  CreatorLevel.newCreator: 'New creator',
  CreatorLevel.rising: 'Rising',
  CreatorLevel.localExpert: 'Local expert',
  CreatorLevel.topCreator: 'Top creator',
  CreatorLevel.trailLegend: 'Trail legend',
};

/// Returns creator level from total plans sold.
CreatorLevel getCreatorLevel(int totalPlansSold) {
  if (totalPlansSold >= 50) return CreatorLevel.trailLegend;
  if (totalPlansSold >= 20) return CreatorLevel.topCreator;
  if (totalPlansSold >= 5) return CreatorLevel.localExpert;
  if (totalPlansSold >= 1) return CreatorLevel.rising;
  return CreatorLevel.newCreator;
}

/// Display name for creator level.
String getCreatorLevelName(int totalPlansSold) {
  return kCreatorLevelNames[getCreatorLevel(totalPlansSold)]!;
}

/// Next threshold for creator progress. Returns null if max level.
int? getNextCreatorLevelThreshold(int totalPlansSold) {
  if (totalPlansSold >= 50) return null;
  if (totalPlansSold >= 20) return 50;
  if (totalPlansSold >= 5) return 20;
  if (totalPlansSold >= 1) return 5;
  return 1;
}
