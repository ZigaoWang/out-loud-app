import Foundation
import AVFoundation

class AudioRecordingService: NSObject {
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioFormat: AVAudioFormat?
    private var audioFile: AVAudioFile?
    private var audioFileURL: URL?
    private var isRecording: Bool = false
    private var bufferWriteCount: Int = 0

    var onAudioBuffer: ((Data) -> Void)?
    var onAudioLevel: ((Float) -> Void)?
    var onError: ((String) -> Void)?

    override init() {
        super.init()
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()

            // Check microphone permission
            switch session.recordPermission {
            case .granted:
                print("✅ Microphone permission granted")
            case .denied:
                let error = "Microphone permission denied. Please enable in Settings."
                print("❌ \(error)")
                notifyError(error)
                return
            case .undetermined:
                print("⚠️ Microphone permission not yet requested")
                session.requestRecordPermission { granted in
                    if !granted {
                        self.notifyError("Microphone permission is required for recording")
                    }
                }
                return
            @unknown default:
                print("⚠️ Unknown microphone permission status")
            }

            try session.setCategory(.record, mode: .measurement, options: [])
            try session.setActive(true)
            print("✅ Audio session configured successfully")
        } catch {
            let errorMsg = "Failed to setup audio session: \(error.localizedDescription)"
            print("❌ \(errorMsg)")
            notifyError(errorMsg)
        }
    }

    func startRecording() throws {
        // Prevent multiple simultaneous recordings
        guard !isRecording else {
            throw RecordingError.alreadyRecording
        }

        // Reset state
        bufferWriteCount = 0

        // Create temporary audio file
        let tempDir = FileManager.default.temporaryDirectory
        audioFileURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")

        guard let audioFileURL = audioFileURL else {
            throw RecordingError.invalidFileURL
        }

        // Initialize audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw RecordingError.audioEngineInitFailed
        }

        guard let inputNode = audioEngine.inputNode as AVAudioInputNode? else {
            throw RecordingError.noInputNode
        }

        self.inputNode = inputNode

        // Get hardware format
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Validate input format
        guard inputFormat.sampleRate > 0 && inputFormat.channelCount > 0 else {
            throw RecordingError.invalidFormat
        }

        print("📊 Input format: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount) channels")

        // Create target format for Soniox (PCM F32LE, 16kHz, mono)
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: AppConstants.Recording.targetSampleRate,
            channels: AppConstants.Recording.targetChannels,
            interleaved: false
        ) else {
            throw RecordingError.invalidFormat
        }

        self.audioFormat = targetFormat

        // Create audio file for recording with AAC settings
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: AppConstants.Recording.targetSampleRate,
            AVNumberOfChannelsKey: AppConstants.Recording.targetChannels,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioFile = try AVAudioFile(forWriting: audioFileURL, settings: settings)
            print("📝 Created audio file: \(audioFileURL.lastPathComponent)")
        } catch {
            print("❌ Failed to create audio file: \(error.localizedDescription)")
            throw RecordingError.audioFileCreationFailed(error)
        }

        // Create audio converter
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw RecordingError.converterCreationFailed
        }

        print("🔄 Audio converter created")

        // Install tap with error handling
        do {
            inputNode.installTap(
                onBus: 0,
                bufferSize: AppConstants.Recording.audioBufferSize,
                format: inputFormat
            ) { [weak self] buffer, time in
                guard let self = self, self.isRecording else { return }
                self.processAudioBuffer(buffer, converter: converter, targetFormat: targetFormat)
            }
        } catch {
            throw RecordingError.tapInstallationFailed(error)
        }

        // Start audio engine
        do {
            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
            print("🎙️ Recording started successfully")
        } catch {
            // Clean up on failure
            inputNode.removeTap(onBus: 0)
            throw RecordingError.engineStartFailed(error)
        }
    }

    func getRecordingURL() -> URL? {
        return audioFileURL
    }

    func stopRecording() {
        guard isRecording else {
            print("⚠️ Stop recording called but not recording")
            return
        }

        isRecording = false

        // Stop engine first
        audioEngine?.stop()

        // Remove tap safely
        inputNode?.removeTap(onBus: 0)

        // Close audio file to flush data
        audioFile = nil

        // Validate the recording
        if let url = audioFileURL {
            let fileExists = FileManager.default.fileExists(atPath: url.path)
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0

            print("🎙️ Recording stopped")
            print("   File: \(url.lastPathComponent)")
            print("   Exists: \(fileExists)")
            print("   Size: \(fileSize) bytes")
            print("   Buffers written: \(bufferWriteCount)")

            // Verify the audio file is valid
            if fileSize > 1000 {
                do {
                    let testPlayer = try AVAudioPlayer(contentsOf: url)
                    print("✅ Audio file validated - Duration: \(String(format: "%.2f", testPlayer.duration))s")
                } catch {
                    let errorMsg = "Audio file validation failed: \(error.localizedDescription)"
                    print("❌ \(errorMsg)")
                    notifyError(errorMsg)
                }
            } else {
                let errorMsg = "Recording file is too small (\(fileSize) bytes) - likely no audio was captured"
                print("⚠️ \(errorMsg)")
                notifyError(errorMsg)
            }
        }

        // Clean up
        inputNode = nil
        audioEngine = nil
    }

    private func processAudioBuffer(
        _ buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        targetFormat: AVAudioFormat
    ) {
        // Validate input buffer
        guard buffer.frameLength > 0 else {
            print("⚠️ Received empty audio buffer")
            return
        }

        // Calculate output buffer capacity
        let capacity = AVAudioFrameCount(
            Double(buffer.frameLength) * targetFormat.sampleRate / buffer.format.sampleRate
        )

        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
            print("❌ Failed to create converted buffer")
            return
        }

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        let status = converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

        if let error = error {
            print("❌ Audio conversion error: \(error.localizedDescription)")
            notifyError("Audio conversion failed")
            return
        }

        if status == .error {
            print("❌ Audio conversion returned error status")
            notifyError("Audio conversion failed")
            return
        }

        // Validate converted buffer
        guard convertedBuffer.frameLength > 0 else {
            print("⚠️ Conversion produced no audio frames")
            return
        }

        // Write to audio file
        do {
            try audioFile?.write(from: convertedBuffer)
            bufferWriteCount += 1

            // Log progress every 50 buffers
            if bufferWriteCount % 50 == 0 {
                print("📝 Written \(bufferWriteCount) audio buffers")
            }
        } catch {
            print("❌ Failed to write audio: \(error.localizedDescription)")
            notifyError("Failed to save audio data")
            return
        }

        // Process audio data
        guard let floatChannelData = convertedBuffer.floatChannelData else {
            print("⚠️ No channel data in converted buffer")
            return
        }

        let frameLength = Int(convertedBuffer.frameLength)
        let channelData = floatChannelData[0]

        // Calculate audio level (RMS)
        var sum: Float = 0
        for i in 0..<frameLength {
            let sample = channelData[i]
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(frameLength))

        // Avoid log of zero
        let db = rms > 0.0 ? 20 * log10(rms) : -60

        // Normalize to 0-1 range (assuming -60dB to 0dB range)
        let normalizedLevel = max(0, min(1, (db + 60) / 60))

        // Send audio level to UI
        DispatchQueue.main.async { [weak self] in
            self?.onAudioLevel?(normalizedLevel)
        }

        // Convert to Data for sending to backend
        let data = Data(bytes: channelData, count: frameLength * MemoryLayout<Float>.size)

        // Send to backend (on background thread to avoid blocking)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.onAudioBuffer?(data)
        }
    }

    private func notifyError(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.onError?(message)
        }
    }
}

enum RecordingError: Error, LocalizedError {
    case invalidFormat
    case microphoneAccessDenied
    case alreadyRecording
    case invalidFileURL
    case audioEngineInitFailed
    case noInputNode
    case audioFileCreationFailed(Error)
    case converterCreationFailed
    case tapInstallationFailed(Error)
    case engineStartFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid audio format"
        case .microphoneAccessDenied:
            return "Microphone access denied. Please enable in Settings."
        case .alreadyRecording:
            return "Already recording. Stop the current recording first."
        case .invalidFileURL:
            return "Failed to create recording file URL"
        case .audioEngineInitFailed:
            return "Failed to initialize audio engine"
        case .noInputNode:
            return "No audio input device available"
        case .audioFileCreationFailed(let error):
            return "Failed to create audio file: \(error.localizedDescription)"
        case .converterCreationFailed:
            return "Failed to create audio converter"
        case .tapInstallationFailed(let error):
            return "Failed to install audio tap: \(error.localizedDescription)"
        case .engineStartFailed(let error):
            return "Failed to start audio engine: \(error.localizedDescription)"
        }
    }
}
