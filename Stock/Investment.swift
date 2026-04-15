//
//  Investment.swift
//  Stock
//
//  Created by bokmacdev on 2026/4/1.
//

import Foundation
import SwiftData

/// 投資紀錄資料模型
/// 每一筆代表一次買入操作，包含標的、價格、數量等資訊
@Model
final class Investment {
    /// 唯一識別碼
    var id: UUID
    /// 標的名稱或代號（例如：2330、0050）
    var ticker: String
    /// 買入日期
    var buyDate: Date
    /// 買入價格（每股）
    var buyPrice: Double
    /// 原始買入數量（建立後不再變動，用於交易紀錄回溯）
    var originalQuantity: Double
    /// 目前持有數量（賣出時會扣減）
    var quantity: Double
    /// 是否已全部平倉（庫存歸零）
    var isClosed: Bool
    /// 賣出價格（平倉時記錄）
    var sellPrice: Double?
    /// 賣出日期（平倉時記錄）
    var sellDate: Date?
    /// 賣出數量（用於記錄最終賣出的股數）
    var sellQuantity: Double?
    /// 買入理由
    var buyReason: String
    /// 賣出理由
    var sellReason: String
    /// 是否為部分賣出時系統拆分產生的紀錄（非使用者手動建立）
    var isPartialSellRecord: Bool
    /// 買入時大盤狀態（V2 新增，舊資料預設 nil）
    var buyMarketCondition: String?
    /// 賣出時大盤狀態（V2 新增，舊資料預設 nil）
    var sellMarketCondition: String?

    init(
        id: UUID = UUID(),
        ticker: String,
        buyDate: Date,
        buyPrice: Double,
        quantity: Double,
        isClosed: Bool = false,
        sellPrice: Double? = nil,
        sellDate: Date? = nil,
        sellQuantity: Double? = nil,
        buyReason: String = "",
        sellReason: String = "",
        isPartialSellRecord: Bool = false,
        buyMarketCondition: MarketCondition? = nil,
        sellMarketCondition: MarketCondition? = nil
    ) {
        self.id = id
        self.ticker = ticker
        self.buyDate = buyDate
        self.buyPrice = buyPrice
        self.originalQuantity = quantity
        self.quantity = quantity
        self.isClosed = isClosed
        self.sellPrice = sellPrice
        self.sellDate = sellDate
        self.sellQuantity = sellQuantity
        self.buyReason = buyReason
        self.sellReason = sellReason
        self.isPartialSellRecord = isPartialSellRecord
        self.buyMarketCondition = buyMarketCondition?.rawValue
        self.sellMarketCondition = sellMarketCondition?.rawValue
    }

    // MARK: - 大盤狀態便利存取

    /// 買入時大盤狀態（enum）
    var buyMarketConditionEnum: MarketCondition? {
        get { buyMarketCondition.flatMap { MarketCondition(rawValue: $0) } }
        set { buyMarketCondition = newValue?.rawValue }
    }

    /// 賣出時大盤狀態（enum）
    var sellMarketConditionEnum: MarketCondition? {
        get { sellMarketCondition.flatMap { MarketCondition(rawValue: $0) } }
        set { sellMarketCondition = newValue?.rawValue }
    }

    // MARK: - 商業邏輯

    /// 計算未實現損益
    func unrealizedProfitLoss(currentPrice: Double) -> Double {
        return (currentPrice - buyPrice) * quantity
    }

    /// 計算投資成本（以目前持有數量計算）
    var totalCost: Double {
        return buyPrice * quantity
    }

    /// 原始買入總成本
    var originalTotalCost: Double {
        return buyPrice * originalQuantity
    }

    /// 計算報酬率（百分比）
    func returnPercentage(currentPrice: Double) -> Double {
        guard buyPrice > 0 else { return 0 }
        return (currentPrice - buyPrice) / buyPrice * 100
    }

    /// 已實現損益（僅適用於已平倉紀錄）
    var realizedProfitLoss: Double {
        guard let sp = sellPrice, let sq = sellQuantity else { return 0 }
        return (sp - buyPrice) * sq
    }

    /// 已實現報酬率（百分比）
    var realizedReturnPercentage: Double {
        guard let sp = sellPrice, buyPrice > 0 else { return 0 }
        return (sp - buyPrice) / buyPrice * 100
    }

