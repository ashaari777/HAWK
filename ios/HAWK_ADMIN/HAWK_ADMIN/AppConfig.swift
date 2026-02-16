import Foundation
import BackgroundTasks
import UserNotifications

struct PricePoint: Codable, Hashable, Identifiable {
    let id: UUID
    let timestamp: Date
    let price: Double

    init(id: UUID = UUID(), timestamp: Date, price: Double) {
        self.id = id
        self.timestamp = timestamp
        self.price = price
    }
}

struct AppEventLogEntry: Codable, Hashable, Identifiable {
    let id: UUID
    let timestamp: Date
    let message: String

    init(id: UUID = UUID(), timestamp: Date = Date(), message: String) {
        self.id = id
        self.timestamp = timestamp
        self.message = message
    }
}

struct TrackedItem: Identifiable, Codable, Equatable {
    var id: UUID
    var remoteItemID: Int?
    var asin: String
    var productURL: String
    var title: String?
    var targetPrice: Double
    var lastPrice: Double?
    var lastPriceText: String?
    var sellerName: String?
    var lastCheckedAt: Date?
    var lastError: String?
    var lastNotifiedPrice: Double?
    var discountPercent: Int?
    var couponText: String?
    var couponPercents: [Int]
    var priceHistory: [PricePoint]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        remoteItemID: Int? = nil,
        asin: String,
        productURL: String,
        title: String? = nil,
        targetPrice: Double,
        lastPrice: Double? = nil,
        lastPriceText: String? = nil,
        sellerName: String? = nil,
        lastCheckedAt: Date? = nil,
        lastError: String? = nil,
        lastNotifiedPrice: Double? = nil,
        discountPercent: Int? = nil,
        couponText: String? = nil,
        couponPercents: [Int] = [],
        priceHistory: [PricePoint] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.remoteItemID = remoteItemID
        self.asin = asin
        self.productURL = productURL
        self.title = title
        self.targetPrice = targetPrice
        self.lastPrice = lastPrice
        self.lastPriceText = lastPriceText
        self.sellerName = sellerName
        self.lastCheckedAt = lastCheckedAt
        self.lastError = lastError
        self.lastNotifiedPrice = lastNotifiedPrice
        self.discountPercent = discountPercent
        self.couponText = couponText
        self.couponPercents = couponPercents
        self.priceHistory = priceHistory
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case remoteItemID
        case asin
        case productURL
        case title
        case targetPrice
        case lastPrice
        case lastPriceText
        case sellerName
        case lastCheckedAt
        case lastError
        case lastNotifiedPrice
        case discountPercent
        case couponText
        case couponPercents
        case legacyCouponPercent = "couponPercent"
        case priceHistory
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        remoteItemID = try c.decodeIfPresent(Int.self, forKey: .remoteItemID)
        asin = try c.decodeIfPresent(String.self, forKey: .asin) ?? ""
        productURL = try c.decodeIfPresent(String.self, forKey: .productURL) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title)
        targetPrice = try c.decodeIfPresent(Double.self, forKey: .targetPrice) ?? 0
        lastPrice = try c.decodeIfPresent(Double.self, forKey: .lastPrice)
        lastPriceText = try c.decodeIfPresent(String.self, forKey: .lastPriceText)
        sellerName = try c.decodeIfPresent(String.self, forKey: .sellerName)
        lastCheckedAt = try c.decodeIfPresent(Date.self, forKey: .lastCheckedAt)
        lastError = try c.decodeIfPresent(String.self, forKey: .lastError)
        lastNotifiedPrice = try c.decodeIfPresent(Double.self, forKey: .lastNotifiedPrice)
        discountPercent = try c.decodeIfPresent(Int.self, forKey: .discountPercent)
        couponText = try c.decodeIfPresent(String.self, forKey: .couponText)

        if let newFormat = try c.decodeIfPresent([Int].self, forKey: .couponPercents) {
            couponPercents = newFormat
        } else if let oldSingle = try c.decodeIfPresent(Int.self, forKey: .legacyCouponPercent) {
            couponPercents = [oldSingle]
        } else {
            couponPercents = []
        }

        priceHistory = try c.decodeIfPresent([PricePoint].self, forKey: .priceHistory) ?? []
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(remoteItemID, forKey: .remoteItemID)
        try c.encode(asin, forKey: .asin)
        try c.encode(productURL, forKey: .productURL)
        try c.encodeIfPresent(title, forKey: .title)
        try c.encode(targetPrice, forKey: .targetPrice)
        try c.encodeIfPresent(lastPrice, forKey: .lastPrice)
        try c.encodeIfPresent(lastPriceText, forKey: .lastPriceText)
        try c.encodeIfPresent(sellerName, forKey: .sellerName)
        try c.encodeIfPresent(lastCheckedAt, forKey: .lastCheckedAt)
        try c.encodeIfPresent(lastError, forKey: .lastError)
        try c.encodeIfPresent(lastNotifiedPrice, forKey: .lastNotifiedPrice)
        try c.encodeIfPresent(discountPercent, forKey: .discountPercent)
        try c.encodeIfPresent(couponText, forKey: .couponText)
        try c.encode(couponPercents, forKey: .couponPercents)
        try c.encode(priceHistory, forKey: .priceHistory)
        try c.encode(createdAt, forKey: .createdAt)
    }

    var displayTitle: String {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty && trimmed.caseInsensitiveCompare(asin) != .orderedSame {
            return trimmed
        }
        return "Loading product title..."
    }

    var currentPriceValue: Double? {
        if let latest = lastPrice {
            return latest
        }
        return sortedHistory.last?.price
    }

    var sortedHistory: [PricePoint] {
        priceHistory.sorted { $0.timestamp < $1.timestamp }
    }

    var lowPriceValue: Double? {
        let values = sortedHistory.map(\.price)
        guard !values.isEmpty else { return currentPriceValue }
        return values.min()
    }

    var highPriceValue: Double? {
        let values = sortedHistory.map(\.price)
        guard !values.isEmpty else { return currentPriceValue }
        return values.max()
    }

    var hasVariation: Bool {
        guard let low = lowPriceValue, let high = highPriceValue else {
            return false
        }
        return abs(high - low) >= 0.005
    }
}

