//
//  MortgageCalculatorViewModel.swift
//  Stock
//
//  Created by bokmacdev on 2026/5/26.
//

import Foundation

/// 還款方式
enum RepaymentMethod: String, CaseIterable, Identifiable {
    case annuity = "本息均攤"
    case equalPrincipal = "本金均攤"
    var id: String { rawValue }
}

/// 每月攤還明細
struct AmortizationEntry: Identifiable {
    let id = UUID()
    let month: Int
    let payment: Double
    let principal: Double
    let interest: Double
    let remainingBalance: Double
}

@Observable
final class MortgageCalculatorViewModel {
    // MARK: - 表單輸入（String 供 TextField 綁定）

    /// 貸款金額（萬元）
    var loanAmountText: String = ""
    /// 貸款成數（例如：8 代表 80%）
    var loanToValueText: String = "8"
    var annualRateText: String = "2"
    var loanTermYearsText: String = "30"
    /// 寬限期（年）
    var gracePeriodYearsText: String = "5"
    var repaymentMethod: RepaymentMethod = .annuity

    // MARK: - 一般計算結果

    /// 每月還款（本息均攤時固定）
    var monthlyPayment: Double?
    /// 首月還款（本金均攤）
    var firstMonthPayment: Double?
    /// 末月還款（本金均攤）
    var lastMonthPayment: Double?
    /// 總利息
    var totalInterest: Double?
    /// 總還款金額
    var totalRepayment: Double?
    /// 攤還明細表
    var amortizationSchedule: [AmortizationEntry] = []
    /// 是否展開攤還表
    var showingSchedule: Bool = false

    // MARK: - 寬限期計算結果

    /// 是否有寬限期
    var hasGracePeriod: Bool { gracePeriodYears != nil && gracePeriodYears! > 0 }
    /// 寬限期每月只繳利息
    var graceMonthlyInterest: Double?
    /// 寬限期結束後每月還款（本息均攤）
    var graceMonthlyPayment: Double?
    /// 寬限期結束後首月還款（本金均攤）
    var graceFirstMonthPayment: Double?
    /// 寬限期結束後末月還款（本金均攤）
    var graceLastMonthPayment: Double?
    /// 含寬限期總利息
    var graceTotalInterest: Double?
    /// 含寬限期總還款金額
    var graceTotalRepayment: Double?
    /// 含寬限期攤還明細表
    var graceAmortizationSchedule: [AmortizationEntry] = []
    /// 是否展開寬限期攤還表
    var showingGraceSchedule: Bool = false

    // MARK: - Alert

    var showingAlert: Bool = false
    var alertMessage: String = ""

    // MARK: - 輸入解析

    /// 貸款金額（萬元）→ 元
    private var loanAmountInYuan: Double? {
        guard let v = Double(loanAmountText), v > 0 else { return nil }
        return v * 10_000
    }

    /// 貸款成數（1~9），nil 表示未填（不套用）
    private var loanToValue: Double? {
        guard let v = Double(loanToValueText), v > 0, v <= 10 else { return nil }
        return v
    }

    /// 實際貸款金額：有填成數則 金額 × 成數 / 10，否則直接用貸款金額
    private var actualLoanAmount: Double? {
        guard let base = loanAmountInYuan else { return nil }
        if let ltv = loanToValue {
            return base * ltv / 10.0
        }
        return base
    }

    private var annualRate: Double? {
        guard let v = Double(annualRateText), v > 0 else { return nil }
        return v
    }

    private var loanTermYears: Int? {
        guard let v = Int(loanTermYearsText), v > 0 else { return nil }
        return v
    }

    private var gracePeriodYears: Int? {
        guard let v = Int(gracePeriodYearsText), v > 0 else { return nil }
        return v
    }

    var canCalculate: Bool {
        actualLoanAmount != nil && annualRate != nil && loanTermYears != nil
    }

    // MARK: - 操作

