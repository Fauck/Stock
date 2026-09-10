# Stock — 投資日誌 iOS App

## 工作流程規範

- 執行任何程式碼修改前，必須先提出完整實作計畫並取得使用者同意後才能開始寫程式碼。

## 專案概述

SwiftUI + SwiftData 股票投資追蹤 App，採用溫暖手帳日誌風格 UI。
支援買入紀錄、部分/整批賣出（FIFO）、行事曆瀏覽、庫存管理、交易紀錄篩選、已實現損益追蹤、技術指標分析、K 線型態辨識、賣出建議評分、交易日誌、CSV/JSON 備份匯出入。

## 架構：MVVM

```
Stock/
├── StockApp.swift                  # App 入口，ModelContainer + SchemaMigrationPlan
├── ContentView.swift               # TabView（5 個 Tab）
├── Investment.swift                # @Model 資料模型 + PortfolioGroup + CodableInvestment
├── TradeJournal.swift              # @Model 交易日誌 + CodableTradeJournal
├── Theme.swift                     # AppColor、字型、共用 UI 元件
├── Secrets.swift                   # API Key（.gitignore，需手動建立）
├── StockSchemaVersioning.swift     # SwiftData VersionedSchema + MigrationPlan
├── Utilities/
│   ├── StockService.swift          # actor 網路層（Fugle API + TWSE/TPEx）
│   ├── StockMapping.swift          # 股票代碼 ↔ 名稱對照（內建 3,246 筆 + 動態快取）
│   ├── TechnicalIndicators.swift   # 技術指標計算（SMA/RSI/KDJ/MACD/BB/背離/K線型態/賣出建議）
│   ├── TechnicalSettings.swift     # 指標參數設定（Codable → UserDefaults）
│   ├── TradingFeeSettings.swift    # 手續費/稅率/移動停利/功能開關
│   ├── CandleCacheData.swift       # K 線快取結構 + UserDefaults 鍵名
│   ├── MarketCondition.swift       # 大盤狀況 enum（大漲/小漲/平盤/小跌/大跌）
│   ├── DateFilterOption.swift      # 日期篩選選項 enum
│   ├── DateFormatters.swift        # AppDateFormatter（快取 DateFormatter）
│   └── DateFilterLogic.swift       # 共用日期篩選函式
├── ViewModels/
│   ├── PortfolioListViewModel.swift       # 庫存主頁（報價/技術信號/法人/移動停利/賣出建議）
│   ├── KLineChartViewModel.swift          # K 線圖（買賣標記/停損線/MA）
│   ├── CalendarViewModel.swift
│   ├── TransactionHistoryViewModel.swift
│   ├── SoldRecordsViewModel.swift
│   ├── AddInvestmentViewModel.swift
│   ├── SellViewModel.swift
│   ├── GroupSellViewModel.swift
│   ├── PnLChartViewModel.swift            # 已實現損益走勢
│   ├── UnrealizedPnLChartViewModel.swift  # 未實現損益走勢
│   ├── IntradayAnalysisViewModel.swift    # 盤中分析（分價量/成交明細/大單）
│   ├── MarketScanViewModel.swift          # 市場掃描（漲幅/跌幅/成交量排行）
│   ├── TradeJournalViewModel.swift
│   ├── DataTransferViewModel.swift        # 備份匯出入（.stockbackup JSON）
│   └── MortgageCalculatorViewModel.swift
├── CalendarView.swift              # Tab 0：行事曆
├── PortfolioListView.swift         # Tab 1：持有庫存
├── TransactionHistoryView.swift    # Tab 2：交易紀錄
├── SoldRecordsView.swift           # Tab 3：已實現損益
├── ToolboxView.swift               # Tab 4：工具箱
│   ├── IntradayAnalysisView         # 盤中分析
│   ├── PnLChartView                 # 損益走勢圖（已實現 + 未實現切換）
│   ├── TradeJournalListView         # 交易日誌列表
│   ├── MortgageCalculatorView       # 房貸試算
│   ├── TechnicalSettingsView        # 參數設定（指標 + 費率 + 功能開關）
│   └── DataTransferView             # 資料備份
├── StockDetailSheetView.swift      # Sheet：個股分析（K線/指標/背離/型態/賣出建議/法人/停利）
├── KLineChartView.swift            # K 線圖元件
├── MarketScanView.swift            # 市場掃描（獨立頁面）
├── AddInvestmentView.swift         # Sheet：新增買入
├── SellView.swift                  # Sheet：單筆賣出
├── GroupSellView.swift             # Sheet：整批賣出
├── TradeJournalDetailView.swift    # 日誌詳情
└── TradeJournalEditView.swift      # 日誌編輯
```