struct PriceCheckResult {
    let resolvedURL: String
    let title: String?
    let priceValue: Double
    let priceText: String
    let sellerName: String?
    let discountPercent: Int?
    let couponText: String?
    let couponPercents: [Int]
}

enum HAWKLocalError: LocalizedError {
    case invalidInput
    case invalidTargetPrice
    case unsupportedURL
    case duplicateASIN(String)
    case failedToResolveShortLink
    case backendNotConfigured
    case backendError(String)

    var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "Enter an Amazon product URL or a valid 10-character ASIN."
        case .invalidTargetPrice:
            return "Target price must be greater than zero."
        case .unsupportedURL:
            return "Only Amazon links are supported."
        case .duplicateASIN(let asin):
            return "This ASIN is already tracked: \(asin)."
        case .failedToResolveShortLink:
            return "Could not resolve this shared short link. Open the product once and try again."
        case .backendNotConfigured:
            return "HAWK_ADMIN backend is not configured yet."
        case .backendError(let message):
            return message
        }
    }
}

enum ProductInputParser {
    private static let rawAsinRegex = try! NSRegularExpression(pattern: "^[A-Za-z0-9]{10}$")
    private static let asinRegex = try! NSRegularExpression(
        pattern: "/dp/([A-Za-z0-9]{10})|/gp/product/([A-Za-z0-9]{10})|[?&]asin=([A-Za-z0-9]{10})",
        options: [.caseInsensitive]
    )
    private static let fallbackAsinRegex = try! NSRegularExpression(
        pattern: "\\b([A-Za-z0-9]{10})\\b",
        options: [.caseInsensitive]
    )

    private static let urlSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 25
        return URLSession(configuration: config)
    }()

    static func parse(input: String) async throws -> (asin: String, canonicalURL: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw HAWKLocalError.invalidInput
        }

        if rawAsinRegex.firstMatch(in: trimmed, range: NSRange(location: 0, length: trimmed.utf16.count)) != nil {
            let asin = trimmed.uppercased()
            let url = "https://www.amazon.sa/dp/\(asin)?language=en_AE"
            return (asin, url)
        }

        guard let initialURL = extractURLCandidate(from: trimmed),
              let scheme = initialURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = initialURL.host?.lowercased() else {
            throw HAWKLocalError.unsupportedURL
        }

        if host.contains("amazon.") {
            if let asin = extractASIN(from: initialURL.absoluteString) {
                return (asin, initialURL.absoluteString)
            }
            let resolvedURL = try await resolveFinalURL(startingAt: initialURL)
            guard let resolvedHost = resolvedURL.host?.lowercased(), resolvedHost.contains("amazon.") else {
                throw HAWKLocalError.unsupportedURL
            }
            if let asin = extractASIN(from: resolvedURL.absoluteString) {
                return (asin, resolvedURL.absoluteString)
            }
            guard let asin = try await extractASINFromPage(at: resolvedURL) else {
                throw HAWKLocalError.invalidInput
            }
            let fallbackCanonical = "https://www.amazon.sa/dp/\(asin)?language=en_AE"
            return (asin, fallbackCanonical)
        }

        if isAmazonShortHost(host) {
            let resolvedURL = try await resolveFinalURL(startingAt: initialURL)
            guard let resolvedHost = resolvedURL.host?.lowercased(), resolvedHost.contains("amazon.") else {
                throw HAWKLocalError.unsupportedURL
            }
            if let asin = extractASIN(from: resolvedURL.absoluteString) {
                return (asin, resolvedURL.absoluteString)
            }
            guard let asin = try await extractASINFromPage(at: resolvedURL) else {
                throw HAWKLocalError.invalidInput
            }
            let fallbackCanonical = "https://www.amazon.sa/dp/\(asin)?language=en_AE"
            return (asin, fallbackCanonical)
        }

        throw HAWKLocalError.unsupportedURL
    }

    private static func extractURLCandidate(from input: String) -> URL? {
        if let normalized = normalizeURLString(input), let url = URL(string: normalized) {
            return url
        }

        let range = NSRange(location: 0, length: (input as NSString).length)
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue),
           let match = detector.firstMatch(in: input, options: [], range: range) {
            if let detectedURL = match.url {
                return detectedURL
            }
            let raw = (input as NSString).substring(with: match.range)
            if let normalized = normalizeURLString(raw), let url = URL(string: normalized) {
                return url
            }
        }

        return nil
    }

    private static func normalizeURLString(_ raw: String) -> String? {
        var text = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'()[]{}<>.,;!?"))

        guard !text.isEmpty else {
            return nil
        }

        if text.lowercased().hasPrefix("www.")
            || text.lowercased().hasPrefix("amzn.")
            || text.lowercased().hasPrefix("amazon.") {
            text = "https://\(text)"
        }

        return text
    }

    private static func isAmazonShortHost(_ host: String) -> Bool {
        if host == "amzn.eu" || host.hasSuffix(".amzn.eu") {
            return true
        }
        return host.hasPrefix("amzn.") || host.contains(".amzn.")
    }

    private static func resolveFinalURL(startingAt url: URL) async throws -> URL {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("en-US,en;q=0.9,ar-SA;q=0.8", forHTTPHeaderField: "Accept-Language")

        do {
            let (_, response) = try await urlSession.data(for: request)
            if let finalURL = response.url {
                return finalURL
            }
            throw HAWKLocalError.failedToResolveShortLink
        } catch {
            throw HAWKLocalError.failedToResolveShortLink
        }
    }

    private static func extractASIN(from text: String) -> String? {
        let nsText = text as NSString
        let full = NSRange(location: 0, length: nsText.length)

        if let match = asinRegex.firstMatch(in: text, options: [], range: full) {
            for idx in 1..<match.numberOfRanges {
                let range = match.range(at: idx)
                if range.location != NSNotFound {
                    return nsText.substring(with: range).uppercased()
                }
            }
        }

        if let fallback = fallbackAsinRegex.firstMatch(in: text, options: [], range: full) {
            let range = fallback.range(at: 1)
            if range.location != NSNotFound {
                return nsText.substring(with: range).uppercased()
            }
        }

        return nil
    }

    private static func extractASINFromPage(at url: URL) async throws -> String? {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("en-US,en;q=0.9,ar-SA;q=0.8", forHTTPHeaderField: "Accept-Language")

        do {
            let (data, response) = try await urlSession.data(for: request)
            if let finalURL = response.url?.absoluteString,
               let asinFromFinalURL = extractASIN(from: finalURL) {
                return asinFromFinalURL
            }
            let html = String(decoding: data, as: UTF8.self)
            return extractASIN(from: html)
        } catch {
            return nil
        }
    }
}

