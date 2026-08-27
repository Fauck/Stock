//
//  TradeJournalEditView.swift
//  Stock
//
//  交易日誌編輯頁：新增或編輯三階段日誌
//

import SwiftUI
import SwiftData

/// 交易日誌編輯頁面
/// 支援「新增」與「編輯」兩種模式
struct TradeJournalEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let investment: Investment
    /// 傳入 nil 表示新增模式，傳入現有 journal 表示編輯模式
    let existingJournal: TradeJournal?

    // MARK: - 進場前 (Plan)
    @State private var tradeMarket: TradeMarket = .tw
    @State private var tradeDirection: TradeDirection = .long
    @State private var setup: String = ""
    @State private var plannedEntryPriceText: String = ""
    @State private var initialStopLossText: String = ""

    // MARK: - 執行中 (Action)
    @State private var emotionScore: Int? = nil

    // MARK: - 出場覆盤 (Review)
    @State private var exitReasonOption: ExitReasonOption = .stopLoss
    @State private var customExitReason: String = ""
    @State private var reflection: String = ""

    @State private var showingSaveAlert = false
    @State private var alertMessage = ""

    private var isEditMode: Bool { existingJournal != nil }

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    headerCard
                    planCard
                    actionCard

                    if investment.isClosed {
                        reviewCard
                    }

                    saveButton
                }
                .padding(16)
            }
            .keyboardDismissable()
        }
        .navigationTitle(isEditMode ? "編輯日誌" : "新增日誌")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(AppColor.primary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear { loadExisting() }
        .alert("提示", isPresented: $showingSaveAlert) {
            Button("確定") {}
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - 載入既有資料

    private func loadExisting() {
        guard let j = existingJournal else {
            // 新增模式：自動偵測市場
            autoDetectMarket()
            return
        }
        tradeMarket = j.marketEnum ?? .tw
        tradeDirection = j.directionEnum ?? .long
        setup = j.setup
        if let p = j.plannedEntryPrice { plannedEntryPriceText = String(format: "%.2f", p) }
        if let s = j.initialStopLoss { initialStopLossText = String(format: "%.2f", s) }
        emotionScore = j.emotionScore
        // 載入覆盤資料
        if !j.exitReason.isEmpty {
            if let match = ExitReasonOption.allCases.first(where: { $0.rawValue == j.exitReason && $0 != .custom }) {
                exitReasonOption = match
            } else {
                exitReasonOption = .custom
                customExitReason = j.exitReason
            }
        }
        reflection = j.reflection
    }

    private func autoDetectMarket() {
        let ticker = investment.ticker
        let hasLetters = ticker.rangeOfCharacter(from: .letters) != nil
        let isAllDigits = ticker.allSatisfy { $0.isNumber }
        tradeMarket = (hasLetters && !isAllDigits) ? .us : .tw
    }

    // MARK: - 標的資訊

    private var headerCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(StockMapping.displayName(for: investment.ticker))
                    .font(.warmTitle())
                    .foregroundStyle(AppColor.textMain)
                Text("買入日期：\(AppDateFormatter.slashDateWithWeekday.string(from: investment.buyDate))")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
            }
            Spacer()
            WarmStatusBadge(
                text: investment.statusText,
                color: investment.isClosed ? AppColor.textSecondary : AppColor.secondary
            )
        }
        .cardStyle()
    }

    // MARK: - 進場前 (Plan)

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            phaseHeader(title: "進場前 (Plan)", icon: "1.circle.fill", color: AppColor.secondary)

            AppColor.divider.frame(height: 1)

            // 市場 & 方向
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("市場")
                        .font(.warmCaption())
                        .foregroundStyle(AppColor.textSecondary)
                    HStack(spacing: 6) {
                        ForEach(TradeMarket.allCases) { market in
                            Button {
                                tradeMarket = market
                            } label: {
                                Text(market.rawValue)
                                    .font(.warmCaption2())
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        tradeMarket == market
                                            ? AppColor.secondary
                                            : AppColor.background
                                    )
                                    .foregroundStyle(
                                        tradeMarket == market ? .white : AppColor.textMain
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .leading, spacing: 6) {
                    Text("方向")
                        .font(.warmCaption())
                        .foregroundStyle(AppColor.textSecondary)
                    HStack(spacing: 6) {
                        ForEach(TradeDirection.allCases) { dir in
                            Button {
                                tradeDirection = dir
                            } label: {
                                Text(dir.rawValue)
                                    .font(.warmCaption2())
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        tradeDirection == dir
                                            ? (dir == .long ? AppColor.softUp : AppColor.softDown)
                                            : AppColor.background
                                    )
                                    .foregroundStyle(
                                        tradeDirection == dir ? .white : AppColor.textMain
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // 進場理由
            NotebookTextField(
                placeholder: "進場理由（技術面/基本面觸發條件）...",
                text: $setup,
                lineLimit: 3,
                icon: "lightbulb",
                iconColor: AppColor.secondary
            )

            // 預定進場價 & 初始停損價
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle")
                            .font(.warmCaption2())
                            .foregroundStyle(AppColor.secondary)
                        Text("預定進場價")
                            .font(.warmCaption())
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    TextField("0.00", text: $plannedEntryPriceText)
                        .keyboardType(.decimalPad)
                        .font(.warmBody())
                        .padding(10)
                        .background(AppColor.background)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "shield.slash")
                            .font(.warmCaption2())
                            .foregroundStyle(AppColor.softDown)
                        Text("初始停損價 ★")
                            .font(.warmCaption())
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    TextField("0.00", text: $initialStopLossText)
                        .keyboardType(.decimalPad)
                        .font(.warmBody())
                        .padding(10)
                        .background(AppColor.background)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .cardStyle()
    }

    // MARK: - 執行中 (Action)

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            phaseHeader(title: "執行中 (Action)", icon: "2.circle.fill", color: AppColor.primary)

            AppColor.divider.frame(height: 1)

            HStack {
                WarmInfoBadge(title: "實際進場價", value: String(format: "$%.2f", investment.buyPrice))
                Spacer()
                WarmInfoBadge(title: "部位規模", value: String(format: "%.0f 股", investment.originalQuantity))
                Spacer()
                WarmInfoBadge(title: "總曝險", value: String(format: "$%.0f", investment.originalTotalCost))
            }

            EmotionScorePicker(selection: $emotionScore)
        }
        .cardStyle()
    }

    // MARK: - 出場覆盤 (Review)

    private var reviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            phaseHeader(title: "出場覆盤 (Review)", icon: "3.circle.fill", color: AppColor.softUp)

            AppColor.divider.frame(height: 1)

            // 出場理由膠囊
            VStack(alignment: .leading, spacing: 6) {
                Text("出場理由")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
                HStack(spacing: 6) {
                    ForEach(ExitReasonOption.allCases) { option in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                exitReasonOption = option
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: option.icon)
                                    .font(.warmCaption2())
                                Text(option.rawValue)
                                    .font(.warmCaption2())
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                exitReasonOption == option
                                    ? exitReasonColor(option)
                                    : AppColor.background
                            )
                            .foregroundStyle(
                                exitReasonOption == option ? .white : AppColor.textMain
                            )
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 自訂理由
            if exitReasonOption == .custom {
                NotebookTextField(
                    placeholder: "出場理由...",
                    text: $customExitReason,
                    lineLimit: 2,
                    icon: "pencil",
                    iconColor: AppColor.primary
                )
            }

            // R-Multiple 預覽
            if let r = rMultiplePreview {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.warmCaption())
                        .foregroundStyle(Color.rMultipleColor(r))
                    Text("R-Multiple 預覽")
                        .font(.warmCaption())
                        .foregroundStyle(AppColor.textSecondary)
                    Spacer()
                    Text(String(format: "%+.2fR", r))
                        .font(.warmHeadline())
                        .foregroundStyle(Color.rMultipleColor(r))
                }
                .padding(10)
                .background(Color.rMultipleColor(r).opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            // 反思筆記
            NotebookTextField(
                placeholder: "如果重來一次，我會怎麼做？",
                text: $reflection,
                lineLimit: 4,
                icon: "lightbulb",
                iconColor: AppColor.secondary
            )
        }
        .cardStyle()
    }

    // MARK: - 儲存按鈕

    private var saveButton: some View {
        Button {
            save()
        } label: {
            HStack {
                Image(systemName: isEditMode ? "checkmark.circle" : "plus.circle")
                Text(isEditMode ? "儲存修改" : "建立日誌")
            }
            .font(.warmHeadline())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppColor.primary)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - 儲存邏輯

    private func save() {
        let plannedEntry = Double(plannedEntryPriceText)
        let stopLoss = Double(initialStopLossText)

        let exitReason: String = {
            if !investment.isClosed { return "" }
            if exitReasonOption == .custom {
                return customExitReason
            }
            return exitReasonOption.rawValue
        }()

        // 計算 R-Multiple
        let rMultiple: Double? = {
            guard investment.isClosed, let sellPrice = investment.sellPrice, let sl = stopLoss else {
                return nil
            }
            return TradeJournal.calculateRMultiple(
                entryPrice: investment.buyPrice,
                exitPrice: sellPrice,
                stopLoss: sl
            )
        }()

        if let journal = existingJournal {
            // 編輯模式：更新現有 journal
            journal.marketEnum = tradeMarket
            journal.directionEnum = tradeDirection
            journal.setup = setup
            journal.plannedEntryPrice = plannedEntry
            journal.initialStopLoss = stopLoss
            journal.emotionScore = emotionScore
            if investment.isClosed {
                journal.exitReason = exitReason
                journal.reflection = reflection
                journal.rMultiple = rMultiple
            }
        } else {
            // 新增模式：建立新 journal
            let journal = TradeJournal(
                investmentID: investment.id,
                market: tradeMarket,
                direction: tradeDirection,
                setup: setup,
                plannedEntryPrice: plannedEntry,
                initialStopLoss: stopLoss,
                emotionScore: emotionScore,
                exitReason: exitReason,
                reflection: reflection,
                rMultiple: rMultiple
            )
            modelContext.insert(journal)
        }

        dismiss()
    }

    // MARK: - 計算

    private var rMultiplePreview: Double? {
        guard investment.isClosed,
              let sellPrice = investment.sellPrice,
              let stopLoss = Double(initialStopLossText),
              stopLoss > 0 else { return nil }
        return TradeJournal.calculateRMultiple(
            entryPrice: investment.buyPrice,
            exitPrice: sellPrice,
            stopLoss: stopLoss
        )
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

    private func exitReasonColor(_ option: ExitReasonOption) -> Color {
        switch option {
        case .stopLoss: return AppColor.softDown
        case .takeProfit: return AppColor.secondary
        case .panicSell: return AppColor.softUp
        case .custom: return AppColor.primary
        }
    }
}

#Preview("新增模式") {
    let investment = Investment(
        ticker: "2330",
        buyDate: Date(),
        buyPrice: 580.0,
        quantity: 1000,
        buyReason: "突破頸線"
    )
    return NavigationStack {
        TradeJournalEditView(investment: investment, existingJournal: nil)
    }
    .modelContainer(for: [Investment.self, TradeJournal.self], inMemory: true)
}
