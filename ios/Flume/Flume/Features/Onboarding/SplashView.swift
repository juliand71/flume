import SwiftUI

// Flume splash screen.
// Basin sits at the top of the screen, five glass tubes curve down from
// spouts on its underside and pour water into each letter of FLUME, which
// fills from the bottom up in sequence (F → L → U → M → E).
//
// Timeline (ms, total 5500):
//   0–700      basin slides in from above
//   600–1300   basin fills with water
//   1200–1800  tubes draw down from basin underside
//   1700–4400  water flows down tubes; letters fill staggered F→L→U→M→E
//   4200–5000  tagline fades in
//   4800–5500  tap-to-begin pulse settles

struct SplashView: View {
    let onFinished: () -> Void

    @State private var startDate = Date()
    @State private var hasFinished = false

    private let totalDuration: TimeInterval = 5.5
    private let postRollDelay: TimeInterval = 0.4

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            let elapsed = max(0, context.date.timeIntervalSince(startDate))
            let ms = elapsed * 1000
            let t = min(1.0, elapsed / totalDuration)

            Canvas { ctx, size in
                drawSplash(ctx: &ctx, size: size, ms: ms, t: t)
            }
        }
        .background(SplashPalette.bg1)
        .ignoresSafeArea()
        .onAppear {
            startDate = Date()
            DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration + postRollDelay) {
                guard !hasFinished else { return }
                hasFinished = true
                onFinished()
            }
        }
    }
}

// MARK: - Design canvas

private let DesignW: CGFloat = 402
private let DesignH: CGFloat = 874

private let LetterCount = 5
private let LetterW: CGFloat = 56
private let LetterH: CGFloat = 110
private let LetterGap: CGFloat = 8
private let LettersTotalW: CGFloat = CGFloat(LetterCount) * LetterW + CGFloat(LetterCount - 1) * LetterGap
private let LettersLeft: CGFloat = (DesignW - LettersTotalW) / 2
private let LetterTop: CGFloat = 510
private let LetterBottom: CGFloat = LetterTop + LetterH
private let LetterStrokeT: CGFloat = 14

private let BasinW: CGFloat = 240
private let BasinH: CGFloat = 120
private let BasinX: CGFloat = (DesignW - BasinW) / 2
private let BasinY: CGFloat = 200
private let BasinSpoutY: CGFloat = BasinY + BasinH - 8
private let BasinBottomPad: CGFloat = 30

private let TubeW: CGFloat = 14
private let Letters = ["F", "L", "U", "M", "E"]

private func letterX(_ i: Int) -> CGFloat { LettersLeft + CGFloat(i) * (LetterW + LetterGap) }
private func letterEntryX(_ i: Int) -> CGFloat { letterX(i) + LetterStrokeT / 2 }

private func spoutX(_ i: Int) -> CGFloat {
    let left = BasinX + BasinBottomPad
    let right = BasinX + BasinW - BasinBottomPad
    return left + (CGFloat(i) + 0.5) / CGFloat(LetterCount) * (right - left)
}

// MARK: - Palette

private enum SplashPalette {
    static let bg1 = Color(red: 0x0b / 255, green: 0x1a / 255, blue: 0x2b / 255)
    static let bg2 = Color(red: 0x14 / 255, green: 0x30 / 255, blue: 0x4d / 255)
    static let water = Color(red: 0x4e / 255, green: 0xa8 / 255, blue: 0xff / 255)
    static let waterHi = Color(red: 0xae / 255, green: 0xe2 / 255, blue: 0xff / 255)
    static let waterDeep = Color(red: 0x1f / 255, green: 0x5f / 255, blue: 0xa8 / 255)
    static let foam = Color(red: 0xea / 255, green: 0xf6 / 255, blue: 0xff / 255)
    static let muted = Color(red: 0xea / 255, green: 0xf6 / 255, blue: 0xff / 255).opacity(0.6)
    static let basin = Color(red: 0xdc / 255, green: 0xc8 / 255, blue: 0x9a / 255)
    static let basinShade = Color(red: 0x8a / 255, green: 0x6c / 255, blue: 0x3c / 255)
    static let tube = Color(red: 0xea / 255, green: 0xf6 / 255, blue: 0xff / 255).opacity(0.10)
    static let tubeStroke = Color(red: 0xea / 255, green: 0xf6 / 255, blue: 0xff / 255).opacity(0.18)
    static let letterEmpty = Color(red: 0xea / 255, green: 0xf6 / 255, blue: 0xff / 255).opacity(0.06)
}

