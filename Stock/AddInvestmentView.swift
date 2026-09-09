//
//  AddInvestmentView.swift
//  Stock
//
//  Created by bokmacdev on 2026/4/1.
//

import SwiftUI
import SwiftData

/// 新增買入紀錄的表單視圖，日誌風格
struct AddInvestmentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var vm: AddInvestmentViewModel


    init(selectedDate: Date) {
        _vm = State(initialValue: AddInvestmentViewModel(selectedDate: selectedDate))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            // MARK: - 買入日期
                            dateCard

                            // MARK: - 標的 & 交易細節
                            tradeInfoCard

                            // MARK: - 大盤狀態
                            marketConditionCard

                            // MARK: - 交易日誌（進場前 + 執行中）
                            journalCard
                                .id("journalCard")

                            // MARK: - 預覽成本
                            costPreviewCard
                        }
                        .padding(16)
                    }
                    .keyboardDismissable()
                }
            }
            .navigationTitle("新增買入紀錄")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppColor.primary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        if vm.save(context: modelContext) {
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("輸入錯誤", isPresented: $vm.showingAlert) {
                Button("確定", role: .cancel) {}
            } message: {
                Text(vm.alertMessage)
            }
            .onAppear {
                vm.autoDetectMarket()
            }
        }
    }

    // MARK: - 日期卡片

    private var dateCard: some View {
        HStack {
            Image(systemName: "calendar.circle.fill")
                .font(.title2)
                .foregroundStyle(AppColor.primary)
            Text(vm.formattedDate)
                .font(.warmHeadline())
                .foregroundStyle(AppColor.textMain)
            Spacer()
        }
        .cardStyle()
    }

    // MARK: - 交易資訊卡片

    private var tradeInfoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "building.columns.fill")
                    .foregroundStyle(AppColor.primary)
                Text("交易資訊")
                    .font(.warmHeadline())
                    .foregroundStyle(AppColor.textMain)
            }

            AppColor.divider.frame(height: 1)

            // 標的名稱
            VStack(alignment: .leading, spacing: 6) {
                Text("標的名稱 / 代號")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
                TextField("例如：2330、台積電", text: $vm.ticker)
                    .textInputAutocapitalization(.characters)
                    .font(.warmBody())
                    .padding(10)
                    .background(AppColor.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onChange(of: vm.ticker) { _, _ in
                        vm.onTickerChanged()
                    }

                // 解析結果顯示
                if let displayText = vm.tickerDisplayText {
                    HStack(spacing: 4) {
                        if vm.isFetchingPrice {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else if vm.fetchError != nil {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.warmCaption2())
                                .foregroundStyle(AppColor.softDown)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.warmCaption2())
                                .foregroundStyle(AppColor.secondary)
                        }
                        Text(displayText)
                            .font(.warmCaption())
                            .foregroundStyle(
                                vm.fetchError != nil
                                    ? AppColor.softDown
                                    : AppColor.secondary
                            )
                    }
                    .padding(.leading, 4)
                }
            }

            HStack(spacing: 12) {
                // 買入價格
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle")
                            .font(.warmCaption2())
                            .foregroundStyle(AppColor.secondary)
                        Text("買入價格")
                            .font(.warmCaption())
                            .foregroundStyle(AppColor.textSecondary)
                        // 即時價帶入按鈕
                        if let price = vm.fetchedPrice {
                            Button {
                                vm.applyFetchedPrice()
                            } label: {
                                Text("即時 $\(String(format: "%.2f", price))")
                                    .font(.warmCaption2())
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppColor.secondary.opacity(0.15))
                                    .foregroundStyle(AppColor.secondary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    TextField("0.00", text: $vm.buyPriceText)
                        .keyboardType(.decimalPad)
                        .font(.warmBody())
                        .padding(10)
                        .background(AppColor.background)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                // 買入數量
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "number.circle")
                            .font(.warmCaption2())
                            .foregroundStyle(AppColor.softUp)
                        Text("買入數量（股）")
                            .font(.warmCaption())
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    TextField("0", text: $vm.quantityText)
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

    // MARK: - 大盤狀態卡片

    private var marketConditionCard: some View {
        MarketConditionPicker(selection: $vm.buyMarketCondition)
            .cardStyle()
    }

    // MARK: - 交易日誌卡片

    private var journalCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 標題列（點擊展開/收合）
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    vm.journalExpanded.toggle()
                    if vm.journalExpanded {
                        vm.autoDetectMarket()
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "book.fill")
                        .foregroundStyle(AppColor.secondary)
                    Text("交易日誌")
                        .font(.warmHeadline())
                        .foregroundStyle(AppColor.textMain)
                    Spacer()
                    if vm.hasJournalContent {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.warmCaption())
                            .foregroundStyle(AppColor.secondary)
                    }
                    Image(systemName: vm.journalExpanded ? "chevron.up" : "chevron.down")
                        .font(.warmCaption())
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
            .buttonStyle(.plain)

            if vm.journalExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    AppColor.divider.frame(height: 1)
                        .padding(.top, 12)

                    // 市場 & 方向
                    HStack(spacing: 12) {
                        // 市場標註
                        VStack(alignment: .leading, spacing: 6) {
                            Text("市場")
                                .font(.warmCaption())
                                .foregroundStyle(AppColor.textSecondary)
                            HStack(spacing: 6) {
                                ForEach(TradeMarket.allCases) { market in
                                    Button {
                                        vm.tradeMarket = market
                                    } label: {
                                        Text(market.rawValue)
                                            .font(.warmCaption2())
                                            .fontWeight(.medium)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                vm.tradeMarket == market
                                                    ? AppColor.secondary
                                                    : AppColor.background
                                            )
                                            .foregroundStyle(
                                                vm.tradeMarket == market
                                                    ? .white
                                                    : AppColor.textMain
                                            )
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Spacer()

                        // 交易方向
                        VStack(alignment: .leading, spacing: 6) {
                            Text("方向")
                                .font(.warmCaption())
                                .foregroundStyle(AppColor.textSecondary)
                            HStack(spacing: 6) {
                                ForEach(TradeDirection.allCases) { dir in
                                    Button {
                                        vm.tradeDirection = dir
                                    } label: {
                                        Text(dir.rawValue)
                                            .font(.warmCaption2())
                                            .fontWeight(.medium)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                vm.tradeDirection == dir
                                                    ? (dir == .long ? AppColor.softUp : AppColor.softDown)
                                                    : AppColor.background
                                            )
                                            .foregroundStyle(
                                                vm.tradeDirection == dir
                                                    ? .white
                                                    : AppColor.textMain
                                            )
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // 進場理由 (Setup)
                    NotebookTextField(
                        placeholder: "進場理由（技術面/基本面觸發條件）...",
                        text: $vm.journalSetup,
                        lineLimit: 3,
                        icon: "lightbulb",
                        iconColor: AppColor.secondary
                    )

                    // 預定進場價
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right.circle")
                                .font(.warmCaption2())
                                .foregroundStyle(AppColor.secondary)
                            Text("預定進場價")
                                .font(.warmCaption())
                                .foregroundStyle(AppColor.textSecondary)
                        }
                        TextField("0.00", text: $vm.plannedEntryPriceText)
                            .keyboardType(.decimalPad)
                            .font(.warmBody())
                            .padding(10)
                            .background(AppColor.background)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    // 目標價 & 初始停損價
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 4) {
                                Image(systemName: "target")
                                    .font(.warmCaption2())
                                    .foregroundStyle(AppColor.softUp)
                                Text("目標價")
                                    .font(.warmCaption())
                                    .foregroundStyle(AppColor.textSecondary)
                            }
                            TextField("0.00", text: $vm.targetPriceText)
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
                            TextField("0.00", text: $vm.initialStopLossText)
                                .keyboardType(.decimalPad)
                                .font(.warmBody())
                                .padding(10)
                                .background(AppColor.background)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }

                    // 情緒分數
                    EmotionScorePicker(selection: $vm.emotionScore)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - 預覽成本

    @ViewBuilder
    private var costPreviewCard: some View {
        if let cost = vm.costPreview {
            HStack {
                Image(systemName: "calculator")
                    .foregroundStyle(AppColor.primary)
                Text("預估成本")
                    .font(.warmSubheadline())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
                Text(String(format: "$%.2f", cost))
                    .font(.warmTitle())
                    .foregroundStyle(AppColor.primary)
            }
            .cardStyle()
        }
    }
}

#Preview {
    AddInvestmentView(selectedDate: Date())
        .modelContainer(for: [Investment.self, TradeJournal.self], inMemory: true)
}