### @Query 橋接模式

`@Query` 依賴 SwiftUI 環境，無法放在 `@Observable` class 中（會靜默回傳空陣列）。
所有 `@Query` 保留在 View，透過 `.onAppear` + `.onChange` 傳入 ViewModel：

```swift
@Query(...) private var investments: [Investment]
@State private var vm = SomeViewModel()

.onAppear { vm.investments = investments }
.onChange(of: investments) { _, new in vm.investments = new }
```

### View 保留的 SwiftUI 專屬元素

- `@FocusState`（鍵盤焦點控制）
- `@Environment(\.modelContext)`（傳入 VM 方法作為參數）
- `@Environment(\.dismiss)`
- `ScrollViewReader` + `.id()` + `proxy.scrollTo()`

## 資料模型關鍵設計

### Investment（@Model）

| 欄位 | 說明 |
|------|------|
| `originalQuantity` | 建立後不變，用於交易紀錄回溯 |
| `quantity` | 目前持有量，賣出時扣減 |
| `isPartialSellRecord` | 部分賣出時系統拆分產生的紀錄 |
| `isClosed` | 全部平倉（quantity = 0） |

### 額外欄位

| 欄位 | 說明 |
|------|------|
| `buyMarketCondition` / `sellMarketCondition` | `MarketCondition.rawValue` 字串，透過 computed property 轉換 |
| `holdingDays` | 交易日計算（排除六日） |

### 損益計算方法

- `unrealizedProfitLoss(currentPrice:fees:)` / `returnPercentage(currentPrice:fees:)` — 接收 `TradingFeeSettings` 參數
- `realizedProfitLoss(fees:)` / `realizedReturnPercentage(fees:)` — 同上

### 部分賣出機制

呼叫 `investment.sell(quantity:price:date:reason:marketCondition:context:)` 時：
- **全部賣出**：直接在原紀錄記錄賣出資訊，標記 `isClosed = true`
- **部分賣出**：拆分一筆新的 `isPartialSellRecord = true` 已平倉紀錄，原紀錄扣減 quantity
- 回傳 `@discardableResult Bool`

### 刪除機制

`Investment.deleteInvestment(_:context:)`：
- 刪除拆分紀錄 → 歸還數量給原始紀錄
- 刪除原始紀錄 → 級聯刪除所有相關拆分紀錄

### PortfolioGroup

同標的未平倉紀錄的彙整結構，提供加權均價、FIFO 整批賣出。
- 分組依據：`StockMapping.normalizedSymbol(for:)` — 確保 "2330" 和 "台積電" 歸為同組
- `batchSell(quantity:price:date:reason:marketCondition:context:)` — FIFO 排序後依序扣減
- 損益計算同樣接受 `TradingFeeSettings`

### Codable 序列化模式

`@Model` 無法直接遵循 `Codable`。使用平行 struct 橋接：
- `Investment` ↔ `CodableInvestment: Codable, Sendable`（透過 `toCodable` / `fromCodable(_:)`）
- `TradeJournal` ↔ `CodableTradeJournal: Codable, Sendable`（同模式）

### TradeJournal（@Model）

與 `Investment` 透過 `investmentID: UUID` 軟連結（非 SwiftData relationship）。

三階段結構：
- **Plan（進場前）**：`market`、`direction`、`setup`、`plannedEntryPrice`、`initialStopLoss`、`targetPrice`
- **Action（執行中）**：`emotionScore`（1=極度恐慌 ~ 5=極度貪婪）
- **Review（覆盤）**：`exitReason`、`reflection`、`rMultiple`

R 倍數計算：`R = (exitPrice - entryPrice) / (entryPrice - stopLoss)`

## UI 風格規範

### 色彩（AppColor）

| 名稱 | 用途 |
|------|------|
| `background` | 全域背景（米白） |
| `primary` | 主要操作色（深綠/褐） |
| `secondary` | 自然綠 #4F7942 |
| `cardBackground` | 卡片背景 |
| `softUp` | 買入/漲（柔和綠） |
| `softDown` | 賣出/跌（柔和紅） |
| `textMain` | 深灰文字 #4A4A4A |
| `textSecondary` | 暖灰文字 |
| `divider` | 暖淺灰分隔線 |

### 字型

全部透過 `Font` extension：`.warmTitle()`, `.warmHeadline()`, `.warmSubheadline()`, `.warmBody()`, `.warmCaption()`, `.warmCaption2()`, `.warmLargeNumber()`

### 共用元件

