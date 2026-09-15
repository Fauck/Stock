//
//  TradeJournalListView.swift
//  Stock
//
//  交易日誌總覽：只看日誌，R-Multiple 明顯顯示
//

import SwiftUI
import SwiftData

/// 交易日誌總覽頁面：從工具箱進入，專注瀏覽所有日誌與 R-Multiple 統計
struct TradeJournalListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Investment.buyDate, order: .reverse)
    private var allInvestments: [Investment]

    @Query private var allJournals: [TradeJournal]

    @State private var selectedFilter: JournalFilterOption = .all
    @State private var selectedDateFilter: DateFilterOption = .all
    @State private var customStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customEndDate: Date = Date()

    /// 有日誌的 Investment（按時間排序）
    private var journaledInvestments: [(investment: Investment, journal: TradeJournal)] {
        let dateFiltered = filterInvestments(
            allInvestments,
            by: selectedDateFilter,
            customStart: customStartDate,
            customEnd: customEndDate,
            dateExtractor: { $0.sellDate ?? $0.buyDate }
        )
        let pairs: [(Investment, TradeJournal)] = dateFiltered.compactMap { inv in
            guard let j = allJournals.first(where: { $0.investmentID == inv.id }) else { return nil }
            return (inv, j)
        }

        switch selectedFilter {
        case .all:
            return pairs
        case .positive:
            return pairs.filter { ($0.1.rMultiple ?? 0) > 0 }
        case .negative:
            return pairs.filter { ($0.1.rMultiple ?? 0) < 0 }
        case .noReview:
            return pairs.filter { !$0.1.hasReview }
        }
    }

    /// R-Multiple 統計（僅計算有 R 值的日誌）
    private var rStats: RStats {
        let withR = journaledInvestments.compactMap { $0.journal.rMultiple }
        guard !withR.isEmpty else { return RStats() }
        let avg = withR.reduce(0, +) / Double(withR.count)
        let positiveCount = withR.filter { $0 > 0 }.count
        let negativeCount = withR.filter { $0 < 0 }.count
        let winRate = Double(positiveCount) / Double(withR.count) * 100
        let best = withR.max() ?? 0
        let worst = withR.min() ?? 0
        let disciplined = withR.filter { $0 >= -1 && $0 < 0 }.count
        let overHeld = withR.filter { $0 < -1 }.count
        return RStats(
            count: withR.count,
            average: avg,
            winRate: winRate,
            positiveCount: positiveCount,
            negativeCount: negativeCount,
            best: best,
            worst: worst,
            disciplinedStops: disciplined,
            overHeldCount: overHeld
        )
    }

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                filterBar

                if journaledInvestments.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            rStatsCard
                            rDistributionCard

                            ForEach(journaledInvestments, id: \.investment.id) { pair in
                                NavigationLink {
                                    TradeJournalDetailView(investment: pair.investment, journal: pair.journal)
                                } label: {
                                    journalCard(investment: pair.investment, journal: pair.journal)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                }
            }
        }
        .navigationTitle("交易日誌")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(AppColor.primary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    // MARK: - 篩選列

    private var filterBar: some View {
        VStack(spacing: 10) {
            // R 值篩選
            HStack(spacing: 8) {
                ForEach(JournalFilterOption.allCases) { option in
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedFilter = option
                        }
                    } label: {
                        Text(option.rawValue)
                            .font(.warmCaption())
                            .fontWeight(.medium)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                selectedFilter == option
                                    ? AppColor.secondary
                                    : AppColor.cardBackground
                            )
                            .foregroundStyle(
                                selectedFilter == option
                                    ? .white
                                    : AppColor.textMain
                            )
                            .clipShape(Capsule())
                            .rowShadow()
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // 日期篩選
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DateFilterOption.allCases) { option in
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedDateFilter = option
                            }
                        } label: {
                            Text(option.rawValue)
                                .font(.warmCaption())
                                .fontWeight(.medium)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(
                                    selectedDateFilter == option
                                        ? AppColor.primary
                                        : AppColor.cardBackground
                                )
                                .foregroundStyle(
                                    selectedDateFilter == option
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

            if selectedDateFilter == .custom {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("起始日期")
                            .font(.warmCaption2())
                            .foregroundStyle(AppColor.textSecondary)
                        DatePicker("", selection: $customStartDate, displayedComponents: .date)
                            .labelsHidden()
                            .tint(AppColor.primary)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("結束日期")
                            .font(.warmCaption2())
                            .foregroundStyle(AppColor.textSecondary)
                        DatePicker("", selection: $customEndDate, displayedComponents: .date)
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
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    // MARK: - 空狀態

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 44))
                .foregroundStyle(AppColor.primary.opacity(0.3))
            Text("尚無交易日誌")
                .font(.warmHeadline())
                .foregroundStyle(AppColor.textMain)
            Text("在買入時展開「交易日誌」區塊即可建立")
                .font(.warmCaption())
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    // MARK: - R-Multiple 統計卡片

    private var rStatsCard: some View {
        VStack(spacing: 14) {
            // 標題列
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .foregroundStyle(AppColor.primary)
                Text("R-Multiple 總覽")
                    .font(.warmHeadline())
                    .foregroundStyle(AppColor.textMain)
                Spacer()
                Text("\(rStats.count) 筆")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
            }

            if rStats.count > 0 {
                AppColor.divider.frame(height: 1)

                // 核心數字：平均 R
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("平均")
                        .font(.warmSubheadline())
                        .foregroundStyle(AppColor.textSecondary)
                    Text(String(format: "%+.2fR", rStats.average))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(Color.rMultipleColor(rStats.average))
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("勝率")
                            .font(.warmCaption2())
                            .foregroundStyle(AppColor.textSecondary)
                        Text(String(format: "%.0f%%", rStats.winRate))
                            .font(.warmTitle())
                            .foregroundStyle(rStats.winRate >= 50 ? AppColor.secondary : AppColor.softDown)
                    }
                }

                // 詳細數據
                HStack {
                    miniStat(title: "最佳", value: String(format: "%+.2fR", rStats.best), color: AppColor.secondary)
                    Spacer()
                    miniStat(title: "最差", value: String(format: "%+.2fR", rStats.worst), color: AppColor.softDown)
                    Spacer()
                    miniStat(title: "正 R", value: "\(rStats.positiveCount)", color: AppColor.secondary)
                    Spacer()
                    miniStat(title: "負 R", value: "\(rStats.negativeCount)", color: AppColor.softDown)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - R 值分佈卡片

    @ViewBuilder
    private var rDistributionCard: some View {
        if rStats.count > 0 && (rStats.disciplinedStops > 0 || rStats.overHeldCount > 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "shield.checkered")
                        .foregroundStyle(AppColor.secondary)
                    Text("停損紀律")
                        .font(.warmHeadline())
                        .foregroundStyle(AppColor.textMain)
                }

                AppColor.divider.frame(height: 1)

                HStack(spacing: 16) {
                    // 紀律停損
                    HStack(spacing: 8) {
                        Circle()
                            .fill(AppColor.textSecondary)
                            .frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("紀律停損 (R ≥ -1)")
                                .font(.warmCaption2())
                                .foregroundStyle(AppColor.textSecondary)
                            Text("\(rStats.disciplinedStops) 筆")
                                .font(.warmSubheadline())
                                .fontWeight(.semibold)
                                .foregroundStyle(AppColor.textMain)
                        }
                    }

                    Spacer()

                    // 凹單
                    HStack(spacing: 8) {
                        Circle()
                            .fill(AppColor.softDown)
                            .frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("凹單虧損 (R < -1)")
                                .font(.warmCaption2())
                                .foregroundStyle(AppColor.textSecondary)
                            HStack(spacing: 4) {
                                Text("\(rStats.overHeldCount) 筆")
                                    .font(.warmSubheadline())
                                    .fontWeight(.semibold)
                                    .foregroundStyle(AppColor.softDown)
                                if rStats.overHeldCount > 0 {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.warmCaption2())
                                        .foregroundStyle(AppColor.softDown)
                                }
                            }
                        }
                    }
                }

                // 紀律比例條
                if rStats.negativeCount > 0 {
                    let ratio = Double(rStats.disciplinedStops) / Double(rStats.negativeCount)
                    VStack(alignment: .leading, spacing: 4) {
                        GeometryReader { geo in
                            HStack(spacing: 2) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(AppColor.textSecondary.opacity(0.5))
                                    .frame(width: max(geo.size.width * ratio, 4))
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(AppColor.softDown.opacity(0.5))
                                    .frame(width: max(geo.size.width * (1 - ratio), 4))
                            }
                        }
                        .frame(height: 8)

                        Text(String(format: "虧損交易中 %.0f%% 紀律停損", ratio * 100))
                            .font(.warmCaption2())
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }
            }
            .cardStyle()
        }
    }

    // MARK: - 單筆日誌卡片

    private func journalCard(investment: Investment, journal: TradeJournal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 第一列：標的 + 方向 + 日期
            HStack {
                Text(StockMapping.displayName(for: investment.ticker))
                    .font(.warmHeadline())
                    .foregroundStyle(AppColor.textMain)

                Text(journal.direction)
                    .font(.warmCaption2())
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        journal.directionEnum == .long
                            ? AppColor.softUp.opacity(0.15)
                            : AppColor.softDown.opacity(0.15)
                    )
                    .foregroundStyle(journal.directionEnum == .long ? AppColor.softUp : AppColor.softDown)
                    .clipShape(Capsule())

                if let mc = journal.marketEnum {
                    Text(mc.prefix)
                        .font(.warmCaption2())
                        .foregroundStyle(AppColor.textSecondary)
                }

                Spacer()

                WarmStatusBadge(
                    text: investment.statusText,
                    color: investment.isClosed ? AppColor.textSecondary : AppColor.secondary
                )
            }

            // 第二列：R-Multiple 醒目顯示
            if let r = journal.rMultiple {
                HStack(spacing: 10) {
                    // R 值大字
                    Text(String(format: "%+.2fR", r))
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(Color.rMultipleColor(r))

                    // R 值解讀
                    Text(rLabel(r))
                        .font(.warmCaption())
                        .foregroundStyle(Color.rMultipleColor(r))

                    if r < -1 {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.warmCaption())
                            .foregroundStyle(AppColor.softDown)
                    }

                    Spacer()

                    // 損益金額
                    if investment.isClosed {
                        let pl = investment.realizedProfitLoss()
                        Text("\(pl >= 0 ? "+" : "")$\(pl, specifier: "%.0f")")
                            .font(.warmSubheadline())
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.profitLossColor(pl))
                    }
                }
                .padding(10)
                .background(Color.rMultipleColor(r).opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.field, style: .continuous))
            } else if !investment.isClosed {
                // 未平倉：無 R 值
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.warmCaption())
                        .foregroundStyle(AppColor.secondary)
                    Text("持有中，待出場覆盤")
                        .font(.warmCaption())
                        .foregroundStyle(AppColor.textSecondary)
                    Spacer()
                }
            }

            // 第三列：進場理由摘要 + 日期
            HStack(alignment: .bottom) {
                if !journal.setup.isEmpty {
                    Text(journal.setup)
                        .font(.warmCaption())
                        .foregroundStyle(AppColor.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(AppDateFormatter.slashDateWithWeekday.string(from: investment.buyDate))
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.textSecondary.opacity(0.7))
            }

            // 情緒分數
            if let score = journal.emotionScore {
                HStack(spacing: 6) {
                    emotionDots(score: score)
                    Spacer()
                    HStack(spacing: 2) {
                        Text("查看日誌")
                            .font(.warmCaption2())
                        Image(systemName: "chevron.right")
                            .font(.warmCaption2())
                    }
                    .foregroundStyle(AppColor.textSecondary.opacity(0.5))
                }
            } else {
                HStack {
                    Spacer()
                    HStack(spacing: 2) {
                        Text("查看日誌")
                            .font(.warmCaption2())
                        Image(systemName: "chevron.right")
                            .font(.warmCaption2())
                    }
                    .foregroundStyle(AppColor.textSecondary.opacity(0.5))
                }
            }
        }
        .cardStyle()
    }

    // MARK: - 共用元件

    private func miniStat(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.warmCaption2())
                .foregroundStyle(AppColor.textSecondary)
            Text(value)
                .font(.warmCaption())
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.inner, style: .continuous))
    }

    private func emotionDots(score: Int) -> some View {
        let colors: [Color] = [.clear, AppColor.softDown, AppColor.softDown.opacity(0.6),
                               AppColor.textSecondary, AppColor.softUp.opacity(0.6), AppColor.softUp]
        let color = score >= 1 && score <= 5 ? colors[score] : AppColor.textSecondary
        return HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { i in
                Circle()
                    .fill(i <= score ? color : AppColor.divider)
                    .frame(width: 6, height: 6)
            }
        }
    }

    private func rLabel(_ r: Double) -> String {
        if r >= 2 { return "優秀" }
        else if r >= 1 { return "正向" }
        else if r > 0 { return "微利" }
        else if r >= -1 { return "紀律停損" }
        else { return "凹單警示" }
    }
}

// MARK: - 日誌篩選選項

private enum JournalFilterOption: String, CaseIterable, Identifiable {
    case all = "全部"
    case positive = "正 R"
    case negative = "負 R"
    case noReview = "未覆盤"

    var id: String { rawValue }
}

// MARK: - R 統計資料

private struct RStats {
    var count: Int = 0
    var average: Double = 0
    var winRate: Double = 0
    var positiveCount: Int = 0
    var negativeCount: Int = 0
    var best: Double = 0
    var worst: Double = 0
    var disciplinedStops: Int = 0
    var overHeldCount: Int = 0
}

#Preview {
    NavigationStack {
        TradeJournalListView()
    }
    .modelContainer(for: [Investment.self, TradeJournal.self], inMemory: true)
}
