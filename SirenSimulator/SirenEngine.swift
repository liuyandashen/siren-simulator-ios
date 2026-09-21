import AVFoundation
import Combine

/// 多音轨实时合成引擎：支持 1~3 路振荡器并发，无需任何音频素材。
final class SirenEngine: ObservableObject {

    @Published private(set) var activeId: String?

    /// 主音量
    @Published var volume: Float = 0.85
    /// 静音（切断全部输出）
    @Published var muted = false
    /// 低功率（−12 dB）
    @Published var lowPower = false

    private var cancellables = Set<AnyCancellable>()
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let sampleRate: Double = 44_100
    private let maxVoices = 3

    // UI 线程写、渲染线程读
    private var toneSpecs: [ToneSpec] = []
    private var voiceCount = 0
    private var targetGain: Double = 0
    private var masterScale: Double = 1

    // 渲染线程内部状态
    private var phase = [Double](repeating: 0, count: 3)
    private var vtime = [Double](repeating: 0, count: 3)
    private var vfreq = [Double](repeating: 600, count: 3)
    private var gate  = [Double](repeating: 1, count: 3)
    private var smoothGain: Double = 0

    init() {
        setupSession()
        setupEngine()

        // 用 Combine 观察，避免在 @Published 上挂属性观察器
        $volume
            .sink { [weak self] value in
                self?.engine.mainMixerNode.outputVolume = value
            }
            .store(in: &cancellables)

        $muted
            .sink { [weak self] _ in self?.updateMaster() }
            .store(in: &cancellables)

        $lowPower
            .sink { [weak self] _ in self?.updateMaster() }
            .store(in: &cancellables)
    }

    // MARK: - 初始化

    private func setupSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
    }

    private func setupEngine() {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else { return }

        let node = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, ablPtr -> OSStatus in
            guard let self else { return noErr }

            let abl = UnsafeMutableAudioBufferListPointer(ablPtr)
            let dt = 1.0 / self.sampleRate
            let specs = self.toneSpecs          // 一次性快照，避免反复读可变属性
            let vc = min(self.voiceCount, self.maxVoices, specs.count)

            for frame in 0..<Int(frameCount) {
                var sample = 0.0

                if vc > 0 {
                    for v in 0..<vc {
                        let spec = specs[v]
                        let t = self.vtime[v]

                        let target = self.instantFreq(spec, t)
                        self.vfreq[v] += (target - self.vfreq[v]) * 0.02

                        self.phase[v] += 2 * Double.pi * self.vfreq[v] * dt
                        if self.phase[v] >= 2 * Double.pi { self.phase[v] -= 2 * Double.pi }

                        var g = spec.gain
                        if spec.mode == .pulse {
                            let gt = sin(2 * Double.pi * spec.pulseRate * t) > 0 ? 1.0 : 0.0
                            self.gate[v] += (gt - self.gate[v]) * 0.02
                            g *= self.gate[v]
                        }

                        sample += self.waveValue(spec.wave, self.phase[v]) * g
                        self.vtime[v] = t + dt
                    }
                }

                // 起停淡入淡出
                self.smoothGain += (self.targetGain * self.masterScale - self.smoothGain) * 0.0009
                let out = Float(sample * self.smoothGain)

                for buffer in abl {
                    if let mData = buffer.mData {
                        mData.assumingMemoryBound(to: Float.self)[frame] = out
                    }
                }
            }
            return noErr
        }

        sourceNode = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = volume
        engine.prepare()
    }

    // MARK: - 合成

    private func instantFreq(_ spec: ToneSpec, _ t: Double) -> Double {
        switch spec.mode {
        case .steady, .pulse:
            return spec.minFreq
        case .sequence:
            guard !spec.sequence.isEmpty else { return spec.minFreq }
            let idx = Int(t / max(spec.step, 0.02)) % spec.sequence.count
            return spec.sequence[idx]
        case .wail, .yelp:
            let p = (t.truncatingRemainder(dividingBy: max(spec.period, 0.05))) / max(spec.period, 0.05)
            let tri = p < 0.5 ? p * 2 : (1 - p) * 2
            return spec.minFreq + (spec.maxFreq - spec.minFreq) * tri
        case .hiLo:
            let p = (t.truncatingRemainder(dividingBy: max(spec.period, 0.05))) / max(spec.period, 0.05)
            return p < 0.5 ? spec.minFreq : spec.maxFreq
        case .rise:
            let p = (t.truncatingRemainder(dividingBy: max(spec.period, 0.05))) / max(spec.period, 0.05)
            return spec.minFreq + (spec.maxFreq - spec.minFreq) * p
        }
    }

    private func waveValue(_ shape: WaveShape, _ ph: Double) -> Double {
        switch shape {
        case .sine:     return sin(ph)
        case .square:   return ph < Double.pi ? 1 : -1
        case .sawtooth: return (ph / Double.pi) - 1
        }
    }

    private func updateMaster() {
        if muted {
            masterScale = 0
        } else if lowPower {
            masterScale = 0.25   // −12 dB
        } else {
            masterScale = 1
        }
    }

    // MARK: - 控制

    func trigger(_ action: SirenAction) {
        if action.isControl { return }

        if activeId == action.id {
            stop()
            return
        }

        toneSpecs = action.tones
        voiceCount = min(action.tones.count, maxVoices)

        for i in 0..<maxVoices {
            phase[i] = 0
            vtime[i] = 0
            gate[i] = 1
            vfreq[i] = i < action.tones.count ? action.tones[i].minFreq : 600
        }

        activeId = action.id
        targetGain = 0.7

        try? AVAudioSession.sharedInstance().setActive(true)
        if !engine.isRunning {
            do { try engine.start() } catch { print("[SirenEngine] start failed: \(error)") }
        }
    }

    func stop() {
        targetGain = 0
        activeId = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self, self.activeId == nil else { return }
            self.engine.pause()
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    func toggleMute() {
        muted.toggle()
        Haptics.impact(.rigid)
    }

    func toggleLowPower() {
        lowPower.toggle()
        Haptics.impact(.light)
    }
}