    /// 目前狀態描述
    var statusText: String {
        if isClosed {
            return "已平倉"
        } else if quantity < originalQuantity {
            return "部分持有"
        } else {
            return "持有中"
        }
    }

    /// 刪除此筆紀錄，並清除相關的部分賣出拆分紀錄
    /// - 若為原始買入紀錄：同時刪除所有由此紀錄拆分出的 partialSellRecord
    /// - 若為部分賣出拆分紀錄：將賣出數量歸還給原始紀錄
    static func deleteInvestment(_ investment: Investment, context: ModelContext) {
        if investment.isPartialSellRecord {
            // 這是拆分紀錄，找到同標的、同買入日期、同買入價格的原始紀錄，歸還數量
            let ticker = investment.ticker
            let buyDate = investment.buyDate
            let buyPrice = investment.buyPrice
            let soldQty = investment.sellQuantity ?? investment.originalQuantity

            let descriptor = FetchDescriptor<Investment>(
                predicate: #Predicate<Investment> {
                    $0.ticker == ticker &&
                    $0.buyDate == buyDate &&
                    $0.buyPrice == buyPrice &&
                    !$0.isPartialSellRecord &&
                    !$0.isClosed
                }
            )
            if let originals = try? context.fetch(descriptor),
               let original = originals.first {
                original.quantity += soldQty
            }
            context.delete(investment)
        } else {
            // 這是原始買入紀錄，同時刪除所有由它拆分出的紀錄
            let ticker = investment.ticker
            let buyDate = investment.buyDate
            let buyPrice = investment.buyPrice

            let descriptor = FetchDescriptor<Investment>(
                predicate: #Predicate<Investment> {
                    $0.ticker == ticker &&
                    $0.buyDate == buyDate &&
                    $0.buyPrice == buyPrice &&
                    $0.isPartialSellRecord
                }
            )
            if let partials = try? context.fetch(descriptor) {
                for partial in partials {
                    context.delete(partial)
                }
            }
            context.delete(investment)
        }
    }

    // MARK: - CSV 匯出

    /// CSV 表頭
    static let csvHeader = "標的,買入日期,買入價格,原始數量,目前數量,狀態,賣出日期,賣出價格,賣出數量,已實現損益,買入理由,賣出理由,買入大盤,賣出大盤"

    /// 將單筆紀錄轉為 CSV 行
    var csvRow: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy/MM/dd"

        let status = statusText
        let buyDateStr = df.string(from: buyDate)
        let sellDateStr = sellDate.map { df.string(from: $0) } ?? ""
        let sellPriceStr = sellPrice.map { String(format: "%.2f", $0) } ?? ""
        let sellQtyStr = sellQuantity.map { String(format: "%.0f", $0) } ?? ""
        let plStr = isClosed ? String(format: "%.0f", realizedProfitLoss) : ""

        // 將理由中的逗號與換行替換，避免破壞 CSV 格式
        func escape(_ s: String) -> String {
            let cleaned = s.replacingOccurrences(of: "\n", with: " ")
            return cleaned.contains(",") || cleaned.contains("\"")
                ? "\"\(cleaned.replacingOccurrences(of: "\"", with: "\"\""))\""
                : cleaned
        }

        return [
            escape(ticker),
            buyDateStr,
            String(format: "%.2f", buyPrice),
            String(format: "%.0f", originalQuantity),
            String(format: "%.0f", quantity),
            status,
            sellDateStr,
            sellPriceStr,
            sellQtyStr,
            plStr,
            escape(buyReason),
            escape(sellReason),
            buyMarketConditionEnum?.rawValue ?? "",
            sellMarketConditionEnum?.rawValue ?? ""
        ].joined(separator: ",")
    }

    /// 將所有紀錄匯出為 CSV 檔案 URL
    static func exportCSV(from investments: [Investment]) -> URL? {
        let csv = csvHeader + "\n" + investments.map(\.csvRow).joined(separator: "\n")

        let tempDir = FileManager.default.temporaryDirectory
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "投資紀錄_\(df.string(from: Date())).csv"
        let fileURL = tempDir.appendingPathComponent(fileName)

        // 使用 BOM + UTF-8 確保 Excel 正確辨識中文
        let bom = "\u{FEFF}"
        guard let data = (bom + csv).data(using: .utf8) else { return nil }

        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }

    /// 處理賣出邏輯
    /// - 全部賣出：記錄賣出資訊，標記為已平倉
    /// - 部分賣出：拆分出一筆新的已平倉紀錄，原紀錄扣減數量
    @discardableResult
    func sell(
        quantity sellQty: Double,
        price: Double,
        date: Date,
        reason: String,
        marketCondition: MarketCondition? = nil,
        context: ModelContext
    ) -> Bool {
        guard sellQty > 0, sellQty <= quantity, price > 0 else {
            return false
        }

        if sellQty >= quantity {
            // 全部賣出：直接在本紀錄上記錄
            self.sellPrice = price
            self.sellDate = date
            self.sellQuantity = quantity
            self.sellReason = reason
            self.sellMarketConditionEnum = marketCondition
            self.quantity = 0
            self.isClosed = true
        } else {
            // 部分賣出：拆分一筆已平倉紀錄（標記為系統拆分）
            let closedRecord = Investment(
                ticker: ticker,
                buyDate: buyDate,
                buyPrice: buyPrice,
                quantity: sellQty,
                isClosed: true,
                sellPrice: price,
                sellDate: date,
                sellQuantity: sellQty,
                buyReason: buyReason,
                sellReason: reason,
                isPartialSellRecord: true,
                buyMarketCondition: buyMarketConditionEnum,
                sellMarketCondition: marketCondition
            )
            // 拆分紀錄的 originalQuantity 設為賣出數量（因為它只代表這一部分）
            closedRecord.originalQuantity = sellQty
            context.insert(closedRecord)

            // 原紀錄扣減數量
            self.quantity -= sellQty
        }

        return true
    }
}

