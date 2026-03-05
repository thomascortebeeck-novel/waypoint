/// Preset checklist categories and items for quick-add in the builder.
/// Used for both category-level ("Add Documents") and item-level ("Add Yellow Fever") suggestions.

class ChecklistSuggestionCategory {
  final String name;
  final List<String> itemNames;

  const ChecklistSuggestionCategory({
    required this.name,
    required this.itemNames,
  });
}

/// Category-level suggestions: tap to add the whole category with all items.
const List<ChecklistSuggestionCategory> checklistCategorySuggestions = [
  ChecklistSuggestionCategory(
    name: 'Documents',
    itemNames: ['Travel insurance', 'Visa', 'Passport', 'Permits'],
  ),
  ChecklistSuggestionCategory(
    name: 'Vaccines',
    itemNames: [
      'Yellow Fever',
      'Hepatitis A',
      'Tetanus',
      'Typhoid',
      'Covid-19',
      'Rabies',
      'Malaria prophylaxis',
    ],
  ),
  ChecklistSuggestionCategory(
    name: 'Food & Drinks',
    itemNames: [
      'Breakfast',
      'Lunch',
      'Dinner',
      'Snacks',
      'Water',
      'Hot drinks',
    ],
  ),
  ChecklistSuggestionCategory(
    name: 'Clothing',
    itemNames: [
      'Underwear',
      'Socks',
      'Base layers',
      'Outer layers',
      'Rain gear',
      'Footwear',
    ],
  ),
  ChecklistSuggestionCategory(
    name: 'Gear',
    itemNames: [
      'Backpack',
      'Sleeping bag',
      'Tent',
      'First aid kit',
      'Headlamp',
      'Maps / GPS',
    ],
  ),
  ChecklistSuggestionCategory(
    name: 'Electronics',
    itemNames: [
      'Phone',
      'Charger',
      'Power bank',
      'Camera',
      'Adapter',
    ],
  ),
  ChecklistSuggestionCategory(
    name: 'Toiletries',
    itemNames: [
      'Toothbrush & paste',
      'Soap',
      'Sunscreen',
      'Insect repellent',
      'Medications',
    ],
  ),
  ChecklistSuggestionCategory(
    name: 'Diversions',
    itemNames: [
      'Books',
      'Games',
      'Music',
      'Camera',
    ],
  ),
];

/// Finds the first category whose name matches [name] (case-insensitive, trimmed).
/// Used for item quick-add to "find or create" category; avoids "Documents" vs "documents" duplicates.
/// Returns the index in [categories], or null if no match.
int? findCategoryIndexByName<T>(
  List<T> categories,
  String name,
  String Function(T) getName,
) {
  final normalized = name.trim().toLowerCase();
  if (normalized.isEmpty) return null;
  for (var i = 0; i < categories.length; i++) {
    if (getName(categories[i]).trim().toLowerCase() == normalized) return i;
  }
  return null;
}

/// Item name -> category name for item-level suggestions (tap to add one item to that category).
/// Built from checklistCategorySuggestions.
Map<String, String> get checklistItemToCategory {
  final map = <String, String>{};
  for (final cat in checklistCategorySuggestions) {
    for (final itemName in cat.itemNames) {
      map[itemName] = cat.name;
    }
  }
  return map;
}

/// All suggested item names in a flat list (e.g. for an "Add suggested item" picker).
List<String> get checklistSuggestedItemNames {
  return checklistCategorySuggestions
      .expand((c) => c.itemNames)
      .toList();
}
