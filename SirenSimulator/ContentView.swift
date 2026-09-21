import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var engine = SirenEngine()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSettings = false

    var body: some View {
        ZStack {
            Color(red: 0.03, green: 0.035, blue: 0.05).ignoresSafeArea()

            VStack(spacing: 9) {
                LightBar(active: engine.activeId != nil)
                Text("手机警报器")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                statusRow

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(SirenCatalog.sections) { section in
                            sectionView(section)
                        }
                    }
                    .padding(.bottom, 6)
                }

                bottomBar
            }
            .padding(.horizontal, 13)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(red: 0.06, green: 0.065, blue: 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { engine.stop() }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(engine: engine)
        }
    }

    // MARK: - 组件

    private var statusRow: some View {
        HStack {
            HStack(spacing: 6) {
                Circle().fill(Color.orange).frame(width: 7, height: 7)
                Text("声光主控引擎就绪")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.75))
            }
            Spacer()
            Text("CAN-BUS 通讯链路正常")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(.horizontal, 2)
    }

    private var bottomBar: some View {
        HStack {
            Text("系统工作正常 · 主功率就绪")
            Spacer()
            Text("电源 12V · 驱动外接电源")
        }
        .font(.system(size: 10))
        .foregroundStyle(.white.opacity(0.4))
        .padding(.horizontal, 2)
        .padding(.top, 2)
    }

    private func sectionView(_ section: SirenSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.orange)
                    .frame(width: 3, height: 13)
                Text(section.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.63, blue: 0.22))
            }

            VStack(spacing: 8) {
                ForEach(rows(for: section.actions)) { row in
                    HStack(spacing: 8) {
                        ForEach(row.actions) { action in
                            ActionButton(
                                action: action,
                                isActive: isActive(action),
                                isOn: isOn(action)
                            ) {
                                handleTap(action)
                            }
                        }
                    }
                }
            }
        }
    }

    private struct ButtonRow: Identifiable {
        let id: Int
        let actions: [SirenAction]
    }

    /// 把按钮排成行：span >= 2 独占一行，其余两个一行
    private func rows(for actions: [SirenAction]) -> [ButtonRow] {
        var result: [ButtonRow] = []
        var pending: [SirenAction] = []

        func flush() {
            guard !pending.isEmpty else { return }
            result.append(ButtonRow(id: result.count, actions: pending))
            pending = []
        }

        for a in actions {
            if a.span >= 2 {
                flush()
                result.append(ButtonRow(id: result.count, actions: [a]))
            } else {
                pending.append(a)
                if pending.count == 2 { flush() }
            }
        }
        flush()
        return result
    }

    private func isActive(_ action: SirenAction) -> Bool {
        engine.activeId == action.id
    }

    /// 控制类按钮的“开启”状态
    private func isOn(_ action: SirenAction) -> Bool {
        switch action.id {
        case "mute": return engine.muted
        case "lowpower": return engine.lowPower
        default: return false
        }
    }

    private func handleTap(_ action: SirenAction) {
        Haptics.impact(.medium)
        switch action.id {
        case "settings": showSettings = true
        case "lowpower": engine.toggleLowPower()
        case "mute":     engine.toggleMute()
        default:         engine.trigger(action)
        }
    }
}

// MARK: - 按钮

struct ActionButton: View {
    let action: SirenAction
    let isActive: Bool
    let isOn: Bool
    let tap: () -> Void

    private var highlighted: Bool { isActive || isOn }

    var body: some View {
        Button(action: tap) {
            VStack(spacing: 3) {
                Text(action.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(highlighted ? .white : action.tone.fg)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(action.subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(highlighted ? Color.white.opacity(0.9) : action.tone.fg.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(highlighted
                          ? AnyShapeStyle(action.tone.border)
                          : AnyShapeStyle(action.tone.bg))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(highlighted ? action.tone.fg : action.tone.border.opacity(0.55),
                            lineWidth: highlighted ? 1.6 : 1)
            )
            .animation(.easeOut(duration: 0.15), value: highlighted)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 顶部警灯条

struct LightBar: View {
    let active: Bool
    private let colors: [Color] = [.orange, .white, .white, .orange, .red, .red, .red]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.28)) { context in
            let on = Int(context.date.timeIntervalSinceReferenceDate / 0.28) % 2 == 0
            HStack(spacing: 5) {
                ForEach(0..<colors.count, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(active && on ? colors[i] : colors[i].opacity(0.10))
                        .frame(height: 12)
                        .shadow(color: (active && on) ? colors[i].opacity(0.7) : .clear, radius: 4)
                }
            }
        }
    }
}

// MARK: - 系统设置

struct SettingsSheet: View {
    @ObservedObject var engine: SirenEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("主音量") {
                    HStack(spacing: 12) {
                        Image(systemName: "speaker.fill")
                        Slider(value: $engine.volume, in: 0...1)
                        Image(systemName: "speaker.wave.3.fill")
                    }
                }
                Section("输出控制") {
                    Toggle("静音（切断全部输出）", isOn: $engine.muted)
                    Toggle("低功率（−12 dB）", isOn: $engine.lowPower)
                }
                Section("设备信息") {
                    LabeledContent("设备", value: "手机警报器 · 声光主控")
                    LabeledContent("电源", value: "12V · 驱动外接电源")
                    LabeledContent("版本", value: "1.0")
                }
            }
            .navigationTitle("系统设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - 触感

enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

#Preview {
    ContentView()
}