- `.cardStyle()` — 圓角 20、cardBackground、陰影
- `.keyboardDismissable()` — 捲動收鍵盤 + 背景點擊 + 工具列「完成」按鈕
- `NotebookTextField` — 手帳風格多行輸入，可選 `isFocused` 綁定
- `WarmInfoBadge` / `WarmStatusBadge` — 資訊標籤
- `ShareSheetView` — UIActivityViewController 包裝
- `hideKeyboard()` — 全域鍵盤收合函式

## 程式習慣

- **命名**：PascalCase（型別）、camelCase（屬性/方法）
- **ViewModel**：`@Observable final class`，以 `@State private var vm` 持有
- **需要初始參數的 VM**：在 View `init` 中用 `_vm = State(initialValue: ...)` 初始化
- **不需要初始參數的 VM**：直接 `@State private var vm = XxxViewModel()`
- **ModelContext**：不注入 VM，而是作為方法參數傳入（如 `vm.save(context: modelContext)`）
- **格式化**：統一使用 `AppDateFormatter` 的快取 formatter
- **日期篩選**：使用 `filterInvestments()` 共用函式 + `DateFilterOption` enum
- **損益預覽**：使用 `ProfitPreview` 值型別（定義於 SellViewModel.swift）
- **4 空格縮排**、繁體中文 UI 文字
- **避免 Combine**，優先使用 async/await
- **Task 取消模式**：VM 中的 `fetchTask: Task<Void, Never>?` 在每次 `load()` 時先 cancel，完成前檢查 `Task.isCancelled`
- **Sendable 合規**：`@Model` class 本身非 Sendable，跨 actor 傳遞一律使用 `Codable` struct 鏡像
- **caseless enum 命名空間**：`TechnicalIndicators`、`StockMapping`、`CandleCacheKeys`、`Secrets` 皆為 enum（無 case，僅 static 成員）
- **@discardableResult**：`sell()` / `batchSell()` 回傳 Bool，呼叫端通常不使用

## 網路層（StockService）

### 架構

`actor StockService`（Swift concurrency actor），`static let shared` 單例。
- Base URL：`https://api.fugle.tw/marketdata/v1.0/stock`
- 認證：`X-API-KEY` header，來自 `Secrets.fugleAPIKey`
- 所有 response type 遵循 `Decodable` + `Sendable`
- Error type：`StockServiceError`（`invalidURL` / `invalidResponse` / `httpError(Int)` / `noPrice` / `noData`）

### API 端點

| 方法 | 用途 |
|------|------|
| `fetchQuote(symbol:)` | 即時報價（fallback: lastPrice → closePrice → previousClose） |
| `fetchTickerInfo(symbol:)` | 股票基本資訊 + 中文名稱 |
| `fetchHistoricalCandles(symbol:from:to:)` | 歷史 OHLCV K 線（最長 1 年） |
| `fetchIntradayTrades(symbol:limit:)` | 盤中成交明細（降序） |
| `fetchIntradayVolumes(symbol:)` | 分價量表 |
| `fetchStats(symbol:)` | 52 週高低 |
| `fetchMovers(market:direction:change:)` | 漲跌幅排行 |
| `fetchActives(market:trade:)` | 成交量/值排行 |
| `fetchQuotes(symbols:)` | 批次報價（TaskGroup 並行） |
| `fetchInstitutionalData(date:)` | TWSE 三大法人（T86 端點） |
| `fetchTPExInstitutionalData(date:)` | TPEx 三大法人 |

### 三大法人資料

- `InstitutionalDayData`：foreignNet / trustNet / dealerNet / totalNet（單位：張）
- `InstitutionalSummary`：持有 `[InstitutionalDayData]`，計算 `foreignStreak` / `trustStreak` / `totalStreak`（正=連買天數，負=連賣天數）
- 來源：TWSE（19 欄 CSV）+ TPEx（24 欄 CSV），shares ÷ 1000 = 張
- 抓取最近 10 個交易日（往回 20 天曆日，跳過週末），TaskGroup 並行

### StockMapping

`enum StockMapping` — 靜態命名空間。
- `builtInMap`：內建 3,246 筆上市櫃代碼 ↔ 名稱
- `dynamicCache`：執行期新增（每次 API 成功回傳後呼叫 `cache(symbol:name:)`）
- `resolve(_ input:) -> (symbol: String, name: String?)`：支援代碼或中文名稱輸入，自動去除 `*` 後綴
- `normalizedSymbol(for:)`：PortfolioGroup 分組鍵
- `displayName(for:)`：回傳中文名稱，無則回傳代碼

## K 線快取系統

### CandleCacheData

