import SwiftUI
import SwiftData
import Charts

/// 交易績效儀表板：六大維度全方位分析
struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Investment> { $0.isClosed },
           sort: \Investment.buyDate, order: .reverse)
    private var allSoldInvestments: [Investment]

    @Query private var allJournals: [TradeJournal]

    @State private var vm = DashboardViewModel()
    @State private var tickerRankTab: TickerRankTab = .profit

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                filterBar

                if vm.filteredInvestments.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    mainContent
                }
            }
        }
        .navigationTitle("交易績效儀表板")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(AppColor.primary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            vm.allSoldInvestments = allSoldInvestments
            vm.allJournals = allJournals
        }
        .onChange(of: allSoldInvestments) { _, newValue in
            vm.allSoldInvestments = newValue
        }
        .onChange(of: allJournals) { _, newValue in
            vm.allJournals = newValue
        }
    }

    // MARK: - 空狀態

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 44))
                .foregroundStyle(AppColor.primary.opacity(0.3))
            Text("尚無已實現交易紀錄")
                .font(.warmHeadline())
                .foregroundStyle(AppColor.textMain)
            Text("平倉後的交易將顯示在此儀表板中")
                .font(.warmCaption())
                .foregroundStyle(AppColor.textSecondary)

            HStack(spacing: 6) {
                Image(systemName: "leaf.fill")
                    .font(.warmDataValue())
                Text("前往「持有庫存」頁籤賣出持股")
                    .font(.warmCaption())
            }
            .foregroundStyle(AppColor.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(AppColor.primary.opacity(0.08))
            .clipShape(Capsule())
        }
    }

    // MARK: - 日期篩選列

    private var filterBar: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DateFilterOption.allCases) { option in
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                vm.selectedFilter = option
                            }
                        } label: {
                            Text(option.rawValue)
                                .font(.warmCaption())
                                .fontWeight(.medium)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(
                                    vm.selectedFilter == option
                                        ? AppColor.primary
                                        : AppColor.cardBackground
                                )
                                .foregroundStyle(
                                    vm.selectedFilter == option
                                        ? .white
                                        : AppColor.textMain
                                )
                                .clipShape(Capsule())
                                .rowShadow()
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 12)

            if vm.selectedFilter == .custom {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("起始日期")
                            .font(.warmCaption2())
                            .foregroundStyle(AppColor.textSecondary)
                        DatePicker("", selection: $vm.customStartDate, displayedComponents: .date)
                            .labelsHidden()
                            .tint(AppColor.primary)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("結束日期")
                            .font(.warmCaption2())
                            .foregroundStyle(AppColor.textSecondary)
                        DatePicker("", selection: $vm.customEndDate, displayedComponents: .date)
                            .labelsHidden()
                            .tint(AppColor.primary)
                    }
                }
                .padding(.horizontal, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.bottom, 8)
        .background(AppColor.cardBackground)
        .smallShadow()
    }

    // MARK: - 主內容

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Section 1: 績效總覽
                overviewCard
                    .padding(.horizontal, 16)

                // Section 2: 累積損益曲線
                if vm.cumulativePnLData.count >= 2 {
                    cumulativePnLCard
                        .padding(.horizontal, 16)
                }

                // Section 2b: 週期損益
                if !vm.periodPnLData.isEmpty {
                    periodPnLChartCard
                        .padding(.horizontal, 16)
                }

                if vm.rollingWinRateData.count >= 2 {
                    rollingWinRateCard
                        .padding(.horizontal, 16)
                }

                // Section 3: 持有天數分析
                if !vm.holdingBucketStats.isEmpty {
                    holdingPeriodCard
                        .padding(.horizontal, 16)
                }

                // Section 4: 情緒 vs 績效
                if vm.hasEmotionData {
                    emotionCard
                        .padding(.horizontal, 16)
                }

                // Section 5: 紀律分析
                if vm.hasRMultipleData {
                    disciplineCard
                        .padding(.horizontal, 16)
                }

                // Section 6: 標的排行
                tickerRankingCard
                    .padding(.horizontal, 16)
            }
            .padding(.vertical, 12)
        }
    }

    // MARK: - Section 1：績效總覽

    private var overviewCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text("績效總覽")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
            }

            // 大字總損益
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("總已實現損益")
                        .font(.warmCaption())
                        .foregroundStyle(AppColor.textSecondary)
                    Text(vm.formatPL(vm.totalPL))
                        .font(.warmLargeNumber())
                        .foregroundStyle(Color.profitLossColor(vm.totalPL))
                }
                Spacer()
                Image(systemName: vm.totalPL >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.profitLossColor(vm.totalPL).opacity(0.3))
            }

            AppColor.divider.frame(height: 1)

            HStack(spacing: 0) {
                statCell(title: "交易筆數", value: "\(vm.tradeCount) 筆", color: AppColor.textMain)
                statCell(title: "勝率", value: String(format: "%.0f%%", vm.winRate),
                         color: vm.winRate >= 50 ? AppColor.softUp : AppColor.softDown)
                statCell(title: "最大連虧", value: "\(vm.maxConsecutiveLosses) 筆",
                         color: vm.maxConsecutiveLosses >= 3 ? AppColor.softDown : AppColor.textMain)
            }

            HStack(spacing: 0) {
                statCell(title: "平均獲利", value: String(format: "+$%.0f", vm.avgProfit), color: AppColor.softUp)
                statCell(title: "平均虧損", value: String(format: "-$%.0f", vm.avgLoss), color: AppColor.softDown)
                statCell(title: "盈虧比",
                         value: vm.profitLossRatio > 0 ? String(format: "1:%.2f", vm.profitLossRatio) : "—",
                         color: vm.profitLossRatio >= 1 ? AppColor.softUp : AppColor.textMain)
            }

            AppColor.divider.frame(height: 1)

            HStack(spacing: 0) {
                statCell(title: "最佳單筆", value: String(format: "+$%.0f", vm.bestTrade), color: AppColor.softUp)
                statCell(title: "最差單筆", value: String(format: "$%.0f", vm.worstTrade), color: AppColor.softDown)
                statCell(title: "最大回撤",
                         value: vm.maxDrawdown > 0 ? String(format: "-$%.0f", vm.maxDrawdown) : "—",
                         color: vm.maxDrawdown > 0 ? AppColor.softDown : AppColor.textSecondary)
            }
        }
        .cardStyle()
    }

    // MARK: - Section 2：累積損益曲線

    private var cumulativePnLCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text("累積損益曲線")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
            }

            Chart {
                ForEach(vm.cumulativePnLData) { point in
                    LineMark(
                        x: .value("日期", point.date),
                        y: .value("累積損益", point.cumulativePnL)
                    )
                    .foregroundStyle(AppColor.primary)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("日期", point.date),
                        yStart: .value("底", 0),
                        yEnd: .value("累積損益", point.cumulativePnL)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColor.primary.opacity(0.2), AppColor.primary.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }

                RuleMark(y: .value("零線", 0))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(AppColor.textSecondary.opacity(0.5))
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(formatAmount(v))
                                .font(.warmCaption2())
                                .foregroundStyle(AppColor.textSecondary)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(AppColor.divider)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(AppDateFormatter.shortMonthDay.string(from: date))
                                .font(.warmCaption2())
                                .foregroundStyle(AppColor.textSecondary)
                        }
                    }
                }
            }
            .frame(height: 200)
        }
        .cardStyle()
    }

    // MARK: - Section 2b：週期損益圖（月/季/年）

    private var periodPnLChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text("損益趨勢")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()

                // 月/季/年切換
                HStack(spacing: 0) {
                    ForEach(PeriodMode.allCases) { mode in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                vm.periodMode = mode
                            }
                        } label: {
                            Text(mode.rawValue)
                                .font(.warmCaption2())
                                .fontWeight(.semibold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(vm.periodMode == mode ? AppColor.primary : Color.clear)
                                .foregroundStyle(vm.periodMode == mode ? .white : AppColor.textSecondary)
                        }
                    }
                }
                .background(AppColor.background)
                .clipShape(Capsule())
            }

            Chart {
                ForEach(vm.periodPnLData) { point in
                    BarMark(
                        x: .value("期間", point.label),
                        y: .value("損益", point.pnl)
                    )
                    .foregroundStyle(point.pnl >= 0 ? AppColor.softUp : AppColor.softDown)
                    .cornerRadius(4)
                }

                RuleMark(y: .value("零線", 0))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(AppColor.textSecondary.opacity(0.5))
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(formatAmount(v))
                                .font(.warmCaption2())
                                .foregroundStyle(AppColor.textSecondary)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(AppColor.divider)
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(.warmCaption2())
                                .foregroundStyle(AppColor.textSecondary)
                                .rotationEffect(.degrees(-30))
                        }
                    }
                }
            }
            .frame(height: 220)

            // 明細列表
            VStack(spacing: 6) {
                ForEach(vm.periodPnLData) { point in
                    HStack(spacing: 8) {
                        Text(point.label)
                            .font(.warmSecondaryData())
                            .foregroundStyle(AppColor.textMain)
                            .frame(width: 62, alignment: .leading)

                        GeometryReader { geo in
                            let winPct = point.tradeCount > 0
                                ? CGFloat(point.winCount) / CGFloat(point.tradeCount) : 0
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: AppRadius.tiny)
                                    .fill(AppColor.softDown.opacity(0.3))
                                RoundedRectangle(cornerRadius: AppRadius.tiny)
                                    .fill(AppColor.softUp.opacity(0.7))
                                    .frame(width: geo.size.width * winPct)
                            }
                        }
                        .frame(height: 6)

                        Text("\(point.winCount)/\(point.tradeCount)")
                            .font(.warmTertiary(.regular))
                            .foregroundStyle(AppColor.textSecondary)
                            .frame(width: 30, alignment: .trailing)

                        Text(formatAmount(point.pnl))
                            .font(.warmSecondaryData(.semibold))
                            .foregroundStyle(Color.profitLossColor(point.pnl))
                            .frame(width: 55, alignment: .trailing)
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Section 2b：滾動勝率

    private var rollingWinRateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "waveform.path.ecg")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text("近 10 筆滾動勝率")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
            }

            Chart {
                ForEach(vm.rollingWinRateData) { point in
                    LineMark(
                        x: .value("筆數", point.tradeIndex),
                        y: .value("勝率", point.winRate * 100)
                    )
                    .foregroundStyle(AppColor.primary)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("筆數", point.tradeIndex),
                        yStart: .value("底", 0),
                        yEnd: .value("勝率", point.winRate * 100)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColor.primary.opacity(0.2), AppColor.primary.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }

                RuleMark(y: .value("50%", 50))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(AppColor.textSecondary.opacity(0.5))
                    .annotation(position: .trailing, alignment: .leading) {
                        Text("50%")
                            .font(.system(size: 8, design: .rounded))
                            .foregroundStyle(AppColor.textSecondary)
                    }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("\(Int(v))%")
                                .font(.warmCaption2())
                                .foregroundStyle(AppColor.textSecondary)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(AppColor.divider)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text("第\(v)筆")
                                .font(.warmCaption2())
                                .foregroundStyle(AppColor.textSecondary)
                        }
                    }
                }
            }
            .frame(height: 180)
        }
        .cardStyle()
    }

    // MARK: - Section 3：持有天數分析

    private var holdingPeriodCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.clock")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text("持有天數分析")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
            }

            // 勝方 vs 敗方平均持有天數
            HStack(spacing: 0) {
                statCell(title: "勝方平均持有", value: "\(vm.avgHoldingDaysWin) 日",
                         color: AppColor.softUp)
                statCell(title: "敗方平均持有", value: "\(vm.avgHoldingDaysLoss) 日",
                         color: AppColor.softDown)
            }

            AppColor.divider.frame(height: 1)

            // 各分類勝率
            ForEach(vm.holdingBucketStats) { stat in
                HStack(spacing: 8) {
                    Text(stat.id.rawValue)
                        .font(.warmSecondaryData())
                        .foregroundStyle(AppColor.textMain)
                        .frame(width: 85, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: AppRadius.tiny)
                                .fill(AppColor.softDown.opacity(0.3))
                            RoundedRectangle(cornerRadius: AppRadius.tiny)
                                .fill(AppColor.softUp.opacity(0.7))
                                .frame(width: geo.size.width * stat.winRate / 100)
                        }
                    }
                    .frame(height: 8)

                    Text(String(format: "%.0f%%", stat.winRate))
                        .font(.warmSecondaryData(.semibold))
                        .foregroundStyle(stat.winRate >= 50 ? AppColor.softUp : AppColor.softDown)
                        .frame(width: 32, alignment: .trailing)

                    Text("\(stat.tradeCount) 筆")
                        .font(.warmTertiary(.regular))
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(width: 28, alignment: .trailing)
                }
                .frame(height: 22)
            }
        }
        .cardStyle()
    }

    // MARK: - Section 4：情緒 vs 績效

    private var emotionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text("情緒 vs 績效")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
            }

            ForEach(vm.emotionGroupStats) { stat in
                HStack(spacing: 8) {
                    Text(stat.scoreLabel)
                        .font(.warmSecondaryData())
                        .foregroundStyle(emotionColor(for: stat.id))
                        .frame(width: 52, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: AppRadius.tiny)
                                .fill(AppColor.divider)
                            RoundedRectangle(cornerRadius: AppRadius.tiny)
                                .fill(emotionColor(for: stat.id).opacity(0.7))
                                .frame(width: geo.size.width * stat.winRate / 100)
                        }
                    }
                    .frame(height: 8)

                    Text(String(format: "%.0f%%", stat.winRate))
                        .font(.warmSecondaryData(.semibold))
                        .foregroundStyle(AppColor.textMain)
                        .frame(width: 32, alignment: .trailing)

                    Text(String(format: "%+.1f%%", stat.avgReturnPct))
                        .font(.warmTertiary())
                        .foregroundStyle(Color.profitLossColor(stat.avgReturnPct))
                        .frame(width: 45, alignment: .trailing)

                    Text("\(stat.tradeCount)筆")
                        .font(.warmTertiary(.regular))
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(width: 25, alignment: .trailing)
                }
                .frame(height: 22)
            }

            // 洞察
            if let best = vm.emotionGroupStats.max(by: { $0.winRate < $1.winRate }) {
                HStack(spacing: 4) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(AppColor.primary)
                    Text("最高勝率出現在「\(best.scoreLabel)」（\(String(format: "%.0f", best.winRate))%）")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(AppColor.textSecondary)
                }
                .padding(.top, 2)
            }
        }
        .cardStyle()
    }

    // MARK: - Section 5：紀律分析

    private var disciplineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "shield.checkerboard")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text("紀律分析")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
            }

            // 關鍵指標
            HStack(spacing: 0) {
                statCell(title: "平均 R",
                         value: vm.averageR.map { String(format: "%+.2fR", $0) } ?? "—",
                         color: (vm.averageR ?? 0) >= 0 ? AppColor.softUp : AppColor.softDown)
                statCell(title: "紀律停損率",
                         value: vm.disciplinedStopRatio.map { String(format: "%.0f%%", $0 * 100) } ?? "—",
                         color: (vm.disciplinedStopRatio ?? 0) >= 0.7 ? AppColor.softUp : AppColor.textMain)
                statCell(title: "恐慌出場率",
                         value: vm.panicSellRatio.map { String(format: "%.0f%%", $0 * 100) } ?? "—",
                         color: (vm.panicSellRatio ?? 0) <= 0.2 ? AppColor.softUp : AppColor.softDown)
            }

            // R 分佈直方圖
            if !vm.rDistributionBuckets.isEmpty {
                AppColor.divider.frame(height: 1)

                Text("R-Multiple 分佈")
                    .font(.warmTertiary())
                    .foregroundStyle(AppColor.textSecondary)

                Chart {
                    ForEach(vm.rDistributionBuckets) { bucket in
                        BarMark(
                            x: .value("R區間", bucket.label),
                            y: .value("筆數", bucket.count)
                        )
                        .foregroundStyle(bucket.isPositive ? AppColor.softUp : AppColor.softDown)
                        .cornerRadius(3)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text("\(v)")
                                    .font(.warmCaption2())
                                    .foregroundStyle(AppColor.textSecondary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .font(.system(size: 8, design: .rounded))
                                    .foregroundStyle(AppColor.textSecondary)
                            }
                        }
                    }
                }
                .frame(height: 140)
            }

            // 出場理由分佈
            if !vm.exitReasonStats.isEmpty {
                AppColor.divider.frame(height: 1)

                Text("出場理由分佈")
                    .font(.warmTertiary())
                    .foregroundStyle(AppColor.textSecondary)

                let maxCount = vm.exitReasonStats.map(\.count).max() ?? 1
                ForEach(vm.exitReasonStats) { stat in
                    HStack(spacing: 8) {
                        Image(systemName: stat.icon)
                            .font(.system(size: 10))
                            .foregroundStyle(AppColor.primary)
                            .frame(width: 16)

                        Text(stat.label)
                            .font(.warmSecondaryData())
                            .foregroundStyle(AppColor.textMain)
                            .frame(width: 65, alignment: .leading)
                            .lineLimit(1)

                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: AppRadius.tiny)
                                .fill(AppColor.primary.opacity(0.4))
                                .frame(width: geo.size.width * Double(stat.count) / Double(maxCount))
                        }
                        .frame(height: 8)

                        Text("\(stat.count) 筆")
                            .font(.warmTertiary(.regular))
                            .foregroundStyle(AppColor.textSecondary)
                            .frame(width: 28, alignment: .trailing)
                    }
                    .frame(height: 22)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Section 6：標的排行

    private var tickerRankingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "trophy.fill")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.primary)
                Text("標的排行")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
            }

            // Tab 切換
            HStack(spacing: 0) {
                ForEach(TickerRankTab.allCases) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            tickerRankTab = tab
                        }
                    } label: {
                        Text(tab.rawValue)
                            .font(.warmSecondaryData(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(tickerRankTab == tab ? AppColor.primary : Color.clear)
                            .foregroundStyle(tickerRankTab == tab ? .white : AppColor.textMain)
                    }
                }
            }
            .background(AppColor.background)
            .clipShape(Capsule())

            // 排行列表
            let items: [DashboardTickerStat] = {
                switch tickerRankTab {
                case .profit: return vm.topProfitTickers
                case .loss:   return vm.topLossTickers
                case .traded: return vm.mostTradedTickers
                }
            }()

            if items.isEmpty {
                Text("尚無資料")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 8) {
                        Text("#\(index + 1)")
                            .font(.warmSecondaryData(.bold))
                            .foregroundStyle(index < 3 ? AppColor.primary : AppColor.textSecondary)
                            .frame(width: 22, alignment: .leading)

                        Text(item.displayName)
                            .font(.warmDataValue())
                            .foregroundStyle(AppColor.textMain)
                            .lineLimit(1)

                        Spacer()

                        if tickerRankTab == .traded {
                            Text("\(item.tradeCount) 筆")
                                .font(.warmSecondaryData(.semibold))
                                .foregroundStyle(AppColor.textMain)
                        } else {
                            Text(formatAmount(item.totalPL))
                                .font(.warmSecondaryData(.semibold))
                                .foregroundStyle(Color.profitLossColor(item.totalPL))
                        }

                        Text(String(format: "%.0f%%", item.winRate))
                            .font(.warmTertiary(.regular))
                            .foregroundStyle(item.winRate >= 50 ? AppColor.softUp : AppColor.softDown)
                            .frame(width: 30, alignment: .trailing)
                    }
                    .padding(.vertical, 4)

                    if index < items.count - 1 {
                        AppColor.divider.frame(height: 0.5)
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Helpers

    private func statCell(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.warmMicro())
                .foregroundStyle(AppColor.textSecondary)
            Text(value)
                .font(.warmDataValue(.bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private func emotionColor(for score: Int) -> Color {
        switch score {
        case 1: return AppColor.softDown
        case 2: return AppColor.softDown.opacity(0.7)
        case 3: return AppColor.textSecondary
        case 4: return AppColor.softUp.opacity(0.7)
        case 5: return AppColor.softUp
        default: return AppColor.textSecondary
        }
    }

    private func formatAmount(_ value: Double) -> String {
        let absVal = abs(value)
        let sign = value >= 0 ? "+" : "-"
        if absVal >= 10000 {
            return String(format: "%@%.1f萬", sign, absVal / 10000)
        }
        if absVal >= 1000 {
            return String(format: "%@%.1fK", sign, absVal / 1000)
        }
        return String(format: "%@$%.0f", sign, absVal)
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
    .modelContainer(for: [Investment.self, TradeJournal.self], inMemory: true)
}