private enum HAWKAdminRemoteConfig {
    // Replace with your deployed backend URL and token.
    static let baseURLString = "https://hawk-admin-api.onrender.com"
    static let apiToken = "85e78df9c6eb390e4dcdc0afd67b03de28a97cd2c8e46324de322d1f88e3d975"
    static let bootstrapEmail = "ashaari777@hawkadmin.local"
    // Test mode: keep auto-update every 15 minutes. Set to nil to use backend interval.
    static let forcedUpdateIntervalSeconds: Int? = 15 * 60

    static var isConfigured: Bool {
        baseURLString.hasPrefix("http") && !baseURLString.contains("YOUR-HAWK-ADMIN-BACKEND")
            && !apiToken.contains("CHANGE_ME") && !apiToken.isEmpty
    }
}

private enum HAWKAdminAPIError: LocalizedError {
    case badURL
    case server(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .badURL:
            return "Backend URL is invalid."
        case .server(let message):
            return message
        case .invalidResponse:
            return "Unexpected server response."
        }
    }
}

private struct MobileAPIErrorEnvelope: Decodable {
    let ok: Bool?
    let error: String?
}

private struct MobileUserPayload: Decodable {
    let id: Int
    let email: String?
    let role: String?
}

private struct MobileBootstrapResponse: Decodable {
    let ok: Bool
    let user: MobileUserPayload?
    let updateIntervalSeconds: Int?
    let lastGlobalRun: String?
    let error: String?
}

private struct MobileHistoryPointPayload: Decodable {
    let ts: String?
    let priceValue: Double?
}

private struct MobileItemPayload: Decodable {
    let id: Int
    let asin: String
    let url: String?
    let targetPriceValue: Double?
    let createdAt: String?
    let title: String?
    let currentPriceText: String?
    let currentPriceValue: Double?
    let discountPercent: Int?
    let couponText: String?
    let couponPercents: [Int]?
    let sellerName: String?
    let lastCheckedAt: String?
    let lastError: String?
    let history: [MobileHistoryPointPayload]?
}

private struct MobileItemsResponse: Decodable {
    let ok: Bool
    let items: [MobileItemPayload]?
    let updateIntervalSeconds: Int?
    let lastGlobalRun: String?
    let error: String?
}

private struct MobileItemResponse: Decodable {
    let ok: Bool
    let item: MobileItemPayload?
    let created: Bool?
    let error: String?
}

private struct MobileCheckAllResponse: Decodable {
    let ok: Bool
    let items: [MobileItemPayload]?
    let updatedItems: Int?
    let errorItems: Int?
    let lastGlobalRun: String?
    let error: String?
}

private struct MobileDeleteResponse: Decodable {
    let ok: Bool
    let deleted: Bool?
    let error: String?
}

