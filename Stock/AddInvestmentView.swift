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

    let selectedDate: Date

    @State private var ticker: String = ""
    @State private var buyPriceText: String = ""
    @State private var quantityText: String = ""
    @State private var buyReason: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // MARK: - 買入日期
                        dateCard

                        // MARK: - 標的 & 交易細節
                        tradeInfoCard

                        // MARK: - 買入理由
                        reasonCard

                        // MARK: - 預覽成本
                        costPreviewCard
                    }
                    .padding(16)
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
                    Button("儲存") { saveInvestment() }
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

    // MARK: - 日期卡片

    private var dateCard: some View {
        HStack {
            Image(systemName: "calendar.circle.fill")
                .font(.title2)
                .foregroundStyle(AppColor.primary)
            Text(formattedDate)
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
                TextField("例如：2330、0050", text: $ticker)
                    .textInputAutocapitalization(.characters)
                    .font(.warmBody())
                    .padding(10)
                    .background(AppColor.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                    }
                    TextField("0.00", text: $buyPriceText)
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
                    TextField("0", text: $quantityText)
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

    // MARK: - 買入理由卡片

    private var reasonCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            NotebookTextField(
                placeholder: "記錄你的買入原因...",
                text: $buyReason,
                lineLimit: 4,
                icon: "pencil.line",
                iconColor: AppColor.primary
            )
        }
        .cardStyle()
    }

    // MARK: - 預覽成本

    @ViewBuilder
    private var costPreviewCard: some View {
        if let price = Double(buyPriceText),
           let qty = Double(quantityText),
           price > 0, qty > 0 {
            HStack {
                Image(systemName: "calculator")
                    .foregroundStyle(AppColor.primary)
                Text("預估成本")
                    .font(.warmSubheadline())
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
                Text(String(format: "$%.2f", price * qty))
                    .font(.warmTitle())
                    .foregroundStyle(AppColor.primary)
            }
            .cardStyle()
        }
    }

    // MARK: - 儲存

    private func saveInvestment() {
        let trimmedTicker = ticker.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTicker.isEmpty else {
            alertMessage = "請輸入標的名稱或代號"
            showingAlert = true
            return
        }

        guard let buyPrice = Double(buyPriceText), buyPrice > 0 else {
            alertMessage = "請輸入有效的買入價格"
            showingAlert = true
            return
        }

        guard let quantity = Double(quantityText), quantity > 0 else {
            alertMessage = "請輸入有效的買入數量"
            showingAlert = true
            return
        }

        let investment = Investment(
            ticker: trimmedTicker,
            buyDate: selectedDate,
            buyPrice: buyPrice,
            quantity: quantity,
            buyReason: buyReason.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        withAnimation {
            modelContext.insert(investment)
        }

        dismiss()
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateFormat = "yyyy 年 M 月 d 日（EEEE）"
        return formatter.string(from: selectedDate)
    }
}

#Preview {
    AddInvestmentView(selectedDate: Date())
        .modelContainer(for: Investment.self, inMemory: true)
}
