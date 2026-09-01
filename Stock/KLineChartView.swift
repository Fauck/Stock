//
//  KLineChartView.swift
//  Stock
//
//  K 線走勢圖：Canvas 繪製蠟燭圖 + 進出場標記
//

import SwiftUI
import SwiftData

/// K 線走勢圖卡片，顯示歷史 OHLC 蠟燭圖與買賣標記
struct KLineChartView: View {
    let vm: KLineChartViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            chartHeader

            if vm.isLoading {
                loadingState
            } else if let error = vm.errorMessage {
                errorState(error)
            } else if vm.candles.isEmpty {
                emptyState
            } else {
                chartCanvas
                if let selected = vm.selectedCandle {
                    tooltipView(selected)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Header

    private var chartHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "chart.bar.xaxis")
                .foregroundStyle(AppColor.primary)
            Text("K 線走勢")
                .font(.warmHeadline())
                .foregroundStyle(AppColor.textMain)
            Spacer()
            if !vm.candles.isEmpty {
                indicatorToggle("MA", isOn: vm.showMA) { vm.showMA.toggle() }
                indicatorToggle("量", isOn: vm.showVolume) { vm.showVolume.toggle() }
                Text("\(vm.candles.count) 日")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
    }

    private func indicatorToggle(_ label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.warmCaption2())
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isOn ? AppColor.primary : AppColor.background)
                .foregroundStyle(isOn ? .white : AppColor.textMain)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - States