// MARK: - 庫存彙整用輔助結構

/// 將同一標的的多筆未平倉紀錄彙整為一組
struct PortfolioGroup: Identifiable {
    let id: String
    let ticker: String
    let investments: [Investment]

    /// 總持有數量
    var totalQuantity: Double {
        investments.reduce(0) { $0 + $1.quantity }
    }

    /// 加權平均成本 = 總投入金額 / 總持有數量
    var weightedAverageCost: Double {
        let totalCost = investments.reduce(0.0) { $0 + $1.buyPrice * $1.quantity }
        guard totalQuantity > 0 else { return 0 }
        return totalCost / totalQuantity
    }

    /// 總投入金額
    var totalInvested: Double {
        investments.reduce(0.0) { $0 + $1.totalCost }
    }

    /// 計算群組未實現損益
    func unrealizedProfitLoss(currentPrice: Double) -> Double {
        return (currentPrice - weightedAverageCost) * totalQuantity
    }

    /// 計算群組報酬率
    func returnPercentage(currentPrice: Double) -> Double {
        guard weightedAverageCost > 0 else { return 0 }
        return (currentPrice - weightedAverageCost) / weightedAverageCost * 100
    }

    /// 整批賣出（FIFO）
    @discardableResult
    func batchSell(
        quantity sellQty: Double,
        price: Double,
        date: Date,
        reason: String,
        marketCondition: MarketCondition? = nil,
        context: ModelContext
    ) -> Bool {
        guard sellQty > 0, sellQty <= totalQuantity, price > 0 else {
            return false
        }

        var remaining = sellQty
        let sorted = investments.sorted { $0.buyDate < $1.buyDate }

        for investment in sorted {
            guard remaining > 0 else { break }
            let qty = min(remaining, investment.quantity)
            investment.sell(quantity: qty, price: price, date: date, reason: reason, marketCondition: marketCondition, context: context)
            remaining -= qty
        }

        return true
    }

    /// 從投資紀錄陣列建立群組
    static func buildGroups(from investments: [Investment]) -> [PortfolioGroup] {
        let grouped = Dictionary(grouping: investments, by: { $0.ticker })
        return grouped.map { ticker, items in
            PortfolioGroup(
                id: ticker,
                ticker: ticker,
                investments: items.sorted { $0.buyDate > $1.buyDate }
            )
        }
        .sorted { $0.ticker < $1.ticker }
    }
}
