import SwiftUI

struct BuyAnalysisView: View {

    @State private var vm = BuyAnalysisViewModel()
    @FocusState private var isSearchFocused: Bool
    @State private var expandedSections: Set<String> = []

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    searchBar
                    Divider().foregroundStyle(AppColor.divider)

                    if vm.isLoading {
                        Spacer()
                        ProgressView("分析中⋯")
                            .font(.warmBody())
                            .foregroundStyle(AppColor.textSecondary)
                        Spacer()
                    } else if let error = vm.errorMessage {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 28))
                                .foregroundStyle(AppColor.softDown)
                            Text(error)
                                .font(.warmCaption())
                                .foregroundStyle(AppColor.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        Spacer()
                    } else if vm.hasResult {
                        resultContent
                    } else {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 28))
                                .foregroundStyle(AppColor.textSecondary.opacity(0.4))
                            Text("輸入股票代號或名稱開始分析")
                                .font(.warmCaption())
                                .foregroundStyle(AppColor.textSecondary)
                        }
                        Spacer()
                    }
                }
            }
            .navigationTitle("買入分析")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: BuyScoreSettingsView()) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14))
                            .foregroundStyle(AppColor.primary)
                    }
                }
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColor.textSecondary)
                TextField("股票代號或名稱", text: $vm.searchText)
                    .font(.warmBody())
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .onSubmit { performSearch() }

                if !vm.searchText.isEmpty {
                    Button {
                        vm.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(AppColor.textSecondary.opacity(0.5))
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(AppColor.divider.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.inner, style: .continuous))

            Button {
                performSearch()
            } label: {
                Text("查詢")
                    .font(.warmSubheadline())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppColor.primary)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.inner, style: .continuous))
            }
            .disabled(vm.searchText.trimmingCharacters(in: .whitespaces).isEmpty || vm.isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Result Content

    private var resultContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                priceHeaderCard

                if let rec = vm.recommendation {
                    scoreCard(rec)
                    factorsCard(rec)
                }

                if let signal = vm.signalSummary {
                    collapsibleCard(
                        id: "indicators",
                        icon: "chart.bar.xaxis",
                        title: "技術指標摘要",
                        summary: indicatorSummaryText(signal)
                    ) {
                        indicatorContent(signal)
                    }
                }

                if !vm.bullishPatterns.isEmpty {
                    collapsibleCard(
                        id: "patterns",
                        icon: "chart.bar.doc.horizontal",
                        title: "多頭 K 線型態",
                        summary: patternSummaryText()
                    ) {
                        patternContent
                    }
                }

                if let inst = vm.institutionalSummary {
                    collapsibleCard(
                        id: "institutional",
                        icon: "building.columns",
                        title: "法人動態",
                        summary: institutionalSummaryText(inst)
                    ) {
                        institutionalContent(inst)
                    }
                }

                if !vm.maDeductions.isEmpty {
                    collapsibleCard(
                        id: "deduction",
                        icon: "arrow.left.arrow.right",
                        title: "均線扣抵值",
                        summary: deductionSummaryText()
                    ) {
                        deductionContent
                    }
                }

                if vm.week52High != nil || vm.week52Low != nil {
                    collapsibleCard(
                        id: "week52",
                        icon: "calendar",
                        title: "52 週區間",
                        summary: week52SummaryText()
                    ) {
                        week52Content
                    }
                }

                // 免責聲明
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 9))
                        .foregroundStyle(AppColor.textSecondary.opacity(0.6))
                    Text("此分析僅供參考，不構成投資建議")
                        .font(.warmMicro())
                        .foregroundStyle(AppColor.textSecondary.opacity(0.6))
                }
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    // MARK: - Collapsible Card

    @ViewBuilder
    private func collapsibleCard<Content: View>(
        id: String,
        icon: String,
        title: String,
        summary: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isExpanded = expandedSections.contains(id)

        VStack(alignment: .leading, spacing: isExpanded ? 8 : 4) {
            // Header row (always visible)
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text(title)
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppColor.textSecondary.opacity(0.5))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }

            if isExpanded {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Text(summary)
                    .font(.warmSecondaryData())
                    .foregroundStyle(AppColor.textSecondary)
                    .lineLimit(1)
                    .transition(.opacity)
            }
        }
        .cardStyle()
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.25)) {
                if isExpanded {
                    expandedSections.remove(id)
                } else {
                    expandedSections.insert(id)
                }
            }
        }
    }

    // MARK: - Summary Helpers

    private func indicatorSummaryText(_ signal: TechnicalIndicators.SignalSummary) -> String {
        var parts: [String] = []
        if let cross = signal.maCross {
            parts.append(cross.label)
        }
        if let rsi = signal.rsi {
            parts.append("RSI \(String(format: "%.1f", rsi))")
        }
        if let kdj = signal.kdjSignal, let label = kdj.label {
            parts.append("KD\(label)")
        }
        if let macd = signal.macdSignal, let label = macd.label {
            parts.append("MACD\(label)")
        }
        let result = Array(parts.prefix(3)).joined(separator: " · ")
        return result.isEmpty ? "無顯著信號" : result
    }

    private func patternSummaryText() -> String {
        let names = vm.bullishPatterns.prefix(3).map { $0.pattern.rawValue }
        let result = names.joined(separator: " · ")
        return result.isEmpty ? "無多頭型態" : result
    }

    private func institutionalSummaryText(_ inst: StockService.InstitutionalSummary) -> String {
        var parts: [String] = []
        let fs = inst.foreignStreak
        if abs(fs) >= 2 {
            parts.append(fs > 0 ? "外資連買\(fs)日" : "外資連賣\(abs(fs))日")
        } else {
            let net = inst.latestForeignNet
            parts.append(net >= 0 ? "外資買超\(net)張" : "外資賣超\(abs(net))張")
        }
        let ts = inst.trustStreak
        if abs(ts) >= 2 {
            parts.append(ts > 0 ? "投信連買\(ts)日" : "投信連賣\(abs(ts))日")
        }
        return parts.joined(separator: " · ")
    }

    private func week52SummaryText() -> String {
        guard let low = vm.week52Low, let high = vm.week52High, high > low else {
            return "資料不足"
        }
        let position = (vm.currentPrice - low) / (high - low)
        let pct = min(100, max(0, position * 100))
        return "目前位於 \(String(format: "%.0f", pct))% 位置"
    }

    // MARK: - Price Header

    private var priceHeaderCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(vm.stockName)
                    .font(.warmHeadline())
                    .foregroundStyle(AppColor.textMain)
                Text(vm.ticker)
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatPrice(vm.currentPrice))
                    .font(.warmLargeNumber())
                    .foregroundStyle(AppColor.textMain)
                if let pct = vm.changePercent {
                    Text(String(format: "%+.2f%%", pct))
                        .font(.warmCaption())
                        .foregroundStyle(pct >= 0 ? AppColor.softUp : AppColor.softDown)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Score Card (Half-Circle Gauge)

    private func scoreCard(_ rec: TechnicalIndicators.BuyRecommendation) -> some View {
        let level = rec.level
        let levelColor = buyLevelColor(level)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text("買入建議")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
            }

            VStack(spacing: 4) {
                ScoreGaugeView(
                    score: rec.score,
                    level: level,
                    levelColor: levelColor
                )
                .frame(height: 110)

                HStack(spacing: 6) {
                    Image(systemName: level.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(levelColor)
                    Text(level.label)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(levelColor)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(levelColor.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.field, style: .continuous))
        }
        .cardStyle()
    }

    // MARK: - Factors Card (with Stacked Bar)

    private func factorsCard(_ rec: TechnicalIndicators.BuyRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "list.bullet")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text("評分因子")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
            }

            if !rec.factors.isEmpty {
                // Stacked bar
                let bullishTotal = rec.factors.filter(\.isBullish).map(\.points).reduce(0, +)
                let bearishTotal = abs(rec.factors.filter { !$0.isBullish }.map(\.points).reduce(0, +))
                let barTotal = bullishTotal + bearishTotal

                if barTotal > 0 {
                    VStack(spacing: 4) {
                        GeometryReader { geo in
                            let width = geo.size.width
                            let bullishWidth = width * CGFloat(bullishTotal) / CGFloat(barTotal)
                            let bearishWidth = width * CGFloat(bearishTotal) / CGFloat(barTotal)

                            HStack(spacing: 0) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(AppColor.softUp)
                                    .frame(width: max(0, bullishWidth), height: 8)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(AppColor.softDown)
                                    .frame(width: max(0, bearishWidth), height: 8)
                            }
                        }
                        .frame(height: 8)

                        HStack {
                            Text("偏多 +\(bullishTotal)")
                                .font(.warmTertiary(.semibold))
                                .foregroundStyle(AppColor.softUp)
                            Spacer()
                            Text("偏空 -\(bearishTotal)")
                                .font(.warmTertiary(.semibold))
                                .foregroundStyle(AppColor.softDown)
                        }
                    }
                    .padding(.bottom, 4)
                }

                // Factor list
                let columns = [
                    GridItem(.flexible(), spacing: 6),
                    GridItem(.flexible(), spacing: 6)
                ]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
                    ForEach(rec.factors) { factor in
                        HStack(spacing: 4) {
                            Image(systemName: factor.isBullish ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                                .font(.system(size: 7))
                                .foregroundStyle(factor.isBullish ? AppColor.softUp : AppColor.softDown)
                            Text(factor.name)
                                .font(.warmTertiary())
                                .foregroundStyle(AppColor.textMain)
                                .lineLimit(1)
                            Spacer(minLength: 2)
                            Text(factor.points > 0 ? "+\(factor.points)" : "\(factor.points)")
                                .font(.warmTertiary(.semibold))
                                .foregroundStyle(factor.isBullish ? AppColor.softUp : AppColor.softDown)
                        }
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Indicator Content (inside collapsible)

    private func indicatorContent(_ signal: TechnicalIndicators.SignalSummary) -> some View {
        let rows = buildIndicatorRows(signal)
        return ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
            HStack {
                Text(row.0)
                    .font(.warmSecondaryData())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
                Text(row.1)
                    .font(.warmSecondaryData(.semibold))
                    .foregroundStyle(row.2)
            }
        }
    }

    // MARK: - K-Line Pattern Content (inside collapsible)

    private var patternContent: some View {
        ForEach(vm.bullishPatterns, id: \.pattern) { p in
            HStack(spacing: 6) {
                reliabilityBadge(p.reliability)
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.pattern.rawValue)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColor.textMain)
                    Text(p.description)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(AppColor.textSecondary)
                }
                Spacer()
                if p.barsAgo == 0 {
                    Text("今日")
                        .font(.warmMicro())
                        .foregroundStyle(AppColor.softUp)
                } else {
                    Text("\(p.barsAgo)日前")
                        .font(.warmMicro())
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
            .padding(.vertical, 4)
            if p.id != vm.bullishPatterns.last?.id {
                Divider().foregroundStyle(AppColor.divider)
            }
        }
    }

    // MARK: - Institutional Content (inside collapsible)

    private func institutionalContent(_ inst: StockService.InstitutionalSummary) -> some View {
        HStack(spacing: 0) {
            institutionalColumn(
                title: "外資",
                streak: inst.foreignStreak,
                latestNet: inst.latestForeignNet
            )
            Spacer()
            institutionalColumn(
                title: "投信",
                streak: inst.trustStreak,
                latestNet: inst.latestTrustNet
            )
            Spacer()
            institutionalColumn(
                title: "自營商",
                streak: 0,
                latestNet: inst.latestDealerNet
            )
        }
    }

    // MARK: - 52 Week Content (inside collapsible)

    @ViewBuilder
    private var week52Content: some View {
        if let low = vm.week52Low, let high = vm.week52High, high > low {
            let range = high - low
            let position = (vm.currentPrice - low) / range
            let clampedPos = min(1, max(0, position))

            VStack(spacing: 6) {
                GeometryReader { geo in
                    let width = geo.size.width
                    let markerX = width * clampedPos

                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [AppColor.softDown, AppColor.softDown.opacity(0.3), AppColor.softUp.opacity(0.3), AppColor.softUp],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 8)

                        Circle()
                            .fill(AppColor.primary)
                            .frame(width: 12, height: 12)
                            .offset(x: markerX - 6)
                    }
                }
                .frame(height: 12)

                HStack {
                    Text(formatPrice(low))
                        .font(.warmTertiary())
                        .foregroundStyle(AppColor.softDown)
                    Spacer()
                    Text(String(format: "%.0f%%", clampedPos * 100))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColor.textSecondary)
                    Spacer()
                    Text(formatPrice(high))
                        .font(.warmTertiary())
                        .foregroundStyle(AppColor.softUp)
                }
            }
        }
    }

    // MARK: - Deduction Summary & Content

    private func deductionSummaryText() -> String {
        let parts = vm.maDeductions.map { d in
            let arrow: String
            switch d.trend {
            case .up:   arrow = "↑"
            case .down: arrow = "↓"
            case .flat: arrow = "→"
            }
            return "\(d.periodLabel)\(arrow)"
        }
        return parts.joined(separator: "｜")
    }

    private var deductionContent: some View {
        VStack(spacing: 6) {
            // 表頭
            HStack {
                Text("均線")
                    .frame(width: 50, alignment: .leading)
                Text("扣抵價")
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Text("現價")
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Text("預判")
                    .frame(width: 70, alignment: .trailing)
            }
            .font(.warmTertiary())
            .foregroundStyle(AppColor.textSecondary)

            Divider().foregroundStyle(AppColor.divider)

            // 各均線資料列
            ForEach(vm.maDeductions) { d in
                HStack {
                    Text(d.periodLabel)
                        .font(.warmSecondaryData(.semibold))
                        .foregroundStyle(AppColor.textMain)
                        .frame(width: 50, alignment: .leading)

                    Text(formatPrice(d.deductionPrice))
                        .font(.warmSecondaryData())
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    Text(formatPrice(d.currentPrice))
                        .font(.warmSecondaryData(.semibold))
                        .foregroundStyle(AppColor.textMain)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    HStack(spacing: 3) {
                        Image(systemName: d.trend == .up ? "arrowtriangle.up.fill" : (d.trend == .down ? "arrowtriangle.down.fill" : "minus"))
                            .font(.system(size: 7))
                        Text(d.trend.rawValue)
                            .font(.warmSecondaryData(.semibold))
                    }
                    .foregroundStyle(deductionTrendColor(d.trend))
                    .frame(width: 70, alignment: .trailing)
                }
            }

            // 未來走勢圖
            Divider().foregroundStyle(AppColor.divider)

            ForEach(vm.maDeductions) { d in
                if d.futureDeductions.count >= 2 {
                    DeductionForecastChart(info: d)
                }
            }

            // 解讀說明
            if let key = vm.maDeductions.first(where: { $0.period == 20 }) ?? vm.maDeductions.first {
                Divider().foregroundStyle(AppColor.divider)
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "lightbulb.min")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                        .padding(.top, 1)
                    Text(deductionInterpretation(key))
                        .font(.warmTertiary())
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func deductionTrendColor(_ trend: TechnicalIndicators.DeductionTrend) -> Color {
        switch trend {
        case .up:   return AppColor.softUp
        case .down: return AppColor.softDown
        case .flat: return AppColor.textSecondary
        }
    }

    private func deductionInterpretation(_ d: TechnicalIndicators.MADeductionInfo) -> String {
        let gap = String(format: "%.1f%%", abs(d.gapPercent))
        switch d.trend {
        case .up:
            return "\(d.periodLabel) 扣抵價 \(formatPrice(d.deductionPrice)) 低於現價（差距 \(gap)），均線近期有上彎動能"
        case .down:
            return "\(d.periodLabel) 扣抵價 \(formatPrice(d.deductionPrice)) 高於現價（差距 \(gap)），均線近期有下彎壓力"
        case .flat:
            return "\(d.periodLabel) 扣抵價與現價接近，均線走勢持平"
        }
    }

    // MARK: - Helpers

    private func performSearch() {
        isSearchFocused = false
        Task { await vm.load() }
    }

    private func buyLevelColor(_ level: TechnicalIndicators.BuyLevel) -> Color {
        switch level {
        case .strongBuy:   return AppColor.softUp
        case .considerBuy: return .orange
        case .neutral:     return AppColor.textSecondary
        case .cautious:    return AppColor.softDown
        case .avoidBuy:    return AppColor.softDown
        }
    }

    private func reliabilityBadge(_ reliability: TechnicalIndicators.CandlestickReliability) -> some View {
        let (text, color): (String, Color) = {
            switch reliability {
            case .high:   return ("高", AppColor.softUp)
            case .medium: return ("中", .orange)
            case .low:    return ("低", AppColor.textSecondary)
            }
        }()
        return Text(text)
            .font(.warmMicro(.bold))
            .foregroundStyle(color)
            .frame(width: 22, height: 22)
            .background(color.opacity(0.12))
            .clipShape(Circle())
    }

    private func institutionalColumn(title: String, streak: Int, latestNet: Int) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.warmTertiary())
                .foregroundStyle(AppColor.textSecondary)
            Text(latestNet >= 0 ? "+\(latestNet)" : "\(latestNet)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(latestNet >= 0 ? AppColor.softUp : AppColor.softDown)
            if abs(streak) >= 2 {
                let label = streak > 0 ? "連買\(streak)日" : "連賣\(abs(streak))日"
                Text(label)
                    .font(.warmMicro())
                    .foregroundStyle(streak > 0 ? AppColor.softUp : AppColor.softDown)
            }
        }
    }

    private func buildIndicatorRows(_ signal: TechnicalIndicators.SignalSummary) -> [(String, String, Color)] {
        var rows: [(String, String, Color)] = []

        if let cross = signal.maCross {
            rows.append(("MA 交叉", cross.label, cross == .goldenCross ? AppColor.softUp : AppColor.softDown))
        }

        if let rsi = signal.rsi {
            let color: Color = rsi > 80 ? AppColor.softDown : (rsi < 20 ? AppColor.softUp : AppColor.textMain)
            rows.append(("RSI", String(format: "%.1f", rsi), color))
        }

        if let k = signal.kdjK, let d = signal.kdjD {
            let status = signal.kdjSignal?.label ?? "—"
            let color: Color = k < 20 ? AppColor.softUp : (k > 80 ? AppColor.softDown : AppColor.textMain)
            rows.append(("KD", "K:\(String(format: "%.0f", k)) D:\(String(format: "%.0f", d)) \(status)", color))
        }

        if let dif = signal.macdDIF, let dea = signal.macdDEA {
            let status = signal.macdSignal?.label ?? "—"
            let color: Color = dif > dea ? AppColor.softUp : AppColor.softDown
            rows.append(("MACD", "DIF:\(String(format: "%.2f", dif)) \(status)", color))
        }

        if let bbSig = signal.bollingerSignal, let label = bbSig.label {
            let color: Color = bbSig == .nearLower ? AppColor.softUp : (bbSig == .nearUpper ? AppColor.softDown : AppColor.textMain)
            rows.append(("布林通道", label, color))
        }

        if let vol = signal.volumeSignal, let label = vol.label {
            rows.append(("成交量", label, vol == .shrink ? AppColor.softDown : AppColor.textMain))
        }

        if let ratio = signal.volumeRatio {
            rows.append(("量比", String(format: "%.2f", ratio), AppColor.textMain))
        }

        return rows
    }

    private func formatPrice(_ price: Double) -> String {
        if price >= 100 {
            return String(format: "%.0f", price)
        } else if price >= 10 {
            return String(format: "%.1f", price)
        } else {
            return String(format: "%.2f", price)
        }
    }
}

