import SwiftUI
import Charts
import UIKit

struct ContentView: View {
    @EnvironmentObject private var appConfig: AppConfig

    @State private var showingSettings = false
    @State private var runningAllChecks = false
    @State private var isAdding = false
    @State private var productInput = ""
    @State private var targetPriceInput = ""
    @State private var addError: String?
    @FocusState private var focusedAddField: AddField?

    private enum AddField {
        case product
        case target
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.hawkBgTop, Color.hawkBgBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .onTapGesture {
                    focusedAddField = nil
                    dismissKeyboard()
                }

                ScrollView {
                    VStack(spacing: 18) {
                        headerCard
                        addPanel

                        if appConfig.sortedItems.isEmpty {
                            emptyState
                        } else {
                            LazyVStack(spacing: 16) {
                                ForEach(appConfig.sortedItems) { item in
                                    ItemCard(item: item)
                                        .environmentObject(appConfig)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
                .simultaneousGesture(
                    TapGesture().onEnded {
                        focusedAddField = nil
                        dismissKeyboard()
                    }
                )
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings") {
                        showingSettings = true
                    }
                    .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(runningAllChecks ? "Checking..." : "Check All") {
                        Task {
                            runningAllChecks = true
                            await appConfig.checkAllItems()
                            runningAllChecks = false
                        }
                    }
                    .disabled(appConfig.sortedItems.isEmpty || runningAllChecks || appConfig.isCheckingAnything)
                    .foregroundStyle(.white)
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(appConfig)
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("HAWK_ADMIN Price Tracker")
                .font(.system(size: 27, weight: .black))
                .foregroundStyle(.white)

            if let lastRun = appConfig.lastCheckRunAt {
                Text("Last update: \(lastRun.formatted(date: .abbreviated, time: .shortened))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.68))
            } else {
                Text("No checks yet")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.68))
            }

            if appConfig.nextAutoCheckAt != nil {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(
                        "Next update in: \(appConfig.nextUpdateCountdownText(referenceDate: context.date))"
                        + (appConfig.isCheckingAnything ? " | Update is runing" : "")
                    )
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.hawkGold.opacity(0.95))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .cardBackground()
    }

    private var addPanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                TextField("Paste Amazon.sa link or ASIN...", text: $productInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .focused($focusedAddField, equals: .product)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)

                TextField("Target (opt)", text: $targetPriceInput)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .focused($focusedAddField, equals: .target)
                    .frame(width: 96)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }

            HStack {
                Button("Paste") {
                    let pasted = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if pasted.isEmpty {
                        addError = "Clipboard is empty."
                    } else {
                        productInput = pasted
                        addError = nil
                    }
                }
                .font(.system(size: 12, weight: .black))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.1))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                if let addError {
                    Text(addError)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.red.opacity(0.9))
                }
                Spacer()
                Button(isAdding ? "Adding..." : "Add") {
                    addItem()
                }
                .font(.system(size: 15, weight: .black))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Color.hawkAccent, Color.hawkGold],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(isAdding)
            }
        }
        .padding(16)
        .cardBackground()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("No items yet")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(.white.opacity(0.95))
            Text("Use the add panel above to track your first product.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.68))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .cardBackground()
    }

    private func addItem() {
        focusedAddField = nil
        dismissKeyboard()

        let inputTrimmed = productInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !inputTrimmed.isEmpty else {
            addError = "Amazon URL or ASIN is required."
            return
        }

        let normalized = targetPriceInput
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        let target: Double?
        if normalized.isEmpty {
            target = nil
        } else {
            guard let parsed = Double(normalized) else {
                addError = "Invalid target price."
                return
            }
            target = parsed
        }

        Task {
            isAdding = true
            defer { isAdding = false }
            do {
                try await appConfig.addItem(input: inputTrimmed, targetPrice: target)
                productInput = ""
                targetPriceInput = ""
                addError = nil
            } catch {
                addError = error.localizedDescription
            }
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private struct ItemCard: View {
    let item: TrackedItem

    @EnvironmentObject private var appConfig: AppConfig
    @State private var showDeleteConfirmation = false
    @State private var targetDraft: String
    @State private var targetError: String?

    init(item: TrackedItem) {
        self.item = item
        _targetDraft = State(initialValue: item.targetPrice.formattedNumberOnly())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(item.displayTitle)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(.white.opacity(0.96))
                .lineLimit(1)

            HStack(spacing: 8) {
                let currentBase = item.currentPriceValue.map { $0.formattedPrice() } ?? "--"
                let currentWithDiscount = item.discountPercent.map { "\(currentBase) (-\($0)%)" } ?? currentBase
                valuePill(currentWithDiscount, style: .current)
                valuePill(item.hasVariation ? "L: \(item.lowPriceValue?.formattedNumberOnly() ?? "--")" : "L: --", style: .low)
                valuePill(item.hasVariation ? "H: \(item.highPriceValue?.formattedNumberOnly() ?? "--")" : "H: --", style: .high)
            }

            if !item.couponPercents.isEmpty {
                let formatted = "Coupon: " + item.couponPercents.map { "%\($0)" }.joined(separator: " | ")
                HStack {
                    valuePill(formatted, style: .coupon)
                    Spacer(minLength: 0)
                }
            }

            if let seller = item.sellerName, !seller.isEmpty {
                Text("Seller: \(seller)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }

            if !item.sortedHistory.isEmpty {
                PriceChartView(points: item.sortedHistory)
                    .frame(height: 210)
            } else if let current = item.currentPriceValue {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.04))
                    .frame(height: 210)
                    .overlay(
                        VStack(spacing: 8) {
                            Text("Current Price")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.6))
                            Text(current.formattedPrice())
                                .font(.system(size: 21, weight: .black))
                                .foregroundStyle(Color.hawkGold)
                        }
                    )
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.04))
                    .frame(height: 210)
                    .overlay(
                        Text("No chart data yet")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.65))
                    )
            }

            HStack(spacing: 8) {
                Text("Target:")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.72))

                TextField("0.00", text: $targetDraft)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 76)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .foregroundStyle(.white)

                Button("Set") {
                    setTarget()
                }
                .font(.system(size: 12, weight: .black))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [Color.hawkAccent, Color.hawkGold],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Spacer(minLength: 0)

                Button(appConfig.activeChecks.contains(item.id) ? "Checking..." : "Check") {
                    Task {
                        await appConfig.checkItem(id: item.id)
                    }
                }
                .font(.system(size: 12, weight: .black))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.hawkGold.opacity(0.20))
                .foregroundStyle(Color.hawkGold)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .disabled(appConfig.activeChecks.contains(item.id))

                Button("Delete") {
                    showDeleteConfirmation = true
                }
                .font(.system(size: 12, weight: .black))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.18))
                .foregroundStyle(Color.red.opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if let targetError {
                Text(targetError)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.red.opacity(0.85))
            }

            HStack(spacing: 8) {
                if let url = URL(string: item.productURL) {
                    Link("Open Product", destination: url)
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.08))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            if let checked = item.lastCheckedAt {
                Text("Last checked: \(checked.formatted(date: .abbreviated, time: .shortened))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.62))
            }

            if let err = item.lastError, !err.isEmpty {
                Text(err)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.red.opacity(0.88))
                    .lineLimit(2)
            }
        }
        .padding(16)
        .cardBackground()
        .onChange(of: item.targetPrice) { newValue in
            targetDraft = newValue.formattedNumberOnly()
        }
        .alert("Are you sure?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                appConfig.deleteItem(id: item.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This item will be removed from tracking.")
        }
    }

    private func setTarget() {
        let normalized = targetDraft.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized) else {
            targetError = "Invalid target value."
            return
        }
        do {
            try appConfig.updateTargetPrice(id: item.id, value: value)
            targetError = nil
        } catch {
            targetError = error.localizedDescription
        }
    }

    private enum PillStyle {
        case current
        case discount
        case low
        case high
        case coupon
    }

    private func valuePill(_ text: String, style: PillStyle) -> some View {
        let colors: (foreground: Color, border: Color, bg: Color) = {
            switch style {
            case .current:
                return (Color.white, Color.white.opacity(0.18), Color.black.opacity(0.22))
            case .discount:
                return (Color.hawkOrange, Color.hawkOrange.opacity(0.35), Color.hawkOrange.opacity(0.1))
            case .low:
                return (Color.hawkGreen, Color.hawkGreen.opacity(0.35), Color.hawkGreen.opacity(0.1))
            case .high:
                return (Color.hawkRed, Color.hawkRed.opacity(0.35), Color.hawkRed.opacity(0.1))
            case .coupon:
                return (Color.white, Color.white.opacity(0.35), Color.white.opacity(0.08))
            }
        }()

        return Text(text)
            .font(.system(size: 11, weight: .black))
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .foregroundStyle(colors.foreground)
            .background(colors.bg)
            .overlay(
                RoundedRectangle(cornerRadius: 999)
                    .stroke(colors.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 999))
    }
}