// MARK: - Easing helpers

private func clamp01(_ x: Double) -> Double { max(0, min(1, x)) }
private func seg(_ t: Double, _ a: Double, _ b: Double) -> Double { clamp01((t - a) / (b - a)) }
private func easeOutCubic(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
private func easeInOutCubic(_ x: Double) -> Double {
    x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
}
private func easeOutQuart(_ x: Double) -> Double { 1 - pow(1 - x, 4) }
private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: Double) -> CGFloat { a + (b - a) * CGFloat(t) }

// MARK: - Top-level draw

private func drawSplash(ctx: inout GraphicsContext, size: CGSize, ms: Double, t: Double) {
    // Aspect-fill the design canvas onto whatever the device gives us.
    let scale = max(size.width / DesignW, size.height / DesignH)
    let dx = (size.width - DesignW * scale) / 2
    let dy = (size.height - DesignH * scale) / 2
    ctx.translateBy(x: dx, y: dy)
    ctx.scaleBy(x: scale, y: scale)

    drawBackground(ctx: &ctx)

    let pBasinIn = easeOutCubic(seg(ms, 0, 700))
    let pBasinFill = easeInOutCubic(seg(ms, 600, 1300))
    let pTubes = easeOutCubic(seg(ms, 1200, 1800))
    let pTagline = easeOutCubic(seg(ms, 4200, 5000))
    let pTap = easeOutCubic(seg(ms, 4800, 5500))

    let fillStart: Double = 1700
    let fillSpan: Double = 700
    let stagger: Double = 320

    if pBasinIn > 0 {
        var basinCtx = ctx
        basinCtx.opacity = pBasinIn
        basinCtx.translateBy(x: 0, y: (1 - pBasinIn) * -60)
        drawBasin(ctx: &basinCtx, pBasinFill: pBasinFill, t: t)
    }

    if pTubes > 0 {
        drawTubes(ctx: &ctx, pTubes: pTubes)
    }

    drawTubeWater(ctx: &ctx, ms: ms, fillStart: fillStart, stagger: stagger)

    drawLetterVessels(ctx: &ctx)

    for i in 0..<LetterCount {
        let s = fillStart + Double(i) * stagger
        let p = easeOutQuart(seg(ms, s, s + fillSpan))
        if p > 0 {
            drawLetterWater(ctx: &ctx, index: i, fillP: p, t: t)
        }
    }

    if pTagline > 0 {
        var tCtx = ctx
        tCtx.opacity = pTagline
        let tagline = Text("CHANNEL EVERY DOLLAR")
            .font(.system(size: 11, weight: .regular, design: .default))
            .tracking(4)
            .foregroundColor(SplashPalette.muted)
        tCtx.draw(tagline, at: CGPoint(x: DesignW / 2, y: LetterBottom + 48), anchor: .center)
    }

    if pTap > 0 {
        let pulse = 0.5 + 0.5 * sin(ms * 0.005)
        var tCtx = ctx
        tCtx.opacity = pTap * pulse
        let hint = Text("Tap to begin")
            .font(.system(size: 13, weight: .regular, design: .default))
            .foregroundColor(SplashPalette.muted)
        tCtx.draw(hint, at: CGPoint(x: DesignW / 2, y: DesignH - 70), anchor: .center)
    }
}

// MARK: - Background

private func drawBackground(ctx: inout GraphicsContext) {
    let bg = GraphicsContext.Shading.radialGradient(
        Gradient(colors: [SplashPalette.bg2, SplashPalette.bg1]),
        center: CGPoint(x: DesignW / 2, y: DesignH * 0.2),
        startRadius: 0,
        endRadius: DesignH * 0.9
    )
    ctx.fill(Path(CGRect(x: 0, y: 0, width: DesignW, height: DesignH)), with: bg)

    let lineColor = GraphicsContext.Shading.color(SplashPalette.foam.opacity(0.04))
    for i in 0..<14 {
        let y = CGFloat(i + 1) * DesignH / 15
        var p = Path()
        p.move(to: CGPoint(x: 0, y: y))
        p.addLine(to: CGPoint(x: DesignW, y: y))
        ctx.stroke(p, with: lineColor, lineWidth: 0.5)
    }
}

// MARK: - Basin

