//
//  TradeJournalDetailView.swift
//  Stock
//
//  交易日誌詳情頁：三階段展示完整日誌
//

import SwiftUI
import SwiftData

/// 交易日誌詳情頁：展示進場前 → 執行中 → 出場覆盤三階段
struct TradeJournalDetailView: View {
    let investment: Investment
    let journal: TradeJournal
    @State private var chartVM: KLineChartViewModel

    init(investment: Investment, journal: TradeJournal) {
        self.investment = investment
        self.journal = journal
        _chartVM = State(initialValue: KLineChartViewModel(investment: investment, journal: journal))
    }

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // 標的資訊摘要
                    headerCard

                    // 階段一：進場前 (Plan)
                    planCard

                    // K 線走勢圖
                    KLineChartView(vm: chartVM)

                    // 階段二：執行中 (Action)
                    actionCard

                    // 階段三：出場覆盤 (Review)
                    if investment.isClosed {
                        reviewCard
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("交易日誌")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(AppColor.primary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    TradeJournalEditView(investment: investment, existingJournal: journal)
                } label: {
                    Image(systemName: "pencil")
                }
            }
        }
        .task {
            await chartVM.loadCandles()
        }
    }

    // MARK: - 標的資訊

    private var headerCard: some View {
        VStack(spacing: 10) {
            HStack {
                Text(StockMapping.displayName(for: investment.ticker))
                    .font(.warmTitle())
                    .foregroundStyle(AppColor.textMain)
                Spacer()
                WarmStatusBadge(
                    text: investment.statusText,
                    color: investment.isClosed ? AppColor.textSecondary : AppColor.secondary
                )
            }

            AppColor.divider.frame(height: 1)

            HStack {
                WarmInfoBadge(
                    title: "市場",
                    value: "\(journal.marketEnum?.prefix ?? "") \(journal.market)"
                )
                Spacer()
                WarmInfoBadge(
                    title: "方向",
                    value: journal.direction,
                    valueColor: journal.directionEnum == .long ? AppColor.softUp : AppColor.softDown
                )
                Spacer()
                WarmInfoBadge(
                    title: "持有天數",
                    value: "\(investment.holdingDays) 日"
                )
            }
        }
        .cardStyle()
    }

    // MARK: - 進場前 (Plan)

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            phaseHeader(title: "進場前 (Plan)", icon: "1.circle.fill", color: AppColor.secondary)

            AppColor.divider.frame(height: 1)

            // 價格資訊
            HStack {
                WarmInfoBadge(title: "實際進場價", value: String(format: "$%.2f", investment.buyPrice))
                Spacer()
                if let planned = journal.plannedEntryPrice {
                    WarmInfoBadge(title: "預定進場價", value: String(format: "$%.2f", planned))
                    Spacer()
                }
                if let stopLoss = journal.initialStopLoss {
                    WarmInfoBadge(
                        title: "初始停損價 ★",
                        value: String(format: "$%.2f", stopLoss),
                        valueColor: AppColor.softDown
                    )
                }
            }

            // 滑價檢查
            if let planned = journal.plannedEntryPrice, planned > 0 {
                let diff = investment.buyPrice - planned
                let pct = diff / planned * 100
                if abs(pct) > 0.1 {
                    HStack(spacing: 4) {
                        Image(systemName: diff > 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.warmCaption2())
                        Text(String(format: "滑價 %+.2f (%.2f%%)", diff, pct))
                            .font(.warmCaption())
                    }
                    .foregroundStyle(abs(pct) > 1 ? AppColor.softDown : AppColor.textSecondary)
                    .padding(8)
                    .background(AppColor.background.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }

            // 進場理由
            if !journal.setup.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("進場理由 (Setup)")
                        .font(.warmCaption())
                        .foregroundStyle(AppColor.textSecondary)
                    Text(journal.setup)
                        .font(.warmBody())
                        .foregroundStyle(AppColor.textMain)
                }
            }

            // 買入理由（僅在沒有 journal setup 時顯示，避免重複）
            if !investment.buyReason.isEmpty && journal.setup.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("買入理由")
                        .font(.warmCaption())
                        .foregroundStyle(AppColor.textSecondary)
                    Text(investment.buyReason)
                        .font(.warmBody())
                        .foregroundStyle(AppColor.textMain)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - 執行中 (Action)

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            phaseHeader(title: "執行中 (Action)", icon: "2.circle.fill", color: AppColor.primary)

            AppColor.divider.frame(height: 1)

            HStack {
                WarmInfoBadge(
                    title: "實際進場價",
                    value: String(format: "$%.2f", investment.buyPrice)
                )
                Spacer()
                WarmInfoBadge(
                    title: "部位規模",
                    value: String(format: "%.0f 股", investment.originalQuantity)
                )
                Spacer()
                WarmInfoBadge(
                    title: "總曝險",
                    value: String(format: "$%.0f", investment.originalTotalCost)
                )
            }

            // 單筆風險金額
            if let stopLoss = journal.initialStopLoss {
                let riskPerShare = investment.buyPrice - stopLoss
                let totalRisk = riskPerShare * investment.originalQuantity
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.shield")
                        .font(.warmCaption2())
                        .foregroundStyle(AppColor.softDown)
                    Text(String(format: "單筆最大虧損 $%.0f（每股風險 $%.2f）", totalRisk, riskPerShare))
                        .font(.warmCaption())
                        .foregroundStyle(AppColor.textSecondary)
                }
            }

            // 情緒分數
            if let score = journal.emotionScore {
                HStack(spacing: 8) {
                    Text("當下情緒")
                        .font(.warmCaption())
                        .foregroundStyle(AppColor.textSecondary)
                    Spacer()
                    emotionBadge(score: score)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - 出場覆盤 (Review)

    private var reviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            phaseHeader(title: "出場覆盤 (Review)", icon: "3.circle.fill", color: AppColor.softUp)

            AppColor.divider.frame(height: 1)

            // 出場價格
            if let sellPrice = investment.sellPrice {
                HStack {
                    WarmInfoBadge(title: "出場價", value: String(format: "$%.2f", sellPrice))
                    Spacer()
                    let pl = investment.realizedProfitLoss()
                    VStack(spacing: 2) {
                        Text("損益")
                            .font(.warmCaption2())
                            .foregroundStyle(AppColor.textSecondary)
                        Text("\(pl >= 0 ? "+" : "")$\(pl, specifier: "%.0f")")
                            .font(.warmCaption())
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.profitLossColor(pl))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.profitLossColor(pl).opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Spacer()
                    let pct = investment.realizedReturnPercentage()
                    WarmInfoBadge(
                        title: "報酬率",
                        value: String(format: "%+.2f%%", pct),
                        valueColor: Color.profitLossColor(pct)
                    )
                }
            }

            // R-Multiple
            if let r = journal.rMultiple {
                rMultipleDisplay(r: r)
            }

            // 出場理由
            if !journal.exitReason.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("出場理由")
                        .font(.warmCaption())
                        .foregroundStyle(AppColor.textSecondary)
                    Text(journal.exitReason)
                        .font(.warmBody())
                        .foregroundStyle(AppColor.textMain)
                }
            }

            // 賣出理由（原始）
            if !investment.sellReason.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("賣出理由")
                        .font(.warmCaption())
                        .foregroundStyle(AppColor.textSecondary)
                    Text(investment.sellReason)
                        .font(.warmBody())
                        .foregroundStyle(AppColor.textMain)
                }
            }

            // 反思
            if !journal.reflection.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "lightbulb")
                            .font(.warmCaption2())
                            .foregroundStyle(AppColor.secondary)
                        Text("檢討與反思")
                            .font(.warmCaption())
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    Text(journal.reflection)
                        .font(.warmBody())
                        .foregroundStyle(AppColor.textMain)
                        .padding(10)
                        .background(AppColor.background.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .cardStyle()
    }

    // MARK: - 共用元件

    private func phaseHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(title)
                .font(.warmHeadline())
                .foregroundStyle(AppColor.textMain)
        }
    }

    private func emotionBadge(score: Int) -> some View {
        let labels = ["", "極度恐慌", "不安", "中立", "樂觀", "極度貪婪"]
        let colors: [Color] = [.clear, AppColor.softDown, AppColor.softDown.opacity(0.6),
                               AppColor.textSecondary, AppColor.softUp.opacity(0.6), AppColor.softUp]
        let label = score >= 1 && score <= 5 ? labels[score] : "—"
        let color = score >= 1 && score <= 5 ? colors[score] : AppColor.textSecondary

        return HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { i in
                Circle()
                    .fill(i <= score ? color : AppColor.divider)
                    .frame(width: 8, height: 8)
            }
            Text("\(score) \(label)")
                .font(.warmCaption())
                .foregroundStyle(color)
        }
    }

    private func rMultipleDisplay(r: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundStyle(Color.rMultipleColor(r))
                Text("R-Multiple（盈虧比）")
                    .font(.warmSubheadline())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
                Text(String(format: "%+.2fR", r))
                    .font(.warmTitle())
                    .foregroundStyle(Color.rMultipleColor(r))
            }

            // R 值解讀
            Text(rMultipleExplanation(r))
                .font(.warmCaption())
                .foregroundStyle(Color.rMultipleColor(r))

            if r < -1 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.warmCaption())
                    Text("⚠️ R < -1：凹單警示！未嚴格執行停損，這是破產的最大主因")
                        .font(.warmCaption())
                }
                .foregroundStyle(AppColor.softDown)
                .padding(8)
                .background(AppColor.softDown.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(12)
        .background(Color.rMultipleColor(r).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func rMultipleExplanation(_ r: Double) -> String {
        if r >= 2 {
            return "優秀交易：賺取了 \(String(format: "%.1f", r)) 倍風險報酬"
        } else if r >= 1 {
            return "正向交易：賺到了原預期風險金額以上"
        } else if r > 0 {
            return "微利出場：報酬未達原始風險金額"
        } else if r >= -1 {
            return "紀律停損：虧損在預期範圍內"
        } else {
            return "凹單虧損：虧損超過原始停損位"
        }
    }
}

#Preview {
    let investment = Investment(
        ticker: "2330",
        buyDate: Date(),
        buyPrice: 580.0,
        quantity: 1000,
        isClosed: true,
        sellPrice: 620.0,
        sellDate: Date(),
        sellQuantity: 1000,
        buyReason: "突破頸線，均線即將上揚"
    )
    let journal = TradeJournal(
        investmentID: investment.id,
        market: .tw,
        direction: .long,
        setup: "股價突破頸線，且短天期均線扣抵值向下，均線即將上揚形成支撐",
        plannedEntryPrice: 575.0,
        initialStopLoss: 550.0,
        emotionScore: 3,
        exitReason: "達到停利",
        reflection: "進場時機不錯，但可以更耐心等待回測確認",
        rMultiple: 1.33
    )
    return NavigationStack {
        TradeJournalDetailView(investment: investment, journal: journal)
    }
    .modelContainer(for: [Investment.self, TradeJournal.self], inMemory: true)
}
