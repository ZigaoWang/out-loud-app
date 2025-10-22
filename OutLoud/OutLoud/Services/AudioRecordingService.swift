import Foundation
import AVFoundation

class AudioRecordingService: NSObject {
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioFormat: AVAudioFormat?
    private var audioFile: AVAudioFile?
    private var audioFileURL: URL?

    var onAudioBuffer: ((Data) -> Void)?
    var onAudioLevel: ((Float) -> Void)?

    override init() {
        super.init()
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement)
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    func startRecording() throws {
        // Create temporary audio file
        let tempDir = FileManager.default.temporaryDirectory
        audioFileURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")

        audioEngine = AVAudioEngine()
        guard let inputNode = audioEngine?.inputNode else {
            throw RecordingError.invalidFormat
        }

        self.inputNode = inputNode

        // Use the input node's native format (hardware format)
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Create converter format - Soniox expects: PCM F32LE, 16kHz, mono
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            throw RecordingError.invalidFormat
        }

        audioFormat = targetFormat

        // Create audio file for recording
        if let audioFileURL = audioFileURL {
            audioFile = try? AVAudioFile(forWriting: audioFileURL, settings: targetFormat.settings)
        }

        // Create audio converter for format conversion
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw RecordingError.invalidFormat
        }

        // Install tap using the hardware's native format
        inputNode.installTap(
            onBus: 0,
            bufferSize: 4096,
            format: inputFormat
        ) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, converter: converter, targetFormat: targetFormat)
        }

        audioEngine?.prepare()
        try audioEngine?.start()
    }

    func getRecordingURL() -> URL? {
        return audioFileURL
    }

    func stopRecording() {
        // Stop engine first
        audioEngine?.stop()

        // Then remove tap
        inputNode?.removeTap(onBus: 0)

        // Clean up
        inputNode = nil
        audioEngine = nil
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter, targetFormat: AVAudioFormat) {
        // Calculate output buffer capacity
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * targetFormat.sampleRate / buffer.format.sampleRate)

        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
            return
        }

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

        if let error = error {
            print("Audio conversion error: \(error)")
            return
        }

        // Write to audio file
        try? audioFile?.write(from: convertedBuffer)

        guard let floatChannelData = convertedBuffer.floatChannelData else { return }

        let frameLength = Int(convertedBuffer.frameLength)
        let channelData = floatChannelData[0]

        // Calculate audio level (RMS - Root Mean Square)
        var sum: Float = 0
        for i in 0..<frameLength {
            let sample = channelData[i]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frameLength))
        let db = 20 * log10(rms)

        // Normalize to 0-1 range (assuming -60dB to 0dB range)
        let normalizedLevel = max(0, min(1, (db + 60) / 60))

        // Send audio level to UI
        DispatchQueue.main.async { [weak self] in
            self?.onAudioLevel?(normalizedLevel)
        }

        // Convert to Data
        let data = Data(bytes: channelData, count: frameLength * MemoryLayout<Float>.size)

        onAudioBuffer?(data)
    }
}

enum RecordingError: Error {
    case invalidFormat
    case microphoneAccessDenied
}
