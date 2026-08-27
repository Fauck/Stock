import Foundation
import SwiftData
import Observation

@Observable
final class AddInvestmentViewModel {
    // MARK: - Input
    let selectedDate: Date

    // MARK: - Form State
    var ticker: String = ""
    var buyPriceText: String = ""
    var quantityText: String = ""
    var buyReason: String = ""
    var buyMarketCondition: MarketCondition?
    var showingAlert: Bool = false
    var alertMessage: String = ""

    // MARK: - 交易日誌（進場前 + 執行中）
    var journalExpanded: Bool = false
    var tradeMarket: TradeMarket = .tw
    var tradeDirection: TradeDirection = .long
    var journalSetup: String = ""
    var plannedEntryPriceText: String = ""
    var initialStopLossText: String = ""
    var emotionScore: Int? = nil

    // MARK: - 即時股價相關
    /// 解析後的股票代號（用於 API 查詢與儲存）
    var resolvedSymbol: String = ""
    /// 顯示用的中文名稱
    var resolvedName: String?
    /// API 回傳的即時價格
    var fetchedPrice: Double?
    /// 是否正在查詢中
    var isFetchingPrice: Bool = false
    /// 查詢錯誤訊息
    var fetchError: String?

    /// 用於防抖的查詢任務
    private var fetchTask: Task<Void, Never>?

    init(selectedDate: Date) {
        self.selectedDate = selectedDate
    }

    // MARK: - Computed

    var formattedDate: String {
        AppDateFormatter.fullDateWithWeekday.string(from: selectedDate)
    }

    var costPreview: Double? {
        guard let price = Double(buyPriceText),
              let qty = Double(quantityText),
              price > 0, qty > 0 else { return nil }
        return price * qty
    }

    /// 顯示在輸入框下方的解析結果文字
    var tickerDisplayText: String? {
        if isFetchingPrice { return "查詢中..." }
        if let name = resolvedName, !resolvedSymbol.isEmpty {
            if resolvedSymbol != ticker.trimmingCharacters(in: .whitespacesAndNewlines) {
                // 使用者輸入中文，顯示代號 + 名稱
                return "\(resolvedSymbol) \(name)"
            } else {
                // 使用者輸入代號，只顯示名稱
                return name
            }
        }
        if let error = fetchError { return error }
        return nil
    }

    // MARK: - 即時查詢

    /// 當 ticker 輸入變更時呼叫（防抖 0.6 秒）
    func onTickerChanged() {
        let input = ticker.trimmingCharacters(in: .whitespacesAndNewlines)

        // 清空狀態
        if input.isEmpty {
            resolvedSymbol = ""
            resolvedName = nil
            fetchedPrice = nil
            fetchError = nil
            isFetchingPrice = false
            fetchTask?.cancel()
            return
        }

        // 先用本地字典解析
        let resolved = StockMapping.resolve(input)
        resolvedSymbol = resolved.symbol
        resolvedName = resolved.name

        // 防抖：取消前一次查詢，延遲後發送新查詢
        fetchTask?.cancel()
        fetchTask = Task { @MainActor in
            isFetchingPrice = true
            fetchError = nil

            // 延遲 0.6 秒（防抖）
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }

            let symbolToQuery = resolved.symbol
            do {
                let result = try await StockService.shared.fetchQuote(symbol: symbolToQuery)
                guard !Task.isCancelled else { return }

                // 更新名稱（API 的名稱最準確）
                if let apiName = Optional(result.name), !apiName.isEmpty {
                    resolvedName = apiName
                    StockMapping.cache(symbol: result.symbol, name: apiName)
                }
                resolvedSymbol = result.symbol
                fetchedPrice = result.lastPrice

                // 如果使用者尚未手動輸入價格，自動填入即時價
                if buyPriceText.isEmpty {
                    buyPriceText = String(format: "%.2f", result.lastPrice)
                }
            } catch {
                guard !Task.isCancelled else { return }
                fetchedPrice = nil
                if resolvedName == nil {
                    fetchError = "查無此代號"
                }
            }
            isFetchingPrice = false
        }
    }

    /// 使用者點擊「帶入即時價」按鈕
    func applyFetchedPrice() {
        guard let price = fetchedPrice else { return }
        buyPriceText = String(format: "%.2f", price)
    }

    // MARK: - 市場自動偵測

    /// 根據代號自動偵測市場（含英文字母 → 美股，否則台股）
    func autoDetectMarket() {
        let symbol = resolvedSymbol.isEmpty
            ? ticker.trimmingCharacters(in: .whitespacesAndNewlines)
            : resolvedSymbol
        let hasLetters = symbol.rangeOfCharacter(from: .letters) != nil
        let isAllDigits = symbol.allSatisfy { $0.isNumber }
        tradeMarket = (hasLetters && !isAllDigits) ? .us : .tw
    }

    /// 日誌是否有填寫任何欄位
    var hasJournalContent: Bool {
        !journalSetup.isEmpty ||
        !plannedEntryPriceText.isEmpty ||
        !initialStopLossText.isEmpty ||
        emotionScore != nil
    }

    // MARK: - Actions

    /// 儲存投資紀錄，成功回傳 true（呼叫端應 dismiss）
    func save(context: ModelContext) -> Bool {
        // 決定實際儲存的 ticker：優先使用解析後的代號
        let saveTicker: String
        if !resolvedSymbol.isEmpty {
            saveTicker = resolvedSymbol
        } else {
            saveTicker = ticker.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard !saveTicker.isEmpty else {
            alertMessage = "請輸入標的名稱或代號"
            showingAlert = true
            return false
        }
        guard let buyPrice = Double(buyPriceText), buyPrice > 0 else {
            alertMessage = "請輸入有效的買入價格"
            showingAlert = true
            return false
        }
        guard let quantity = Double(quantityText), quantity > 0 else {
            alertMessage = "請輸入有效的買入數量"
            showingAlert = true
            return false
        }
        let investment = Investment(
            ticker: saveTicker,
            buyDate: selectedDate,
            buyPrice: buyPrice,
            quantity: quantity,
            buyReason: buyReason.trimmingCharacters(in: .whitespacesAndNewlines),
            buyMarketCondition: buyMarketCondition
        )
        context.insert(investment)

        // 建立交易日誌（如果有填寫任何日誌欄位）
        if hasJournalContent || journalExpanded {
            let journal = TradeJournal(
                investmentID: investment.id,
                market: tradeMarket,
                direction: tradeDirection,
                setup: journalSetup.trimmingCharacters(in: .whitespacesAndNewlines),
                plannedEntryPrice: Double(plannedEntryPriceText),
                initialStopLoss: Double(initialStopLossText),
                emotionScore: emotionScore
            )
            context.insert(journal)
        }

        return true
    }
}
