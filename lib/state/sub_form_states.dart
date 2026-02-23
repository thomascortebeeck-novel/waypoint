import 'package:flutter/material.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/adventure_context_model.dart';

/// Packing category with items
class PackingCategoryFormState extends ChangeNotifier {
  final TextEditingController nameCtrl;
  final TextEditingController? descriptionCtrl;
  final List<PackingItemFormState> items;
  
  PackingCategoryFormState({
    required this.nameCtrl,
    this.descriptionCtrl,
    required this.items,
  });
  
  factory PackingCategoryFormState.initial() => PackingCategoryFormState(
    nameCtrl: TextEditingController(),
    descriptionCtrl: null,
    items: [],
  );
  
  factory PackingCategoryFormState.fromModel(PackingCategory category) {
    return PackingCategoryFormState(
      nameCtrl: TextEditingController(text: category.name),
      descriptionCtrl: category.description != null
          ? TextEditingController(text: category.description!)
          : null,
      items: category.items.map((item) => PackingItemFormState.fromModel(item)).toList(),
    );
  }
  
  @override
  void dispose() {
    nameCtrl.dispose();
    descriptionCtrl?.dispose();
    for (final item in items) {
      item.dispose();
    }
    super.dispose();
  }
}

class PackingItemFormState {
  final String id;
  final TextEditingController nameCtrl;
  final TextEditingController? descriptionCtrl;
  bool isEssential;
  
  PackingItemFormState({
    required this.id,
    required this.nameCtrl,
    this.descriptionCtrl,
    this.isEssential = false,
  });
  
  factory PackingItemFormState.fromModel(PackingItem item) => PackingItemFormState(
    id: item.id,
    nameCtrl: TextEditingController(text: item.name),
    descriptionCtrl: item.description != null
        ? TextEditingController(text: item.description!)
        : null,
    isEssential: false, // Not in model, default to false
  );
  
  void dispose() {
    nameCtrl.dispose();
    descriptionCtrl?.dispose();
  }
}

/// Transportation option
class TransportationFormState extends ChangeNotifier {
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final List<TransportationType> types;
  
  TransportationFormState({
    required this.titleCtrl,
    required this.descCtrl,
    required this.types,
  });
  
  factory TransportationFormState.initial() => TransportationFormState(
    titleCtrl: TextEditingController(),
    descCtrl: TextEditingController(),
    types: [],
  );
  
  factory TransportationFormState.fromModel(TransportationOption option) =>
      TransportationFormState(
    titleCtrl: TextEditingController(text: option.title),
    descCtrl: TextEditingController(text: option.description),
    types: List<TransportationType>.from(option.types),
  );
  
  @override
  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
    super.dispose();
  }
}

/// FAQ item
class FAQFormState {
  final TextEditingController questionCtrl;
  final TextEditingController answerCtrl;
  
  FAQFormState({
    required this.questionCtrl,
    required this.answerCtrl,
  });
  
  factory FAQFormState.initial() => FAQFormState(
    questionCtrl: TextEditingController(),
    answerCtrl: TextEditingController(),
  );
  
  factory FAQFormState.fromModel(FAQItem item) => FAQFormState(
    questionCtrl: TextEditingController(text: item.question),
    answerCtrl: TextEditingController(text: item.answer),
  );
  
  void dispose() {
    questionCtrl.dispose();
    answerCtrl.dispose();
  }
}

/// Permit (in Prepare)
class PermitFormState {
  final TextEditingController typeCtrl;
  final TextEditingController detailsCtrl;
  final TextEditingController howToObtainCtrl;
  final TextEditingController? costCtrl;
  
  PermitFormState({
    required this.typeCtrl,
    required this.detailsCtrl,
    required this.howToObtainCtrl,
    this.costCtrl,
  });
  
  factory PermitFormState.initial() => PermitFormState(
    typeCtrl: TextEditingController(),
    detailsCtrl: TextEditingController(),
    howToObtainCtrl: TextEditingController(),
    costCtrl: null,
  );
  
  factory PermitFormState.fromModel(Permit permit) => PermitFormState(
    typeCtrl: TextEditingController(text: permit.type),
    detailsCtrl: TextEditingController(text: permit.details),
    howToObtainCtrl: TextEditingController(text: permit.howToObtain),
    costCtrl: permit.cost != null
        ? TextEditingController(text: permit.cost!)
        : null,
  );
  
  void dispose() {
    typeCtrl.dispose();
    detailsCtrl.dispose();
    howToObtainCtrl.dispose();
    costCtrl?.dispose();
  }
}