    func calculate() {
        guard let principal = actualLoanAmount else {
            alertMessage = "請輸入有效的貸款金額"
            showingAlert = true
            return
        }
        guard let rate = annualRate else {
            alertMessage = "請輸入有效的年利率"
            showingAlert = true
            return
        }
        guard let years = loanTermYears else {
            alertMessage = "請輸入有效的貸款年限"
            showingAlert = true
            return
        }

        let monthlyRate = rate / 100.0 / 12.0
        let totalMonths = years * 12

        // 一般計算（無寬限期）
        switch repaymentMethod {
        case .annuity:
            calculateAnnuity(principal: principal, monthlyRate: monthlyRate, totalMonths: totalMonths)
        case .equalPrincipal:
            calculateEqualPrincipal(principal: principal, monthlyRate: monthlyRate, totalMonths: totalMonths)
        }

        // 寬限期計算
        if let graceYears = gracePeriodYears, graceYears > 0, graceYears < years {
            let graceMonths = graceYears * 12
            let remainingMonths = totalMonths - graceMonths
            switch repaymentMethod {
            case .annuity:
                calculateGraceAnnuity(principal: principal, monthlyRate: monthlyRate, graceMonths: graceMonths, remainingMonths: remainingMonths)
            case .equalPrincipal:
                calculateGraceEqualPrincipal(principal: principal, monthlyRate: monthlyRate, graceMonths: graceMonths, remainingMonths: remainingMonths)
            }
        } else {
            clearGraceResults()
        }
    }

    func reset() {
        loanAmountText = ""
        loanToValueText = ""
        annualRateText = ""
        loanTermYearsText = ""
        gracePeriodYearsText = ""
        repaymentMethod = .annuity
        monthlyPayment = nil
        firstMonthPayment = nil
        lastMonthPayment = nil
        totalInterest = nil
        totalRepayment = nil
        amortizationSchedule = []
        showingSchedule = false
        clearGraceResults()
    }

    private func clearGraceResults() {
        graceMonthlyInterest = nil
        graceMonthlyPayment = nil
        graceFirstMonthPayment = nil
        graceLastMonthPayment = nil
        graceTotalInterest = nil
        graceTotalRepayment = nil
        graceAmortizationSchedule = []
        showingGraceSchedule = false
    }

    // MARK: - 本息均攤（等額本息）

    /// M = P × r × (1+r)^n / ((1+r)^n - 1)
    private func calculateAnnuity(principal: Double, monthlyRate: Double, totalMonths: Int) {
        let r = monthlyRate
        let n = Double(totalMonths)
        let power = pow(1 + r, n)
        let monthly = principal * r * power / (power - 1)

        monthlyPayment = monthly
        firstMonthPayment = nil
        lastMonthPayment = nil
        totalRepayment = monthly * n
        totalInterest = (totalRepayment ?? 0) - principal

        var schedule: [AmortizationEntry] = []
        var remaining = principal
        for month in 1...totalMonths {
            let interestPart = remaining * r
            let principalPart = monthly - interestPart
            remaining -= principalPart
            if remaining < 0 { remaining = 0 }
            schedule.append(AmortizationEntry(
                month: month,
                payment: monthly,
                principal: principalPart,
                interest: interestPart,
                remainingBalance: remaining
            ))
        }
        amortizationSchedule = schedule
    }

    // MARK: - 本金均攤（等額本金）