private func drawBasin(ctx: inout GraphicsContext, pBasinFill: Double, t: Double) {
    // Drop shadow.
    let shadowRect = CGRect(
        x: DesignW / 2 - (BasinW / 2 + 10),
        y: BasinY + BasinH + 20 - 6,
        width: BasinW + 20,
        height: 12
    )
    var shadowCtx = ctx
    shadowCtx.addFilter(.blur(radius: 4))
    shadowCtx.fill(Path(ellipseIn: shadowRect), with: .color(.black.opacity(0.5)))

    // Body.
    let body = basinBodyPath()
    let bodyShading = GraphicsContext.Shading.linearGradient(
        Gradient(colors: [SplashPalette.basin, SplashPalette.basinShade]),
        startPoint: CGPoint(x: 0, y: BasinY),
        endPoint: CGPoint(x: 0, y: BasinY + BasinH)
    )
    ctx.fill(body, with: bodyShading)
    ctx.stroke(body, with: .color(.black.opacity(0.3)), lineWidth: 1.5)

    // Water inside basin (clipped to interior).
    var waterCtx = ctx
    waterCtx.clip(to: basinInteriorPath())

    let surfaceY = lerp(BasinY + BasinH - 8, BasinY + 22, pBasinFill)
    let waterRect = CGRect(x: BasinX - 8, y: surfaceY, width: BasinW + 16, height: BasinH + 20)
    let waterShading = GraphicsContext.Shading.linearGradient(
        Gradient(colors: [SplashPalette.waterHi, SplashPalette.water, SplashPalette.waterDeep]),
        startPoint: CGPoint(x: 0, y: surfaceY),
        endPoint: CGPoint(x: 0, y: surfaceY + BasinH + 20)
    )
    waterCtx.fill(Path(waterRect), with: waterShading)

    // Surface ripple line.
    var wave = Path()
    let n = 24
    let phase = t * .pi * 6
    for i in 0...n {
        let px = BasinX + BasinW * CGFloat(i) / CGFloat(n)
        let py = surfaceY
            + sin(CGFloat(i) * 0.6 + CGFloat(phase)) * 1.4
            + sin(CGFloat(i) * 0.21 + CGFloat(phase) * 0.8) * 1.0
        if i == 0 { wave.move(to: CGPoint(x: px, y: py)) } else { wave.addLine(to: CGPoint(x: px, y: py)) }
    }
    waterCtx.stroke(wave, with: .color(SplashPalette.waterHi.opacity(0.7)), lineWidth: 1.5)

    // Surface shine.
    let shineRect = CGRect(x: BasinX - 8, y: surfaceY, width: BasinW + 16, height: 20)
    let shine = GraphicsContext.Shading.linearGradient(
        Gradient(colors: [SplashPalette.foam.opacity(0.6), SplashPalette.foam.opacity(0)]),
        startPoint: CGPoint(x: 0, y: surfaceY),
        endPoint: CGPoint(x: 0, y: surfaceY + 20)
    )
    waterCtx.fill(Path(shineRect), with: shine)

    // Rim highlight.
    var rim = Path()
    rim.move(to: CGPoint(x: BasinX + 8, y: BasinY + 12))
    rim.addQuadCurve(
        to: CGPoint(x: BasinX + BasinW - 8, y: BasinY + 12),
        control: CGPoint(x: BasinX + BasinW / 2, y: BasinY - 2)
    )
    ctx.stroke(rim, with: .color(.white.opacity(0.35)), lineWidth: 1.5)

    // Spouts under the basin.
    for i in 0..<LetterCount {
        let cx = spoutX(i)
        var spout = Path()
        spout.move(to: CGPoint(x: cx - 8, y: BasinSpoutY - 2))
        spout.addQuadCurve(
            to: CGPoint(x: cx + 8, y: BasinSpoutY - 2),
            control: CGPoint(x: cx, y: BasinSpoutY + 8)
        )
        spout.closeSubpath()
        ctx.fill(spout, with: bodyShading)
        ctx.stroke(spout, with: .color(.black.opacity(0.3)), lineWidth: 1)
    }
}

private func basinBodyPath() -> Path {
    let x = BasinX, y = BasinY, w = BasinW, h = BasinH
    let tilt: CGFloat = 22
    var p = Path()
    p.move(to: CGPoint(x: x, y: y + 6))
    p.addQuadCurve(to: CGPoint(x: x + w, y: y + 6), control: CGPoint(x: x + w / 2, y: y - 10))
    p.addLine(to: CGPoint(x: x + w - tilt, y: y + h))
    p.addQuadCurve(to: CGPoint(x: x + tilt, y: y + h), control: CGPoint(x: x + w / 2, y: y + h + 16))
    p.closeSubpath()
    return p
}