    private var loadingState: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                ProgressView()
                    .tint(AppColor.primary)
                Text("載入走勢圖...")
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
            }
            .padding(.vertical, 40)
            Spacer()
        }
    }

    private func errorState(_ message: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.title2)
                    .foregroundStyle(AppColor.textSecondary.opacity(0.4))
                Text(message)
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.textSecondary)
                Button {
                    Task { await vm.loadCandles() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("重試")
                    }
                    .font(.warmCaption())
                    .foregroundStyle(AppColor.primary)
                }
            }
            .padding(.vertical, 30)
            Spacer()
        }
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            Text("查無歷史資料")
                .font(.warmCaption())
                .foregroundStyle(AppColor.textSecondary)
                .padding(.vertical, 30)
            Spacer()
        }
    }

    // MARK: - Chart Canvas

    private var chartCanvas: some View {
        let candles = vm.candles
        let layout = ChartLayout(candles: candles, vm: vm)

        return VStack(spacing: 0) {
            Canvas { context, size in
                let area = layout.drawableArea(in: size)
                guard area.width > 0, area.height > 0 else { return }

                // 背景參考線
                drawGridLines(context: context, layout: layout, size: size, area: area)

                // 停損線
                if let sl = vm.stopLossPrice, sl > 0 {
                    drawHorizontalLine(
                        context: context, price: sl,
                        color: AppColor.softDown, dash: [6, 4],
                        layout: layout, area: area
                    )
                }

                // 計畫進場線
                if let pe = vm.plannedEntryPrice, pe > 0 {
                    drawHorizontalLine(
                        context: context, price: pe,
                        color: AppColor.textSecondary, dash: [3, 3],
                        layout: layout, area: area
                    )
                }

                // 成交量分隔線 + 柱狀圖
                if vm.showVolume {
                    let volArea = layout.volumeArea(in: size)
                    drawVolumeSeparator(context: context, area: area)
                    drawVolumeBars(context: context, layout: layout, volArea: volArea)
                }

                // 蠟燭
                drawCandles(context: context, layout: layout, area: area)

                // MA 均線
                if vm.showMA {
                    drawMALine(context: context, values: vm.ma5,
                               color: AppColor.softUp.opacity(0.8), layout: layout, area: area)
                    drawMALine(context: context, values: vm.ma20,
                               color: AppColor.softDown.opacity(0.8), layout: layout, area: area)
                    drawMALegend(context: context, area: area)
                }

                // 選中高亮
                if let idx = vm.selectedCandleIndex, idx >= 0, idx < candles.count {
                    let x = layout.xForIndex(idx, in: area)
                    var highlightPath = Path()
                    let highlightBottom = vm.showVolume ? layout.volumeArea(in: size).maxY : area.maxY
                    highlightPath.move(to: CGPoint(x: x, y: area.minY))
                    highlightPath.addLine(to: CGPoint(x: x, y: highlightBottom))
                    context.stroke(
                        highlightPath,
                        with: .color(AppColor.primary.opacity(0.3)),
                        style: StrokeStyle(lineWidth: 1, dash: [2, 2])
                    )
                }

                // 買入標記（單筆 or 多筆）
                if layout.buyIndex != nil {
                    drawBuyMarker(context: context, layout: layout, area: area)
                } else if !layout.buyIndices.isEmpty {
                    drawBuyMarkers(context: context, layout: layout, area: area)
                }

                // 賣出標記
                drawSellMarker(context: context, layout: layout, area: area)

                // 右側標註徽章（停損、計畫、買入價、賣出價 — 自動避開重疊）
                drawRightAnnotations(context: context, layout: layout, area: area, size: size)

                // Y 軸價格標籤
                drawPriceAxis(context: context, layout: layout, size: size, area: area)
            }
            .frame(height: vm.showVolume ? 280 : 220)
            .overlay {
                GeometryReader { geo in
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    let size = geo.size
                                    let layout = ChartLayout(candles: vm.candles, vm: vm)
                                    let area = layout.drawableArea(in: size)
                                    let tapX = value.location.x
                                    let idx = layout.indexForX(tapX, in: area)
                                    if idx == vm.selectedCandleIndex {
                                        vm.selectedCandleIndex = nil
                                    } else {
                                        vm.selectedCandleIndex = idx
                                    }
                                }
                        )
                }
            }

            // X 軸日期標籤
            dateAxisLabels(layout: layout)
        }
    }

    // MARK: - Drawing Helpers

    private func drawGridLines(context: GraphicsContext, layout: ChartLayout, size: CGSize, area: CGRect) {
        let steps = 4
        for i in 0...steps {
            let ratio = Double(i) / Double(steps)
            let price = layout.priceMax - ratio * layout.priceRange
            let y = layout.yForPrice(price, in: area)
            var path = Path()
            path.move(to: CGPoint(x: area.minX, y: y))
            path.addLine(to: CGPoint(x: area.maxX, y: y))
            context.stroke(
                path,
                with: .color(AppColor.divider.opacity(0.5)),
                style: StrokeStyle(lineWidth: 0.5)
            )
        }
    }

    private func drawCandles(context: GraphicsContext, layout: ChartLayout, area: CGRect) {
        let bodyWidth = layout.candleWidth * 0.7

        for (i, candle) in vm.candles.enumerated() {
            let x = layout.xForIndex(i, in: area)
            let isUp = candle.close >= candle.open
            let color = isUp ? AppColor.softUp : AppColor.softDown

            // 影線
            let highY = layout.yForPrice(candle.high, in: area)
            let lowY = layout.yForPrice(candle.low, in: area)
            var wickPath = Path()
            wickPath.move(to: CGPoint(x: x, y: highY))
            wickPath.addLine(to: CGPoint(x: x, y: lowY))
            context.stroke(wickPath, with: .color(color), lineWidth: 1)

            // 實體
            let openY = layout.yForPrice(candle.open, in: area)
            let closeY = layout.yForPrice(candle.close, in: area)
            let bodyTop = min(openY, closeY)
            let bodyHeight = max(abs(openY - closeY), 1)
            let bodyRect = CGRect(
                x: x - bodyWidth / 2,
                y: bodyTop,
                width: bodyWidth,
                height: bodyHeight
            )
            context.fill(Path(bodyRect), with: .color(color))
        }
    }

    private func drawHorizontalLine(
        context: GraphicsContext,
        price: Double,
        color: Color,
        dash: [CGFloat],
        layout: ChartLayout,
        area: CGRect
    ) {
        guard price >= layout.priceMin, price <= layout.priceMax else { return }
        let y = layout.yForPrice(price, in: area)
        var path = Path()
        path.move(to: CGPoint(x: area.minX, y: y))
        path.addLine(to: CGPoint(x: area.maxX, y: y))
        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: 1, dash: dash)
        )
    }

    private func drawBuyMarker(context: GraphicsContext, layout: ChartLayout, area: CGRect) {
        guard let idx = layout.buyIndex else { return }
        let x = layout.xForIndex(idx, in: area)
        let candle = vm.candles[idx]
        let lowY = layout.yForPrice(candle.low, in: area)

        // 確保標記在可視範圍內（向下偏移，但不超出區域）
        let y = min(lowY + 12, area.maxY - 4)

        // 上三角
        let size: CGFloat = 8
        var triangle = Path()
        triangle.move(to: CGPoint(x: x, y: y - size))
        triangle.addLine(to: CGPoint(x: x - size / 2, y: y))
        triangle.addLine(to: CGPoint(x: x + size / 2, y: y))
        triangle.closeSubpath()
        context.fill(triangle, with: .color(AppColor.secondary))

        // "買" 標籤
        let text = Text("買").font(.system(size: 9, weight: .bold, design: .rounded)).foregroundColor(AppColor.secondary)
        context.draw(context.resolve(text), at: CGPoint(x: x, y: min(y + 7, area.maxY)), anchor: .center)
    }

    /// 庫存總覽用：多筆買入標記
    private func drawBuyMarkers(context: GraphicsContext, layout: ChartLayout, area: CGRect) {
        for marker in layout.buyIndices {
            let idx = marker.index
            guard idx >= 0, idx < vm.candles.count else { continue }
            let x = layout.xForIndex(idx, in: area)
            let candle = vm.candles[idx]
            let lowY = layout.yForPrice(candle.low, in: area)
            let y = min(lowY + 12, area.maxY - 4)

            let size: CGFloat = 8
            var triangle = Path()
            triangle.move(to: CGPoint(x: x, y: y - size))
            triangle.addLine(to: CGPoint(x: x - size / 2, y: y))
            triangle.addLine(to: CGPoint(x: x + size / 2, y: y))
            triangle.closeSubpath()
            context.fill(triangle, with: .color(AppColor.secondary))

            let text = Text("買").font(.system(size: 9, weight: .bold, design: .rounded)).foregroundColor(AppColor.secondary)
            context.draw(context.resolve(text), at: CGPoint(x: x, y: min(y + 7, area.maxY)), anchor: .center)
        }
    }

    private func drawSellMarker(context: GraphicsContext, layout: ChartLayout, area: CGRect) {
        guard let idx = layout.sellIndex else { return }
        let x = layout.xForIndex(idx, in: area)
        let candle = vm.candles[idx]
        let highY = layout.yForPrice(candle.high, in: area)

        // 確保標記在可視範圍內（向上偏移，但不超出區域）
        let y = max(highY - 12, area.minY + 4)

        let isProfit = (vm.investment?.sellPrice ?? 0) >= (vm.investment?.buyPrice ?? 0)
        let color = isProfit ? AppColor.softUp : AppColor.softDown

        // 下三角
        let size: CGFloat = 8
        var triangle = Path()
        triangle.move(to: CGPoint(x: x, y: y + size))
        triangle.addLine(to: CGPoint(x: x - size / 2, y: y))
        triangle.addLine(to: CGPoint(x: x + size / 2, y: y))
        triangle.closeSubpath()
        context.fill(triangle, with: .color(color))

        // "賣" 標籤
        let text = Text("賣").font(.system(size: 9, weight: .bold, design: .rounded)).foregroundColor(color)
        context.draw(context.resolve(text), at: CGPoint(x: x, y: max(y - 7, area.minY)), anchor: .center)
    }

    // MARK: - Right-Side Annotation Badges

    /// 在圖表右側繪製標註徽章，自動避免重疊
    /// 包含：停損線、計畫進場線、買入價、賣出價
    private func drawRightAnnotations(context: GraphicsContext, layout: ChartLayout, area: CGRect, size: CGSize) {
        // 收集所有需要右側標註的項目
        struct Annotation {
            let label: String
            let price: Double
            let color: Color
            let idealY: CGFloat
        }

        var annotations: [Annotation] = []

        // 買入價（單筆模式）
        if let buy = vm.buyMarker, layout.buyIndex != nil {
            let buyY = layout.yForPrice(buy.price, in: area)
            annotations.append(Annotation(label: "買 \(formatPrice(buy.price))", price: buy.price, color: AppColor.secondary, idealY: buyY))
        }
        // 買入價（多筆模式：庫存總覽）
        if layout.buyIndex == nil {
            for marker in layout.buyIndices {
                let buyY = layout.yForPrice(marker.price, in: area)
                annotations.append(Annotation(label: "買 \(formatPrice(marker.price))", price: marker.price, color: AppColor.secondary, idealY: buyY))
            }
        }

        // 賣出價
        if let sell = vm.sellMarker, layout.sellIndex != nil {
            let isProfit = (vm.investment?.sellPrice ?? 0) >= (vm.investment?.buyPrice ?? 0)
            let color = isProfit ? AppColor.softUp : AppColor.softDown
            let sellY = layout.yForPrice(sell.price, in: area)
            annotations.append(Annotation(label: "賣 \(formatPrice(sell.price))", price: sell.price, color: color, idealY: sellY))
        }

        // 停損線
        if let sl = vm.stopLossPrice, sl > 0, sl >= layout.priceMin, sl <= layout.priceMax {
            let slY = layout.yForPrice(sl, in: area)
            annotations.append(Annotation(label: "停損 \(formatPrice(sl))", price: sl, color: AppColor.softDown, idealY: slY))
        }

        // 計畫進場線
        if let pe = vm.plannedEntryPrice, pe > 0, pe >= layout.priceMin, pe <= layout.priceMax {
            let peY = layout.yForPrice(pe, in: area)
            annotations.append(Annotation(label: "計畫 \(formatPrice(pe))", price: pe, color: AppColor.textSecondary, idealY: peY))
        }

        guard !annotations.isEmpty else { return }

        // 按 idealY 排序（由上到下）
        let sorted = annotations.sorted { $0.idealY < $1.idealY }

        // 智慧排列：確保相鄰標籤間距至少 14pt
        let minSpacing: CGFloat = 14
        var adjustedYs = sorted.map { $0.idealY }

        // 從上到下推開重疊的標籤
        for i in 1..<adjustedYs.count {
            let gap = adjustedYs[i] - adjustedYs[i - 1]
            if gap < minSpacing {
                adjustedYs[i] = adjustedYs[i - 1] + minSpacing
            }
        }

        // 如果底部超出，從下往上回推
        let maxY = area.maxY - 2
        if let last = adjustedYs.last, last > maxY {
            let overflow = last - maxY
            for i in (0..<adjustedYs.count).reversed() {
                adjustedYs[i] -= overflow
            }
            // 再次從上到下確保間距
            let topLimit = area.minY + 2
            if adjustedYs[0] < topLimit {
                adjustedYs[0] = topLimit
            }
            for i in 1..<adjustedYs.count {
                if adjustedYs[i] < adjustedYs[i - 1] + minSpacing {
                    adjustedYs[i] = adjustedYs[i - 1] + minSpacing
                }
            }
        }

        // 繪製標籤在圖表右側
        let badgeX = area.maxX + 3
        for (i, annotation) in sorted.enumerated() {
            let y = adjustedYs[i]

            // 從水平線連接到標籤的小連接線
            let lineY = annotation.idealY
            if abs(lineY - y) > 2 {
                var connector = Path()
                connector.move(to: CGPoint(x: area.maxX, y: lineY))
                connector.addLine(to: CGPoint(x: area.maxX + 2, y: y))
                context.stroke(connector, with: .color(annotation.color.opacity(0.5)), lineWidth: 0.5)
            }

            let text = Text(annotation.label)
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .foregroundColor(annotation.color)
            context.draw(context.resolve(text), at: CGPoint(x: badgeX, y: y), anchor: .leading)
        }
    }

    private func drawPriceAxis(context: GraphicsContext, layout: ChartLayout, size: CGSize, area: CGRect) {
        let steps = 4
        for i in 0...steps {
            let ratio = Double(i) / Double(steps)
            let price = layout.priceMax - ratio * layout.priceRange
            let y = layout.yForPrice(price, in: area)
            let priceStr = price >= 100
                ? String(format: "%.0f", price)
                : String(format: "%.1f", price)
            let text = Text(priceStr)
                .font(.system(size: 9, design: .rounded))
                .foregroundColor(AppColor.textSecondary)
            context.draw(context.resolve(text), at: CGPoint(x: area.minX - 4, y: y), anchor: .trailing)
        }
    }

    // MARK: - MA Line Drawing

    private func drawMALine(
        context: GraphicsContext,
        values: [Double?],
        color: Color,
        layout: ChartLayout,
        area: CGRect
    ) {
        var path = Path()
        var started = false

        for (i, maValue) in values.enumerated() {
            guard let value = maValue else {
                started = false
                continue
            }
            let point = CGPoint(
                x: layout.xForIndex(i, in: area),
                y: layout.yForPrice(value, in: area)
            )
            if started {
                path.addLine(to: point)
            } else {
                path.move(to: point)
                started = true
            }
        }

        context.stroke(path, with: .color(color), lineWidth: 1.5)
    }

    private func drawMALegend(context: GraphicsContext, area: CGRect) {
        let y = area.minY + 2
        let ma5Text = Text("MA5")
            .font(.system(size: 8, weight: .medium, design: .rounded))
            .foregroundColor(AppColor.softUp.opacity(0.8))
        context.draw(context.resolve(ma5Text),
                     at: CGPoint(x: area.minX + 2, y: y), anchor: .topLeading)

        let ma20Text = Text("MA20")
            .font(.system(size: 8, weight: .medium, design: .rounded))
            .foregroundColor(AppColor.softDown.opacity(0.8))
        context.draw(context.resolve(ma20Text),
                     at: CGPoint(x: area.minX + 28, y: y), anchor: .topLeading)
    }

    // MARK: - Volume Bars Drawing

    private func drawVolumeBars(context: GraphicsContext, layout: ChartLayout, volArea: CGRect) {
        let bodyWidth = layout.candleWidth * 0.7

        for (i, candle) in vm.candles.enumerated() {
            let x = layout.xForIndex(i, in: volArea)
            let isUp = candle.close >= candle.open
            let color = (isUp ? AppColor.softUp : AppColor.softDown).opacity(0.6)
            let topY = layout.yForVolume(candle.volume, in: volArea)
            let barHeight = max(volArea.maxY - topY, 0.5)
            let barRect = CGRect(
                x: x - bodyWidth / 2,
                y: topY,
                width: bodyWidth,
                height: barHeight
            )
            context.fill(Path(barRect), with: .color(color))
        }
    }

    private func drawVolumeSeparator(context: GraphicsContext, area: CGRect) {
        let y = area.maxY + 2
        var path = Path()
        path.move(to: CGPoint(x: area.minX, y: y))
        path.addLine(to: CGPoint(x: area.maxX, y: y))
        context.stroke(
            path,
            with: .color(AppColor.divider.opacity(0.5)),
            style: StrokeStyle(lineWidth: 0.5)
        )
    }

    // MARK: - Date Axis

    private func dateAxisLabels(layout: ChartLayout) -> some View {
        let candles = vm.candles
        guard !candles.isEmpty else { return AnyView(EmptyView()) }

        let step = max(1, candles.count / 5)
        let indices = stride(from: 0, to: candles.count, by: step).map { $0 }

        return AnyView(
            HStack {
                Spacer().frame(width: 36)
                HStack {
                    ForEach(indices, id: \.self) { i in
                        if i < candles.count {
                            Text(candles[i].dateLabel)
                                .font(.warmCaption2())
                                .foregroundStyle(AppColor.textSecondary)
                        }
                        if i != indices.last {
                            Spacer()
                        }
                    }
                }
                Spacer().frame(width: 4)
            }
            .padding(.top, 4)
        )
    }

    // MARK: - Tooltip

    private func tooltipView(_ candle: CandleItem) -> some View {
        let isUp = candle.close >= candle.open
        let color = isUp ? AppColor.softUp : AppColor.softDown

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Text(candle.dateLabel)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColor.textMain)

                Group {
                    miniLabel("開", value: formatPrice(candle.open))
                    miniLabel("高", value: formatPrice(candle.high), color: AppColor.softUp)
                    miniLabel("低", value: formatPrice(candle.low), color: AppColor.softDown)
                    miniLabel("收", value: formatPrice(candle.close), color: color)
                }

                Spacer()

                Text(formatVolume(candle.volume))
                    .foregroundStyle(AppColor.textSecondary)
            }

            // MA 值（僅開啟時顯示）
            if vm.showMA, let idx = vm.selectedCandleIndex {
                HStack(spacing: 12) {
                    if let ma5Val = vm.ma5[safe: idx] ?? nil {
                        miniLabel("MA5", value: formatPrice(ma5Val),
                                  color: AppColor.softUp.opacity(0.8))
                    }
                    if let ma20Val = vm.ma20[safe: idx] ?? nil {
                        miniLabel("MA20", value: formatPrice(ma20Val),
                                  color: AppColor.softDown.opacity(0.8))
                    }
                    Spacer()
                }
            }
        }
        .font(.warmCaption2())
        .padding(8)
        .background(AppColor.background.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func miniLabel(_ title: String, value: String, color: Color = AppColor.textMain) -> some View {
        HStack(spacing: 1) {
            Text(title)
                .foregroundStyle(AppColor.textSecondary)
            Text(value)
                .foregroundStyle(color)
        }
    }

    private func formatPrice(_ price: Double) -> String {
        price >= 100 ? String(format: "%.0f", price) : String(format: "%.2f", price)
    }

    private func formatVolume(_ volume: Int) -> String {
        if volume >= 1_000_000 {
            return String(format: "%.1fM", Double(volume) / 1_000_000)
        } else if volume >= 1_000 {
            return String(format: "%.0fK", Double(volume) / 1_000)
        }
        return "\(volume)"
    }
}

