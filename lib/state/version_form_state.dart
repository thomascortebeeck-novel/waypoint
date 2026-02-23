import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/adventure_context_model.dart';
import 'package:waypoint/presentation/widgets/link_preview_card.dart';
import 'package:waypoint/services/link_preview_service.dart';
import 'package:waypoint/state/day_form_state.dart';
import 'package:waypoint/state/sub_form_states.dart';

/// Form state for one version — owns Prepare, LocalTips, and Days
class VersionFormState extends ChangeNotifier {
  final String tempId;
  final TextEditingController nameCtrl;
  final TextEditingController durationCtrl;
  
  // Guard flag to prevent listener stacking
  bool _localTipsListenersAttached = false;
  bool get localTipsListenersAttached => _localTipsListenersAttached;
  void markLocalTipsListenersAttached() => _localTipsListenersAttached = true;
  void resetLocalTipsListenersAttached() => _localTipsListenersAttached = false;
  
  // --- Prepare (per-version) ---
  Prepare? _generatedPrepare;
  Prepare? get generatedPrepare => _generatedPrepare;
  set generatedPrepare(Prepare? value) {
    if (_generatedPrepare != value) {
      _generatedPrepare = value;
      notifyListeners();
    }
  }
  
  // Prepare sub-field controllers (populated when AI generates or when loading)
  // Travel Insurance
  final TextEditingController prepareInsuranceRecommendationCtrl;
  final TextEditingController prepareInsuranceUrlCtrl;
  final TextEditingController prepareInsuranceNoteCtrl;
  // Visa
  final TextEditingController prepareVisaRequirementCtrl;
  final TextEditingController prepareVisaUrlCtrl;
  final TextEditingController prepareVisaNoteCtrl;
  // Passport
  final TextEditingController preparePassportValidityCtrl;
  final TextEditingController preparePassportNoteCtrl;
  // Permits (list — managed as List<PermitFormState>)
  final List<PermitFormState> permits;
  // Vaccines
  final TextEditingController prepareVaccinesRequiredCtrl;
  final TextEditingController prepareVaccinesRecommendedCtrl;
  final TextEditingController prepareVaccinesNoteCtrl;
  // Climate
  final TextEditingController prepareClimateDescriptionCtrl;
  final TextEditingController prepareClimateBestTimeCtrl;
  
  // --- Packing (per-version, inside Prepare tab) ---
  final List<PackingCategoryFormState> packingCategories;
  
  // --- Transportation (per-version, inside Prepare tab) ---
  final List<TransportationFormState> transportationOptions;
  
  // --- Local Tips (per-version) ---
  LocalTips? _generatedLocalTips;
  LocalTips? get generatedLocalTips => _generatedLocalTips;
  set generatedLocalTips(LocalTips? value) {
    if (_generatedLocalTips != value) {
      _generatedLocalTips = value;
      notifyListeners();
    }
  }
  
  // Local Tips sub-field controllers
  final List<FoodSpecialtyFormState> foodSpecialties;
  final List<EtiquetteFormState> etiquetteItems;
  final List<FoodWarningFormState> foodWarnings;
  final TextEditingController localTipsLanguageCtrl;
  final TextEditingController localTipsCurrencyCtrl;
  final TextEditingController localTipsEmergencyPoliceCtrl;
  final TextEditingController localTipsEmergencyAmbulanceCtrl;
  final TextEditingController localTipsEmergencyFireCtrl;
  final TextEditingController localTipsEmergencyTouristCtrl;
  final TextEditingController localTipsEmergencyNoteCtrl;
  // Additional LocalTips controllers (moved from temporary build-time controllers)
  final TextEditingController localTipsGeneralEmergencyCtrl;
  final TextEditingController localTipsMessagingAppNameCtrl;
  final TextEditingController localTipsMessagingAppNoteCtrl;
  final TextEditingController localTipsTippingPracticeCtrl;
  final TextEditingController localTipsTippingRestaurantCtrl;
  final TextEditingController localTipsTippingTaxiCtrl;
  final TextEditingController localTipsTippingHotelCtrl;
  
  // --- Days (per-version, lazy) ---
  final Map<int, DayFormState> _days = {};
  