private struct PriceChartView: View {
    let points: [PricePoint]
    @State private var selectedPoint: PricePoint?

    private var sortedPoints: [PricePoint] {
        points.sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        VStack(spacing: 8) {
            Chart(sortedPoints) { point in
                AreaMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Price", point.price)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.hawkGold.opacity(0.36), Color.hawkGold.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Price", point.price)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.2))
                .foregroundStyle(Color.hawkGold)

                if let selectedPoint {
                    RuleMark(x: .value("Selected Time", selectedPoint.timestamp))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(Color.white.opacity(0.55))

                    PointMark(
                        x: .value("Selected Time", selectedPoint.timestamp),
                        y: .value("Selected Price", selectedPoint.price)
                    )
                    .symbolSize(30)
                    .foregroundStyle(Color.hawkGold)
                    .annotation(position: .top, spacing: 6) {
                        VStack(spacing: 2) {
                            Text(selectedPoint.price.formattedNumberOnly())
                                .font(.system(size: 11, weight: .black))
                            Text(selectedPoint.timestamp, format: .dateTime.day().month(.abbreviated))
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .foregroundStyle(.black.opacity(0.9))
                        .background(Color.hawkGold)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                    AxisValueLabel {
                        if let price = value.as(Double.self) {
                            Text(price.formattedNumberOnly())
                                .font(.system(size: 10, weight: .semibold))
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.6, dash: [2, 3]))
                        .foregroundStyle(Color.white.opacity(0.09))
                }
            }
            .chartLegend(.hidden)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 8)
                                .onChanged { value in
                                    // Keep vertical scroll smooth; only track mainly horizontal drags.
                                    guard abs(value.translation.width) >= abs(value.translation.height) else {
                                        selectedPoint = nil
                                        return
                                    }
                                    updateSelectedPoint(at: value.location, proxy: proxy, geometry: geo)
                                }
                                .onEnded { _ in
                                    selectedPoint = nil
                                }
                        )
                }
            }
            .padding(10)
            .background(Color.black.opacity(0.16))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.09), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack {
                Text(keepaDateLabel(sortedPoints.first?.timestamp))
                Spacer()
                Text(keepaDateLabel(selectedPoint?.timestamp ?? midpointDate))
                Spacer()
                Text(keepaDateLabel(sortedPoints.last?.timestamp))
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white.opacity(0.62))
            .padding(.horizontal, 4)
        }
    }

    private var midpointDate: Date? {
        guard let first = sortedPoints.first?.timestamp,
              let last = sortedPoints.last?.timestamp else {
            return nil
        }
        let midpoint = (first.timeIntervalSince1970 + last.timeIntervalSince1970) / 2
        return Date(timeIntervalSince1970: midpoint)
    }

    private func updateSelectedPoint(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        let plotOrigin = geometry[proxy.plotAreaFrame].origin
        let xPosition = location.x - plotOrigin.x
        guard xPosition >= 0, xPosition <= proxy.plotAreaSize.width else {
            selectedPoint = nil
            return
        }
        guard let date: Date = proxy.value(atX: xPosition) else {
            selectedPoint = nil
            return
        }
        selectedPoint = nearestPoint(to: date)
    }

    private func nearestPoint(to date: Date) -> PricePoint? {
        sortedPoints.min { lhs, rhs in
            abs(lhs.timestamp.timeIntervalSince(date)) < abs(rhs.timestamp.timeIntervalSince(date))
        }
    }

    private func keepaDateLabel(_ date: Date?) -> String {
        guard let date else {
            return "--"
        }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }
}

private extension View {
    func cardBackground() -> some View {
        self
            .background(Color.hawkCard)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

extension Color {
    static let hawkBgTop = Color(red: 15 / 255, green: 12 / 255, blue: 41 / 255)
    static let hawkBgBottom = Color(red: 22 / 255, green: 22 / 255, blue: 45 / 255)
    static let hawkCard = Color(red: 30 / 255, green: 30 / 255, blue: 50 / 255).opacity(0.58)
    static let hawkAccent = Color(red: 213 / 255, green: 51 / 255, blue: 105 / 255)
    static let hawkGold = Color(red: 218 / 255, green: 174 / 255, blue: 81 / 255)
    static let hawkOrange = Color(red: 248 / 255, green: 157 / 255, blue: 58 / 255)
    static let hawkGreen = Color(red: 46 / 255, green: 229 / 255, blue: 157 / 255)
    static let hawkRed = Color(red: 255 / 255, green: 90 / 255, blue: 90 / 255)
}
