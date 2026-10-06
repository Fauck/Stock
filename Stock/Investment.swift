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

    /// 輸入驗證錯誤
    enum ValidationError: LocalizedError {
        case emptyTicker
        case invalidBuyPrice
        case invalidQuantity

        var errorDescription: String? {
            switch self {
            case .emptyTicker: return "標的代號不可為空"
            case .invalidBuyPrice: return "買入價格必須大於 0"
            case .invalidQuantity: return "數量必須大於 0"
            }
        }
    }

    /// 驗證輸入值（供 UI 層在建立前呼叫）
    static func validate(ticker: String, buyPrice: Double, quantity: Double) throws {
        guard !ticker.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ValidationError.emptyTicker
        }
        guard buyPrice > 0 else {
            throw ValidationError.invalidBuyPrice
        }
        guard quantity > 0 else {
            throw ValidationError.invalidQuantity
        }
    }

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
        // 防禦性驗證：對新建立（非已平倉）的紀錄 clamp 不合理數值
        // 已平倉紀錄的 quantity 可能為 0（合法狀態）
        let safeBuyPrice = max(buyPrice, 0.01)
        let safeQuantity = isClosed ? max(quantity, 0) : max(quantity, 1)
        let safeTicker = ticker.trimmingCharacters(in: .whitespaces).isEmpty ? "UNKNOWN" : ticker

        self.id = id
        self.ticker = safeTicker
        self.buyDate = buyDate
        self.buyPrice = safeBuyPrice
        self.originalQuantity = safeQuantity
        self.quantity = safeQuantity
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

    // MARK: - 持有交易日天數

    /// 持有交易日天數：從買入日到賣出日（已平倉）或今天（持有中），僅計算週一至週五
    var holdingDays: Int {
        let end = sellDate ?? Date()
        return Investment.tradingDaysBetween(from: buyDate, to: end)
    }

    /// 計算兩個日期之間的交易日數（排除週六、週日），不含起始日
    static func tradingDaysBetween(from start: Date, to end: Date) -> Int {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)

        guard startDay < endDay else { return 0 }

        // 從起始日的隔天開始計算
        guard var current = calendar.date(byAdding: .day, value: 1, to: startDay) else { return 0 }

        var count = 0
        while current <= endDay {
            let weekday = calendar.component(.weekday, from: current)
            // weekday: 1 = Sunday, 7 = Saturday
            if weekday != 1 && weekday != 7 {
                count += 1
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return count
    }

    // MARK: - 商業邏輯

    /// 計算未實現損益（扣除手續費與交易稅）
    func unrealizedProfitLoss(currentPrice: Double, fees: TradingFeeSettings = .defaults) -> Double {
        let gross = (currentPrice - buyPrice) * quantity
        return gross - fees.totalFees(buyPrice: buyPrice, sellPrice: currentPrice, quantity: quantity)
    }

    /// 計算投資成本（以目前持有數量計算）
    var totalCost: Double {
        return buyPrice * quantity
    }

    /// 原始買入總成本
    var originalTotalCost: Double {
        return buyPrice * originalQuantity
    }

    /// 計算報酬率（百分比，扣除手續費與交易稅）
    func returnPercentage(currentPrice: Double, fees: TradingFeeSettings = .defaults) -> Double {
        let costWithFee = buyPrice * quantity + fees.buyCommission(price: buyPrice, quantity: quantity)
        guard costWithFee > 0 else { return 0 }
        let netProceeds = currentPrice * quantity
            - fees.sellCommission(price: currentPrice, quantity: quantity)
            - fees.transactionTax(sellPrice: currentPrice, quantity: quantity)
        return (netProceeds - costWithFee) / costWithFee * 100
    }

    /// 已實現損益（扣除手續費與交易稅）
    func realizedProfitLoss(fees: TradingFeeSettings = .defaults) -> Double {
        guard let sp = sellPrice, let sq = sellQuantity else { return 0 }
        return fees.netProfitLoss(buyPrice: buyPrice, sellPrice: sp, quantity: sq)
    }

    /// 已實現報酬率（百分比，扣除手續費與交易稅）
    func realizedReturnPercentage(fees: TradingFeeSettings = .defaults) -> Double {
        guard let sp = sellPrice, let sq = sellQuantity, buyPrice > 0 else { return 0 }
        let costWithFee = buyPrice * sq + fees.buyCommission(price: buyPrice, quantity: sq)
        guard costWithFee > 0 else { return 0 }
        let netProceeds = sp * sq
            - fees.sellCommission(price: sp, quantity: sq)
            - fees.transactionTax(sellPrice: sp, quantity: sq)
        return (netProceeds - costWithFee) / costWithFee * 100
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

    /// 刪除此筆紀錄，並清除相關的部分賣出拆分紀錄（原子性操作）
    /// - 若為原始買入紀錄：同時刪除所有由此紀錄拆分出的 partialSellRecord
    /// - 若為部分賣出拆分紀錄：將賣出數量歸還給原始紀錄
    /// - 任何步驟失敗時 rollback 所有暫存變更，確保資料一致性
    static func deleteInvestment(_ investment: Investment, context: ModelContext) throws {
        do {
            try performDelete(investment, context: context)
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    /// 內部刪除實作（不含 save/rollback，由外層統一處理）
    private static func performDelete(_ investment: Investment, context: ModelContext) throws {
        // 清除關聯的 TradeJournal（避免孤兒資料）
        let investmentID = investment.id
        let journalDescriptor = FetchDescriptor<TradeJournal>(
            predicate: #Predicate<TradeJournal> { $0.investmentID == investmentID }
        )
        let orphanJournals = try context.fetch(journalDescriptor)
        for j in orphanJournals {
            context.delete(j)
        }

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
            let originals = try context.fetch(descriptor)
            guard let original = originals.first else {
                throw InvestmentDeleteError.originalRecordNotFound
            }
            original.quantity += soldQty
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
            let partials = try context.fetch(descriptor)
            for partial in partials {
                // 清除拆分紀錄的 journals
                let partialID = partial.id
                let pjDescriptor = FetchDescriptor<TradeJournal>(
                    predicate: #Predicate<TradeJournal> { $0.investmentID == partialID }
                )
                let pjournals = try context.fetch(pjDescriptor)
                for pj in pjournals {
                    context.delete(pj)
                }
                context.delete(partial)
            }
            context.delete(investment)
        }
    }

    /// 刪除投資紀錄時的錯誤類型
    enum InvestmentDeleteError: LocalizedError {
        case originalRecordNotFound

        var errorDescription: String? {
            switch self {
            case .originalRecordNotFound:
                return "找不到原始買入紀錄，無法歸還賣出數量。請嘗試重新啟動 App 後再試。"
            }
        }
    }

    // MARK: - CSV 匯出

    /// CSV 表頭
    static let csvHeader = "標的,買入日期,買入價格,原始數量,目前數量,狀態,賣出日期,賣出價格,賣出數量,已實現損益,買入理由,賣出理由,買入大盤,賣出大盤,市場,交易方向,進場理由,預定進場價,初始停損價,目標價,情緒分數,出場理由,反思,R-Multiple"

    /// 將單筆紀錄轉為 CSV 行（可選搭配交易日誌）
    func csvRow(journal: TradeJournal? = nil) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy/MM/dd"

        let status = statusText
        let buyDateStr = df.string(from: buyDate)
        let sellDateStr = sellDate.map { df.string(from: $0) } ?? ""
        let sellPriceStr = sellPrice.map { String(format: "%.2f", $0) } ?? ""
        let sellQtyStr = sellQuantity.map { String(format: "%.0f", $0) } ?? ""
        let plStr = isClosed ? String(format: "%.0f", realizedProfitLoss()) : ""

        // 將理由中的逗號與換行替換，避免破壞 CSV 格式
        func escape(_ s: String) -> String {
            let cleaned = s.replacingOccurrences(of: "\n", with: " ")
            return cleaned.contains(",") || cleaned.contains("\"")
                ? "\"\(cleaned.replacingOccurrences(of: "\"", with: "\"\""))\""
                : cleaned
        }

        var fields = [
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
        ]

        // 交易日誌欄位
        if let j = journal {
            fields.append(contentsOf: [
                j.market,
                j.direction,
                escape(j.setup),
                j.plannedEntryPrice.map { String(format: "%.2f", $0) } ?? "",
                j.initialStopLoss.map { String(format: "%.2f", $0) } ?? "",
                j.targetPrice.map { String(format: "%.2f", $0) } ?? "",
                j.emotionScore.map { String($0) } ?? "",
                escape(j.exitReason),
                escape(j.reflection),
                j.rMultiple.map { String(format: "%.2f", $0) } ?? ""
            ])
        } else {
            fields.append(contentsOf: Array(repeating: "", count: 10))
        }

        return fields.joined(separator: ",")
    }

    /// 轉換為可序列化的傳輸結構
    var toCodable: CodableInvestment {
        CodableInvestment(
            id: id,
            ticker: ticker,
            buyDate: buyDate,
            buyPrice: buyPrice,
            originalQuantity: originalQuantity,
            quantity: quantity,
            isClosed: isClosed,
            sellPrice: sellPrice,
            sellDate: sellDate,
            sellQuantity: sellQuantity,
            buyReason: buyReason,
            sellReason: sellReason,
            isPartialSellRecord: isPartialSellRecord,
            buyMarketCondition: buyMarketCondition,
            sellMarketCondition: sellMarketCondition
        )
    }

    /// 從傳輸結構建立 Investment
    static func fromCodable(_ c: CodableInvestment) -> Investment {
        let inv = Investment(
            id: c.id,
            ticker: c.ticker,
            buyDate: c.buyDate,
            buyPrice: c.buyPrice,
            quantity: c.quantity,
            isClosed: c.isClosed,
            sellPrice: c.sellPrice,
            sellDate: c.sellDate,
            sellQuantity: c.sellQuantity,
            buyReason: c.buyReason,
            sellReason: c.sellReason,
            isPartialSellRecord: c.isPartialSellRecord,
            buyMarketCondition: c.buyMarketCondition.flatMap { MarketCondition(rawValue: $0) },
            sellMarketCondition: c.sellMarketCondition.flatMap { MarketCondition(rawValue: $0) }
        )
        // init 會將 originalQuantity 設為 quantity，需手動覆寫
        inv.originalQuantity = c.originalQuantity
        return inv
    }

    // MARK: - JSON 備份匯出

    /// 將所有紀錄匯出為 JSON 備份檔案 URL（含交易日誌）
    static func exportJSON(from investments: [Investment], journals: [TradeJournal] = []) -> URL? {
        let codables = investments.map(\.toCodable)
        let journalCodables = journals.map(\.toCodable)
        let backup = InvestmentBackup(investments: codables, journals: journalCodables)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(backup) else { return nil }

        let tempDir = FileManager.default.temporaryDirectory
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "投資紀錄備份_\(df.string(from: Date())).stockbackup"
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }

    /// 將所有紀錄匯出為 CSV 檔案 URL（可選搭配交易日誌）
    static func exportCSV(from investments: [Investment], journals: [TradeJournal] = []) -> URL? {
        let journalMap = Dictionary(uniqueKeysWithValues: journals.map { ($0.investmentID, $0) })
        let rows = investments.map { inv in inv.csvRow(journal: journalMap[inv.id]) }
        let csv = csvHeader + "\n" + rows.joined(separator: "\n")

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

    /// 最早買入日至今的持有交易日天數
    var holdingDays: Int {
        guard let earliest = investments.map(\.buyDate).min() else { return 0 }
        return Investment.tradingDaysBetween(from: earliest, to: Date())
    }

    /// 計算群組未實現損益（扣除手續費與交易稅）
    func unrealizedProfitLoss(currentPrice: Double, fees: TradingFeeSettings = .defaults) -> Double {
        let gross = (currentPrice - weightedAverageCost) * totalQuantity
        return gross - fees.totalFees(buyPrice: weightedAverageCost, sellPrice: currentPrice, quantity: totalQuantity)
    }

    /// 計算群組報酬率（扣除手續費與交易稅）
    func returnPercentage(currentPrice: Double, fees: TradingFeeSettings = .defaults) -> Double {
        let costWithFee = weightedAverageCost * totalQuantity + fees.buyCommission(price: weightedAverageCost, quantity: totalQuantity)
        guard costWithFee > 0 else { return 0 }
        let netProceeds = currentPrice * totalQuantity
            - fees.sellCommission(price: currentPrice, quantity: totalQuantity)
            - fees.transactionTax(sellPrice: currentPrice, quantity: totalQuantity)
        return (netProceeds - costWithFee) / costWithFee * 100
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
    /// 使用標準化代號分組，讓同股票不同 ticker 格式（如 "2330" 和 "台積電"）合併
    static func buildGroups(from investments: [Investment]) -> [PortfolioGroup] {
        let grouped = Dictionary(grouping: investments, by: {
            StockMapping.normalizedSymbol(for: $0.ticker)
        })
        return grouped.map { symbol, items in
            PortfolioGroup(
                id: symbol,
                ticker: symbol,
                investments: items.sorted { $0.buyDate > $1.buyDate }
            )
        }
        .sorted { $0.ticker < $1.ticker }
    }
}

// MARK: - JSON 備份傳輸結構

/// 可序列化的 Investment 傳輸結構（避免 @Model + Codable 衝突）
struct CodableInvestment: Codable, Sendable {
    let id: UUID
    let ticker: String
    let buyDate: Date
    let buyPrice: Double
    let originalQuantity: Double
    let quantity: Double
    let isClosed: Bool
    let sellPrice: Double?
    let sellDate: Date?
    let sellQuantity: Double?
    let buyReason: String
    let sellReason: String
    let isPartialSellRecord: Bool
    let buyMarketCondition: String?
    let sellMarketCondition: String?
}

/// 備份信封：包含版本資訊，供未來相容
struct InvestmentBackup: Codable, Sendable {
    let version: Int
    let exportDate: Date
    let recordCount: Int
    let investments: [CodableInvestment]
    /// V2 新增：交易日誌（舊版備份此欄位為 nil）
    let journals: [CodableTradeJournal]?

    init(investments: [CodableInvestment], journals: [CodableTradeJournal] = []) {
        self.version = journals.isEmpty ? 1 : 2
        self.exportDate = Date()
        self.recordCount = investments.count
        self.investments = investments
        self.journals = journals.isEmpty ? nil : journals
    }
}