// MARK: - Chart Layout Calculator

/// 計算圖表佈局：座標轉換、蠟燭寬度、買賣標記位置
private struct ChartLayout {
    let candles: [CandleItem]
    let priceMin: Double
    let priceMax: Double
    let priceRange: Double
    let candleWidth: CGFloat
    let buyIndex: Int?
    /// 多筆買入標記的 index（庫存總覽用）
    let buyIndices: [(index: Int, price: Double)]
    let sellIndex: Int?
    let showVolume: Bool
    let volumeMax: Int

    private static let insets = EdgeInsets(top: 8, leading: 40, bottom: 4, trailing: 40)
    private static let volumeHeight: CGFloat = 56
    private static let volumeGap: CGFloat = 4

    init(candles: [CandleItem], vm: KLineChartViewModel) {
        self.candles = candles
        self.showVolume = vm.showVolume
        self.volumeMax = vm.volumeMax

        // 找最近的蠟燭 index
        self.buyIndex = vm.buyMarker.flatMap { Self.closestIndex(to: $0.date, in: candles) }
        self.buyIndices = vm.buyMarkers.compactMap { marker in
            guard let idx = Self.closestIndex(to: marker.date, in: candles) else { return nil }
            return (index: idx, price: marker.price)
        }
        self.sellIndex = vm.sellMarker.flatMap { Self.closestIndex(to: $0.date, in: candles) }

        // 計算價格範圍（含標記線）
        var lo = candles.map(\.low).min() ?? 0
        var hi = candles.map(\.high).max() ?? 0

        // 擴展以包含停損線與計畫線
        if let sl = vm.stopLossPrice, sl > 0 { lo = min(lo, sl) }
        if let pe = vm.plannedEntryPrice, pe > 0 {
            lo = min(lo, pe)
            hi = max(hi, pe)
        }
        // 擴展以包含所有買入標記
        for marker in vm.buyMarkers {
            lo = min(lo, marker.price)
            hi = max(hi, marker.price)
        }
        if let sell = vm.sellMarker {
            lo = min(lo, sell.price)
            hi = max(hi, sell.price)
        }

        let range = hi - lo
        let padding = range * 0.08
        self.priceMin = lo - padding
        self.priceMax = hi + padding
        self.priceRange = self.priceMax - self.priceMin

        // 蠟燭寬度：根據蠟燭數量動態計算，限制在 2~10pt
        let count = CGFloat(max(candles.count, 1))
        let estimated = 280.0 / count * 0.8
        self.candleWidth = max(2, min(10, estimated))
    }

