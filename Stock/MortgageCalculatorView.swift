//
//  MortgageCalculatorView.swift
//  Stock
//
//  Created by bokmacdev on 2026/5/26.
//

import SwiftUI

/// 房貸試算工具
struct MortgageCalculatorView: View {
    @State private var vm = MortgageCalculatorViewModel()

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    inputCard
                    actionButtons

                    if vm.totalRepayment != nil {
                        resultCard
                    }

                    if !vm.amortizationSchedule.isEmpty {
                        amortizationCard
                    }
                }
                .padding(16)
            }
            .keyboardDismissable()
        }
        .navigationTitle("房貸試算")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(AppColor.primary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .alert("輸入錯誤", isPresented: $vm.showingAlert) {
            Button("確定", role: .cancel) {}
        } message: {
            Text(vm.alertMessage)
        }
    }

    // MARK: - 貸款資訊輸入

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "house.fill")
                    .foregroundStyle(AppColor.primary)
                Text("貸款資訊")
                    .font(.warmHeadline())
                    .foregroundStyle(AppColor.textMain)

                Spacer()

                HStack(spacing: 4) {
                    ForEach(RepaymentMethod.allCases) { method in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                vm.repaymentMethod = method
                            }
                        } label: {
                            Text(method.rawValue)
                                .font(.warmCaption2())
                                .fontWeight(.medium)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    vm.repaymentMethod == method
                                        ? AppColor.primary
                                        : AppColor.background
                                )
                                .foregroundStyle(
                                    vm.repaymentMethod == method
                                        ? .white
                                        : AppColor.textMain
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            AppColor.divider.frame(height: 1)

            HStack(spacing: 12) {
                inputField(
                    label: "房屋總價（萬元）",
                    icon: "dollarsign.circle",
                    iconColor: AppColor.secondary,
                    placeholder: "例如：1000",
                    text: $vm.loanAmountText
                )

                inputField(
                    label: "貸款成數",
                    icon: "slider.horizontal.3",
                    iconColor: AppColor.primary,
                    placeholder: "例如：8",
                    text: $vm.loanToValueText
                )
            }

            HStack(spacing: 12) {
                inputField(
                    label: "年利率（%）",
                    icon: "percent",
                    iconColor: AppColor.softUp,
                    placeholder: "例如：2.1",
                    text: $vm.annualRateText
                )

                inputField(
                    label: "貸款年限（年）",
                    icon: "clock",
                    iconColor: AppColor.primary,
                    placeholder: "例如：30",
                    text: $vm.loanTermYearsText
                )

                inputField(
                    label: "寬限期（年）",
                    icon: "hourglass",
                    iconColor: AppColor.softDown,
                    placeholder: "例如：3",
                    text: $vm.gracePeriodYearsText
                )
            }
        }
        .cardStyle()
    }

    private func inputField(
        label: String,
        icon: String,
        iconColor: Color,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.warmCaption2())
                    .foregroundStyle(iconColor)
                Text(label)
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
            }
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .font(.warmBody())
                .padding(10)
                .background(AppColor.background)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.field, style: .continuous))
        }
    }

    // MARK: - 操作按鈕

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation { vm.reset() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("重置")
                }
                .font(.warmSubheadline())
                .fontWeight(.medium)
                .foregroundStyle(AppColor.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppColor.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .smallShadow()
            }

            Button {
                hideKeyboard()
                withAnimation { vm.calculate() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "calculator")
                    Text("開始試算")
                }
                .font(.warmSubheadline())
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppColor.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .smallShadow()
            }
        }
    }

    // MARK: - 計算結果

    private var resultCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .foregroundStyle(AppColor.primary)
                Text("試算結果")
                    .font(.warmHeadline())
                    .foregroundStyle(AppColor.textMain)
                Spacer()
            }

            AppColor.divider.frame(height: 1)

            // 頭期款
            if let dp = vm.downPayment {
                resultRow(title: "頭期款", value: formatCurrency(dp), isHighlighted: false)
                AppColor.divider.frame(height: 0.5)
            }

            if vm.hasGracePeriod {
                // 有寬限期：並排顯示
                twoColumnResult
            } else {
                // 無寬限期：單欄顯示
                singleColumnResult
            }
        }
        .cardStyle()
    }

    // MARK: - 單欄結果（無寬限期）

    private var singleColumnResult: some View {
        VStack(spacing: 10) {
            if let monthly = vm.monthlyPayment {
                resultRow(title: "每月還款", value: formatCurrency(monthly), isHighlighted: true)
            }
            if let first = vm.firstMonthPayment {
                resultRow(title: "首月還款", value: formatCurrency(first), isHighlighted: true)
            }
            if let last = vm.lastMonthPayment {
                resultRow(title: "末月還款", value: formatCurrency(last), isHighlighted: false)
            }
            if let totalInt = vm.totalInterest {
                resultRow(title: "總利息", value: formatCurrency(totalInt), isHighlighted: false)
            }
            if let totalRep = vm.totalRepayment {
                resultRow(title: "總還款", value: formatCurrency(totalRep), isHighlighted: false)
            }
        }
    }

    // MARK: - 並排結果（有寬限期）

    private var twoColumnResult: some View {
        VStack(spacing: 12) {
            // 欄位標題
            HStack {
                Text("")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("無寬限期")
                    .font(.warmSubheadline())
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColor.primary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Text("有寬限期")
                    .font(.warmSubheadline())
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColor.softDown)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            AppColor.divider.frame(height: 0.5)

            // 寬限期每月繳息
            if let graceInterest = vm.graceMonthlyInterest {
                comparisonRow(title: "寬限期月繳", normalValue: "—", graceValue: formatCurrency(graceInterest))
            }

            // 本息均攤：每月還款
            if let monthly = vm.monthlyPayment, let graceMonthly = vm.graceMonthlyPayment {
                comparisonRow(title: "每月還款", normalValue: formatCurrency(monthly), graceValue: formatCurrency(graceMonthly))
            }

            // 本金均攤：首月 / 末月
            if let first = vm.firstMonthPayment, let graceFirst = vm.graceFirstMonthPayment {
                comparisonRow(title: "首月還款", normalValue: formatCurrency(first), graceValue: formatCurrency(graceFirst))
            }
            if let last = vm.lastMonthPayment, let graceLast = vm.graceLastMonthPayment {
                comparisonRow(title: "末月還款", normalValue: formatCurrency(last), graceValue: formatCurrency(graceLast))
            }

            AppColor.divider.frame(height: 0.5)

            // 總利息
            if let totalInt = vm.totalInterest, let graceTotalInt = vm.graceTotalInterest {
                comparisonRow(title: "總利息", normalValue: formatCurrency(totalInt), graceValue: formatCurrency(graceTotalInt))
            }

            // 總還款
            if let totalRep = vm.totalRepayment, let graceTotalRep = vm.graceTotalRepayment {
                comparisonRow(title: "總還款", normalValue: formatCurrency(totalRep), graceValue: formatCurrency(graceTotalRep))
            }

            // 利息差額
            if let totalInt = vm.totalInterest, let graceTotalInt = vm.graceTotalInterest {
                let diff = graceTotalInt - totalInt
                HStack {
                    Text("利息差額")
                        .font(.warmSubheadline())
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text("+\(formatCurrency(diff))")
                        .font(.warmSubheadline())
                        .fontWeight(.medium)
                        .foregroundStyle(AppColor.softUp)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }

    private func resultRow(title: String, value: String, isHighlighted: Bool) -> some View {
        HStack {
            Text(title)
                .font(.warmHeadline())
                .foregroundStyle(AppColor.textSecondary)
            Spacer()
            Text(value)
                .font(.warmLargeNumber())
                .fontWeight(isHighlighted ? .bold : .semibold)
                .foregroundStyle(isHighlighted ? AppColor.primary : AppColor.textMain)
        }
    }

    private func comparisonRow(title: String, normalValue: String, graceValue: String) -> some View {
        HStack {
            Text(title)
                .font(.warmSubheadline())
                .foregroundStyle(AppColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(normalValue)
                .font(.warmSubheadline())
                .fontWeight(.medium)
                .foregroundStyle(AppColor.textMain)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(graceValue)
                .font(.warmSubheadline())
                .fontWeight(.medium)
                .foregroundStyle(AppColor.softDown)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: - 攤還明細表

    private var amortizationCard: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    vm.showingSchedule.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "tablecells")
                        .foregroundStyle(AppColor.primary)
                    Text("攤還明細表")
                        .font(.warmHeadline())
                        .foregroundStyle(AppColor.textMain)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.warmCaption2())
                        .foregroundStyle(AppColor.textSecondary.opacity(0.5))
                        .rotationEffect(.degrees(vm.showingSchedule ? 90 : 0))
                }
            }
            .buttonStyle(.plain)

            if vm.showingSchedule {
                AppColor.divider.frame(height: 1)

                // 表頭
                HStack {
                    Text("期數").frame(width: 40, alignment: .leading)
                    Text("還款").frame(maxWidth: .infinity, alignment: .trailing)
                    Text("本金").frame(maxWidth: .infinity, alignment: .trailing)
                    Text("利息").frame(maxWidth: .infinity, alignment: .trailing)
                    Text("餘額").frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.warmCaption2())
                .foregroundStyle(AppColor.textSecondary)

                // 表格
                LazyVStack(spacing: 4) {
                    ForEach(vm.amortizationSchedule) { entry in
                        HStack {
                            Text("\(entry.month)")
                                .frame(width: 40, alignment: .leading)
                                .foregroundStyle(AppColor.textMain)
                            Text(formatCompact(entry.payment))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .foregroundStyle(AppColor.textMain)
                            Text(formatCompact(entry.principal))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .foregroundStyle(AppColor.secondary)
                            Text(formatCompact(entry.interest))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .foregroundStyle(AppColor.softUp)
                            Text(formatCompact(entry.remainingBalance))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .foregroundStyle(AppColor.textSecondary)
                        }
                        .font(.warmCaption2())
                        .padding(.vertical, 4)

                        if entry.month % 12 == 0 && entry.month < vm.amortizationSchedule.count {
                            AppColor.divider.frame(height: 0.5)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .cardStyle()
    }

    // MARK: - 格式化

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.groupingSeparator = ","
        return f
    }()

    private func formatCurrency(_ value: Double) -> String {
        let formatted = Self.currencyFormatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
        return "$\(formatted)"
    }

    private func formatCompact(_ value: Double) -> String {
        Self.currencyFormatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}

#Preview {
    NavigationStack {
        MortgageCalculatorView()
    }
}