```swift
struct CandleCacheData: Codable {
    let dates: [String]    // "yyyy-MM-dd"
    let opens: [Double]
    let closes: [Double]
    let highs: [Double]
    let lows: [Double]
    let volumes: [Int]
}
```

### 快取策略（PortfolioListViewModel / UnrealizedPnLChartViewModel 共用）

1. `UserDefaults.string(forKey: "candleCacheDate")` 比對今日 `"yyyyMMdd"`
2. 日期相同 → decode `[String: CandleCacheData]`；不同或 decode 失敗 → 重新抓取
3. TaskGroup 並行抓取各 ticker，合併寫回 UserDefaults
4. 額外快取：`weekStatsCache` / `institutionalCache`（各有獨立日期鍵）

## 技術指標系統（TechnicalIndicators）

caseless `enum TechnicalIndicators` — 純靜態函數，無狀態。

### 指標函數

| 函數 | 說明 | 預設參數 |
|------|------|----------|
| `sma(closes:period:)` | 滑動視窗 O(n) | — |
| `rsi(closes:period:)` | Wilder's smoothing | period=14 |
| `kdj(highs:lows:closes:period:kSmooth:dSmooth:)` | RSV → K/D/J | 9/3/3 |
| `ema(values:period:)` | SMA 種子標準 EMA | — |
| `macd(closes:fastPeriod:slowPeriod:signalPeriod:)` | DIF/DEA/Histogram | 12/26/9 |
| `bollingerBands(closes:period:multiplier:)` | SMA20 ± 2σ + bandwidth | 20/2.0 |

### SignalSummary

`computeSignalSummary(opens:closes:highs:lows:volumes:settings:)` → 匯總所有指標：

| 欄位 | 類型 | 說明 |
|------|------|------|
| `ma5Position` / `ma20Position` | `.above` / `.below` | 價格相對均線 |
| `maCross` | `.goldenCross` / `.deathCross` | 均線交叉（比較前後兩根） |
| `rsi` / `rsiSignal` | Double / `.overbought`(>80) / `.oversold`(<20) | RSI |
| `kdjSignal` / `kdjK` / `kdjD` | `.goldenCross` / `.deathCross` | KDJ |
| `macdSignal` / `macdDIF` / `macdDEA` | 同上 | MACD |
| `bollingerSignal` | `.nearUpper` / `.nearLower` / `.squeeze` / `.normal` | 布林 |
| `volumeSignal` / `volumeRatio` | `.surge`(≥2x) / `.high`(≥1.5x) / `.shrink`(≤0.5x) | 量能 |
| `divergences` | `[DivergenceSignal]` | RSI/MACD 頂底背離 |
| `candlestickPatterns` | `[CandlestickSignal]` | K 線型態（最多 3 個） |

### 背離偵測

`detectDivergences(closes:highs:lows:rsiValues:macdValues:lookback:minSwingPct:)`
- lookback=40、局部極值 order=3、間隔至少 5 根 K 棒
- 頂背離：價格新高 + 指標未新高 → bearish
- 底背離：價格新低 + 指標未新低 → bullish

### K 線型態偵測

`detectCandlestickPatterns(opens:closes:highs:lows:ma5Values:ma20Values:)`
- 掃描最近 5 根 K 棒
- 優先序：三根（晨星/夜星）→ 兩根（吞噬）→ 單根（槌子/上吊/流星/十字星）
- 所有型態需搭配趨勢驗證（MA5 vs MA20）
- 台股適配：晨星/夜星不要求價格跳空
- 回傳最多 3 個，按可靠度高→低、barsAgo 小→大排序

| 型態 | K 棒數 | 方向 | 可靠度 |
|------|--------|------|--------|
| 槌子線 | 1 | 偏多 | 中 |
| 上吊線 | 1 | 偏空 | 中 |
| 十字星 | 1 | 依趨勢 | 低 |
| 流星線 | 1 | 偏空 | 中 |
| 多頭吞噬 | 2 | 偏多 | 高 |
| 空頭吞噬 | 2 | 偏空 | 高 |
| 晨星 | 3 | 偏多 | 高 |
| 夜星 | 3 | 偏空 | 高 |

### 賣出建議評分

`computeSellRecommendation(signal:trailingStopTriggered:nearTrailingStop:foreignStreak:trustStreak:)`

起始分數 50，各因子加減分後 clamp 至 0–100：