    func drawableArea(in size: CGSize) -> CGRect {
        let volumeReserve: CGFloat = showVolume ? Self.volumeHeight + Self.volumeGap : 0
        return CGRect(
            x: Self.insets.leading,
            y: Self.insets.top,
            width: max(1, size.width - Self.insets.leading - Self.insets.trailing),
            height: max(1, size.height - Self.insets.top - Self.insets.bottom - volumeReserve)
        )
    }

    func volumeArea(in size: CGSize) -> CGRect {
        let candleArea = drawableArea(in: size)
        return CGRect(
            x: candleArea.minX,
            y: candleArea.maxY + Self.volumeGap,
            width: candleArea.width,
            height: Self.volumeHeight
        )
    }

    func yForVolume(_ volume: Int, in volArea: CGRect) -> CGFloat {
        guard volumeMax > 0 else { return volArea.maxY }
        let ratio = CGFloat(volume) / CGFloat(volumeMax)
        return volArea.maxY - volArea.height * ratio
    }

    func xForIndex(_ index: Int, in area: CGRect) -> CGFloat {
        guard candles.count > 1 else { return area.midX }
        let spacing = area.width / CGFloat(candles.count)
        return area.minX + spacing * (CGFloat(index) + 0.5)
    }

    func yForPrice(_ price: Double, in area: CGRect) -> CGFloat {
        guard priceRange > 0 else { return area.midY }
        let ratio = (priceMax - price) / priceRange
        return area.minY + area.height * ratio
    }