    /// 每月本金固定，利息逐月遞減
    private func calculateEqualPrincipal(principal: Double, monthlyRate: Double, totalMonths: Int) {
        let fixedPrincipal = principal / Double(totalMonths)
        var remaining = principal
        var totalInt = 0.0
        var schedule: [AmortizationEntry] = []

        for month in 1...totalMonths {
            let interestPart = remaining * monthlyRate
            let payment = fixedPrincipal + interestPart
            totalInt += interestPart
            remaining -= fixedPrincipal
            if remaining < 0 { remaining = 0 }
            schedule.append(AmortizationEntry(
                month: month,
                payment: payment,
                principal: fixedPrincipal,
                interest: interestPart,
                remainingBalance: remaining
            ))
        }

        monthlyPayment = nil
        firstMonthPayment = schedule.first?.payment
        lastMonthPayment = schedule.last?.payment
        totalInterest = totalInt
        totalRepayment = principal + totalInt
        amortizationSchedule = schedule
    }

    // MARK: - 寬限期本息均攤

    /// 寬限期間只繳利息，到期後以剩餘期數做本息均攤
    private func calculateGraceAnnuity(principal: Double, monthlyRate: Double, graceMonths: Int, remainingMonths: Int) {
        let interestOnly = principal * monthlyRate
        graceMonthlyInterest = interestOnly

        // 寬限期後本息均攤
        let r = monthlyRate
        let n = Double(remainingMonths)
        let power = pow(1 + r, n)
        let monthly = principal * r * power / (power - 1)

        graceMonthlyPayment = monthly
        graceFirstMonthPayment = nil
        graceLastMonthPayment = nil

        let graceInterestTotal = interestOnly * Double(graceMonths)
        let repaymentTotal = monthly * n
        graceTotalInterest = graceInterestTotal + (repaymentTotal - principal)
        graceTotalRepayment = graceInterestTotal + repaymentTotal

        // 建立攤還表
        var schedule: [AmortizationEntry] = []
        // 寬限期
        for month in 1...graceMonths {
            schedule.append(AmortizationEntry(
                month: month,
                payment: interestOnly,
                principal: 0,
                interest: interestOnly,
                remainingBalance: principal
            ))
        }
        // 正常還款期
        var remaining = principal
        for i in 1...remainingMonths {
            let interestPart = remaining * r
            let principalPart = monthly - interestPart
            remaining -= principalPart
            if remaining < 0 { remaining = 0 }
            schedule.append(AmortizationEntry(
                month: graceMonths + i,
                payment: monthly,
                principal: principalPart,
                interest: interestPart,
                remainingBalance: remaining
            ))
        }
        graceAmortizationSchedule = schedule
    }

    // MARK: - 寬限期本金均攤

    /// 寬限期間只繳利息，到期後以剩餘期數做本金均攤
    private func calculateGraceEqualPrincipal(principal: Double, monthlyRate: Double, graceMonths: Int, remainingMonths: Int) {
        let interestOnly = principal * monthlyRate
        graceMonthlyInterest = interestOnly

        let fixedPrincipal = principal / Double(remainingMonths)
        var remaining = principal
        var totalInt = interestOnly * Double(graceMonths)
        var schedule: [AmortizationEntry] = []

        // 寬限期
        for month in 1...graceMonths {
            schedule.append(AmortizationEntry(
                month: month,
                payment: interestOnly,
                principal: 0,
                interest: interestOnly,
                remainingBalance: principal
            ))
        }

        // 正常還款期
        var repaymentEntries: [AmortizationEntry] = []
        for i in 1...remainingMonths {
            let interestPart = remaining * monthlyRate
            let payment = fixedPrincipal + interestPart
            totalInt += interestPart
            remaining -= fixedPrincipal
            if remaining < 0 { remaining = 0 }
            let entry = AmortizationEntry(
                month: graceMonths + i,
                payment: payment,
                principal: fixedPrincipal,
                interest: interestPart,
                remainingBalance: remaining
            )
            repaymentEntries.append(entry)
            schedule.append(entry)
        }

        graceMonthlyPayment = nil
        graceFirstMonthPayment = repaymentEntries.first?.payment
        graceLastMonthPayment = repaymentEntries.last?.payment
        graceTotalInterest = totalInt
        graceTotalRepayment = principal + totalInt
        graceAmortizationSchedule = schedule
    }
}