  VersionFormState({
    required this.tempId,
    required this.nameCtrl,
    required this.durationCtrl,
    Prepare? generatedPrepare,
    required this.prepareInsuranceRecommendationCtrl,
    required this.prepareInsuranceUrlCtrl,
    required this.prepareInsuranceNoteCtrl,
    required this.prepareVisaRequirementCtrl,
    required this.prepareVisaUrlCtrl,
    required this.prepareVisaNoteCtrl,
    required this.preparePassportValidityCtrl,
    required this.preparePassportNoteCtrl,
    required this.permits,
    required this.prepareVaccinesRequiredCtrl,
    required this.prepareVaccinesRecommendedCtrl,
    required this.prepareVaccinesNoteCtrl,
    required this.prepareClimateDescriptionCtrl,
    required this.prepareClimateBestTimeCtrl,
    required this.packingCategories,
    required this.transportationOptions,
    LocalTips? generatedLocalTips,
    required this.foodSpecialties,
    required this.etiquetteItems,
    required this.foodWarnings,
    required this.localTipsLanguageCtrl,
    required this.localTipsCurrencyCtrl,
    required this.localTipsEmergencyPoliceCtrl,
    required this.localTipsEmergencyAmbulanceCtrl,
    required this.localTipsEmergencyFireCtrl,
    required this.localTipsEmergencyTouristCtrl,
    required this.localTipsEmergencyNoteCtrl,
    required this.localTipsGeneralEmergencyCtrl,
    required this.localTipsMessagingAppNameCtrl,
    required this.localTipsMessagingAppNoteCtrl,
    required this.localTipsTippingPracticeCtrl,
    required this.localTipsTippingRestaurantCtrl,
    required this.localTipsTippingTaxiCtrl,
    required this.localTipsTippingHotelCtrl,
  }) : _generatedPrepare = generatedPrepare,
       _generatedLocalTips = generatedLocalTips;
  
  int get daysCount => int.tryParse(durationCtrl.text) ?? 0;
  
  DayFormState getDayState(int dayNum) {
    return _days.putIfAbsent(dayNum, () => DayFormState(dayNum: dayNum));
  }
  
  // --- Factories ---
  factory VersionFormState.initial() {
    return VersionFormState(
      tempId: const Uuid().v4(),
      nameCtrl: TextEditingController(),
      durationCtrl: TextEditingController(text: '1'),
      prepareInsuranceRecommendationCtrl: TextEditingController(),
      prepareInsuranceUrlCtrl: TextEditingController(),
      prepareInsuranceNoteCtrl: TextEditingController(),
      prepareVisaRequirementCtrl: TextEditingController(),
      prepareVisaUrlCtrl: TextEditingController(),
      prepareVisaNoteCtrl: TextEditingController(),
      preparePassportValidityCtrl: TextEditingController(),
      preparePassportNoteCtrl: TextEditingController(),
      permits: [],
      prepareVaccinesRequiredCtrl: TextEditingController(),
      prepareVaccinesRecommendedCtrl: TextEditingController(),
      prepareVaccinesNoteCtrl: TextEditingController(),
      prepareClimateDescriptionCtrl: TextEditingController(),
      prepareClimateBestTimeCtrl: TextEditingController(),
      packingCategories: [],
      transportationOptions: [],
      foodSpecialties: [],
      etiquetteItems: [],
      foodWarnings: [],
      localTipsLanguageCtrl: TextEditingController(),
      localTipsCurrencyCtrl: TextEditingController(),
      localTipsEmergencyPoliceCtrl: TextEditingController(),
      localTipsEmergencyAmbulanceCtrl: TextEditingController(),
      localTipsEmergencyFireCtrl: TextEditingController(),
      localTipsEmergencyTouristCtrl: TextEditingController(),
      localTipsEmergencyNoteCtrl: TextEditingController(),
      localTipsGeneralEmergencyCtrl: TextEditingController(),
      localTipsMessagingAppNameCtrl: TextEditingController(),
      localTipsMessagingAppNoteCtrl: TextEditingController(),
      localTipsTippingPracticeCtrl: TextEditingController(),
      localTipsTippingRestaurantCtrl: TextEditingController(),
      localTipsTippingTaxiCtrl: TextEditingController(),
      localTipsTippingHotelCtrl: TextEditingController(),
    );
  }
  