private func basinInteriorPath() -> Path {
    let x = BasinX, y = BasinY, w = BasinW, h = BasinH
    let tilt: CGFloat = 26
    let inset: CGFloat = 6
    var p = Path()
    p.move(to: CGPoint(x: x + inset, y: y + 14))
    p.addQuadCurve(to: CGPoint(x: x + w - inset, y: y + 14), control: CGPoint(x: x + w / 2, y: y + 2))
    p.addLine(to: CGPoint(x: x + w - tilt, y: y + h - 6))
    p.addQuadCurve(to: CGPoint(x: x + tilt, y: y + h - 6), control: CGPoint(x: x + w / 2, y: y + h + 8))
    p.closeSubpath()
    return p
}

// MARK: - Tubes

private func tubePath(_ i: Int) -> Path {
    let sx = spoutX(i), sy = BasinSpoutY
    let ex = letterEntryX(i), ey = LetterTop + 6
    let midY = (sy + ey) / 2
    var p = Path()
    p.move(to: CGPoint(x: sx, y: sy))
    p.addCurve(
        to: CGPoint(x: ex, y: ey),
        control1: CGPoint(x: sx, y: midY),
        control2: CGPoint(x: ex, y: midY)
    )
    return p
}

private func drawTubes(ctx: inout GraphicsContext, pTubes: Double) {
    var c = ctx
    c.opacity = pTubes
    for i in 0..<LetterCount {
        let drawn = tubePath(i).trimmedPath(from: 0, to: pTubes)
        c.stroke(
            drawn,
            with: .color(SplashPalette.tubeStroke),
            style: StrokeStyle(lineWidth: TubeW + 1, lineCap: .round)
        )
        c.stroke(
            drawn,
            with: .color(SplashPalette.tube),
            style: StrokeStyle(lineWidth: TubeW - 1, lineCap: .round)
        )
    }
}

private func drawTubeWater(ctx: inout GraphicsContext, ms: Double, fillStart: Double, stagger: Double) {
    for i in 0..<LetterCount {
        let startMs = fillStart + Double(i) * stagger - 220
        let progress = clamp01((ms - startMs) / 280)
        guard progress > 0 else { continue }

        let drawn = tubePath(i).trimmedPath(from: 0, to: progress)
        let shading = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [SplashPalette.waterHi, SplashPalette.water, SplashPalette.waterDeep]),
            startPoint: CGPoint(x: 0, y: BasinSpoutY),
            endPoint: CGPoint(x: 0, y: LetterTop + 6)
        )
        var c = ctx
        c.opacity = 0.95
        c.stroke(
            drawn,
            with: shading,
            style: StrokeStyle(lineWidth: TubeW - 4, lineCap: .round)
        )
    }
}

// MARK: - Letters

private func drawLetterVessels(ctx: inout GraphicsContext) {
    for i in 0..<LetterCount {
        let path = letterPath(ch: Letters[i], x: letterX(i), y: LetterTop, w: LetterW, h: LetterH)
        ctx.fill(path, with: .color(SplashPalette.letterEmpty))
    }
}

private func drawLetterWater(ctx: inout GraphicsContext, index i: Int, fillP: Double, t: Double) {
    let lx = letterX(i)
    let top = LetterTop + 4
    let surfaceY = lerp(LetterBottom, top, fillP)

    var c = ctx
    c.clip(to: letterPath(ch: Letters[i], x: lx, y: LetterTop, w: LetterW, h: LetterH))

    let n = 12
    let phase = t * .pi * 5 + Double(i) * 0.7
    var wavePts: [CGPoint] = []
    wavePts.reserveCapacity(n + 1)
    for j in 0...n {
        let px = lx - 2 + (LetterW + 4) * CGFloat(j) / CGFloat(n)
        let py = surfaceY
            + sin(CGFloat(j) * 0.9 + CGFloat(phase)) * 1.6
            + sin(CGFloat(j) * 0.4 + CGFloat(phase) * 0.7) * 0.8
        wavePts.append(CGPoint(x: px, y: py))
    }

    var waterBody = Path()
    waterBody.move(to: wavePts[0])
    for pt in wavePts.dropFirst() { waterBody.addLine(to: pt) }
    waterBody.addLine(to: CGPoint(x: lx + LetterW + 2, y: surfaceY + 200))
    waterBody.addLine(to: CGPoint(x: lx - 2, y: surfaceY + 200))
    waterBody.closeSubpath()

    let shading = GraphicsContext.Shading.linearGradient(
        Gradient(colors: [SplashPalette.waterHi, SplashPalette.water, SplashPalette.waterDeep]),
        startPoint: CGPoint(x: 0, y: surfaceY),
        endPoint: CGPoint(x: 0, y: surfaceY + LetterH)
    )
    c.fill(waterBody, with: shading)

    var waveOutline = Path()
    waveOutline.move(to: wavePts[0])
    for pt in wavePts.dropFirst() { waveOutline.addLine(to: pt) }
    c.stroke(waveOutline, with: .color(SplashPalette.waterHi.opacity(0.85)), lineWidth: 1.2)

    let shineRect = CGRect(x: lx - 4, y: surfaceY, width: LetterW + 8, height: 14)
    let shine = GraphicsContext.Shading.linearGradient(
        Gradient(colors: [SplashPalette.foam.opacity(0.6), SplashPalette.foam.opacity(0)]),
        startPoint: CGPoint(x: 0, y: surfaceY),
        endPoint: CGPoint(x: 0, y: surfaceY + 14)
    )
    c.fill(Path(shineRect), with: shine)
}