    func indexForX(_ x: CGFloat, in area: CGRect) -> Int? {
        guard !candles.isEmpty else { return nil }
        let spacing = area.width / CGFloat(candles.count)
        let rawIndex = Int((x - area.minX) / spacing)
        return max(0, min(candles.count - 1, rawIndex))
    }

    private static func closestIndex(to date: Date, in candles: [CandleItem]) -> Int? {
        guard !candles.isEmpty else { return nil }
        var bestIdx = 0
        var bestDiff = abs(candles[0].date.timeIntervalSince(date))
        for (i, candle) in candles.enumerated() {
            let diff = abs(candle.date.timeIntervalSince(date))
            if diff < bestDiff {
                bestDiff = diff
                bestIdx = i
            }
        }
        return bestIdx
    }
}

// MARK: - Safe Array Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview

#Preview {
    let investment = Investment(
        ticker: "2330",
        buyDate: Date(),
        buyPrice: 580.0,
        quantity: 1000,
        buyReason: "突破頸線"
    )
    let journal = TradeJournal(
        investmentID: investment.id,
        market: .tw,
        direction: .long,
        setup: "股價突破頸線",
        plannedEntryPrice: 575.0,
        initialStopLoss: 550.0,
        emotionScore: 3
    )
    return KLineChartView(vm: KLineChartViewModel(investment: investment, journal: journal))
        .padding(16)
        .modelContainer(for: [Investment.self, TradeJournal.self], inMemory: true)
}
