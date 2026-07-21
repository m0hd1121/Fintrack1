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

    static let apiKeyKey = "google_places_api_key"

    /// merchant key → TransactionCategory rawValue ("" = looked up, no result)
    private var cache: [String: String]
    // v2: a prior bug cached a negative result even when a lookup merely
    // *failed* (bad key, quota, network) rather than genuinely finding
    // nothing — bumping this key gives every merchant a clean retry.
    // v3: the lookup got materially stronger (country-biased search, walking
    // multiple results, a much wider place-type→category table), so re-evaluate
    // every merchant instead of trusting stale negatives from the weaker logic.
    private let cacheKey = "ft_merchant_maps_category_cache_v3"

    private init() {
        cache = (UserDefaults.standard.dictionary(forKey: cacheKey) as? [String: String]) ?? [:]
    }

    /// Always on. Merchant→category map lookup is a silent enhancement with no
    /// user-facing toggle; any value a previously-shown toggle may have stored
    /// is ignored so the feature can never get stuck off.
    var isEnabled: Bool { true }

    var googleAPIKey: String {
        get { UserDefaults.standard.string(forKey: Self.apiKeyKey) ?? "" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Self.apiKeyKey) }
    }

    var cachedCount: Int { cache.count }

    /// ISO country code used to bias place lookups to where the user actually
    /// spends. Defaults to AE (the app's home market) when the device region
    /// isn't available. Finance transactions are almost always domestic, so
    /// biasing sharply improves precision (a same-named shop abroad won't win).
    private var regionCode: String {
        Locale.current.region?.identifier ?? "AE"
    }

    // MARK: - Lookup

    /// Distinguishes a genuine "no place found" from a request failure
    /// (bad/unbilled key, API not enabled, quota, network hiccup) so a
    /// transient failure never permanently caches a negative result nor
    /// blocks the free OpenStreetMap fallback.
    private enum LookupOutcome {
        case found(TransactionCategory)
        case notFound
        case failed
    }

    func lookupCategory(for merchant: String) async -> (category: TransactionCategory, source: String)? {
        guard isEnabled else { return nil }
        let key = ImportLearningService.merchantKey(merchant)
        guard key.count >= 3 else { return nil }

        if let cached = cache[key] {
            guard !cached.isEmpty, let category = TransactionCategory(rawValue: cached) else { return nil }
            return (category, "Maps (cached)")
        }

        var result: (TransactionCategory, String)?
        var definitive = true   // false when every attempt failed rather than genuinely finding nothing

        if !googleAPIKey.isEmpty {
            switch await lookupGooglePlaces(merchant: merchant) {
            case .found(let category): result = (category, "Google Maps")
            case .notFound: break
            case .failed: definitive = false
            }
        }

        if result == nil {
            switch await lookupNominatim(merchant: merchant) {
            case .found(let category): result = (category, "OpenStreetMap")
            case .notFound: break
            case .failed: definitive = false
            }
        }

        // Only cache a negative result when every source we tried gave an
        // authoritative "not found" — a failure should be retried next sync.
        if result != nil || definitive {
            cache[key] = result?.0.rawValue ?? ""
            UserDefaults.standard.set(cache, forKey: cacheKey)
        }
        return result.map { (category: $0.0, source: $0.1) }
    }

    // MARK: - Google Places (Text Search, New API)

    private func lookupGooglePlaces(merchant: String) async -> LookupOutcome {
        guard let url = URL(string: "https://places.googleapis.com/v1/places:searchText") else { return .failed }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(googleAPIKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue("places.primaryType,places.types", forHTTPHeaderField: "X-Goog-FieldMask")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "textQuery": merchant,
            "maxResultCount": 1,
            "regionCode": regionCode,
        ])

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else { return .failed }
        guard http.statusCode == 200 else { return .failed }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let places = json["places"] as? [[String: Any]],
              let place = places.first else { return .notFound }

        // primaryType is the single most representative type (what Google shows
        // as the place's label, e.g. "Hypermarket"), so trust it before falling
        // back to the broader `types` list.
        let primary = place["primaryType"] as? String
        let types = place["types"] as? [String] ?? []
        for type in ([primary].compactMap { $0 } + types) {
            if let category = Self.category(forPlaceType: type) { return .found(category) }
        }
        return .notFound
    }

    // MARK: - OpenStreetMap Nominatim (keyless fallback)

    private func lookupNominatim(merchant: String) async -> LookupOutcome {
        let query = merchant.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? merchant
        // Pull several candidates and bias to the user's country: the single top
        // hit is often a road or admin area that maps to nothing, while the real
        // shop sits a couple rows down.
        let country = regionCode.lowercased()
        guard let url = URL(string: "https://nominatim.openstreetmap.org/search?q=\(query)&format=jsonv2&limit=10&countrycodes=\(country)") else {
            return .failed
        }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("FinTrack-iOS/1.0 (personal finance app)", forHTTPHeaderField: "User-Agent")
        request.setValue("en", forHTTPHeaderField: "Accept-Language")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else { return .failed }
        guard http.statusCode == 200 else { return .failed }
        guard let results = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return .failed }
        guard !results.isEmpty else { return .notFound }

        // Nominatim tags places as class/type pairs, e.g. amenity/restaurant,
        // shop/supermarket — both slot into the same mapping table. Walk the
        // ranked results and take the first that maps to a category.
        for place in results {
            let osmClass = place["class"] as? String ?? ""
            let osmType = place["type"] as? String ?? ""
            if let category = Self.category(forPlaceType: osmType) ?? Self.category(forPlaceType: osmClass) {
                return .found(category)
            }
        }
        return .notFound
    }

    // MARK: - Place type → TransactionCategory

    /// Shared mapping for Google place types and OSM class/type tags.
    static func category(forPlaceType rawType: String) -> TransactionCategory? {
        switch rawType.lowercased() {
        case "restaurant", "cafe", "cafeteria", "coffee_shop", "coffee", "tea", "bakery",
             "pastry", "bar", "pub", "fast_food", "meal_takeaway", "meal_delivery", "food",
             "food_court", "ice_cream_shop", "ice_cream", "supermarket", "hypermarket",
             "grocery_store", "grocery_or_supermarket", "grocery", "convenience_store",
             "convenience", "butcher", "greengrocer", "deli", "seafood", "confectionery",
             "chocolate", "beverages", "spices", "dairy", "cheese", "farm", "alcohol", "wine":
            return .food
        case "gas_station", "fuel", "charging_station", "electric_vehicle_charging_station":
            return .fuel
        case "shopping_mall", "mall", "marketplace", "department_store", "variety_store",
             "general", "kiosk", "clothing_store", "clothes", "boutique", "fashion_accessories",
             "shoe_store", "shoes", "bag", "jewelry_store", "jewelry", "watches",
             "electronics_store", "electronics", "computer", "mobile_phone", "mobile_phone_shop",
             "hifi", "video_games", "furniture_store", "furniture", "interior_decoration",
             "home_goods_store", "houseware", "kitchen", "appliance", "hardware_store", "hardware",
             "doityourself", "trade", "gift_shop", "gift", "store", "shop", "book_store", "books",
             "stationery", "toy_store", "toys", "pet_store", "pet", "sporting_goods_store",
             "sports", "cosmetics", "perfumery", "chemist_retail", "optician", "florist",
             "fabric", "second_hand", "department":
            return .shopping
        case "pharmacy", "chemist", "drugstore", "hospital", "clinic", "doctor",
             "doctors", "dentist", "dental_clinic", "veterinary_care", "medical_lab", "medical_supply":
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
             "subway_station", "parking", "car_rental", "car_wash", "car_repair", "car_dealer",
             "car", "car_parts", "tyres", "motorcycle":
            return .transportation
        case "gym", "fitness_center", "fitness_centre", "sports_club", "sports_centre", "yoga_studio":
            return .subscriptions
        case "insurance_agency", "insurance":
            return .insurance
        case "beauty_salon", "beauty", "hair_care", "hairdresser", "barber", "spa", "massage",
             "nail_salon", "laundry", "dry_cleaning":
            return .other
        default:
            return nil
        }
    }
}
