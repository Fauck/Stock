# Stock — 投資日誌 iOS App

## 專案概述

SwiftUI + SwiftData 股票投資追蹤 App，採用溫暖手帳日誌風格 UI。
支援買入紀錄、部分/整批賣出（FIFO）、行事曆瀏覽、庫存管理、交易紀錄篩選、已實現損益追蹤、CSV 匯出。

## 架構：MVVM

```
Stock/
├── StockApp.swift              # App 入口，ModelContainer
├── ContentView.swift           # TabView（4 個 Tab）
├── Investment.swift            # @Model 資料模型 + PortfolioGroup
├── Theme.swift                 # AppColor、字型、共用 UI 元件
├── Utilities/
│   ├── DateFilterOption.swift  # 日期篩選選項 enum
│   ├── DateFormatters.swift    # AppDateFormatter（快取 DateFormatter）
│   └── DateFilterLogic.swift   # 共用日期篩選函式
├── ViewModels/
│   ├── CalendarViewModel.swift
│   ├── PortfolioListViewModel.swift
│   ├── TransactionHistoryViewModel.swift
│   ├── SoldRecordsViewModel.swift
│   ├── AddInvestmentViewModel.swift
│   ├── SellViewModel.swift
│   └── GroupSellViewModel.swift
├── CalendarView.swift          # Tab 0：行事曆
├── PortfolioListView.swift     # Tab 1：持有庫存
├── TransactionHistoryView.swift# Tab 2：交易紀錄
├── SoldRecordsView.swift       # Tab 3：已實現損益
├── AddInvestmentView.swift     # Sheet：新增買入
├── SellView.swift              # Sheet：單筆賣出
└── GroupSellView.swift         # Sheet：整批賣出
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

### 部分賣出機制

呼叫 `investment.sell(quantity:price:date:reason:context:)` 時：
- **全部賣出**：直接在原紀錄記錄賣出資訊，標記 `isClosed = true`
- **部分賣出**：拆分一筆新的 `isPartialSellRecord = true` 已平倉紀錄，原紀錄扣減 quantity

### 刪除機制

`Investment.deleteInvestment(_:context:)`：
- 刪除拆分紀錄 → 歸還數量給原始紀錄
- 刪除原始紀錄 → 級聯刪除所有相關拆分紀錄

### PortfolioGroup

同標的未平倉紀錄的彙整結構，提供加權均價、FIFO 整批賣出。

## UI 風格規範

### 色彩（AppColor）

| 名稱 | 用途 |
|------|------|
| `background` | 全域背景（米白） |
| `primary` | 主要操作色（深綠/褐） |
| `cardBackground` | 卡片背景 |
| `softUp` | 買入/漲（柔和綠） |
| `softDown` | 賣出/跌（柔和紅） |

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
