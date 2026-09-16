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
    @State private var markersAppeared = false

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
                indicatorChipBar
                if vm.isDragging, let chIdx = vm.crosshairIndex,
                   chIdx >= 0, chIdx < vm.candles.count {
                    crosshairTooltip(vm.candles[chIdx], index: chIdx)
                } else if let selected = vm.selectedCandle {
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
                Text("\(vm.candles.count) 日")
                    .font(.warmCaption2())
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
    }

    /// 底部指標切換 Chip 列
    private var indicatorChipBar: some View {
        HStack(spacing: 8) {
            indicatorChip("MA5", isOn: vm.showMA5) { vm.showMA5.toggle() }
            indicatorChip("MA20", isOn: vm.showMA20) { vm.showMA20.toggle() }
            indicatorChip("量", isOn: vm.showVolume) { vm.showVolume.toggle() }
            indicatorChip("MACD", isOn: vm.showMACD) { vm.showMACD.toggle() }
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 6)
    }

    private func indicatorChip(_ label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isOn ? AppColor.primary.opacity(0.15) : AppColor.background)
                .foregroundStyle(isOn ? AppColor.primary : AppColor.textSecondary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(isOn ? AppColor.primary.opacity(0.4) : AppColor.divider, lineWidth: 0.5)
                )
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

                // MACD 子圖
                if vm.showMACD {
                    let macdArea = layout.macdArea(in: size)
                    drawMACDSeparator(context: context, layout: layout, size: size)
                    drawMACDChart(context: context, layout: layout, macdArea: macdArea)
                }

                // 蠟燭
                drawCandles(context: context, layout: layout, area: area)

                // MA 均線
                if vm.showMA5 {
                    drawMALine(context: context, values: vm.ma5,
                               color: AppColor.softUp.opacity(0.8), layout: layout, area: area)
                }
                if vm.showMA20 {
                    drawMALine(context: context, values: vm.ma20,
                               color: AppColor.softDown.opacity(0.8), layout: layout, area: area)
                }
                if vm.showMA5 || vm.showMA20 {
                    drawMALegend(context: context, area: area, showMA5: vm.showMA5, showMA20: vm.showMA20)
                }

                // 選中高亮
                if !vm.isDragging, let idx = vm.selectedCandleIndex, idx >= 0, idx < candles.count {
                    let x = layout.xForIndex(idx, in: area)
                    var highlightPath = Path()
                    let highlightBottom = layout.bottomMostY(in: size)
                    highlightPath.move(to: CGPoint(x: x, y: area.minY))
                    highlightPath.addLine(to: CGPoint(x: x, y: highlightBottom))
                    context.stroke(
                        highlightPath,
                        with: .color(AppColor.primary.opacity(0.3)),
                        style: StrokeStyle(lineWidth: 1, dash: [2, 2])
                    )
                }

                // 十字游標（長按拖動時）
                if vm.isDragging, let chIdx = vm.crosshairIndex,
                   chIdx >= 0, chIdx < candles.count {
                    let chCandle = candles[chIdx]
                    let chX = layout.xForIndex(chIdx, in: area)
                    let chY = layout.yForPrice(chCandle.close, in: area)
                    let chBottom = layout.bottomMostY(in: size)
                    let chColor = AppColor.textMain.opacity(0.6)
                    let dashStyle = StrokeStyle(lineWidth: 0.5, dash: [4, 3])

                    // 垂直線
                    var vLine = Path()
                    vLine.move(to: CGPoint(x: chX, y: area.minY))
                    vLine.addLine(to: CGPoint(x: chX, y: chBottom))
                    context.stroke(vLine, with: .color(chColor), style: dashStyle)

                    // 水平線
                    var hLine = Path()
                    hLine.move(to: CGPoint(x: area.minX, y: chY))
                    hLine.addLine(to: CGPoint(x: area.maxX, y: chY))
                    context.stroke(hLine, with: .color(chColor), style: dashStyle)

                    // 右側價格標籤
                    let priceStr = chCandle.close >= 100
                        ? String(format: "%.0f", chCandle.close)
                        : String(format: "%.2f", chCandle.close)
                    let priceBadge = Text(priceStr)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    let badgePt = CGPoint(x: area.maxX + 2, y: chY)
                    // 背景矩形
                    let badgeRect = CGRect(x: badgePt.x, y: badgePt.y - 7, width: 38, height: 14)
                    context.fill(
                        Path(roundedRect: badgeRect, cornerRadius: 3),
                        with: .color(AppColor.textMain.opacity(0.75))
                    )
                    context.draw(context.resolve(priceBadge), at: CGPoint(x: badgeRect.midX, y: badgeRect.midY), anchor: .center)

                    // 頂部日期標籤
                    let dateText = Text(chCandle.dateLabel)
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                    let dateBadgeRect = CGRect(x: chX - 18, y: area.minY - 14, width: 36, height: 13)
                    context.fill(
                        Path(roundedRect: dateBadgeRect, cornerRadius: 3),
                        with: .color(AppColor.textMain.opacity(0.75))
                    )
                    context.draw(context.resolve(dateText), at: CGPoint(x: dateBadgeRect.midX, y: dateBadgeRect.midY), anchor: .center)
                }

                // 買入/賣出標記（改用 SwiftUI overlay 繪製以支援動畫）

                // 右側標註徽章（停損、計畫、買入價、賣出價 — 自動避開重疊）
                drawRightAnnotations(context: context, layout: layout, area: area, size: size)

                // Y 軸價格標籤
                drawPriceAxis(context: context, layout: layout, size: size, area: area)
            }
            .frame(height: layout.canvasHeight)
            .overlay {
                GeometryReader { geo in
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            LongPressGesture(minimumDuration: 0.3)
                                .sequenced(before: DragGesture(minimumDistance: 0))
                                .onChanged { value in
                                    switch value {
                                    case .second(true, let drag):
                                        guard let drag = drag else { return }
                                        let size = geo.size
                                        let layout = ChartLayout(candles: vm.candles, vm: vm)
                                        let area = layout.drawableArea(in: size)
                                        if let idx = layout.indexForX(drag.location.x, in: area) {
                                            vm.isDragging = true
                                            vm.crosshairIndex = idx
                                        }
                                    default:
                                        break
                                    }
                                }
                                .onEnded { _ in
                                    vm.isDragging = false
                                    vm.crosshairIndex = nil
                                }
                        )
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    guard !vm.isDragging else { return }
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
            // 買賣標記 overlay（帶動畫）
            .overlay {
                GeometryReader { geo in
                    let size = geo.size
                    let area = layout.drawableArea(in: size)

                    // 買入標記
                    ForEach(Array(markerPositions(layout: layout, area: area, isBuy: true).enumerated()), id: \.offset) { idx, pos in
                        markerTriangle(isBuy: true, color: AppColor.secondary)
                            .position(x: pos.x, y: pos.y)
                            .scaleEffect(markersAppeared ? 1 : 0.01)
                            .opacity(markersAppeared ? 1 : 0)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.6)
                                .delay(Double(idx) * 0.1),
                                value: markersAppeared
                            )
                    }

                    // 賣出標記
                    if let sellPos = sellMarkerPosition(layout: layout, area: area) {
                        let isProfit = (vm.investment?.sellPrice ?? 0) >= (vm.investment?.buyPrice ?? 0)
                        let color = isProfit ? AppColor.softUp : AppColor.softDown
                        markerTriangle(isBuy: false, color: color)
                            .position(x: sellPos.x, y: sellPos.y)
                            .scaleEffect(markersAppeared ? 1 : 0.01)
                            .opacity(markersAppeared ? 1 : 0)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.6).delay(0.2),
                                value: markersAppeared
                            )
                    }
                }
                .allowsHitTesting(false)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    markersAppeared = true
                }
            }
            .onChange(of: vm.candles.count) {
                markersAppeared = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    markersAppeared = true
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

    // MARK: - Animated Marker Helpers

    /// 計算買入標記位置
    private func markerPositions(layout: ChartLayout, area: CGRect, isBuy: Bool) -> [CGPoint] {
        var positions: [CGPoint] = []

        if isBuy {
            // 單筆買入
            if let idx = layout.buyIndex, idx >= 0, idx < vm.candles.count {
                let x = layout.xForIndex(idx, in: area)
                let lowY = layout.yForPrice(vm.candles[idx].low, in: area)
                let y = min(lowY + 16, area.maxY - 4)
                positions.append(CGPoint(x: x, y: y))
            }
            // 多筆買入
            if layout.buyIndex == nil {
                for marker in layout.buyIndices {
                    let idx = marker.index
                    guard idx >= 0, idx < vm.candles.count else { continue }
                    let x = layout.xForIndex(idx, in: area)
                    let lowY = layout.yForPrice(vm.candles[idx].low, in: area)
                    let y = min(lowY + 16, area.maxY - 4)
                    positions.append(CGPoint(x: x, y: y))
                }
            }
        }

        return positions
    }

    /// 計算賣出標記位置
    private func sellMarkerPosition(layout: ChartLayout, area: CGRect) -> CGPoint? {
        guard let idx = layout.sellIndex, idx >= 0, idx < vm.candles.count else { return nil }
        let x = layout.xForIndex(idx, in: area)
        let highY = layout.yForPrice(vm.candles[idx].high, in: area)
        let y = max(highY - 16, area.minY + 4)
        return CGPoint(x: x, y: y)
    }

    /// 三角形標記 view
    private func markerTriangle(isBuy: Bool, color: Color) -> some View {
        VStack(spacing: 1) {
            if !isBuy {
                Text("賣")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
            Image(systemName: isBuy ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                .font(.system(size: 8))
                .foregroundStyle(color)
            if isBuy {
                Text("買")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
        }
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

    private func drawMALegend(context: GraphicsContext, area: CGRect, showMA5: Bool, showMA20: Bool) {
        let y = area.minY + 2
        var offsetX = area.minX + 2

        if showMA5 {
            let ma5Text = Text("MA5")
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .foregroundColor(AppColor.softUp.opacity(0.8))
            context.draw(context.resolve(ma5Text),
                         at: CGPoint(x: offsetX, y: y), anchor: .topLeading)
            offsetX += 26
        }

        if showMA20 {
            let ma20Text = Text("MA20")
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .foregroundColor(AppColor.softDown.opacity(0.8))
            context.draw(context.resolve(ma20Text),
                         at: CGPoint(x: offsetX, y: y), anchor: .topLeading)
        }
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

    // MARK: - MACD Drawing

    private func drawMACDSeparator(context: GraphicsContext, layout: ChartLayout, size: CGSize) {
        let macdArea = layout.macdArea(in: size)
        let y = macdArea.minY - 2
        var path = Path()
        path.move(to: CGPoint(x: macdArea.minX, y: y))
        path.addLine(to: CGPoint(x: macdArea.maxX, y: y))
        context.stroke(
            path,
            with: .color(AppColor.divider.opacity(0.5)),
            style: StrokeStyle(lineWidth: 0.5)
        )
    }

    private func drawMACDChart(context: GraphicsContext, layout: ChartLayout, macdArea: CGRect) {
        guard vm.macdAbsMax > 0 else { return }
        let bodyWidth = layout.candleWidth * 0.7

        // 零軸
        let zeroY = macdArea.midY
        var zeroPath = Path()
        zeroPath.move(to: CGPoint(x: macdArea.minX, y: zeroY))
        zeroPath.addLine(to: CGPoint(x: macdArea.maxX, y: zeroY))
        context.stroke(
            zeroPath,
            with: .color(AppColor.divider.opacity(0.4)),
            style: StrokeStyle(lineWidth: 0.5, dash: [3, 3])
        )

        // 柱狀圖
        for (i, result) in vm.macdData.enumerated() {
            guard let r = result else { continue }
            let x = layout.xForIndex(i, in: macdArea)
            let barY = layout.yForMACD(r.histogram, in: macdArea)
            let color = r.histogram >= 0 ? AppColor.softUp : AppColor.softDown
            let topY = min(barY, zeroY)
            let barHeight = max(abs(barY - zeroY), 0.5)
            let barRect = CGRect(
                x: x - bodyWidth / 2,
                y: topY,
                width: bodyWidth,
                height: barHeight
            )
            context.fill(Path(barRect), with: .color(color.opacity(0.5)))
        }

        // DIF 線
        drawMACDLine(context: context, layout: layout, macdArea: macdArea,
                     values: vm.macdData.map { $0?.dif },
                     color: AppColor.softUp.opacity(0.9))

        // DEA 線
        drawMACDLine(context: context, layout: layout, macdArea: macdArea,
                     values: vm.macdData.map { $0?.dea },
                     color: AppColor.softDown.opacity(0.9))

        // 左上角圖例
        let difLabel = Text("DIF")
            .font(.system(size: 8, weight: .medium, design: .rounded))
            .foregroundColor(AppColor.softUp.opacity(0.9))
        context.draw(context.resolve(difLabel),
                     at: CGPoint(x: macdArea.minX + 2, y: macdArea.minY + 2), anchor: .topLeading)

        let deaLabel = Text("DEA")
            .font(.system(size: 8, weight: .medium, design: .rounded))
            .foregroundColor(AppColor.softDown.opacity(0.9))
        context.draw(context.resolve(deaLabel),
                     at: CGPoint(x: macdArea.minX + 26, y: macdArea.minY + 2), anchor: .topLeading)
    }

    private func drawMACDLine(
        context: GraphicsContext,
        layout: ChartLayout,
        macdArea: CGRect,
        values: [Double?],
        color: Color
    ) {
        var path = Path()
        var started = false

        for (i, value) in values.enumerated() {
            guard let v = value else {
                started = false
                continue
            }
            let point = CGPoint(
                x: layout.xForIndex(i, in: macdArea),
                y: layout.yForMACD(v, in: macdArea)
            )
            if started {
                path.addLine(to: point)
            } else {
                path.move(to: point)
                started = true
            }
        }

        context.stroke(path, with: .color(color), lineWidth: 1)
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

    // MARK: - Crosshair Tooltip

    private func crosshairTooltip(_ candle: CandleItem, index: Int) -> some View {
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

            if vm.showMA5 || vm.showMA20 {
                HStack(spacing: 12) {
                    if vm.showMA5, let ma5Val = vm.ma5[safe: index] ?? nil {
                        miniLabel("MA5", value: formatPrice(ma5Val),
                                  color: AppColor.softUp.opacity(0.8))
                    }
                    if vm.showMA20, let ma20Val = vm.ma20[safe: index] ?? nil {
                        miniLabel("MA20", value: formatPrice(ma20Val),
                                  color: AppColor.softDown.opacity(0.8))
                    }
                    Spacer()
                }
            }

            if vm.showMACD, let macdResult = vm.macdData[safe: index] ?? nil {
                macdTooltipRow(macdResult)
            }
        }
        .font(.warmCaption2())
        .padding(8)
        .background(AppColor.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.inner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.inner, style: .continuous)
                .strokeBorder(AppColor.primary.opacity(0.2), lineWidth: 0.5)
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
            if (vm.showMA5 || vm.showMA20), let idx = vm.selectedCandleIndex {
                HStack(spacing: 12) {
                    if vm.showMA5, let ma5Val = vm.ma5[safe: idx] ?? nil {
                        miniLabel("MA5", value: formatPrice(ma5Val),
                                  color: AppColor.softUp.opacity(0.8))
                    }
                    if vm.showMA20, let ma20Val = vm.ma20[safe: idx] ?? nil {
                        miniLabel("MA20", value: formatPrice(ma20Val),
                                  color: AppColor.softDown.opacity(0.8))
                    }
                    Spacer()
                }
            }

            if vm.showMACD, let idx = vm.selectedCandleIndex,
               let macdResult = vm.macdData[safe: idx] ?? nil {
                macdTooltipRow(macdResult)
            }
        }
        .font(.warmCaption2())
        .padding(8)
        .background(AppColor.background.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.inner, style: .continuous))
    }

    private func miniLabel(_ title: String, value: String, color: Color = AppColor.textMain) -> some View {
        HStack(spacing: 1) {
            Text(title)
                .foregroundStyle(AppColor.textSecondary)
            Text(value)
                .foregroundStyle(color)
        }
    }

    private func macdTooltipRow(_ result: TechnicalIndicators.MACDResult) -> some View {
        HStack(spacing: 12) {
            miniLabel("DIF", value: String(format: "%.2f", result.dif),
                      color: AppColor.softUp.opacity(0.9))
            miniLabel("DEA", value: String(format: "%.2f", result.dea),
                      color: AppColor.softDown.opacity(0.9))
            let histColor = result.histogram >= 0 ? AppColor.softUp : AppColor.softDown
            miniLabel("柱", value: String(format: "%.2f", result.histogram),
                      color: histColor)
            Spacer()
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
    let showMACD: Bool
    let macdAbsMax: Double

    private static let insets = EdgeInsets(top: 8, leading: 40, bottom: 4, trailing: 40)
    private static let volumeHeight: CGFloat = 56
    private static let volumeGap: CGFloat = 4
    private static let macdHeight: CGFloat = 60
    private static let macdGap: CGFloat = 4

    /// 計算 Canvas 總高度
    var canvasHeight: CGFloat {
        var h: CGFloat = 220
        if showVolume { h += Self.volumeHeight + Self.volumeGap }
        if showMACD { h += Self.macdHeight + Self.macdGap }
        return h
    }

    init(candles: [CandleItem], vm: KLineChartViewModel) {
        self.candles = candles
        self.showVolume = vm.showVolume
        self.volumeMax = vm.volumeMax
        self.showMACD = vm.showMACD
        self.macdAbsMax = vm.macdAbsMax

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
        let macdReserve: CGFloat = showMACD ? Self.macdHeight + Self.macdGap : 0
        return CGRect(
            x: Self.insets.leading,
            y: Self.insets.top,
            width: max(1, size.width - Self.insets.leading - Self.insets.trailing),
            height: max(1, size.height - Self.insets.top - Self.insets.bottom - volumeReserve - macdReserve)
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

    func macdArea(in size: CGSize) -> CGRect {
        // MACD 區在成交量下方（若有），否則在價格區下方
        let prevBottom: CGFloat
        if showVolume {
            prevBottom = volumeArea(in: size).maxY
        } else {
            prevBottom = drawableArea(in: size).maxY
        }
        return CGRect(
            x: drawableArea(in: size).minX,
            y: prevBottom + Self.macdGap,
            width: drawableArea(in: size).width,
            height: Self.macdHeight
        )
    }

    func yForMACD(_ value: Double, in macdArea: CGRect) -> CGFloat {
        guard macdAbsMax > 0 else { return macdArea.midY }
        let ratio = value / macdAbsMax
        return macdArea.midY - macdArea.height / 2 * ratio
    }

    /// 取得最底部子圖的 maxY（用於十字線/選中高亮延伸）
    func bottomMostY(in size: CGSize) -> CGFloat {
        if showMACD { return macdArea(in: size).maxY }
        if showVolume { return volumeArea(in: size).maxY }
        return drawableArea(in: size).maxY
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