private final class HAWKAdminAPIClient {
    static let shared = HAWKAdminAPIClient()

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 90
        config.timeoutIntervalForResource = 600
        return URLSession(configuration: config)
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    private init() {}

    private func makeURL(path: String, query: [URLQueryItem] = []) throws -> URL {
        guard var comps = URLComponents(string: HAWKAdminRemoteConfig.baseURLString) else {
            throw HAWKAdminAPIError.badURL
        }
        comps.path = path
        if !query.isEmpty {
            comps.queryItems = query
        }
        guard let url = comps.url else {
            throw HAWKAdminAPIError.badURL
        }
        return url
    }

    private func perform<Response: Decodable>(
        path: String,
        method: String,
        query: [URLQueryItem] = [],
        body: Data? = nil
    ) async throws -> Response {
        let url = try makeURL(path: path, query: query)
        let maxAttempts = 3
        var attempt = 0

        while true {
            attempt += 1
            do {
                var request = URLRequest(url: url)
                request.httpMethod = method
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue(HAWKAdminRemoteConfig.apiToken, forHTTPHeaderField: "X-API-TOKEN")
                if let body {
                    request.httpBody = body
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }

                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw HAWKAdminAPIError.invalidResponse
                }

                if !(200...299).contains(http.statusCode) {
                    if [502, 503, 504].contains(http.statusCode), attempt < maxAttempts {
                        try? await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000)
                        continue
                    }

                    if let err = try? decoder.decode(MobileAPIErrorEnvelope.self, from: data),
                       let message = err.error, !message.isEmpty {
                        throw HAWKAdminAPIError.server(message)
                    }
                    throw HAWKAdminAPIError.server("Backend request failed (\(http.statusCode)).")
                }

                return try decoder.decode(Response.self, from: data)
            } catch {
                let retriable: Bool
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .timedOut, .notConnectedToInternet, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .dnsLookupFailed:
                        retriable = true
                    default:
                        retriable = false
                    }
                } else {
                    retriable = false
                }

                if retriable, attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000)
                    continue
                }
                throw error
            }
        }
    }

    func bootstrap(email: String) async throws -> MobileBootstrapResponse {
        struct Body: Encodable { let email: String }
        let body = try encoder.encode(Body(email: email))
        let response: MobileBootstrapResponse = try await perform(
            path: "/api/mobile/bootstrap",
            method: "POST",
            body: body
        )
        guard response.ok else {
            throw HAWKAdminAPIError.server(response.error ?? "Bootstrap failed.")
        }
        return response
    }

    func fetchItems(userID: Int) async throws -> MobileItemsResponse {
        let response: MobileItemsResponse = try await perform(
            path: "/api/mobile/items",
            method: "GET",
            query: [URLQueryItem(name: "user_id", value: String(userID))]
        )
        guard response.ok else {
            throw HAWKAdminAPIError.server(response.error ?? "Failed to fetch items.")
        }
        return response
    }

    func addItem(userID: Int, asin: String, url: String, targetPriceValue: Double?) async throws -> MobileItemResponse {
        struct Body: Encodable {
            let userID: Int
            let asin: String
            let url: String
            let targetPriceValue: Double?
        }
        let body = try encoder.encode(Body(
            userID: userID,
            asin: asin,
            url: url,
            targetPriceValue: targetPriceValue
        ))
        let response: MobileItemResponse = try await perform(
            path: "/api/mobile/items",
            method: "POST",
            body: body
        )
        guard response.ok else {
            throw HAWKAdminAPIError.server(response.error ?? "Failed to add item.")
        }
        return response
    }

    func updateTarget(userID: Int, itemID: Int, targetPriceValue: Double) async throws -> MobileItemResponse {
        struct Body: Encodable {
            let userID: Int
            let targetPriceValue: Double
        }
        let body = try encoder.encode(Body(userID: userID, targetPriceValue: targetPriceValue))
        let response: MobileItemResponse = try await perform(
            path: "/api/mobile/items/\(itemID)/target",
            method: "PATCH",
            body: body
        )
        guard response.ok else {
            throw HAWKAdminAPIError.server(response.error ?? "Failed to update target.")
        }
        return response
    }

    func deleteItem(userID: Int, itemID: Int) async throws {
        let response: MobileDeleteResponse = try await perform(
            path: "/api/mobile/items/\(itemID)",
            method: "DELETE",
            query: [URLQueryItem(name: "user_id", value: String(userID))]
        )
        guard response.ok else {
            throw HAWKAdminAPIError.server(response.error ?? "Failed to delete item.")
        }
    }

    func checkItem(userID: Int, itemID: Int) async throws -> MobileItemResponse {
        struct Body: Encodable { let userID: Int }
        let body = try encoder.encode(Body(userID: userID))
        let response: MobileItemResponse = try await perform(
            path: "/api/mobile/items/\(itemID)/check",
            method: "POST",
            body: body
        )
        guard response.ok else {
            throw HAWKAdminAPIError.server(response.error ?? "Failed to check item.")
        }
        return response
    }

    func checkAll(userID: Int) async throws -> MobileCheckAllResponse {
        struct Body: Encodable { let userID: Int }
        let body = try encoder.encode(Body(userID: userID))
        let response: MobileCheckAllResponse = try await perform(
            path: "/api/mobile/check-all",
            method: "POST",
            body: body
        )
        guard response.ok else {
            throw HAWKAdminAPIError.server(response.error ?? "Failed to check items.")
        }
        return response
    }
}