| 因子 | 偏空分數 | 偏多分數 |
|------|----------|----------|
| 均線死叉 / 金叉 | +15 | -10 |
| MACD 死叉 / 金叉 | +12 | -8 |
| KDJ 死叉 / 金叉 | +10 | -6 |
| RSI 超買 / 超賣 | +12 | -8 |
| 布林上軌 / 下軌 | +8 | -6 |
| 量能放大 | +8 | — |
| 移動停利觸發 | +20 | — |
| 接近停利線 | +10 | — |
| 安全持有 | — | -5 |
| 價格 < MA5/MA20 | +5 each | -3 each |
| 法人連賣/買 ≥3 日 | +5 | -3 |
| RSI/MACD 頂/底背離 | +10 | -6 |
| K 線型態（高/中/低） | +8/+5/+3 | -8/-5/-3 |

等級：`strongSell`(≥70) / `considerSell`(50–69) / `neutral`(30–49) / `holdBullish`(10–29) / `strongHold`(<10)

## 設定系統

### TechnicalSettings

`struct TechnicalSettings: Codable, Equatable, Sendable` → UserDefaults `"technicalSettings"`

可調參數：MA(5/20)、RSI(14/80/20)、KDJ(9/3/3)、MACD(12/26/9)、Bollinger(20/2.0)、Volume(2.0/1.5/0.5/MA20)

方法：`load()` / `save()` / `resetToDefaults()`

### TradingFeeSettings

`struct TradingFeeSettings: Codable, Equatable, Sendable` → UserDefaults `"tradingFeeSettings"`

| 欄位 | 預設值 | 說明 |
|------|--------|------|
| `commissionRate` | 0.001425 | 0.1425%（買賣各一次） |
| `taxRate` | 0.003 | 0.3%（僅賣出） |
| `trailingStopPct` | 10 | 移動停利回撤 % |
| `sellRecommendationEnabled` | false | 功能開關：賣出建議 |
| `supportResistanceEnabled` | false | 功能開關：壓力/支撐 |

費用計算：`totalFees(buyPrice:sellPrice:quantity:)` / `netProfitLoss(...)`

## StockDetailSheetView（個股分析頁）

從 PortfolioListView 開啟，顯示單一標的的完整分析。區塊順序：

1. **K 線走勢圖** — 嵌入 `KLineChartView`（含買賣標記、MA 線）
2. **技術指標信號** — 操作建議列表 + 指標數值表（RSI/KDJ/MACD/BB/Volume）
3. **背離信號** — 僅有背離時顯示
4. **K 線型態** — 僅有型態時顯示
5. **賣出建議** — 需 `sellRecommendationEnabled` 開啟
6. **目標/停損** — 來自 TradeJournal，可就地編輯
7. **移動停利** — 基於 highSinceBuy × (1 - trailingStopPct%)，下限為均價
8. **法人買賣超** — 外資/投信/自營商淨買賣張數與連續天數
9. **52 週區間** — 最高/最低價
10. **壓力/支撐** — 需 `supportResistanceEnabled` 開啟（MA5/MA20/BB/近20日高低）

## PortfolioListViewModel 載入順序

1. **Phase 1**：`fetchAllPricesAsync()` — 即時報價（每次進入必跑）
2. **Phase 2**（Phase 1 完成後並行）：技術信號 + 52 週統計 + 法人資料
3. 同日刷新最佳化：若 `lastLoadDate == todayString` 且信號已快取，僅跑 Phase 1

移動停利計算：掃描 K 線自買入日起的 max(high)，搭配即時價格。Stop = max(peak × (1 - pct/100), avgCost)。

## 備份匯出入（DataTransferViewModel）

- 格式：`.stockbackup`（JSON），結構為 `InvestmentBackup`
  - `version: Int`（1=純投資，2=投資+日誌）
  - `investments: [CodableInvestment]`
  - `journals: [CodableTradeJournal]?`
- 匯入模式：`.merge`（跳過重複 UUID）/ `.replace`（全刪後插入）
- 沙盒存取：`url.startAccessingSecurityScopedResource()`
- CSV 匯出含 UTF-8 BOM（Excel 相容）

## SwiftData 版本管理

```swift
enum StockSchemaV1: VersionedSchema   // Version(1, 0, 0)
enum StockMigrationPlan: SchemaMigrationPlan  // stages: [] (尚無遷移)
```

`ModelContainer` 使用 `Schema(versionedSchema: StockSchemaV1.self)` + `migrationPlan`。
註冊模型：`Investment`、`TradeJournal`。

## Secrets.swift

```swift
enum Secrets: Sendable {
    nonisolated(unsafe) static let fugleAPIKey = "..."
}
```

- 已加入 `.gitignore`，clone 後需手動建立
- `nonisolated(unsafe)` 允許跨 actor 存取