  /// Copy Prepare and LocalTips from another version as starting point
  factory VersionFormState.copyFrom(VersionFormState source) {
    final copy = VersionFormState.initial();
    // Copy Prepare controllers
    copy.prepareInsuranceRecommendationCtrl.text = source.prepareInsuranceRecommendationCtrl.text;
    copy.prepareInsuranceUrlCtrl.text = source.prepareInsuranceUrlCtrl.text;
    copy.prepareInsuranceNoteCtrl.text = source.prepareInsuranceNoteCtrl.text;
    copy.prepareVisaRequirementCtrl.text = source.prepareVisaRequirementCtrl.text;
    copy.prepareVisaUrlCtrl.text = source.prepareVisaUrlCtrl.text;
    copy.prepareVisaNoteCtrl.text = source.prepareVisaNoteCtrl.text;
    copy.preparePassportValidityCtrl.text = source.preparePassportValidityCtrl.text;
    copy.preparePassportNoteCtrl.text = source.preparePassportNoteCtrl.text;
    copy.prepareVaccinesRequiredCtrl.text = source.prepareVaccinesRequiredCtrl.text;
    copy.prepareVaccinesRecommendedCtrl.text = source.prepareVaccinesRecommendedCtrl.text;
    copy.prepareVaccinesNoteCtrl.text = source.prepareVaccinesNoteCtrl.text;
    copy.prepareClimateDescriptionCtrl.text = source.prepareClimateDescriptionCtrl.text;
    copy.prepareClimateBestTimeCtrl.text = source.prepareClimateBestTimeCtrl.text;
    
    // Copy permits
    for (final permit in source.permits) {
      copy.permits.add(PermitFormState(
        typeCtrl: TextEditingController(text: permit.typeCtrl.text),
        detailsCtrl: TextEditingController(text: permit.detailsCtrl.text),
        howToObtainCtrl: TextEditingController(text: permit.howToObtainCtrl.text),
        costCtrl: permit.costCtrl != null
            ? TextEditingController(text: permit.costCtrl!.text)
            : null,
      ));
    }
    
    // Copy LocalTips controllers
    for (final food in source.foodSpecialties) {
      copy.foodSpecialties.add(FoodSpecialtyFormState(
        nameCtrl: TextEditingController(text: food.nameCtrl.text),
        descriptionCtrl: TextEditingController(text: food.descriptionCtrl.text),
      ));
    }
    for (final etiquette in source.etiquetteItems) {
      copy.etiquetteItems.add(EtiquetteFormState(
        tipCtrl: TextEditingController(text: etiquette.tipCtrl.text),
      ));
    }
    copy.localTipsLanguageCtrl.text = source.localTipsLanguageCtrl.text;
    copy.localTipsCurrencyCtrl.text = source.localTipsCurrencyCtrl.text;
    copy.localTipsEmergencyPoliceCtrl.text = source.localTipsEmergencyPoliceCtrl.text;
    copy.localTipsEmergencyAmbulanceCtrl.text = source.localTipsEmergencyAmbulanceCtrl.text;
    copy.localTipsEmergencyFireCtrl.text = source.localTipsEmergencyFireCtrl.text;
    copy.localTipsEmergencyTouristCtrl.text = source.localTipsEmergencyTouristCtrl.text;
    copy.localTipsEmergencyNoteCtrl.text = source.localTipsEmergencyNoteCtrl.text;
    copy.localTipsGeneralEmergencyCtrl.text = source.localTipsGeneralEmergencyCtrl.text;
    copy.localTipsMessagingAppNameCtrl.text = source.localTipsMessagingAppNameCtrl.text;
    copy.localTipsMessagingAppNoteCtrl.text = source.localTipsMessagingAppNoteCtrl.text;
    copy.localTipsTippingPracticeCtrl.text = source.localTipsTippingPracticeCtrl.text;
    copy.localTipsTippingRestaurantCtrl.text = source.localTipsTippingRestaurantCtrl.text;
    copy.localTipsTippingTaxiCtrl.text = source.localTipsTippingTaxiCtrl.text;
    copy.localTipsTippingHotelCtrl.text = source.localTipsTippingHotelCtrl.text;
    
    // Copy packing categories and transportation
    for (final cat in source.packingCategories) {
      final newCat = PackingCategoryFormState(
        nameCtrl: TextEditingController(text: cat.nameCtrl.text),
        descriptionCtrl: cat.descriptionCtrl != null
            ? TextEditingController(text: cat.descriptionCtrl!.text)
            : null,
        items: cat.items.map((item) => PackingItemFormState(
          id: item.id,
          nameCtrl: TextEditingController(text: item.nameCtrl.text),
          descriptionCtrl: item.descriptionCtrl != null
              ? TextEditingController(text: item.descriptionCtrl!.text)
              : null,
          isEssential: item.isEssential,
        )).toList(),
      );
      copy.packingCategories.add(newCat);
    }
    for (final trans in source.transportationOptions) {
      copy.transportationOptions.add(TransportationFormState(
        titleCtrl: TextEditingController(text: trans.titleCtrl.text),
        descCtrl: TextEditingController(text: trans.descCtrl.text),
        types: List<TransportationType>.from(trans.types),
      ));
    }
    
    // Copy food specialties, etiquette, and food warnings
    for (final food in source.foodSpecialties) {
      copy.foodSpecialties.add(FoodSpecialtyFormState(
        nameCtrl: TextEditingController(text: food.nameCtrl.text),
        descriptionCtrl: TextEditingController(text: food.descriptionCtrl.text),
      ));
    }
    for (final etiquette in source.etiquetteItems) {
      copy.etiquetteItems.add(EtiquetteFormState(
        tipCtrl: TextEditingController(text: etiquette.tipCtrl.text),
      ));
    }
    for (final warning in source.foodWarnings) {
      copy.foodWarnings.add(FoodWarningFormState(
        warningCtrl: TextEditingController(text: warning.warningCtrl.text),
      ));
    }
    
    return copy;
  }
  