@MainActor
final class AppConfig: ObservableObject {
    @Published private(set) var items: [TrackedItem] = []
    @Published private(set) var activeChecks: Set<UUID> = []
    @Published private(set) var eventLogs: [AppEventLogEntry] = []
    @Published var notificationsEnabled: Bool
    @Published private(set) var notificationAuthorizationStatus = "Unknown"
    @Published private(set) var lastCheckRunAt: Date?
    @Published private(set) var nextAutoCheckAt: Date?

    private let itemsKey = "hawk_admin_items"
    private let eventLogsKey = "hawk_admin_event_logs"
    private let backendUserIDKey = "hawk_admin_backend_user_id"
    private let notificationsEnabledKey = "hawk_admin_notifications_enabled"
    private let checkRunAtKey = "hawk_admin_last_check_run_at"
    private let nextAutoCheckKey = "hawk_admin_next_auto_check"
    private let bgRefreshTaskIdentifier = "com.abdullah.hawkadmin.refresh"
    private var didRegisterBackgroundTask = false
    private var foregroundSchedulerTimer: Timer?
    private var backendUserID: Int?
    private let maxEventLogCount = 250
    private var updateIntervalSeconds: TimeInterval =
        TimeInterval(HAWKAdminRemoteConfig.forcedUpdateIntervalSeconds ?? (60 * 60))

    private static let serverDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    init() {
        notificationsEnabled = UserDefaults.standard.bool(forKey: notificationsEnabledKey)
        if let last = UserDefaults.standard.object(forKey: checkRunAtKey) as? Date {
            lastCheckRunAt = last
        }
        if let next = UserDefaults.standard.object(forKey: nextAutoCheckKey) as? Date {
            nextAutoCheckAt = next
        }
        backendUserID = UserDefaults.standard.object(forKey: backendUserIDKey) as? Int
        loadItems()
        loadEventLogs()
        registerBackgroundRefreshTaskIfNeeded()
        if nextAutoCheckAt == nil {
            scheduleNextAutoCheck(from: Date())
        }
        addEventLog("App launched")
        Task {
            await refreshNotificationStatus()
            await syncFromServer(markRun: false)
        }
    }

    var sortedItems: [TrackedItem] {
        items.sorted { lhs, rhs in
            switch (lhs.lastCheckedAt, rhs.lastCheckedAt) {
            case let (l?, r?):
                return l > r
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.createdAt > rhs.createdAt
            }
        }
    }

    var isCheckingAnything: Bool {
        !activeChecks.isEmpty
    }

    func setupAutoUpdates() {
        registerBackgroundRefreshTaskIfNeeded()
        if nextAutoCheckAt == nil {
            scheduleNextAutoCheck(from: Date())
        }
        scheduleBackgroundRefreshTask()
    }

    func appDidBecomeActive() {
        startForegroundScheduler()
        addEventLog("App became active")
        Task {
            await syncFromServer(markRun: false)
            await runScheduledCheckIfDue()
        }
    }

    func appDidEnterBackground() {
        stopForegroundScheduler()
        addEventLog("App entered background")
        scheduleBackgroundRefreshTask()
    }

    func nextUpdateCountdownText(referenceDate: Date = Date()) -> String {
        guard let nextAutoCheckAt else {
            return "--"
        }

        let remaining = max(0, Int(nextAutoCheckAt.timeIntervalSince(referenceDate)))
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        let seconds = remaining % 60

        if hours > 0 {
            return String(format: "%02dh %02dm %02ds", hours, minutes, seconds)
        }
        return String(format: "%02dm %02ds", minutes, seconds)
    }

    func addItem(input: String, targetPrice: Double?) async throws {
        guard HAWKAdminRemoteConfig.isConfigured else {
            throw HAWKLocalError.backendNotConfigured
        }

        addEventLog("Add item requested")
        let parsed = try await ProductInputParser.parse(input: input)
        if items.contains(where: { $0.asin == parsed.asin }) {
            throw HAWKLocalError.duplicateASIN(parsed.asin)
        }

        let uid = try await ensureBackendUser()
        let addResponse = try await HAWKAdminAPIClient.shared.addItem(
            userID: uid,
            asin: parsed.asin,
            url: parsed.canonicalURL,
            targetPriceValue: (targetPrice ?? 0) > 0 ? targetPrice : nil
        )
        if let newRemoteID = addResponse.item?.id {
            _ = try? await HAWKAdminAPIClient.shared.checkItem(userID: uid, itemID: newRemoteID)
        }
        await syncFromServer(markRun: true)
        addEventLog("Item added: \(parsed.asin)")
    }

    func updateTargetPrice(id: UUID, value: Double) throws {
        guard value > 0 else {
            throw HAWKLocalError.invalidTargetPrice
        }
        guard let idx = items.firstIndex(where: { $0.id == id }) else {
            return
        }
        let remoteID = items[idx].remoteItemID
        items[idx].targetPrice = value
        items[idx].lastError = nil
        saveItems()
        addEventLog("Target updated for \(items[idx].displayTitle): \(value.formattedNumberOnly())")

        guard let remoteID, HAWKAdminRemoteConfig.isConfigured else {
            return
        }

        Task {
            do {
                let uid = try await ensureBackendUser()
                _ = try await HAWKAdminAPIClient.shared.updateTarget(
                    userID: uid,
                    itemID: remoteID,
                    targetPriceValue: value
                )
                await syncFromServer(markRun: false)
            } catch {
                addEventLog("Target update failed: \(error.localizedDescription)")
                updateItem(id: id) { item in
                    item.lastError = error.localizedDescription
                }
            }
        }
    }

