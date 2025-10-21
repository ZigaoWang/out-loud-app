# Out Loud iOS App

SwiftUI-based iOS app for speech-based learning.

## 🏗 Architecture

### MVVM Pattern

- **Models**: Data structures (`Models.swift`)
- **ViewModels**: Business logic (`SessionViewModel.swift`)
- **Views**: UI components (`ModeSelectionView`, `SessionView`)
- **Services**: External integrations (Audio, WebSocket)

### Services

**AudioRecordingService**
- Captures audio using AVAudioEngine
- Converts to PCM F32LE format (16kHz, mono)
- Streams audio buffers to callback

**WebSocketService**
- Manages WebSocket connection to backend
- Handles message parsing and routing
- Delegates events to ViewModel

### Key Features

1. **Real-time Audio Streaming**
   - Low-latency audio capture
   - Automatic format conversion
   - Chunked streaming to backend

2. **Live Transcription Display**
   - Partial (in-progress) transcripts in orange
   - Final transcripts in green
   - Auto-scrolling transcript view

3. **AI Interaction**
   - Real-time caption generation
   - Interactive question overlays
   - Post-session analysis display

## 🎨 UI Components

### ModeSelectionView
- Home screen with mode selection
- Cards for Solo and Interactive modes
- Navigation to SessionView

### SessionView
- Header with mode indicator
- Caption area (shows during recording)
- Scrollable transcript view
- Record/Stop control button
- Analysis results view
- Interactive question overlay

## 🔧 Configuration

### Server URL

Update in `SessionViewModel.swift`:
```swift
init(mode: SessionMode, serverURL: String = "ws://YOUR_SERVER:3000")
```

For local testing: `ws://localhost:3000`
For device testing: `ws://YOUR_COMPUTER_IP:3000`

### Audio Format

Configured in `AudioRecordingService.swift`:
- Format: PCM Float32 Little Endian
- Sample Rate: 16000 Hz
- Channels: 1 (mono)

This matches Soniox API requirements.

## 📱 Building for Device

1. **Connect your iPhone/iPad**

2. **Enable Developer Mode** on device

3. **Select your device** in Xcode

4. **Update server URL** to your computer's IP:
   ```swift
   // In SessionViewModel.swift
   private let serverURL = "ws://192.168.1.XXX:3000"
   ```

5. **Trust developer certificate** on device (Settings → General → VPN & Device Management)

6. **Run** (⌘R)

## 🧪 Testing

### Simulator Testing
- UI testing works fine
- Audio recording requires real device

### Device Testing
1. Ensure backend is running and accessible
2. Check microphone permissions
3. Test in quiet environment for best results

## 📦 Dependencies

- **Starscream**: WebSocket client library
  - GitHub: https://github.com/daltoniam/Starscream
  - Version: 4.0.0+

Add via Swift Package Manager in Xcode:
1. File → Add Packages
2. Enter URL: `https://github.com/daltoniam/Starscream.git`
3. Select version 4.0.0+

## 🐛 Troubleshooting

### "WebSocket failed to connect"
- Check backend is running
- Verify server URL is correct
- Ensure device and server are on same network

### "Microphone access denied"
- Check Settings → Privacy → Microphone
- Ensure Out Loud has permission
- Add NSMicrophoneUsageDescription to Info.plist

### "No audio being sent"
- Check AVAudioSession is active
- Verify audio format matches backend expectations
- Test with real device (not simulator)

## 📝 Code Style

- SwiftUI for all views
- Combine for reactive bindings
- @StateObject for ViewModels
- @Published for observable properties
- Async callbacks for service layers

## 🔮 Future Enhancements

- [ ] Session history and playback
- [ ] Cloud sync
- [ ] Offline mode
- [ ] Multiple language support
- [ ] Export analysis as PDF
- [ ] Dark mode theming
