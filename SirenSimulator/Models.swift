import SwiftUI

// MARK: - 音色基础定义

enum WaveShape {
    case sine       // 正弦：圆润
    case square     // 方波：电子、刺耳
    case sawtooth   // 锯齿：低沉、汽笛
}

enum SweepMode {
    case wail       // 缓慢上下扫频
    case yelp       // 快速上下扫频
    case hiLo       // 高低两音交替
    case rise       // 单向上扬
    case steady     // 固定音调
    case pulse      // 固定音调 + 脉冲门控
    case sequence   // 音阶序列
}

/// 单个音轨（一路振荡器）的参数
struct ToneSpec {
    var minFreq: Double
    var maxFreq: Double
    var period: Double = 2.0
    var mode: SweepMode = .wail
    var wave: WaveShape = .sine
    var gain: Double = 0.55
    var sequence: [Double] = []
    var step: Double = 0.16      // 序列模式下每个音的时长
    var pulseRate: Double = 4.5  // 脉冲门控频率
}

// MARK: - 按钮配色

enum ButtonTone {
    case red, green, orange, blue, purple, gold, gray, teal

    var bg: Color {
        switch self {
        case .red:    return Color(red: 0.30, green: 0.07, blue: 0.09)
        case .green:  return Color(red: 0.06, green: 0.24, blue: 0.14)
        case .orange: return Color(red: 0.38, green: 0.16, blue: 0.03)
        case .blue:   return Color(red: 0.05, green: 0.16, blue: 0.34)
        case .purple: return Color(red: 0.16, green: 0.08, blue: 0.28)
        case .gold:   return Color(red: 0.28, green: 0.20, blue: 0.03)
        case .gray:   return Color(red: 0.13, green: 0.14, blue: 0.17)
        case .teal:   return Color(red: 0.04, green: 0.21, blue: 0.23)
        }
    }

    var border: Color {
        switch self {
        case .red:    return Color(red: 0.75, green: 0.24, blue: 0.26)
        case .green:  return Color(red: 0.20, green: 0.68, blue: 0.40)
        case .orange: return Color(red: 0.90, green: 0.48, blue: 0.12)
        case .blue:   return Color(red: 0.24, green: 0.55, blue: 0.95)
        case .purple: return Color(red: 0.55, green: 0.35, blue: 0.90)
        case .gold:   return Color(red: 0.85, green: 0.62, blue: 0.15)
        case .gray:   return Color(red: 0.35, green: 0.38, blue: 0.44)
        case .teal:   return Color(red: 0.20, green: 0.70, blue: 0.72)
        }
    }

    var fg: Color {
        switch self {
        case .red:    return Color(red: 1.00, green: 0.48, blue: 0.46)
        case .green:  return Color(red: 0.44, green: 0.94, blue: 0.60)
        case .orange: return Color(red: 1.00, green: 0.70, blue: 0.30)
        case .blue:   return Color(red: 0.55, green: 0.80, blue: 1.00)
        case .purple: return Color(red: 0.78, green: 0.65, blue: 1.00)
        case .gold:   return Color(red: 1.00, green: 0.82, blue: 0.38)
        case .gray:   return Color(red: 0.85, green: 0.87, blue: 0.92)
        case .teal:   return Color(red: 0.55, green: 0.95, blue: 0.95)
        }
    }
}

// MARK: - 按钮与分组

struct SirenAction: Identifiable {
    let id: String
    let name: String
    let subtitle: String
    let tone: ButtonTone
    let tones: [ToneSpec]
    var span: Int = 1            // 占几列
    var isControl: Bool = false  // 控制类（非发声）按钮
}

struct SirenSection: Identifiable {
    let id: String
    let title: String
    let actions: [SirenAction]
}

// MARK: - 全部面板配置

enum SirenCatalog {