// MARK: - Score Gauge View (Half-Circle)

private struct ScoreGaugeView: View {
    let score: Int
    let level: TechnicalIndicators.BuyLevel
    let levelColor: Color

    @State private var animatedProgress: Double = 0

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height * 2)
            let lineWidth: CGFloat = 14
            let radius = (size - lineWidth) / 2

            ZStack {
                // Background arc
                SemiCircleArc()
                    .stroke(AppColor.divider, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .frame(width: size, height: size / 2)

                // Filled arc
                SemiCircleArc()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        AngularGradient(
                            colors: [AppColor.softDown, .orange, AppColor.softUp],
                            center: .bottom,
                            startAngle: .degrees(180),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .frame(width: size, height: size / 2)

                // Score text
                VStack(spacing: 0) {
                    Text("\(score)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(levelColor)
                    Text("/ 100")
                        .font(.warmSecondaryData())
                        .foregroundStyle(AppColor.textSecondary)
                }
                .offset(y: radius * 0.15)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animatedProgress = Double(score) / 100.0
            }
        }
        .onChange(of: score) { _, newValue in
            animatedProgress = 0
            withAnimation(.easeOut(duration: 0.8)) {
                animatedProgress = Double(newValue) / 100.0
            }
        }
    }
}

/// A half-circle arc shape drawn from 180° to 360° (left to right along the top)
private struct SemiCircleArc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.maxY)
        let radius = min(rect.width, rect.height * 2) / 2
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(360),
            clockwise: false
        )
        return path
    }
}

#Preview {
    BuyAnalysisView()
}