private func letterPath(ch: String, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) -> Path {
    let t = LetterStrokeT
    var path = Path()

    switch ch {
    case "F":
        path.addRect(CGRect(x: x, y: y, width: t, height: h))
        path.addRect(CGRect(x: x, y: y, width: w, height: t))
        path.addRect(CGRect(x: x, y: y + h * 0.45, width: w * 0.78, height: t))

    case "L":
        path.addRect(CGRect(x: x, y: y, width: t, height: h))
        path.addRect(CGRect(x: x, y: y + h - t, width: w, height: t))

    case "U":
        let r = w / 2
        path.move(to: CGPoint(x: x, y: y))
        path.addLine(to: CGPoint(x: x + t, y: y))
        path.addLine(to: CGPoint(x: x + t, y: y + h - r))
        path.addQuadCurve(
            to: CGPoint(x: x + r, y: y + h - t),
            control: CGPoint(x: x + t, y: y + h - t)
        )
        path.addLine(to: CGPoint(x: x + w - r, y: y + h - t))
        path.addQuadCurve(
            to: CGPoint(x: x + w - t, y: y + h - r),
            control: CGPoint(x: x + w - t, y: y + h - t)
        )
        path.addLine(to: CGPoint(x: x + w - t, y: y))
        path.addLine(to: CGPoint(x: x + w, y: y))
        path.addLine(to: CGPoint(x: x + w, y: y + h - r))
        path.addQuadCurve(
            to: CGPoint(x: x + w - r, y: y + h),
            control: CGPoint(x: x + w, y: y + h)
        )
        path.addLine(to: CGPoint(x: x + r, y: y + h))
        path.addQuadCurve(
            to: CGPoint(x: x, y: y + h - r),
            control: CGPoint(x: x, y: y + h)
        )
        path.closeSubpath()

    case "M":
        path.addRect(CGRect(x: x, y: y, width: t, height: h))
        path.addRect(CGRect(x: x + w - t, y: y, width: t, height: h))
        let cx = x + w / 2
        let apex = y + h * 0.55
        path.move(to: CGPoint(x: x + t / 2, y: y))
        path.addLine(to: CGPoint(x: x + t + t / 2, y: y))
        path.addLine(to: CGPoint(x: cx + t / 2, y: apex))
        path.addLine(to: CGPoint(x: cx - t / 2, y: apex))
        path.closeSubpath()
        path.move(to: CGPoint(x: x + w - t - t / 2, y: y))
        path.addLine(to: CGPoint(x: x + w - t / 2, y: y))
        path.addLine(to: CGPoint(x: cx + t / 2, y: apex))
        path.addLine(to: CGPoint(x: cx - t / 2, y: apex))
        path.closeSubpath()

    case "E":
        path.addRect(CGRect(x: x, y: y, width: t, height: h))
        path.addRect(CGRect(x: x, y: y, width: w, height: t))
        path.addRect(CGRect(x: x, y: y + h * 0.45, width: w * 0.82, height: t))
        path.addRect(CGRect(x: x, y: y + h - t, width: w, height: t))

    default:
        path.addRect(CGRect(x: x, y: y, width: w, height: h))
    }

    return path
}

#Preview {
    SplashView(onFinished: {})
}
