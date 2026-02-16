import Foundation

enum PriceCheckerError: LocalizedError {
    case invalidURL
    case badHTTPStatus(Int)
    case blockedByWebsite
    case priceNotFound

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Product URL is invalid."
        case .badHTTPStatus(let code):
            return "Website returned HTTP \(code)."
        case .blockedByWebsite:
            return "Amazon blocked this request. Try again later."
        case .priceNotFound:
            return "Price not found on product page."
        }
    }
}

actor PriceChecker {
    static let shared = PriceChecker()

    private let session: URLSession
    private let jsonPriceRegex = try! NSRegularExpression(
        pattern: "\"priceToPay\"\\s*:\\s*\\{[^\\}]*\"priceAmount\"\\s*:\\s*([0-9]+(?:\\.[0-9]+)?)",
        options: [.caseInsensitive]
    )
    private let genericJsonPriceRegex = try! NSRegularExpression(
        pattern: "\"priceAmount\"\\s*:\\s*([0-9]+(?:\\.[0-9]+)?)",
        options: [.caseInsensitive]
    )
    private let displayPriceRegex = try! NSRegularExpression(
        pattern: "\"displayPrice\"\\s*:\\s*\"([^\"]+)\"",
        options: [.caseInsensitive]
    )
    private let offscreenPriceRegex = try! NSRegularExpression(
        pattern: "a-offscreen\">\\s*([^<]+)\\s*</span>",
        options: [.caseInsensitive]
    )
    private let wholeRegex = try! NSRegularExpression(
        pattern: "a-price-whole\">\\s*([^<]+)\\s*</span>",
        options: [.caseInsensitive]
    )
    private let fractionRegex = try! NSRegularExpression(
        pattern: "a-price-fraction\">\\s*([^<]+)\\s*</span>",
        options: [.caseInsensitive]
    )
    private let titleRegex = try! NSRegularExpression(
        pattern: "<title>(.*?)</title>",
        options: [.caseInsensitive, .dotMatchesLineSeparators]
    )
    private let sellerMerchantRegex = try! NSRegularExpression(
        pattern: "\"merchantName\"\\s*:\\s*\"([^\"]+)\"",
        options: [.caseInsensitive]
    )
    private let sellerPlainRegex = try! NSRegularExpression(
        pattern: "(?:shipper\\s*/\\s*seller\\s*:\\s*|sold by\\s+)([^\\n\\r|]+)",
        options: [.caseInsensitive]
    )
    private let couponIdRegex = try! NSRegularExpression(
        pattern: "couponTextpctch[^>]*>([^<]+)<",
        options: [.caseInsensitive]
    )
    private let discountPercentRegex = try! NSRegularExpression(
        pattern: "(?:savingsPercentage|reinventPriceSavingsPercentageMargin|priceBlockSavingsString|priceBlockDealBadges|a-size-large\\s+a-color-price)[^>]*>\\s*-?\\s*(\\d{1,3})\\s*(?:%|٪)",
        options: [.caseInsensitive]
    )
    private let negativePercentRegex = try! NSRegularExpression(
        pattern: "-\\s*(\\d{1,3})\\s*(?:%|٪)",
        options: [.caseInsensitive]
    )
    private let percentRegex = try! NSRegularExpression(pattern: "(\\d{1,3})\\s*(?:%|٪)")
    private let couponKeywords = ["coupon", "redeem", "promo code", "قسيمة", "كوبون", "رمز"]
    private let couponNoise = ["renewed", "used", "open box", "customer review", "review", "subscribe & save", "auto-deliveries"]

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 30
        session = URLSession(configuration: config)
    }

    func check(item: TrackedItem) async throws -> PriceCheckResult {
        guard let url = URL(string: item.productURL) else {
            throw PriceCheckerError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 25
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("en-US,en;q=0.9,ar-SA;q=0.8", forHTTPHeaderField: "Accept-Language")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw PriceCheckerError.badHTTPStatus(-1)
        }
        guard (200...299).contains(http.statusCode) else {
            throw PriceCheckerError.badHTTPStatus(http.statusCode)
        }

        let finalURL = response.url?.absoluteString ?? url.absoluteString
        let html = String(decoding: data, as: UTF8.self)
        if html.localizedCaseInsensitiveContains("automated access")
            || html.localizedCaseInsensitiveContains("captcha")
            || html.localizedCaseInsensitiveContains("enter the characters you see below") {
            throw PriceCheckerError.blockedByWebsite
        }

        let title = extractTitle(from: html)
        let coupon = extractCoupon(from: html)
        let discountPercent = extractDiscountPercent(from: html)
        let sellerName = extractSellerName(from: html)

        if let fromJSON = extractFirstNumber(regex: jsonPriceRegex, in: html) {
            let text = fromJSON.formattedPrice()
            return PriceCheckResult(
                resolvedURL: finalURL,
                title: title,
                priceValue: fromJSON,
                priceText: text,
                sellerName: sellerName,
                discountPercent: discountPercent,
                couponText: coupon.text,
                couponPercents: coupon.percents
            )
        }

        if let genericJSON = extractFirstNumber(regex: genericJsonPriceRegex, in: html), genericJSON > 0 {
            let text = genericJSON.formattedPrice()
            return PriceCheckResult(
                resolvedURL: finalURL,
                title: title,
                priceValue: genericJSON,
                priceText: text,
                sellerName: sellerName,
                discountPercent: discountPercent,
                couponText: coupon.text,
                couponPercents: coupon.percents
            )
        }

        if let displayPrice = extractFirstText(regex: displayPriceRegex, in: html),
           let parsedDisplayPrice = parseNumericPrice(displayPrice) {
            return PriceCheckResult(
                resolvedURL: finalURL,
                title: title,
                priceValue: parsedDisplayPrice,
                priceText: parsedDisplayPrice.formattedPrice(),
                sellerName: sellerName,
                discountPercent: discountPercent,
                couponText: coupon.text,
                couponPercents: coupon.percents
            )
        }

        if let offscreen = extractFirstText(regex: offscreenPriceRegex, in: html),
           let value = parseNumericPrice(offscreen) {
            return PriceCheckResult(
                resolvedURL: finalURL,
                title: title,
                priceValue: value,
                priceText: offscreen.cleanedHTMLText(),
                sellerName: sellerName,
                discountPercent: discountPercent,
                couponText: coupon.text,
                couponPercents: coupon.percents
            )
        }

        if let whole = extractFirstText(regex: wholeRegex, in: html) {
            let fraction = extractFirstText(regex: fractionRegex, in: html) ?? "00"
            let composed = "\(whole).\(fraction)"
            if let value = parseNumericPrice(composed) {
                let text = value.formattedPrice()
                return PriceCheckResult(
                    resolvedURL: finalURL,
                    title: title,
                    priceValue: value,
                    priceText: text,
                    sellerName: sellerName,
                    discountPercent: discountPercent,
                    couponText: coupon.text,
                    couponPercents: coupon.percents
                )
            }
        }

        throw PriceCheckerError.priceNotFound
    }

    private func extractCoupon(from html: String) -> (text: String?, percents: [Int]) {
        let directCouponTexts = extractAllTexts(regex: couponIdRegex, in: html)
            .map { $0.cleanedHTMLText().trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !directCouponTexts.isEmpty {
            let merged = directCouponTexts.joined(separator: " ")
            let percents = extractUniquePercents(from: merged)
            return (directCouponTexts.first, percents)
        }

        let plain = html.strippingHTMLTags().cleanedHTMLText()
        let contexts = couponContexts(in: plain)
        let percents = extractUniquePercents(from: contexts.joined(separator: " "))

        let firstMeaningful = contexts.first?.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = firstMeaningful?.isEmpty == true ? nil : firstMeaningful
        return (text, percents)
    }

    private func extractDiscountPercent(from html: String) -> Int? {
        if let strict = extractFirstText(regex: discountPercentRegex, in: html)?.trimmingCharacters(in: .whitespacesAndNewlines),
           let value = Int(strict), (1...95).contains(value) {
            return value
        }

        let plain = html.strippingHTMLTags().cleanedHTMLText()
        if let fallback = extractFirstText(regex: negativePercentRegex, in: plain)?.trimmingCharacters(in: .whitespacesAndNewlines),
           let value = Int(fallback), (1...95).contains(value) {
            return value
        }

        return nil
    }

    private func extractSellerName(from html: String) -> String? {
        let merchantCandidates = extractAllTexts(regex: sellerMerchantRegex, in: html)
        for candidate in merchantCandidates {
            if let normalized = normalizedSellerName(candidate) {
                return normalized
            }
        }

        let plain = html.strippingHTMLTags().cleanedHTMLText()
        let plainCandidates = extractAllTexts(regex: sellerPlainRegex, in: plain)
        for candidate in plainCandidates {
            if let normalized = normalizedSellerName(candidate) {
                return normalized
            }
        }

        return nil
    }

    private func normalizedSellerName(_ raw: String) -> String? {
        var text = raw
            .cleanedHTMLText()
            .replacingOccurrences(of: "Fulfilled by Amazon / Sold by", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "Shipper / Seller:", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "Sold by", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if text.isEmpty {
            return nil
        }

        if let first = text.split(separator: "|").first {
            text = String(first).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if text.lowercased().contains("amazon") {
            return "Amazon"
        }

        let suffixesToTrim = ["product", "store", "trading", "official"]
        var words = text.split(separator: " ").map(String.init)
        if let last = words.last, suffixesToTrim.contains(last.lowercased()), words.count > 1 {
            words.removeLast()
        }

        if words.isEmpty {
            return nil
        }

        return words.joined(separator: " ")
    }

    private func couponContexts(in plainText: String) -> [String] {
        let ns = plainText as NSString
        let range = NSRange(location: 0, length: ns.length)
        let matches = percentRegex.matches(in: plainText, options: [], range: range)

        var out: [String] = []
        for match in matches {
            let lower = max(0, match.range.location - 55)
            let upper = min(ns.length, match.range.location + match.range.length + 55)
            let contextRange = NSRange(location: lower, length: max(0, upper - lower))
            guard contextRange.length > 0 else {
                continue
            }

            let context = ns.substring(with: contextRange).lowercased()
            let hasKeyword = couponKeywords.contains { context.contains($0) }
            let hasNoise = couponNoise.contains { context.contains($0) }
            if !hasKeyword || hasNoise {
                continue
            }

            let cleaned = context
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty {
                out.append(cleaned)
            }
        }

        return Array(NSOrderedSet(array: out)) as? [String] ?? out
    }

    private func extractUniquePercents(from text: String) -> [Int] {
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        let matches = percentRegex.matches(in: text, options: [], range: range)
        let values: [Int] = matches.compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            let r = match.range(at: 1)
            guard r.location != NSNotFound else { return nil }
            guard let n = Int(ns.substring(with: r)), (1...95).contains(n) else { return nil }
            return n
        }
        return Array(Set(values)).sorted(by: >)
    }

    private func extractTitle(from html: String) -> String? {
        guard let raw = extractFirstText(regex: titleRegex, in: html)?
            .replacingOccurrences(of: "Amazon.sa", with: "")
            .replacingOccurrences(of: "| Amazon.sa", with: "") else {
            return nil
        }
        let cleaned = raw.cleanedHTMLText().trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private func extractFirstText(regex: NSRegularExpression, in text: String) -> String? {
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1 else {
            return nil
        }
        let group = match.range(at: 1)
        guard group.location != NSNotFound else {
            return nil
        }
        return ns.substring(with: group)
    }

    private func extractAllTexts(regex: NSRegularExpression, in text: String) -> [String] {
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        return regex.matches(in: text, options: [], range: range).compactMap { match in
            guard match.numberOfRanges > 1 else {
                return nil
            }
            let group = match.range(at: 1)
            guard group.location != NSNotFound else {
                return nil
            }
            return ns.substring(with: group)
        }
    }

    private func extractFirstNumber(regex: NSRegularExpression, in text: String) -> Double? {
        guard let s = extractFirstText(regex: regex, in: text) else {
            return nil
        }
        return parseNumericPrice(s)
    }

    private func parseNumericPrice(_ raw: String) -> Double? {
        let cleaned = raw
            .replacingOccurrences(of: "SAR", with: "")
            .replacingOccurrences(of: "AED", with: "")
            .replacingOccurrences(of: "ر.س", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "٫", with: ".")
            .replacingOccurrences(of: " ", with: "")
            .cleanedHTMLText()
            .normalizedArabicDigits()

        let regex = try! NSRegularExpression(pattern: "([0-9]+(?:\\.[0-9]+)?)")
        let ns = cleaned as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: cleaned, options: [], range: range) else {
            return nil
        }
        let valueRange = match.range(at: 1)
        guard valueRange.location != NSNotFound else {
            return nil
        }
        let valueText = ns.substring(with: valueRange)
        return Double(valueText)
    }
}

extension String {
    func cleanedHTMLText() -> String {
        self.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }

    func strippingHTMLTags() -> String {
        self.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func normalizedArabicDigits() -> String {
        let easternArabic: [Character: Character] = [
            "٠": "0", "١": "1", "٢": "2", "٣": "3", "٤": "4",
            "٥": "5", "٦": "6", "٧": "7", "٨": "8", "٩": "9",
            "۰": "0", "۱": "1", "۲": "2", "۳": "3", "۴": "4",
            "۵": "5", "۶": "6", "۷": "7", "۸": "8", "۹": "9"
        ]

        return String(map { easternArabic[$0] ?? $0 })
    }
}
