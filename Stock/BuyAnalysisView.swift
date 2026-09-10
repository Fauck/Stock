import SwiftUI

struct BuyAnalysisView: View {

    @State private var vm = BuyAnalysisViewModel()
    @FocusState private var isSearchFocused: Bool

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
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Button {
                performSearch()
            } label: {
                Text("查詢")
                    .font(.warmSubheadline())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppColor.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                    indicatorSummaryCard(signal)
                }
                if !vm.bullishPatterns.isEmpty {
                    kLinePatternCard
                }
                if let inst = vm.institutionalSummary {
                    institutionalCard(inst)
                }
                if vm.week52High != nil || vm.week52Low != nil {
                    week52Card
                }

                // 免責聲明
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 9))
                        .foregroundStyle(AppColor.textSecondary.opacity(0.6))
                    Text("此分析僅供參考，不構成投資建議")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColor.textSecondary.opacity(0.6))
                }
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
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

    // MARK: - Score Card

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

            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: level.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(levelColor)
                    Text(level.label)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(levelColor)
                    Spacer()
                    Text("\(rec.score)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(levelColor)
                    + Text(" / 100")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColor.textSecondary)
                }

                // 進度條
                GeometryReader { geo in
                    let width = geo.size.width
                    let fillWidth = width * CGFloat(rec.score) / 100

                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppColor.divider)
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(levelColor)
                            .frame(width: max(0, fillWidth), height: 6)
                    }
                }
                .frame(height: 6)
            }
            .padding(10)
            .background(levelColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .cardStyle()
    }

    // MARK: - Factors Card

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
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(AppColor.textMain)
                                .lineLimit(1)
                            Spacer(minLength: 2)
                            Text(factor.points > 0 ? "+\(factor.points)" : "\(factor.points)")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(factor.isBullish ? AppColor.softUp : AppColor.softDown)
                        }
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Indicator Summary Card

    private func indicatorSummaryCard(_ signal: TechnicalIndicators.SignalSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text("技術指標摘要")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
            }

            let rows: [(String, String, Color)] = buildIndicatorRows(signal)

            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack {
                    Text(row.0)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColor.textSecondary)
                    Spacer()
                    Text(row.1)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(row.2)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - K-Line Pattern Card

    private var kLinePatternCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "candybarphone")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text("多頭 K 線型態")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
            }

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
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColor.softUp)
                    } else {
                        Text("\(p.barsAgo)日前")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }
                .padding(.vertical, 4)
                if p.id != vm.bullishPatterns.last?.id {
                    Divider().foregroundStyle(AppColor.divider)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Institutional Card

    private func institutionalCard(_ inst: StockService.InstitutionalSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "building.columns")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text("法人動態")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
            }

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
        .cardStyle()
    }

    // MARK: - 52 Week Card

    private var week52Card: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text("52 週區間")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
            }

            if let low = vm.week52Low, let high = vm.week52High, high > low {
                let range = high - low
                let position = (vm.currentPrice - low) / range
                let clampedPos = min(1, max(0, position))

                VStack(spacing: 6) {
                    GeometryReader { geo in
                        let width = geo.size.width
                        let markerX = width * clampedPos

                        ZStack(alignment: .leading) {
                            // 背景
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [AppColor.softDown, AppColor.softDown.opacity(0.3), AppColor.softUp.opacity(0.3), AppColor.softUp],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 8)

                            // 標記
                            Circle()
                                .fill(AppColor.primary)
                                .frame(width: 12, height: 12)
                                .offset(x: markerX - 6)
                        }
                    }
                    .frame(height: 12)

                    HStack {
                        Text(formatPrice(low))
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColor.softDown)
                        Spacer()
                        Text(String(format: "%.0f%%", clampedPos * 100))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColor.textSecondary)
                        Spacer()
                        Text(formatPrice(high))
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColor.softUp)
                    }
                }
            }
        }
        .cardStyle()
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
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .frame(width: 22, height: 22)
            .background(color.opacity(0.12))
            .clipShape(Circle())
    }

    private func institutionalColumn(title: String, streak: Int, latestNet: Int) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(AppColor.textSecondary)
            Text(latestNet >= 0 ? "+\(latestNet)" : "\(latestNet)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(latestNet >= 0 ? AppColor.softUp : AppColor.softDown)
            if abs(streak) >= 2 {
                let label = streak > 0 ? "連買\(streak)日" : "連賣\(abs(streak))日"
                Text(label)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(streak > 0 ? AppColor.softUp : AppColor.softDown)
            }
        }
    }

    private func buildIndicatorRows(_ signal: TechnicalIndicators.SignalSummary) -> [(String, String, Color)] {
        var rows: [(String, String, Color)] = []

        // 均線
        if let cross = signal.maCross {
            rows.append(("MA 交叉", cross.label, cross == .goldenCross ? AppColor.softUp : AppColor.softDown))
        }

        // RSI
        if let rsi = signal.rsi {
            let color: Color = rsi > 80 ? AppColor.softDown : (rsi < 20 ? AppColor.softUp : AppColor.textMain)
            rows.append(("RSI", String(format: "%.1f", rsi), color))
        }

        // KDJ
        if let k = signal.kdjK, let d = signal.kdjD {
            let status = signal.kdjSignal?.label ?? "—"
            let color: Color = k < 20 ? AppColor.softUp : (k > 80 ? AppColor.softDown : AppColor.textMain)
            rows.append(("KD", "K:\(String(format: "%.0f", k)) D:\(String(format: "%.0f", d)) \(status)", color))
        }

        // MACD
        if let dif = signal.macdDIF, let dea = signal.macdDEA {
            let status = signal.macdSignal?.label ?? "—"
            let color: Color = dif > dea ? AppColor.softUp : AppColor.softDown
            rows.append(("MACD", "DIF:\(String(format: "%.2f", dif)) \(status)", color))
        }

        // 布林
        if let bbSig = signal.bollingerSignal, let label = bbSig.label {
            let color: Color = bbSig == .nearLower ? AppColor.softUp : (bbSig == .nearUpper ? AppColor.softDown : AppColor.textMain)
            rows.append(("布林通道", label, color))
        }

        // 成交量
        if let vol = signal.volumeSignal, let label = vol.label {
            rows.append(("成交量", label, vol == .shrink ? AppColor.softDown : AppColor.textMain))
        }

        // 量比
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

#Preview {
    BuyAnalysisView()
}