    func deleteItem(id: UUID) {
        guard let existing = items.first(where: { $0.id == id }) else {
            return
        }
        addEventLog("Deleted item: \(existing.displayTitle)")
        items.removeAll { $0.id == id }
        saveItems()

        guard let remoteID = existing.remoteItemID, HAWKAdminRemoteConfig.isConfigured else {
            return
        }

        Task {
            do {
                let uid = try await ensureBackendUser()
                try await HAWKAdminAPIClient.shared.deleteItem(userID: uid, itemID: remoteID)
                await syncFromServer(markRun: false)
            } catch {
                // Keep local delete to avoid blocking UX.
            }
        }
    }

    func deleteItems(at offsets: IndexSet, from currentList: [TrackedItem]) {
        let idsToDelete = offsets.map { currentList[$0].id }
        for id in idsToDelete {
            deleteItem(id: id)
        }
    }

    func clearAllItems() {
        let remoteIDs = items.compactMap(\.remoteItemID)
        let count = items.count
        items.removeAll()
        saveItems()
        addEventLog("Deleted all items (\(count))")

        guard HAWKAdminRemoteConfig.isConfigured, !remoteIDs.isEmpty else {
            return
        }

        Task {
            do {
                let uid = try await ensureBackendUser()
                for rid in remoteIDs {
                    try? await HAWKAdminAPIClient.shared.deleteItem(userID: uid, itemID: rid)
                }
                await syncFromServer(markRun: false)
            } catch {
                // Best-effort delete.
            }
        }
    }

    func setNotificationsEnabled(_ enabled: Bool) async {
        notificationsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: notificationsEnabledKey)

