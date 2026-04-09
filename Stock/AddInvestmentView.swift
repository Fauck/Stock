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
    @FocusState private var isReasonFocused: Bool

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

                            // MARK: - 買入理由
                            reasonCard
                                .id("reasonCard")

                            // MARK: - 預覽成本
                            costPreviewCard
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
                TextField("例如：2330、0050", text: $vm.ticker)
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

    // MARK: - 買入理由卡片

    private var reasonCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            NotebookTextField(
                placeholder: "記錄你的買入原因...",
                text: $vm.buyReason,
                lineLimit: 4,
                icon: "pencil.line",
                iconColor: AppColor.primary,
                isFocused: $isReasonFocused
            )
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
        .modelContainer(for: Investment.self, inMemory: true)
}
