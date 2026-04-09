//
//  SellView.swift
//  Stock
//
//  Created by bokmacdev on 2026/4/1.
//

import SwiftUI
import SwiftData

/// 賣出視圖：日誌風格，讓使用者輸入賣出價格與數量
struct SellView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var vm: SellViewModel
    @FocusState private var isReasonFocused: Bool

    init(investment: Investment) {
        _vm = State(initialValue: SellViewModel(investment: investment))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            // MARK: - 標的資訊
                            infoCard

                            // MARK: - 賣出輸入
                            sellInputCard

                            // MARK: - 賣出理由
                            reasonCard
                                .id("reasonCard")

                            // MARK: - 預覽損益
                            profitPreviewCard
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
            .navigationTitle("賣出 \(vm.investment.ticker)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppColor.primary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("確認賣出") {
                        if vm.executeSell(context: modelContext) {
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
        }
    }

    // MARK: - 標的資訊卡片

    private var infoCard: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundStyle(AppColor.primary)
                Text("標的資訊")
                    .font(.warmHeadline())
                    .foregroundStyle(AppColor.textMain)
                Spacer()
            }

            AppColor.divider.frame(height: 1)

            HStack {
                WarmInfoBadge(title: "代號", value: vm.investment.ticker)
                Spacer()
                WarmInfoBadge(title: "買入價", value: String(format: "$%.2f", vm.investment.buyPrice))
                Spacer()
                WarmInfoBadge(title: "持有量", value: String(format: "%.0f 股", vm.investment.quantity))
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
                    TextField("0.00", text: $vm.sellPriceText)
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
                    TextField("0", text: $vm.sellQuantityText)
                        .keyboardType(.decimalPad)
                        .font(.warmBody())
                        .padding(10)
                        .background(AppColor.background)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            Button {
                vm.fillAllQuantity()
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

    // MARK: - 賣出理由卡片

    private var reasonCard: some View {
        NotebookTextField(
            placeholder: "記錄你的賣出原因...",
            text: $vm.sellReason,
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
        if let preview = vm.profitPreview {
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
                    Text(String(format: "$%.2f", preview.sellTotal))
                        .font(.warmSubheadline())
                        .foregroundStyle(AppColor.textMain)
                }
                HStack {
                    Text("成本總額")
                        .font(.warmCaption())
                        .foregroundStyle(AppColor.textSecondary)
                    Spacer()
                    Text(String(format: "$%.2f", preview.costTotal))
                        .font(.warmSubheadline())
                        .foregroundStyle(AppColor.textMain)
                }

                AppColor.divider.frame(height: 1)

                HStack {
                    Text("已實現損益")
                        .font(.warmSubheadline())
                        .foregroundStyle(AppColor.textSecondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(preview.profitLoss >= 0 ? "+" : "")$\(preview.profitLoss, specifier: "%.2f")")
                            .font(.warmHeadline())
                            .foregroundStyle(Color.profitLossColor(preview.profitLoss))
                        Text("\(preview.returnPct >= 0 ? "+" : "")\(preview.returnPct, specifier: "%.2f")%")
                            .font(.warmCaption())
                            .foregroundStyle(Color.profitLossColor(preview.returnPct))
                    }
                }
            }
            .cardStyle()
        }
    }
}

#Preview {
    let investment = Investment(
        ticker: "2330",
        buyDate: Date(),
        buyPrice: 580.0,
        quantity: 1000
    )
    return SellView(investment: investment)
        .modelContainer(for: Investment.self, inMemory: true)
}