/// Food specialty (in Local Tips)
class FoodSpecialtyFormState {
  final TextEditingController nameCtrl;
  final TextEditingController descriptionCtrl;
  
  FoodSpecialtyFormState({
    required this.nameCtrl,
    required this.descriptionCtrl,
  });
  
  factory FoodSpecialtyFormState.initial() => FoodSpecialtyFormState(
    nameCtrl: TextEditingController(),
    descriptionCtrl: TextEditingController(),
  );
  
  factory FoodSpecialtyFormState.fromModel(FoodSpecialty food) => FoodSpecialtyFormState(
    nameCtrl: TextEditingController(text: food.name),
    descriptionCtrl: TextEditingController(text: food.description),
  );
  
  void dispose() {
    nameCtrl.dispose();
    descriptionCtrl.dispose();
  }
}

/// Etiquette item (in Local Tips) - stored as simple strings
class EtiquetteFormState {
  final TextEditingController tipCtrl;
  
  EtiquetteFormState({
    required this.tipCtrl,
  });
  
  factory EtiquetteFormState.initial() => EtiquetteFormState(
    tipCtrl: TextEditingController(),
  );
  
  factory EtiquetteFormState.fromString(String tip) => EtiquetteFormState(
    tipCtrl: TextEditingController(text: tip),
  );
  
  void dispose() {
    tipCtrl.dispose();
  }
}

/// Food warning (in Local Tips) - stored as simple strings
class FoodWarningFormState {
  final TextEditingController warningCtrl;
  
  FoodWarningFormState({
    required this.warningCtrl,
  });
  
  factory FoodWarningFormState.initial() => FoodWarningFormState(
    warningCtrl: TextEditingController(),
  );
  
  factory FoodWarningFormState.fromString(String warning) => FoodWarningFormState(
    warningCtrl: TextEditingController(text: warning),
  );
  
  void dispose() {
    warningCtrl.dispose();
  }
}

/// Accommodation (in Day) - for backward compatibility with legacy data
/// Note: New waypoints use RouteWaypoint with WaypointType.accommodation
class AccommodationFormState {
  final TextEditingController nameCtrl;
  final TextEditingController urlCtrl;
  final TextEditingController costCtrl;
  AccommodationType? type;
  
  AccommodationFormState({
    required this.nameCtrl,
    required this.urlCtrl,
    required this.costCtrl,
    this.type,
  });
  
  factory AccommodationFormState.initial() => AccommodationFormState(
    nameCtrl: TextEditingController(),
    urlCtrl: TextEditingController(),
    costCtrl: TextEditingController(),
    type: null,
  );
  
  void dispose() {
    nameCtrl.dispose();
    urlCtrl.dispose();
    costCtrl.dispose();
  }
}

/// Restaurant (in Day) - for backward compatibility with legacy data
/// Note: New waypoints use RouteWaypoint with WaypointType.restaurant
class RestaurantFormState {
  final TextEditingController nameCtrl;
  final TextEditingController urlCtrl;
  final TextEditingController costCtrl;
  MealType? mealType;
  
  RestaurantFormState({
    required this.nameCtrl,
    required this.urlCtrl,
    required this.costCtrl,
    this.mealType,
  });
  
  factory RestaurantFormState.initial() => RestaurantFormState(
    nameCtrl: TextEditingController(),
    urlCtrl: TextEditingController(),
    costCtrl: TextEditingController(),
    mealType: MealType.lunch,
  );
  
  void dispose() {
    nameCtrl.dispose();
    urlCtrl.dispose();
    costCtrl.dispose();
  }
}

/// Activity/POI (in Day) - for backward compatibility with legacy data
/// Note: New waypoints use RouteWaypoint with WaypointType.activity/attraction
class ActivityFormState {
  final TextEditingController nameCtrl;
  final TextEditingController urlCtrl;
  final TextEditingController costCtrl;
  final TextEditingController durationCtrl;
  
  ActivityFormState({
    required this.nameCtrl,
    required this.urlCtrl,
    required this.costCtrl,
    required this.durationCtrl,
  });
  
  factory ActivityFormState.initial() => ActivityFormState(
    nameCtrl: TextEditingController(),
    urlCtrl: TextEditingController(),
    costCtrl: TextEditingController(),
    durationCtrl: TextEditingController(),
  );
  
  void dispose() {
    nameCtrl.dispose();
    urlCtrl.dispose();
    costCtrl.dispose();
    durationCtrl.dispose();
  }
}

