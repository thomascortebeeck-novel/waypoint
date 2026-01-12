import 'package:uuid/uuid.dart';
import 'package:waypoint/models/plan_model.dart';

// Re-export models for backward compatibility
export 'package:waypoint/models/plan_model.dart';

// ==========================================
// MOCK DATA GENERATOR
// ==========================================

const _uuid = Uuid();

final List<Plan> mockPlans = [
  Plan(
    id: _uuid.v4(),
    name: "The Arctic Trail",
    description: "Experience the raw beauty of the Arctic circle. This trail takes you through untouched wilderness, glaciers, and remote fjords.",
    heroImageUrl: "https://images.unsplash.com/photo-1531366936337-7c912a4589a7?q=80&w=2070&auto=format&fit=crop",
    location: "Norway / Sweden",
    basePrice: 0,
    creatorId: "admin",
    creatorName: "Nordic Explorer",
    isFeatured: true,
    isPublished: true,
    createdAt: DateTime.now().subtract(const Duration(days: 30)),
    updatedAt: DateTime.now().subtract(const Duration(days: 30)),
    versions: [
      PlanVersion(
        id: _uuid.v4(),
        name: "5-Day Extreme",
        durationDays: 5,
        difficulty: Difficulty.extreme,
        comfortType: ComfortType.extreme,
        price: 2.0,
        days: List.generate(5, (index) => DayItinerary(
          dayNum: index + 1,
          title: "Day ${index + 1}: Crossing the Pass",
          description: "A challenging day with steep accents and breathtaking views of the glacier.",
          distanceKm: 18.5,
          estimatedTimeMinutes: 420,
          stay: StayInfo(name: "Wild Camp site ${index+1}", type: "Campsite", cost: 0),
          photos: ["https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?q=80&w=2070&auto=format&fit=crop"],
        )),
      ),
      PlanVersion(
        id: _uuid.v4(),
        name: "3-Day Comfort",
        durationDays: 3,
        difficulty: Difficulty.moderate,
        comfortType: ComfortType.comfort,
        price: 2.0,
        days: List.generate(3, (index) => DayItinerary(
          dayNum: index + 1,
          title: "Day ${index + 1}: Valley Walk",
          description: "Relaxed walking through the valley floor with stops at local villages.",
          distanceKm: 12.0,
          estimatedTimeMinutes: 240,
          stay: StayInfo(name: "Mountain Lodge ${index+1}", type: "Lodge", cost: 80.0, bookingLink: "https://booking.com"),
          photos: ["https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?q=80&w=1948&auto=format&fit=crop"],
        )),
      ),
    ],
  ),
  Plan(
    id: _uuid.v4(),
    name: "Patagonia Peaks",
    description: "The ultimate South American trekking experience. Jagged peaks, turquoise lakes, and wind-swept plains.",
    heroImageUrl: "https://images.unsplash.com/photo-1518081461904-7d8590635f79?q=80&w=2070&auto=format&fit=crop",
    location: "Chile / Argentina",
    basePrice: 2.0,
    creatorId: "admin",
    creatorName: "Andes Adventures",
    isPublished: true,
    createdAt: DateTime.now().subtract(const Duration(days: 20)),
    updatedAt: DateTime.now().subtract(const Duration(days: 20)),
    versions: [
      PlanVersion(
        id: _uuid.v4(),
        name: "W-Trek Classic",
        durationDays: 5,
        difficulty: Difficulty.hard,
        comfortType: ComfortType.comfort,
        price: 5.0,
        days: [],
      ),
    ],
  ),
  Plan(
    id: _uuid.v4(),
    name: "Dolomites Alta Via",
    description: "High altitude trekking in the Italian Alps. Dramatic rock formations and delicious cuisine.",
    heroImageUrl: "https://images.unsplash.com/photo-1483729558449-99ef09a8c325?q=80&w=2070&auto=format&fit=crop",
    location: "Italy",
    basePrice: 2.0,
    creatorId: "admin",
    creatorName: "Alpine Guides",
    isPublished: true,
    createdAt: DateTime.now().subtract(const Duration(days: 15)),
    updatedAt: DateTime.now().subtract(const Duration(days: 15)),
    versions: [],
  ),
   Plan(
    id: _uuid.v4(),
    name: "Kyoto Ancient Trails",
    description: "Walk the path of samurais and monks. A spiritual journey through forests and temples.",
    heroImageUrl: "https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?q=80&w=2070&auto=format&fit=crop",
    location: "Japan",
    basePrice: 0.0,
    creatorId: "admin",
    creatorName: "Zen Walker",
    isPublished: true,
    createdAt: DateTime.now().subtract(const Duration(days: 10)),
    updatedAt: DateTime.now().subtract(const Duration(days: 10)),
    versions: [],
  ),
];