        if enabled {
            _ = await requestNotificationAuthorization()
        } else {
            await refreshNotificationStatus()
        }
    }

    func requestNotificationAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await refreshNotificationStatus()
            if !granted {
                notificationsEnabled = false
                UserDefaults.standard.set(false, forKey: notificationsEnabledKey)
            }
            return granted
        } catch {
            await refreshNotificationStatus()
            notificationsEnabled = false
            UserDefaults.standard.set(false, forKey: notificationsEnabledKey)
            return false
        }
    }

    func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            notificationAuthorizationStatus = "Allowed"
        case .denied:
            notificationAuthorizationStatus = "Denied (enable from iOS Settings)"
            notificationsEnabled = false
            UserDefaults.standard.set(false, forKey: notificationsEnabledKey)
        case .notDetermined:
            notificationAuthorizationStatus = "Not requested"
        @unknown default:
            notificationAuthorizationStatus = "Unknown"
        }
    }

    func checkItem(id: UUID) async {
        guard !activeChecks.contains(id), let snapshot = items.first(where: { $0.id == id }) else {
            return
        }
        guard HAWKAdminRemoteConfig.isConfigured else {
            updateItem(id: id) { item in
                item.lastError = HAWKLocalError.backendNotConfigured.localizedDescription
            }
            return
        }

        activeChecks.insert(id)
        defer { activeChecks.remove(id) }
        addEventLog("Check started: \(snapshot.displayTitle)")

        do {
            let uid = try await ensureBackendUser()
            if let remoteID = snapshot.remoteItemID {
                _ = try await HAWKAdminAPIClient.shared.checkItem(userID: uid, itemID: remoteID)
            } else {
                _ = try await HAWKAdminAPIClient.shared.addItem(
                    userID: uid,
                    asin: snapshot.asin,
                    url: snapshot.productURL,
                    targetPriceValue: snapshot.targetPrice > 0 ? snapshot.targetPrice : nil
                )
            }
            await syncFromServer(markRun: true)
            addEventLog("Check finished: \(snapshot.displayTitle)")
        } catch {
            updateItem(id: id) { item in
                item.lastCheckedAt = Date()
                item.lastError = error.localizedDescription
            }
            addEventLog("Check failed: \(error.localizedDescription)")
            markCheckRunNow()
        }
    }

    func checkAllItems() async {
        guard HAWKAdminRemoteConfig.isConfigured else {
            for item in items {
                updateItem(id: item.id) { tracked in
                    tracked.lastError = HAWKLocalError.backendNotConfigured.localizedDescription
                }
            }
            return
        }
        guard !items.isEmpty else {
            await syncFromServer(markRun: false)
            return
        }

        let ids = Set(items.map(\.id))
        activeChecks.formUnion(ids)
        defer { activeChecks.subtract(ids) }
        addEventLog("Check all started (\(ids.count) items)")

        do {
            let uid = try await ensureBackendUser()
            let response = try await HAWKAdminAPIClient.shared.checkAll(userID: uid)
            await syncFromServer(markRun: true)
            let updated = response.updatedItems ?? 0
            let failed = response.errorItems ?? 0
            addEventLog("Check all finished: updated \(updated), errors \(failed)")
        } catch {
            for itemID in ids {
                updateItem(id: itemID) { item in
                    item.lastError = error.localizedDescription
                    item.lastCheckedAt = Date()
                }
            }
            addEventLog("Check all failed: \(error.localizedDescription)")
            markCheckRunNow()
        }
    }

    private func runScheduledCheckIfDue() async {
        guard let dueAt = nextAutoCheckAt else {
            scheduleNextAutoCheck(from: Date())
            return
        }
        guard Date() >= dueAt else {
            return
        }
        guard !isCheckingAnything else {
            return
        }
        await runAutomaticCheckCycle()
    }

    private func runAutomaticCheckCycle() async {
        addEventLog("Automatic update cycle started")
        if items.isEmpty {
            await syncFromServer(markRun: false)
        } else {
            await checkAllItems()
        }
        scheduleNextAutoCheck(from: Date())
        scheduleBackgroundRefreshTask()
        addEventLog("Automatic update cycle finished")
    }

    private func scheduleNextAutoCheck(from date: Date) {
        nextAutoCheckAt = date.addingTimeInterval(updateIntervalSeconds)
        UserDefaults.standard.set(nextAutoCheckAt, forKey: nextAutoCheckKey)
    }

    private func startForegroundScheduler() {
        stopForegroundScheduler()
        foregroundSchedulerTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.runScheduledCheckIfDue()
            }
        }
    }

    private func stopForegroundScheduler() {
        foregroundSchedulerTimer?.invalidate()
        foregroundSchedulerTimer = nil
    }

    private func registerBackgroundRefreshTaskIfNeeded() {
        guard !didRegisterBackgroundTask else {
            return
        }
        didRegisterBackgroundTask = true

        BGTaskScheduler.shared.register(forTaskWithIdentifier: bgRefreshTaskIdentifier, using: nil) { [weak self] task in
            guard let self, let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in
                await self.handleBackgroundRefreshTask(refreshTask)
            }
        }
    }

    private func scheduleBackgroundRefreshTask() {
        let request = BGAppRefreshTaskRequest(identifier: bgRefreshTaskIdentifier)
        request.earliestBeginDate = nextAutoCheckAt ?? Date().addingTimeInterval(updateIntervalSeconds)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Foreground sync still runs while app is active.
        }
    }

    private func handleBackgroundRefreshTask(_ task: BGAppRefreshTask) async {
        addEventLog("Background refresh task started")
        scheduleBackgroundRefreshTask()
        let work = Task { @MainActor in
            await runAutomaticCheckCycle()
        }
        task.expirationHandler = {
            work.cancel()
        }
        await work.value
        task.setTaskCompleted(success: !work.isCancelled)
        addEventLog(work.isCancelled ? "Background refresh cancelled" : "Background refresh completed")
    }

    private func applyUpdateInterval(serverValue: Int?) {
        if let forced = HAWKAdminRemoteConfig.forcedUpdateIntervalSeconds {
            updateIntervalSeconds = TimeInterval(max(300, forced))
            return
        }
        if let serverValue {
            updateIntervalSeconds = TimeInterval(max(300, serverValue))
        }
    }

    private func ensureBackendUser() async throws -> Int {
        if !HAWKAdminRemoteConfig.isConfigured {
            throw HAWKLocalError.backendNotConfigured
        }
        if let backendUserID, backendUserID > 0 {
            return backendUserID
        }

        let bootstrap = try await HAWKAdminAPIClient.shared.bootstrap(email: HAWKAdminRemoteConfig.bootstrapEmail)
        guard let userID = bootstrap.user?.id else {
            throw HAWKAdminAPIError.invalidResponse
        }
        backendUserID = userID
        UserDefaults.standard.set(userID, forKey: backendUserIDKey)

        applyUpdateInterval(serverValue: bootstrap.updateIntervalSeconds)
        if let lastRun = parseServerDate(bootstrap.lastGlobalRun) {
            lastCheckRunAt = lastRun
            UserDefaults.standard.set(lastRun, forKey: checkRunAtKey)
        }
        if nextAutoCheckAt == nil {
            scheduleNextAutoCheck(from: Date())
        }
        return userID
    }

    private func syncFromServer(markRun: Bool) async {
        guard HAWKAdminRemoteConfig.isConfigured else {
            return
        }
        do {
            let uid = try await ensureBackendUser()
            let payload = try await HAWKAdminAPIClient.shared.fetchItems(userID: uid)
            applyUpdateInterval(serverValue: payload.updateIntervalSeconds)

            mergeRemoteItems(payload.items ?? [])
            if let lastRun = parseServerDate(payload.lastGlobalRun) {
                lastCheckRunAt = lastRun
                UserDefaults.standard.set(lastRun, forKey: checkRunAtKey)
            } else if markRun {
                markCheckRunNow()
            }

            scheduleBackgroundRefreshTask()
            evaluateTargetNotifications()
            addEventLog("Sync success: \(items.count) items")
        } catch {
            if markRun {
                markCheckRunNow()
            }
            addEventLog("Sync failed: \(error.localizedDescription)")
            if !items.isEmpty {
                for item in items {
                    updateItem(id: item.id) { tracked in
                        tracked.lastError = error.localizedDescription
                    }
                }
            }
        }
    }

    private func mergeRemoteItems(_ remoteItems: [MobileItemPayload]) {
        let existingByRemoteID: [Int: TrackedItem] = Dictionary(
            uniqueKeysWithValues: items.compactMap { item in
                guard let remoteID = item.remoteItemID else { return nil }
                return (remoteID, item)
            }
        )
        let existingByASIN = Dictionary(uniqueKeysWithValues: items.map { ($0.asin, $0) })

        var merged: [TrackedItem] = []
        merged.reserveCapacity(remoteItems.count)

        for remote in remoteItems {
            var item = existingByRemoteID[remote.id]
                ?? existingByASIN[remote.asin]
                ?? TrackedItem(
                    remoteItemID: remote.id,
                    asin: remote.asin,
                    productURL: remote.url ?? "https://www.amazon.sa/dp/\(remote.asin)?language=en",
                    targetPrice: max(0, remote.targetPriceValue ?? 0)
                )

            item.remoteItemID = remote.id
            item.asin = remote.asin
            item.productURL = remote.url ?? item.productURL
            item.title = remote.title ?? item.title
            item.targetPrice = max(0, remote.targetPriceValue ?? item.targetPrice)
            item.lastPrice = remote.currentPriceValue
            item.lastPriceText = remote.currentPriceText
            item.sellerName = remote.sellerName
            item.discountPercent = remote.discountPercent
            item.couponText = remote.couponText
            item.couponPercents = remote.couponPercents ?? []
            item.lastCheckedAt = parseServerDate(remote.lastCheckedAt)
            item.lastError = remote.lastError
            item.createdAt = parseServerDate(remote.createdAt) ?? item.createdAt

            let historyPoints = (remote.history ?? []).compactMap { point -> PricePoint? in
                guard let ts = parseServerDate(point.ts), let price = point.priceValue else {
                    return nil
                }
                return PricePoint(timestamp: ts, price: price)
            }
            if !historyPoints.isEmpty {
                item.priceHistory = historyPoints
            } else if let current = remote.currentPriceValue {
                item.priceHistory = [PricePoint(timestamp: item.lastCheckedAt ?? Date(), price: current)]
            }

            merged.append(item)
        }

        items = merged
        saveItems()
    }

    private func evaluateTargetNotifications() {
        guard notificationsEnabled else { return }
        for item in items {
            tryNotifyIfNeeded(for: item.id)
        }
    }

    private func parseServerDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else {
            return nil
        }
        return Self.serverDateFormatter.date(from: value)
    }

    private func markCheckRunNow() {
        lastCheckRunAt = Date()
        UserDefaults.standard.set(lastCheckRunAt, forKey: checkRunAtKey)
    }

    private func tryNotifyIfNeeded(for id: UUID) {
        guard notificationsEnabled, let item = items.first(where: { $0.id == id }) else {
            return
        }
        guard item.targetPrice > 0 else {
            return
        }
        guard let latest = item.currentPriceValue, latest <= item.targetPrice else {
            return
        }
        if let notified = item.lastNotifiedPrice, abs(notified - latest) < 0.0001 {
            return
        }

        let content = UNMutableNotificationContent()
        let currentText = item.currentPriceValue?.formattedPrice() ?? (item.lastPriceText ?? "Price updated")
        content.title = "Target Reached"
        content.body = "\(item.displayTitle) is now \(currentText), at or below your target \(item.targetPrice.formattedPrice())."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "target-\(item.id.uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)

        updateItem(id: id) { tracked in
            tracked.lastNotifiedPrice = latest
        }
    }

    private func updateItem(id: UUID, mutation: (inout TrackedItem) -> Void) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else {
            return
        }
        mutation(&items[idx])
        saveItems()
    }

    private func loadItems() {
        guard let data = UserDefaults.standard.data(forKey: itemsKey) else {
            return
        }
        do {
            items = try JSONDecoder().decode([TrackedItem].self, from: data)
        } catch {
            items = []
        }
    }

    private func saveItems() {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: itemsKey)
        } catch {
            // Ignore write errors to avoid crashing the UI flow.
        }
    }

    func clearEventLogs() {
        eventLogs.removeAll()
        UserDefaults.standard.removeObject(forKey: eventLogsKey)
    }

    private func addEventLog(_ message: String) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        eventLogs.insert(AppEventLogEntry(message: trimmed), at: 0)
        if eventLogs.count > maxEventLogCount {
            eventLogs = Array(eventLogs.prefix(maxEventLogCount))
        }
        saveEventLogs()
    }

    private func loadEventLogs() {
        guard let data = UserDefaults.standard.data(forKey: eventLogsKey) else {
            eventLogs = []
            return
        }
        do {
            eventLogs = try JSONDecoder().decode([AppEventLogEntry].self, from: data)
        } catch {
            eventLogs = []
        }
    }

    private func saveEventLogs() {
        do {
            let data = try JSONEncoder().encode(eventLogs)
            UserDefaults.standard.set(data, forKey: eventLogsKey)
        } catch {
            // Ignore write errors to avoid blocking app flow.
        }
    }
}
extension Double {
    func formattedPrice() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "SAR"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self)) ?? String(format: "%.2f", self)
    }

    func formattedNumberOnly() -> String {
        String(format: "%.2f", self)
    }
}