  factory VersionFormState.fromVersion(PlanVersion version) {
    final state = VersionFormState(
      tempId: version.id,
      nameCtrl: TextEditingController(text: version.name),
      durationCtrl: TextEditingController(text: version.durationDays.toString()),
      prepareInsuranceRecommendationCtrl: TextEditingController(
        text: version.prepare?.travelInsurance?.recommendation ?? '',
      ),
      prepareInsuranceUrlCtrl: TextEditingController(
        text: version.prepare?.travelInsurance?.url ?? '',
      ),
      prepareInsuranceNoteCtrl: TextEditingController(
        text: version.prepare?.travelInsurance?.note ?? '',
      ),
      prepareVisaRequirementCtrl: TextEditingController(
        text: version.prepare?.visa?.requirement ?? '',
      ),
      prepareVisaUrlCtrl: TextEditingController(
        text: version.prepare?.visa?.requirement ?? '', // Note: visa doesn't have URL in model
      ),
      prepareVisaNoteCtrl: TextEditingController(
        text: version.prepare?.visa?.note ?? '',
      ),
      preparePassportValidityCtrl: TextEditingController(
        text: version.prepare?.passport?.validityRequirement ?? '',
      ),
      preparePassportNoteCtrl: TextEditingController(
        text: version.prepare?.passport?.blankPagesRequired ?? '',
      ),
      permits: (version.prepare?.permits ?? []).map((p) => PermitFormState.fromModel(p)).toList(),
      prepareVaccinesRequiredCtrl: TextEditingController(
        text: (version.prepare?.vaccines?.required ?? []).join(', '),
      ),
      prepareVaccinesRecommendedCtrl: TextEditingController(
        text: (version.prepare?.vaccines?.recommended ?? []).join(', '),
      ),
      prepareVaccinesNoteCtrl: TextEditingController(
        text: version.prepare?.vaccines?.note ?? '',
      ),
      prepareClimateDescriptionCtrl: TextEditingController(
        text: version.prepare?.climate?.location ?? '',
      ),
      prepareClimateBestTimeCtrl: TextEditingController(
        text: '', // Climate best time not in model structure
      ),
      packingCategories: version.packingCategories
          .map((cat) => PackingCategoryFormState.fromModel(cat))
          .toList(),
      transportationOptions: version.transportationOptions
          .map((t) => TransportationFormState.fromModel(t))
          .toList(),
      foodSpecialties: (version.localTips?.foodSpecialties ?? [])
          .map((f) => FoodSpecialtyFormState.fromModel(f))
          .toList(),
      etiquetteItems: (version.localTips?.etiquette ?? [])
          .map((e) => EtiquetteFormState.fromString(e))
          .toList(),
      foodWarnings: (version.localTips?.foodWarnings ?? [])
          .map((w) => FoodWarningFormState.fromString(w))
          .toList(),
      localTipsLanguageCtrl: TextEditingController(), // Not in model
      localTipsCurrencyCtrl: TextEditingController(), // Not in model
      localTipsEmergencyPoliceCtrl: TextEditingController(
        text: version.localTips?.emergency?.police ?? '',
      ),
      localTipsEmergencyAmbulanceCtrl: TextEditingController(
        text: version.localTips?.emergency?.ambulance ?? '',
      ),
      localTipsEmergencyFireCtrl: TextEditingController(
        text: version.localTips?.emergency?.fire ?? '',
      ),
      localTipsEmergencyTouristCtrl: TextEditingController(
        text: version.localTips?.emergency?.generalEmergency ?? '',
      ),
      localTipsEmergencyNoteCtrl: TextEditingController(
        text: version.localTips?.emergency?.mountainRescue ?? '',
      ),
      localTipsGeneralEmergencyCtrl: TextEditingController(
        text: version.localTips?.emergency?.generalEmergency ?? '',
      ),
      localTipsMessagingAppNameCtrl: TextEditingController(
        text: version.localTips?.messagingApp?.name ?? '',
      ),
      localTipsMessagingAppNoteCtrl: TextEditingController(
        text: version.localTips?.messagingApp?.note ?? '',
      ),
      localTipsTippingPracticeCtrl: TextEditingController(
        text: version.localTips?.tipping?.practice ?? '',
      ),
      localTipsTippingRestaurantCtrl: TextEditingController(
        text: version.localTips?.tipping?.restaurant ?? '',
      ),
      localTipsTippingTaxiCtrl: TextEditingController(
        text: version.localTips?.tipping?.taxi ?? '',
      ),
      localTipsTippingHotelCtrl: TextEditingController(
        text: version.localTips?.tipping?.hotel ?? '',
      ),
      generatedPrepare: version.prepare,
      generatedLocalTips: version.localTips,
    );
    
    // Hydrate day states
    for (final day in version.days) {
      final dayState = state.getDayState(day.dayNum);
      dayState.titleCtrl.text = day.title;
      dayState.descCtrl.text = day.description;
      dayState.distanceCtrl.text = day.distanceKm.toStringAsFixed(2);
      dayState.timeCtrl.text = (day.estimatedTimeMinutes / 60.0).toStringAsFixed(1);
      if (day.stay != null) {
        dayState.stayUrlCtrl.text = day.stay!.bookingLink ?? '';
        dayState.stayCostCtrl.text = day.stay!.cost?.toStringAsFixed(2) ?? '';
        if (day.stay!.linkTitle != null || day.stay!.linkDescription != null) {
          dayState.stayMeta = LinkPreviewData(
            url: day.stay!.bookingLink ?? '',
            title: day.stay!.linkTitle,
            description: day.stay!.linkDescription,
            imageUrl: day.stay!.linkImageUrl,
            siteName: day.stay!.linkSiteName,
          );
        }
      }
      dayState.komootLinkCtrl.text = day.komootLink ?? '';
      dayState.allTrailsLinkCtrl.text = day.allTrailsLink ?? '';
      if (day.startLat != null && day.startLng != null) {
        dayState.start = ll.LatLng(day.startLat!, day.startLng!);
      }
      if (day.endLat != null && day.endLng != null) {
        dayState.end = ll.LatLng(day.endLat!, day.endLng!);
      }
      dayState.route = day.route;
      dayState.routeInfo = day.routeInfo;
      dayState.gpxRoute = day.gpxRoute;
      if (day.photos.isNotEmpty) {
        dayState.existingImageUrls = List<String>.from(day.photos);
      }
    }
    
    return state;
  }
  
