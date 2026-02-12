import 'package:cloud_firestore/cloud_firestore.dart';

/// AI-generated travel preparation information
class Prepare {
  final TravelInsurance? travelInsurance;
  final VisaInfo? visa;
  final PassportInfo? passport;
  final List<Permit> permits;
  final VaccineInfo? vaccines;
  final ClimateData? climate;

  Prepare({
    this.travelInsurance,
    this.visa,
    this.passport,
    this.permits = const [],
    this.vaccines,
    this.climate,
  });

  factory Prepare.fromJson(Map<String, dynamic>? json) {
    if (json == null) return Prepare();
    
    return Prepare(
      travelInsurance: json['travel_insurance'] != null
          ? TravelInsurance.fromJson(json['travel_insurance'] as Map<String, dynamic>)
          : null,
      visa: json['visa'] != null
          ? VisaInfo.fromJson(json['visa'] as Map<String, dynamic>)
          : null,
      passport: json['passport'] != null
          ? PassportInfo.fromJson(json['passport'] as Map<String, dynamic>)
          : null,
      permits: (json['permits'] as List<dynamic>?)
          ?.map((p) => Permit.fromJson(p as Map<String, dynamic>))
          .toList() ?? [],
      vaccines: json['vaccines'] != null
          ? VaccineInfo.fromJson(json['vaccines'] as Map<String, dynamic>)
          : null,
      climate: json['climate'] != null
          ? ClimateData.fromJson(json['climate'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (travelInsurance != null) 'travel_insurance': travelInsurance!.toJson(),
      if (visa != null) 'visa': visa!.toJson(),
      if (passport != null) 'passport': passport!.toJson(),
      'permits': permits.map((p) => p.toJson()).toList(),
      if (vaccines != null) 'vaccines': vaccines!.toJson(),
      if (climate != null) 'climate': climate!.toJson(),
    };
  }
}

class TravelInsurance {
  final String recommendation;
  final String url;
  final String note;

  TravelInsurance({
    required this.recommendation,
    required this.url,
    required this.note,
  });

  factory TravelInsurance.fromJson(Map<String, dynamic> json) {
    return TravelInsurance(
      recommendation: json['recommendation'] as String? ?? '',
      url: json['url'] as String? ?? '',
      note: json['note'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'recommendation': recommendation,
      'url': url,
      'note': note,
    };
  }
}

class VisaInfo {
  final String requirement;
  final bool medicalInsuranceRequiredForVisa;
  final String? note;

  VisaInfo({
    required this.requirement,
    required this.medicalInsuranceRequiredForVisa,
    this.note,
  });

  factory VisaInfo.fromJson(Map<String, dynamic> json) {
    return VisaInfo(
      requirement: json['requirement'] as String? ?? '',
      medicalInsuranceRequiredForVisa: json['medical_insurance_required_for_visa'] as bool? ?? false,
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'requirement': requirement,
      'medical_insurance_required_for_visa': medicalInsuranceRequiredForVisa,
      if (note != null) 'note': note,
    };
  }
}

class PassportInfo {
  final String validityRequirement;
  final String blankPagesRequired;

  PassportInfo({
    required this.validityRequirement,
    required this.blankPagesRequired,
  });

  factory PassportInfo.fromJson(Map<String, dynamic> json) {
    return PassportInfo(
      validityRequirement: json['validity_requirement'] as String? ?? '',
      blankPagesRequired: json['blank_pages_required'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'validity_requirement': validityRequirement,
      'blank_pages_required': blankPagesRequired,
    };
  }
}

class Permit {
  final String type;
  final String details;
  final String howToObtain;
  final String? cost;

  Permit({
    required this.type,
    required this.details,
    required this.howToObtain,
    this.cost,
  });

  factory Permit.fromJson(Map<String, dynamic> json) {
    return Permit(
      type: json['type'] as String? ?? '',
      details: json['details'] as String? ?? '',
      howToObtain: json['how_to_obtain'] as String? ?? '',
      cost: json['cost'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'details': details,
      'how_to_obtain': howToObtain,
      if (cost != null) 'cost': cost,
    };
  }
}

class VaccineInfo {
  final List<String> required;
  final List<String> recommended;
  final String? note;

  VaccineInfo({
    this.required = const [],
    this.recommended = const [],
    this.note,
  });

  factory VaccineInfo.fromJson(Map<String, dynamic> json) {
    return VaccineInfo(
      required: (json['required'] as List<dynamic>?)
          ?.map((v) => v.toString())
          .toList() ?? [],
      recommended: (json['recommended'] as List<dynamic>?)
          ?.map((v) => v.toString())
          .toList() ?? [],
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'required': required,
      'recommended': recommended,
      if (note != null) 'note': note,
    };
  }
}

class ClimateData {
  final String location;
  final List<ClimateMonth> data;

  ClimateData({
    required this.location,
    this.data = const [],
  });

  factory ClimateData.fromJson(Map<String, dynamic> json) {
    return ClimateData(
      location: json['location'] as String? ?? '',
      data: (json['data'] as List<dynamic>?)
          ?.map((m) => ClimateMonth.fromJson(m as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'location': location,
      'data': data.map((m) => m.toJson()).toList(),
    };
  }
}

class ClimateMonth {
  final String month;
  final double avgTempHighC;
  final double avgTempLowC;
  final double avgRainMm;
  final int avgRainDays;
  final double avgDaylightHours;

  ClimateMonth({
    required this.month,
    required this.avgTempHighC,
    required this.avgTempLowC,
    required this.avgRainMm,
    required this.avgRainDays,
    required this.avgDaylightHours,
  });

  factory ClimateMonth.fromJson(Map<String, dynamic> json) {
    return ClimateMonth(
      month: json['month'] as String? ?? '',
      avgTempHighC: (json['avg_temp_high_c'] as num?)?.toDouble() ?? 0.0,
      avgTempLowC: (json['avg_temp_low_c'] as num?)?.toDouble() ?? 0.0,
      avgRainMm: (json['avg_rain_mm'] as num?)?.toDouble() ?? 0.0,
      avgRainDays: (json['avg_rain_days'] as num?)?.toInt() ?? 0,
      avgDaylightHours: (json['avg_daylight_hours'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'month': month,
      'avg_temp_high_c': avgTempHighC,
      'avg_temp_low_c': avgTempLowC,
      'avg_rain_mm': avgRainMm,
      'avg_rain_days': avgRainDays,
      'avg_daylight_hours': avgDaylightHours,
    };
  }
}

/// AI-generated local tips and cultural information
class LocalTips {
  final EmergencyInfo? emergency;
  final MessagingApp? messagingApp;
  final List<String> etiquette;
  final TippingInfo? tipping;
  final List<BasicPhrase> basicPhrases;
  final List<FoodSpecialty> foodSpecialties;
  final List<String> foodWarnings;

  LocalTips({
    this.emergency,
    this.messagingApp,
    this.etiquette = const [],
    this.tipping,
    this.basicPhrases = const [],
    this.foodSpecialties = const [],
    this.foodWarnings = const [],
  });

  factory LocalTips.fromJson(Map<String, dynamic>? json) {
    if (json == null) return LocalTips();
    
    return LocalTips(
      emergency: json['emergency'] != null
          ? EmergencyInfo.fromJson(json['emergency'] as Map<String, dynamic>)
          : null,
      messagingApp: json['messaging_app'] != null
          ? MessagingApp.fromJson(json['messaging_app'] as Map<String, dynamic>)
          : null,
      etiquette: (json['etiquette'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      tipping: json['tipping'] != null
          ? TippingInfo.fromJson(json['tipping'] as Map<String, dynamic>)
          : null,
      basicPhrases: (json['basic_phrases'] as List<dynamic>?)
          ?.map((p) => BasicPhrase.fromJson(p as Map<String, dynamic>))
          .toList() ?? [],
      foodSpecialties: (json['food_specialties'] as List<dynamic>?)
          ?.map((f) => FoodSpecialty.fromJson(f as Map<String, dynamic>))
          .toList() ?? [],
      foodWarnings: (json['food_warnings'] as List<dynamic>?)
          ?.map((w) => w.toString())
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (emergency != null) 'emergency': emergency!.toJson(),
      if (messagingApp != null) 'messaging_app': messagingApp!.toJson(),
      'etiquette': etiquette,
      if (tipping != null) 'tipping': tipping!.toJson(),
      'basic_phrases': basicPhrases.map((p) => p.toJson()).toList(),
      'food_specialties': foodSpecialties.map((f) => f.toJson()).toList(),
      'food_warnings': foodWarnings,
    };
  }
}

class EmergencyInfo {
  final String generalEmergency;
  final String police;
  final String ambulance;
  final String fire;
  final String? mountainRescue;

  EmergencyInfo({
    required this.generalEmergency,
    required this.police,
    required this.ambulance,
    required this.fire,
    this.mountainRescue,
  });

  factory EmergencyInfo.fromJson(Map<String, dynamic> json) {
    return EmergencyInfo(
      generalEmergency: json['general_emergency'] as String? ?? '',
      police: json['police'] as String? ?? '',
      ambulance: json['ambulance'] as String? ?? '',
      fire: json['fire'] as String? ?? '',
      mountainRescue: json['mountain_rescue'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'general_emergency': generalEmergency,
      'police': police,
      'ambulance': ambulance,
      'fire': fire,
      if (mountainRescue != null) 'mountain_rescue': mountainRescue,
    };
  }
}

class MessagingApp {
  final String name;
  final String note;

  MessagingApp({
    required this.name,
    required this.note,
  });

  factory MessagingApp.fromJson(Map<String, dynamic> json) {
    return MessagingApp(
      name: json['name'] as String? ?? '',
      note: json['note'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'note': note,
    };
  }
}

class TippingInfo {
  final String practice;
  final String restaurant;
  final String taxi;
  final String hotel;

  TippingInfo({
    required this.practice,
    required this.restaurant,
    required this.taxi,
    required this.hotel,
  });

  factory TippingInfo.fromJson(Map<String, dynamic> json) {
    return TippingInfo(
      practice: json['practice'] as String? ?? '',
      restaurant: json['restaurant'] as String? ?? '',
      taxi: json['taxi'] as String? ?? '',
      hotel: json['hotel'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'practice': practice,
      'restaurant': restaurant,
      'taxi': taxi,
      'hotel': hotel,
    };
  }
}

class BasicPhrase {
  final String english;
  final String local;
  final String pronunciation;

  BasicPhrase({
    required this.english,
    required this.local,
    required this.pronunciation,
  });

  factory BasicPhrase.fromJson(Map<String, dynamic> json) {
    return BasicPhrase(
      english: json['english'] as String? ?? '',
      local: json['local'] as String? ?? '',
      pronunciation: json['pronunciation'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'english': english,
      'local': local,
      'pronunciation': pronunciation,
    };
  }
}

class FoodSpecialty {
  final String name;
  final String description;

  FoodSpecialty({
    required this.name,
    required this.description,
  });

  factory FoodSpecialty.fromJson(Map<String, dynamic> json) {
    return FoodSpecialty(
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
    };
  }
}