    static let sections: [SirenSection] = [

        SirenSection(id: "s1", title: "警笛与车外广播（独立双音轨 · 鸣笛 / 播报）", actions: [
            SirenAction(
                id: "airhorn", name: "气笛号角", subtitle: "高低双管 · 气喇叭", tone: .red,
                tones: [
                    ToneSpec(minFreq: 370, maxFreq: 370, mode: .steady, wave: .sawtooth, gain: 0.42),
                    ToneSpec(minFreq: 466, maxFreq: 466, mode: .steady, wave: .sawtooth, gain: 0.34)
                ]),
            SirenAction(
                id: "pa", name: "车外广播", subtitle: "车载喊话器喊话", tone: .green,
                tones: [
                    ToneSpec(minFreq: 660, maxFreq: 660, mode: .steady, wave: .square, gain: 0.30),
                    ToneSpec(minFreq: 660, maxFreq: 990, period: 1.4, mode: .hiLo, wave: .sine, gain: 0.30)
                ])
        ]),

        SirenSection(id: "s2", title: "警报音播放系统（多音源模式 / 循环重奏）", actions: [
            SirenAction(
                id: "auto", name: "自动滚动", subtitle: "警报循环", tone: .orange, span: 2,
                tones: [ToneSpec(minFreq: 550, maxFreq: 1100, period: 3.2, mode: .wail, wave: .sine, gain: 0.62)]),
            SirenAction(
                id: "m1", name: "模式 1", subtitle: "高低音交替", tone: .orange,
                tones: [ToneSpec(minFreq: 600, maxFreq: 900, period: 0.9, mode: .hiLo, wave: .sine, gain: 0.6)]),
            SirenAction(
                id: "m2", name: "模式 2", subtitle: "双音循环", tone: .orange,
                tones: [ToneSpec(minFreq: 440, maxFreq: 660, period: 1.0, mode: .hiLo, wave: .sine, gain: 0.6)]),
            SirenAction(
                id: "m3", name: "模式 3", subtitle: "短音大循环", tone: .orange,
                tones: [ToneSpec(minFreq: 700, maxFreq: 1000, period: 0.6, mode: .yelp, wave: .sine, gain: 0.6)]),
            SirenAction(
                id: "stop", name: "拦截停车", subtitle: "短促警示", tone: .gray,
                tones: [ToneSpec(minFreq: 900, maxFreq: 900, period: 1.0, mode: .pulse, wave: .square, gain: 0.45, pulseRate: 6.0)])
        ]),

        SirenSection(id: "s3", title: "手动 / 电笛（音量加分 · 低音重响）", actions: [
            SirenAction(
                id: "manual", name: "手动巡航", subtitle: "踏音操作 / 匀速警鸣", tone: .gold,
                tones: [ToneSpec(minFreq: 520, maxFreq: 520, mode: .steady, wave: .sawtooth, gain: 0.5)]),
            SirenAction(
                id: "mech", name: "机械重型电笛", subtitle: "低音加重 · 长按警鸣", tone: .gold,
                tones: [
                    ToneSpec(minFreq: 300, maxFreq: 300, mode: .steady, wave: .sawtooth, gain: 0.40),
                    ToneSpec(minFreq: 304, maxFreq: 304, mode: .steady, wave: .sawtooth, gain: 0.30)
                ])
        ]),

        SirenSection(id: "s4", title: "巡航警笛（频段 650–1650Hz · 可调 / 变调）", actions: [
            SirenAction(
                id: "wail", name: "巡航 Wail", subtitle: "标准 5.4 秒循环", tone: .blue,
                tones: [ToneSpec(minFreq: 650, maxFreq: 1200, period: 5.4, mode: .wail, wave: .sine, gain: 0.62)]),
            SirenAction(
                id: "wail_slow", name: "慢速 Wail", subtitle: "6.0 秒 · 变调大气", tone: .blue,
                tones: [ToneSpec(minFreq: 650, maxFreq: 1150, period: 6.0, mode: .wail, wave: .sine, gain: 0.62)]),
            SirenAction(
                id: "wail_fast", name: "快速 Wail", subtitle: "3.0 秒 · 变调急速", tone: .blue,
                tones: [ToneSpec(minFreq: 800, maxFreq: 1500, period: 3.0, mode: .wail, wave: .sine, gain: 0.62)])
        ]),

        SirenSection(id: "s5", title: "应急 / 警报（频段无级变 · 3.85Hz）", actions: [
            SirenAction(
                id: "yelp", name: "急促 Yelp", subtitle: "快速高低变频", tone: .gray,
                tones: [ToneSpec(minFreq: 700, maxFreq: 1300, period: 0.45, mode: .yelp, wave: .sine, gain: 0.6)]),
            SirenAction(
                id: "pursuit", name: "追击变频", subtitle: "5.0Hz 变频警笛", tone: .gray,
                tones: [ToneSpec(minFreq: 600, maxFreq: 1600, period: 0.35, mode: .yelp, wave: .sine, gain: 0.6)]),
            SirenAction(
                id: "piercer", name: "极速穿透", subtitle: "8.0Hz 刺耳警笛", tone: .gray,
                tones: [ToneSpec(minFreq: 900, maxFreq: 1800, period: 0.28, mode: .yelp, wave: .square, gain: 0.45)])
        ]),

        SirenSection(id: "s6", title: "特种 / 专用音效", actions: [
            SirenAction(
                id: "tactical", name: "战术警示", subtitle: "12 音节警示", tone: .gray,
                tones: [ToneSpec(minFreq: 800, maxFreq: 800, mode: .sequence, wave: .square, gain: 0.45,
                                 sequence: [1200, 900, 1200, 900, 1200, 900, 1200, 900, 1200, 900, 1200, 900],
                                 step: 0.13)]),
            SirenAction(
                id: "ambulance", name: "救护 Hi-Lo", subtitle: "600 / 750Hz 医疗", tone: .gray,
                tones: [ToneSpec(minFreq: 600, maxFreq: 750, period: 0.8, mode: .hiLo, wave: .sine, gain: 0.6)]),
            SirenAction(
                id: "patrol", name: "自动巡检", subtitle: "巡逻 / 单向 / 部署巡检", tone: .teal,
                tones: [ToneSpec(minFreq: 500, maxFreq: 900, period: 2.0, mode: .wail, wave: .sine, gain: 0.6)])
        ]),

        SirenSection(id: "s7", title: "200W 双喇叭 · 真实并发（左右声道独立可调）", actions: [
            SirenAction(
                id: "mix_a", name: "并发 A：巡航 + 急促", subtitle: "警笛混音 + 变调打点", tone: .purple, span: 2,
                tones: [
                    ToneSpec(minFreq: 650, maxFreq: 1200, period: 5.4, mode: .wail, wave: .sine, gain: 0.34),
                    ToneSpec(minFreq: 700, maxFreq: 1300, period: 0.45, mode: .yelp, wave: .sine, gain: 0.30)
                ]),
            SirenAction(
                id: "mix_b", name: "并发 B：急促 + 追击", subtitle: "变频混音 + 急促变频", tone: .purple, span: 2,
                tones: [
                    ToneSpec(minFreq: 700, maxFreq: 1300, period: 0.45, mode: .yelp, wave: .sine, gain: 0.32),
                    ToneSpec(minFreq: 600, maxFreq: 1600, period: 0.35, mode: .yelp, wave: .square, gain: 0.22)
                ])
        ]),

        SirenSection(id: "s8", title: "声学技术与控制", actions: [
            SirenAction(
                id: "pulse_heavy", name: "重型音脉冲", subtitle: "低音重放 · 脉冲", tone: .orange,
                tones: [ToneSpec(minFreq: 320, maxFreq: 320, mode: .pulse, wave: .sawtooth, gain: 0.55, pulseRate: 4.0)]),
            SirenAction(
                id: "settings", name: "系统设置", subtitle: "系统参数设置", tone: .gray,
                tones: [], isControl: true),
            SirenAction(
                id: "lowpower", name: "低功率", subtitle: "−12 dB", tone: .gray,
                tones: [], isControl: true),
            SirenAction(
                id: "mute", name: "静音", subtitle: "切断全部输出", tone: .red,
                tones: [], isControl: true)
        ])
    ]

    static func action(id: String) -> SirenAction? {
        for s in sections {
            if let a = s.actions.first(where: { $0.id == id }) { return a }
        }
        return nil
    }
}
