import Foundation
import Observation

// MARK: - MerchantCategoryService
// Resolves a merchant name to a spending category using map/place data:
//   1. Google Places (Text Search) when the user has configured an API key
//   2. OpenStreetMap Nominatim as the keyless fallback
// Only consulted when rules, learned history, and keywords all failed, and
// every verdict (including "nothing found") is cached per merchant so each
// merchant costs at most one network call ever.

@Observable
@MainActor
final class MerchantCategoryService {
    static let shared = MerchantCategoryService()

    static let enabledKey = "maps_category_enabled"
    static let apiKeyKey = "google_places_api_key"

    /// merchant key → TransactionCategory rawValue ("" = looked up, no result)
    private var cache: [String: String]
    private let cacheKey = "ft_merchant_maps_category_cache_v1"

    private init() {
        cache = (UserDefaults.standard.dictionary(forKey: cacheKey) as? [String: String]) ?? [:]
    }

    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
    }

    var googleAPIKey: String {
        get { UserDefaults.standard.string(forKey: Self.apiKeyKey) ?? "" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Self.apiKeyKey) }
    }

    var cachedCount: Int { cache.count }

    // MARK: - Lookup

    func lookupCategory(for merchant: String) async -> (category: TransactionCategory, source: String)? {
        guard isEnabled else { return nil }
        let key = ImportLearningService.merchantKey(merchant)
        guard key.count >= 3 else { return nil }

        if let cached = cache[key] {
            guard !cached.isEmpty, let category = TransactionCategory(rawValue: cached) else { return nil }
            return (category, "Maps (cached)")
        }

        var result: (TransactionCategory, String)?
        if !googleAPIKey.isEmpty, let fromGoogle = await lookupGooglePlaces(merchant: merchant) {
            result = (fromGoogle, "Google Maps")
        } else if let fromOSM = await lookupNominatim(merchant: merchant) {
            result = (fromOSM, "OpenStreetMap")
        }

        cache[key] = result?.0.rawValue ?? ""
        UserDefaults.standard.set(cache, forKey: cacheKey)
        return result.map { (category: $0.0, source: $0.1) }
    }

    // MARK: - Google Places (Text Search, New API)

    private func lookupGooglePlaces(merchant: String) async -> TransactionCategory? {
        guard let url = URL(string: "https://places.googleapis.com/v1/places:searchText") else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(googleAPIKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue("places.types", forHTTPHeaderField: "X-Goog-FieldMask")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "textQuery": merchant,
            "maxResultCount": 1,
            "regionCode": "AE",
        ])

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let places = json["places"] as? [[String: Any]],
              let types = places.first?["types"] as? [String] else { return nil }

        for type in types {
            if let category = Self.category(forPlaceType: type) { return category }
        }
        return nil
    }

    // MARK: - OpenStreetMap Nominatim (keyless fallback)

    private func lookupNominatim(merchant: String) async -> TransactionCategory? {
        let query = merchant.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? merchant
        guard let url = URL(string: "https://nominatim.openstreetmap.org/search?q=\(query)&format=jsonv2&limit=1") else {
            return nil
        }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("FinTrack-iOS/1.0 (personal finance app)", forHTTPHeaderField: "User-Agent")
        request.setValue("en", forHTTPHeaderField: "Accept-Language")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let results = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = results.first else { return nil }

        // Nominatim tags places as class/type pairs, e.g. amenity/restaurant,
        // shop/supermarket — both slot into the same mapping table.
        let osmClass = first["class"] as? String ?? ""
        let osmType = first["type"] as? String ?? ""
        return Self.category(forPlaceType: osmType) ?? Self.category(forPlaceType: osmClass)
    }

    // MARK: - Place type → TransactionCategory

    /// Shared mapping for Google place types and OSM class/type tags.
    static func category(forPlaceType rawType: String) -> TransactionCategory? {
        switch rawType.lowercased() {
        case "restaurant", "cafe", "coffee_shop", "bakery", "bar", "fast_food",
             "meal_takeaway", "meal_delivery", "food", "food_court", "ice_cream_shop",
             "supermarket", "grocery_store", "grocery_or_supermarket", "convenience_store",
             "butcher", "greengrocer":
            return .food
        case "gas_station", "fuel", "charging_station", "electric_vehicle_charging_station":
            return .fuel
        case "shopping_mall", "mall", "department_store", "clothing_store", "clothes",
             "shoe_store", "shoes", "jewelry_store", "jewelry", "electronics_store",
             "electronics", "furniture_store", "furniture", "home_goods_store",
             "hardware_store", "doityourself", "gift_shop", "store", "shop",
             "book_store", "books", "toy_store", "toys", "pet_store", "sporting_goods_store":
            return .shopping
        case "pharmacy", "chemist", "drugstore", "hospital", "clinic", "doctor",
             "doctors", "dentist", "dental_clinic", "veterinary_care", "medical_lab":
            return .medical
        case "movie_theater", "cinema", "amusement_park", "theme_park", "bowling_alley",
             "casino", "night_club", "nightclub", "arcade", "video_arcade", "theatre",
             "concert_hall", "stadium", "zoo", "aquarium", "water_park":
            return .entertainment
        case "lodging", "hotel", "motel", "resort_hotel", "guest_house", "hostel",
             "travel_agency", "airport", "airline":
            return .travel
        case "school", "university", "college", "primary_school", "secondary_school",
             "kindergarten", "library", "tutoring_service":
            return .education
        case "taxi_stand", "taxi", "transit_station", "bus_station", "train_station",
             "subway_station", "parking", "car_rental", "car_wash", "car_repair", "car_dealer":
            return .transportation
        case "gym", "fitness_center", "fitness_centre", "sports_club", "yoga_studio":
            return .subscriptions
        case "insurance_agency", "insurance":
            return .insurance
        case "beauty_salon", "hair_care", "hairdresser", "spa", "nail_salon", "laundry", "dry_cleaning":
            return .other
        default:
            return nil
        }
    }
}