  // --- Dispose ---
  @override
  void dispose() {
    nameCtrl.dispose();
    durationCtrl.dispose();
    // Dispose all prepare controllers
    prepareInsuranceRecommendationCtrl.dispose();
    prepareInsuranceUrlCtrl.dispose();
    prepareInsuranceNoteCtrl.dispose();
    prepareVisaRequirementCtrl.dispose();
    prepareVisaUrlCtrl.dispose();
    prepareVisaNoteCtrl.dispose();
    preparePassportValidityCtrl.dispose();
    preparePassportNoteCtrl.dispose();
    for (final p in permits) { p.dispose(); }
    prepareVaccinesRequiredCtrl.dispose();
    prepareVaccinesRecommendedCtrl.dispose();
    prepareVaccinesNoteCtrl.dispose();
    prepareClimateDescriptionCtrl.dispose();
    prepareClimateBestTimeCtrl.dispose();
    // Dispose packing & transportation
    for (final p in packingCategories) { p.dispose(); }
    for (final t in transportationOptions) { t.dispose(); }
    // Dispose local tips controllers
    for (final f in foodSpecialties) { f.dispose(); }
    for (final e in etiquetteItems) { e.dispose(); }
    for (final w in foodWarnings) { w.dispose(); }
    localTipsLanguageCtrl.dispose();
    localTipsCurrencyCtrl.dispose();
    localTipsEmergencyPoliceCtrl.dispose();
    localTipsEmergencyAmbulanceCtrl.dispose();
    localTipsEmergencyFireCtrl.dispose();
    localTipsEmergencyTouristCtrl.dispose();
    localTipsEmergencyNoteCtrl.dispose();
    localTipsGeneralEmergencyCtrl.dispose();
    localTipsMessagingAppNameCtrl.dispose();
    localTipsMessagingAppNoteCtrl.dispose();
    localTipsTippingPracticeCtrl.dispose();
    localTipsTippingRestaurantCtrl.dispose();
    localTipsTippingTaxiCtrl.dispose();
    localTipsTippingHotelCtrl.dispose();
    // Dispose days
    for (final day in _days.values) { day.dispose(); }
    super.dispose();
  }
}

