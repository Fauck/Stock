//
//  TradeJournal.swift
//  Stock
//
//  交易日誌資料模型
//  分為「進場前 (Plan)」、「執行中 (Action)」、「出場覆盤 (Review)」三階段
//

import Foundation
import SwiftData

/// 交易方向
enum TradeDirection: String, CaseIterable, Identifiable, Codable {
    case long = "做多"
    case short = "做空"

    var id: String { rawValue }
}

/// 市場標註
enum TradeMarket: String, CaseIterable, Identifiable, Codable {
    case tw = "台股"
    case us = "美股"

    var id: String { rawValue }

    /// 代號前綴
    var prefix: String {
        switch self {
        case .tw: return "TW"
        case .us: return "US"
        }
    }
}

/// 出場理由預設選項
enum ExitReasonOption: String, CaseIterable, Identifiable {
    case stopLoss = "觸發停損"
    case takeProfit = "達到停利"
    case panicSell = "恐慌平倉"
    case custom = "自訂"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .stopLoss:  return "shield.slash"
        case .takeProfit: return "target"
        case .panicSell: return "exclamationmark.triangle"
        case .custom:    return "pencil"
        }
    }
}

/// 交易日誌資料模型
/// 透過 investmentID 關聯 Investment，記錄完整的三階段交易日誌
@Model
final class TradeJournal {
    /// 唯一識別碼
    var id: UUID
    /// 關聯的 Investment ID
    var investmentID: UUID

    // MARK: - 進場前 (Plan)

    /// 市場標註（"台股" / "美股"）
    var market: String
    /// 交易方向（"做多" / "做空"）
    var direction: String
    /// 進場理由 (Setup)：技術面或基本面觸發條件
    var setup: String
    /// 預定進場價
    var plannedEntryPrice: Double?
    /// 初始停損價（最重要的一欄）
    var initialStopLoss: Double?
    /// 目標價（預期出場價位）
    var targetPrice: Double?

    // MARK: - 執行中 (Action)

    /// 當下情緒分數：1 (極度恐慌) ~ 5 (極度貪婪)
    var emotionScore: Int?

    // MARK: - 出場覆盤 (Review)

    /// 出場理由
    var exitReason: String
    /// 檢討與反思：「如果重來一次，我會怎麼做？」
    var reflection: String
    /// R-Multiple 盈虧比（出場時計算並儲存）
    var rMultiple: Double?

    init(
        id: UUID = UUID(),
        investmentID: UUID,
        market: TradeMarket = .tw,
        direction: TradeDirection = .long,
        setup: String = "",
        plannedEntryPrice: Double? = nil,
        initialStopLoss: Double? = nil,
        targetPrice: Double? = nil,
        emotionScore: Int? = nil,
        exitReason: String = "",
        reflection: String = "",
        rMultiple: Double? = nil
    ) {
        self.id = id
        self.investmentID = investmentID
        self.market = market.rawValue
        self.direction = direction.rawValue
        self.setup = setup
        self.plannedEntryPrice = plannedEntryPrice
        self.initialStopLoss = initialStopLoss
        self.targetPrice = targetPrice
        self.emotionScore = emotionScore
        self.exitReason = exitReason
        self.reflection = reflection
        self.rMultiple = rMultiple
    }

    // MARK: - Enum 便利存取

    var marketEnum: TradeMarket? {
        get { TradeMarket(rawValue: market) }
        set { market = newValue?.rawValue ?? TradeMarket.tw.rawValue }
    }

    var directionEnum: TradeDirection? {
        get { TradeDirection(rawValue: direction) }
        set { direction = newValue?.rawValue ?? TradeDirection.long.rawValue }
    }

    // MARK: - R-Multiple 計算

    /// 計算 R-Multiple
    /// R = (實際出場價 - 實際進場價) / (實際進場價 - 初始停損價)
    static func calculateRMultiple(
        entryPrice: Double,
        exitPrice: Double,
        stopLoss: Double
    ) -> Double? {
        let risk = entryPrice - stopLoss
        guard risk != 0 else { return nil }
        return (exitPrice - entryPrice) / risk
    }

    /// R-Multiple 的顯示文字
    var rMultipleText: String {
        guard let r = rMultiple else { return "—" }
        return String(format: "%+.2fR", r)
    }

    /// 是否有完成進場前計畫（至少填了停損價）
    var hasPlan: Bool {
        initialStopLoss != nil
    }

    /// 是否有完成覆盤（有出場理由或反思）
    var hasReview: Bool {
        !exitReason.isEmpty || !reflection.isEmpty
    }

    // MARK: - CSV 匯出

    static let csvHeader = "市場,交易方向,進場理由,預定進場價,初始停損價,目標價,情緒分數,出場理由,反思,R-Multiple"

    var csvRow: String {
        func escape(_ s: String) -> String {
            let cleaned = s.replacingOccurrences(of: "\n", with: " ")
            return cleaned.contains(",") || cleaned.contains("\"")
                ? "\"\(cleaned.replacingOccurrences(of: "\"", with: "\"\""))\""
                : cleaned
        }

        return [
            market,
            direction,
            escape(setup),
            plannedEntryPrice.map { String(format: "%.2f", $0) } ?? "",
            initialStopLoss.map { String(format: "%.2f", $0) } ?? "",
            targetPrice.map { String(format: "%.2f", $0) } ?? "",
            emotionScore.map { String($0) } ?? "",
            escape(exitReason),
            escape(reflection),
            rMultiple.map { String(format: "%.2f", $0) } ?? ""
        ].joined(separator: ",")
    }

    // MARK: - JSON 備份

    var toCodable: CodableTradeJournal {
        CodableTradeJournal(
            id: id,
            investmentID: investmentID,
            market: market,
            direction: direction,
            setup: setup,
            plannedEntryPrice: plannedEntryPrice,
            initialStopLoss: initialStopLoss,
            targetPrice: targetPrice,
            emotionScore: emotionScore,
            exitReason: exitReason,
            reflection: reflection,
            rMultiple: rMultiple
        )
    }

    static func fromCodable(_ c: CodableTradeJournal) -> TradeJournal {
        let journal = TradeJournal(
            id: c.id,
            investmentID: c.investmentID,
            market: TradeMarket(rawValue: c.market) ?? .tw,
            direction: TradeDirection(rawValue: c.direction) ?? .long,
            setup: c.setup,
            plannedEntryPrice: c.plannedEntryPrice,
            initialStopLoss: c.initialStopLoss,
            targetPrice: c.targetPrice,
            emotionScore: c.emotionScore,
            exitReason: c.exitReason,
            reflection: c.reflection,
            rMultiple: c.rMultiple
        )
        return journal
    }
}

// MARK: - JSON 備份傳輸結構

struct CodableTradeJournal: Codable, Sendable {
    let id: UUID
    let investmentID: UUID
    let market: String
    let direction: String
    let setup: String
    let plannedEntryPrice: Double?
    let initialStopLoss: Double?
    let targetPrice: Double?
    let emotionScore: Int?
    let exitReason: String
    let reflection: String
    let rMultiple: Double?
}
