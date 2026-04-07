//
//  GroupSellView.swift
//  Stock
//
//  Created by bokmacdev on 2026/4/1.
//

import SwiftUI
import SwiftData

/// 整批賣出視圖：日誌風格，FIFO 自動分配
struct GroupSellView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let group: PortfolioGroup

    @State private var sellPriceText: String = ""
    @State private var sellQuantityText: String = ""
    @State private var sellReason: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @FocusState private var isReasonFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            // MARK: - 標的彙整資訊
                            infoCard

                            // MARK: - 賣出輸入
                            sellInputCard

                            // MARK: - 賣出理由
                            reasonCard
                                .id("reasonCard")

                            // MARK: - 預覽損益
                            profitPreviewCard

                            // MARK: - FIFO 說明
                            fifoNote
                        }
                        .padding(16)
                    }
                    .keyboardDismissable()
                    .onChange(of: isReasonFocused) { _, focused in
                        if focused {
                            withAnimation { proxy.scrollTo("reasonCard", anchor: .bottom) }
                        }
                    }
                }
            }
            .navigationTitle("賣出 \(group.ticker)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppColor.primary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("確認賣出") { executeSell() }
                        .fontWeight(.semibold)
                }
            }
            .alert("輸入錯誤", isPresented: $showingAlert) {
                Button("確定", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    // MARK: - 標的彙整卡片

    private var infoCard: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundStyle(AppColor.primary)
                Text("標的資訊")
                    .font(.warmHeadline())
                    .foregroundStyle(AppColor.textMain)
                Spacer()
                Text(group.ticker)
                    .font(.warmTitle())
                    .foregroundStyle(AppColor.primary)
            }

            AppColor.divider.frame(height: 1)

            HStack {
                WarmInfoBadge(title: "總持有", value: String(format: "%.0f 股", group.totalQuantity))
                Spacer()
                WarmInfoBadge(title: "均價", value: String(format: "$%.2f", group.weightedAverageCost))
                Spacer()
                WarmInfoBadge(title: "總投入", value: String(format: "$%.0f", group.totalInvested))
            }

            HStack {
                Spacer()
                Text("\(group.investments.count) 筆買入紀錄")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .cardStyle()
    }

    // MARK: - 賣出輸入卡片

    private var sellInputCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(AppColor.softUp)
                Text("賣出資訊")
                    .font(.warmHeadline())
                    .foregroundStyle(AppColor.textMain)
            }

            AppColor.divider.frame(height: 1)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle")
                            .font(.warmCaption2())
                            .foregroundStyle(AppColor.secondary)
                        Text("賣出價格")
                            .font(.warmCaption())
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    TextField("0.00", text: $sellPriceText)
                        .keyboardType(.decimalPad)
                        .font(.warmBody())
                        .padding(10)
                        .background(AppColor.background)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "number.circle")
                            .font(.warmCaption2())
                            .foregroundStyle(AppColor.softUp)
                        Text("賣出數量（股）")
                            .font(.warmCaption())
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    TextField("0", text: $sellQuantityText)
                        .keyboardType(.decimalPad)
                        .font(.warmBody())
                        .padding(10)
                        .background(AppColor.background)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            Button {
                sellQuantityText = "\(Int(group.totalQuantity))"
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle")
                    Text("全部賣出")
                }
                .font(.warmCaption())
                .fontWeight(.medium)
                .foregroundStyle(AppColor.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(AppColor.primary.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .cardStyle()
    }

    // MARK: - 賣出理由

    private var reasonCard: some View {
        NotebookTextField(
            placeholder: "記錄你的賣出原因...",
            text: $sellReason,
            lineLimit: 4,
            icon: "text.quote",
            iconColor: AppColor.softUp,
            isFocused: $isReasonFocused
        )
        .cardStyle()
    }

    // MARK: - 預覽損益

    @ViewBuilder
    private var profitPreviewCard: some View {
        if let sellPrice = Double(sellPriceText),
           let sellQty = Double(sellQuantityText),
           sellPrice > 0, sellQty > 0 {
            let avgCost = group.weightedAverageCost
            let profitLoss = (sellPrice - avgCost) * sellQty
            let returnPct = avgCost > 0
                ? (sellPrice - avgCost) / avgCost * 100
                : 0

            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundStyle(AppColor.primary)
                    Text("預估損益")
                        .font(.warmHeadline())
                        .foregroundStyle(AppColor.textMain)
                    Spacer()
                }

                AppColor.divider.frame(height: 1)

                HStack {
                    Text("賣出總額")
                        .font(.warmCaption())
                        .foregroundStyle(AppColor.textSecondary)
                    Spacer()
                    Text(String(format: "$%.2f", sellPrice * sellQty))
                        .font(.warmSubheadline())
                        .foregroundStyle(AppColor.textMain)
                }
                HStack {
                    Text("成本總額（均價）")
                        .font(.warmCaption())
                        .foregroundStyle(AppColor.textSecondary)
                    Spacer()
                    Text(String(format: "$%.2f", avgCost * sellQty))
                        .font(.warmSubheadline())
                        .foregroundStyle(AppColor.textMain)
                }

                AppColor.divider.frame(height: 1)

                HStack {
                    Text("預估損益")
                        .font(.warmSubheadline())
                        .foregroundStyle(AppColor.textSecondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(profitLoss >= 0 ? "+" : "")$\(profitLoss, specifier: "%.2f")")
                            .font(.warmHeadline())
                            .foregroundStyle(Color.profitLossColor(profitLoss))
                        Text("\(returnPct >= 0 ? "+" : "")\(returnPct, specifier: "%.2f")%")
                            .font(.warmCaption())
                            .foregroundStyle(Color.profitLossColor(returnPct))
                    }
                }
            }
            .cardStyle()
        }
    }

    // MARK: - FIFO 說明

    private var fifoNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(AppColor.primary.opacity(0.6))
            Text("系統將以先買先賣（FIFO）順序自動分配賣出數量至各筆買入紀錄")
                .font(.warmCaption2())
                .foregroundStyle(AppColor.textSecondary)
        }
        .padding(12)
        .background(AppColor.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - 執行賣出

    private func executeSell() {
        guard let sellPrice = Double(sellPriceText), sellPrice > 0 else {
            alertMessage = "請輸入有效的賣出價格"
            showingAlert = true
            return
        }

        guard let sellQuantity = Double(sellQuantityText), sellQuantity > 0 else {
            alertMessage = "請輸入有效的賣出數量"
            showingAlert = true
            return
        }

        guard sellQuantity <= group.totalQuantity else {
            alertMessage = "賣出數量（\(Int(sellQuantity))）不可大於總持有數量（\(Int(group.totalQuantity))）"
            showingAlert = true
            return
        }

        group.batchSell(
            quantity: sellQuantity,
            price: sellPrice,
            date: Date(),
            reason: sellReason.trimmingCharacters(in: .whitespacesAndNewlines),
            context: modelContext
        )

        dismiss()
    }
}

#Preview {
    let inv1 = Investment(ticker: "2330", buyDate: Date(), buyPrice: 550, quantity: 500)
    let inv2 = Investment(ticker: "2330", buyDate: Date(), buyPrice: 600, quantity: 300)
    let group = PortfolioGroup(id: "2330", ticker: "2330", investments: [inv1, inv2])
    return GroupSellView(group: group)
        .modelContainer(for: Investment.self, inMemory: true)
}
