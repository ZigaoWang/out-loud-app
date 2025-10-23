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
        // Create temporary audio file - use CAF format (most reliable for AVAudioFile)
        let tempDir = FileManager.default.temporaryDirectory
        audioFileURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("caf")

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

        // Create audio file for recording in CAF format with LPCM
        if let audioFileURL = audioFileURL {
            do {
                audioFile = try AVAudioFile(forWriting: audioFileURL, settings: targetFormat.settings)
                print("📝 Created audio file: \(audioFileURL.lastPathComponent)")
            } catch {
                print("❌ Failed to create audio file: \(error)")
                throw RecordingError.invalidFormat
            }
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
        print("🎙️ Recording started")
    }

    func getRecordingURL() -> URL? {
        return audioFileURL
    }

    func stopRecording() {
        // Stop engine first
        audioEngine?.stop()

        // Then remove tap
        inputNode?.removeTap(onBus: 0)

        // IMPORTANT: Close the audio file to flush all data
        audioFile = nil

        // Log the file info
        if let url = audioFileURL {
            let fileExists = FileManager.default.fileExists(atPath: url.path)
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
            print("🎙️ Recording stopped - File: \(url.lastPathComponent), Exists: \(fileExists), Size: \(fileSize) bytes")

            // Verify the audio file is valid
            if fileSize > 0 {
                do {
                    let testPlayer = try AVAudioPlayer(contentsOf: url)
                    print("✅ Audio file is valid - Duration: \(testPlayer.duration)s")
                } catch {
                    print("❌ Audio file validation failed: \(error)")
                }
            }
        }

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

        let status = converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

        if let error = error {
            print("❌ Audio conversion error: \(error)")
            return
        }

        if status == .error {
            print("❌ Audio conversion failed")
            return
        }

        // CRITICAL: Check if we actually got audio data
        guard convertedBuffer.frameLength > 0 else {
            print("⚠️ No audio frames in converted buffer")
            return
        }

        // Write to audio file
        do {
            try audioFile?.write(from: convertedBuffer)
        } catch {
            print("❌ Failed to write audio: \(error)")
        }

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
