import SwiftUI

// Calmer, professional design system for Out Loud
struct AppTheme {
    // Primary color palette - softer, calmer tones
    static let primary = Color(red: 0.4, green: 0.5, blue: 0.9) // Soft blue
    static let secondary = Color(red: 0.3, green: 0.7, blue: 0.6) // Muted teal
    static let accent = Color(red: 0.8, green: 0.5, blue: 0.3) // Warm orange

    // State colors - less intense
    static let recording = Color(red: 0.9, green: 0.3, blue: 0.3) // Softer red
    static let success = Color(red: 0.4, green: 0.7, blue: 0.5) // Gentle green
    static let warning = Color(red: 0.9, green: 0.6, blue: 0.3) // Warm amber

    // Neutrals - calm background tones
    static let surface = Color(.systemBackground)
    static let surfaceSecondary = Color(red: 0.97, green: 0.97, blue: 0.98)
    static let surfaceTertiary = Color(red: 0.95, green: 0.95, blue: 0.96)

    // Text colors
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color(white: 0.5)

    // Spacing system
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    // Corner radius system
    struct Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }

    // Shadow system - subtle and calm
    struct Shadow {
        static func light() -> some View {
            Color.black.opacity(0.03)
        }

        static func medium() -> some View {
            Color.black.opacity(0.06)
        }

        static func strong() -> some View {
            Color.black.opacity(0.1)
        }
    }
}

// Custom view modifiers for consistent styling
extension View {
    func cardStyle() -> some View {
        self
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
            .shadow(color: Color.black.opacity(0.02), radius: 2, x: 0, y: 1)
    }

    func sectionCard() -> some View {
        self
            .background(AppTheme.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
    }

    func pillStyle(color: Color = AppTheme.primary) -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(color.opacity(0.2), lineWidth: 0.5)
            )
    }
}

// Simple FlowLayout for keywords
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var frames: [CGRect] = []

        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > width && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: width, height: y + lineHeight)
        }
    }
}

struct SessionView: View {
    let mode: SessionMode
    @StateObject private var viewModel: SessionViewModel
    @Environment(\.presentationMode) var presentationMode

    init(mode: SessionMode) {
        self.mode = mode
        _viewModel = StateObject(wrappedValue: SessionViewModel(mode: mode))
    }

    var body: some View {
        ZStack {
            // Main content
            VStack(spacing: 0) {
                // Header
                header

                // Caption area
                if viewModel.state == .recording {
                    captionArea
                        .transition(.move(edge: .top))
                }

                Spacer()

                // Transcript display
                if !viewModel.transcriptSegments.isEmpty {
                    transcriptView
                        .transition(.opacity)
                }

                Spacer()

                // Control button
                controlButton

                // Analysis result
                if let analysis = viewModel.analysisResult {
                    analysisView(analysis)
                        .transition(.move(edge: .bottom))
                }
            }

            // Interaction overlay
            if let question = viewModel.interactionQuestion {
                interactionOverlay(question)
            }

            // Error alert
            if let error = viewModel.errorMessage {
                errorAlert(error)
            }
        }
        .navigationBarBackButtonHidden(viewModel.state == .recording)
        .navigationBarItems(leading: backButton)
        .animation(.easeInOut(duration: 0.35), value: viewModel.state)
        .animation(.easeOut(duration: 0.25), value: viewModel.transcriptSegments.count)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: viewModel.analysisResult != nil)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            Text(mode == .solo ? "Solo Mode" : "Interactive Mode")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.textPrimary)

            if viewModel.state == .recording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppTheme.recording)
                        .frame(width: 5, height: 5)
                        .opacity(0.7)
                        .animation(
                            Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                            value: viewModel.state
                        )

                    Text("Recording")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.recording)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(AppTheme.recording.opacity(0.08))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(AppTheme.recording.opacity(0.15), lineWidth: 0.5)
                )
            }
        }
        .padding(.top, AppTheme.Spacing.xxl)
    }

    // MARK: - Caption Area

    private var captionArea: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            // Real-time AI caption with streaming effect
            if !viewModel.displayedCaption.isEmpty {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "waveform")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondary)

                    Text(viewModel.displayedCaption)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.secondary)
                }
                .pillStyle(color: AppTheme.secondary)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            // Audio waveform visualization
            AudioWaveformView(
                audioLevel: viewModel.audioLevel,
                isRecording: viewModel.state == .recording
            )
            .padding(.horizontal, AppTheme.Spacing.xxl)
        }
        .padding(.vertical, AppTheme.Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    AppTheme.surfaceTertiary,
                    AppTheme.surface
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.top, AppTheme.Spacing.lg)
    }

    // MARK: - Transcript View

    private var transcriptView: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                Image(systemName: "text.bubble")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)

                Text("Transcript")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer()
            }
            .padding(.horizontal, AppTheme.Spacing.xl)

            ScrollView {
                ScrollViewReader { proxy in
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                        ForEach(viewModel.transcriptSegments) { segment in
                            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                                Circle()
                                    .fill(segment.isFinal ?
                                          AppTheme.success.opacity(0.6) :
                                          AppTheme.textTertiary.opacity(0.4))
                                    .frame(width: 4, height: 4)
                                    .padding(.top, 7)

                                Text(segment.text)
                                    .font(.body)
                                    .foregroundColor(segment.isFinal ?
                                                   AppTheme.textPrimary :
                                                   AppTheme.textSecondary.opacity(0.7))
                                    .lineSpacing(5)
                            }
                            .id(segment.id)
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.xl)
                    .padding(.vertical, AppTheme.Spacing.lg)
                    .onChange(of: viewModel.transcriptSegments.count) { _ in
                        if let lastSegment = viewModel.transcriptSegments.last {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(lastSegment.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 250)
            .background(AppTheme.surfaceSecondary.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
            .padding(.horizontal, AppTheme.Spacing.lg)
        }
    }

    // MARK: - Control Button

    private var controlButton: some View {
        Button(action: {
            if viewModel.state == .idle {
                viewModel.startSession()
            } else if viewModel.state == .recording {
                viewModel.stopSession()
            } else if viewModel.state == .completed {
                viewModel.resetSession()
            }
        }) {
            ZStack {
                Circle()
                    .fill(buttonColor)
                    .frame(width: 72, height: 72)
                    .shadow(color: buttonColor.opacity(0.3), radius: 12, x: 0, y: 6)

                Image(systemName: buttonIcon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
                    .scaleEffect(viewModel.state == .recording ? 0.9 : 1.0)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: viewModel.state == .recording)
            }
        }
        .disabled(viewModel.state == .processing)
        .scaleEffect(viewModel.state == .recording ? 1.03 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.65), value: viewModel.state)
        .padding(.vertical, AppTheme.Spacing.xxxl)
    }

    private var buttonColor: Color {
        switch viewModel.state {
        case .idle:
            return AppTheme.primary
        case .recording:
            return AppTheme.recording
        case .processing:
            return AppTheme.textTertiary
        case .completed:
            return AppTheme.success
        }
    }

    private var buttonIcon: String {
        switch viewModel.state {
        case .idle:
            return "mic.fill"
        case .recording:
            return "stop.fill"
        case .processing:
            return "hourglass"
        case .completed:
            return "arrow.clockwise"
        }
    }

    // MARK: - Analysis View (Minimal MVP)

    private func analysisView(_ analysis: AnalysisResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxl) {
                // Header - minimal
                HStack {
                    Circle()
                        .fill(AppTheme.success)
                        .frame(width: 8, height: 8)

                    Text("Session Complete")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.textPrimary)

                    Spacer()
                }

                // Scores - big and bold
                HStack(spacing: AppTheme.Spacing.xxxl) {
                    VStack(spacing: AppTheme.Spacing.xs) {
                        Text("\(analysis.report.thinkingIntensity)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.primary)

                        Text("Depth")
                            .font(.caption)
                            .foregroundColor(AppTheme.textTertiary)
                            .textCase(.uppercase)
                            .tracking(1)
                    }

                    VStack(spacing: AppTheme.Spacing.xs) {
                        Text("\(analysis.report.coherenceScore)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.secondary)

                        Text("Flow")
                            .font(.caption)
                            .foregroundColor(AppTheme.textTertiary)
                            .textCase(.uppercase)
                            .tracking(1)
                    }

                    Spacer()
                }
                .padding(.vertical, AppTheme.Spacing.lg)

                // Divider
                Rectangle()
                    .fill(AppTheme.surfaceTertiary)
                    .frame(height: 1)

                // Summary - clean text
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    Text("Summary")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.textTertiary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    Text(analysis.summary)
                        .font(.body)
                        .foregroundColor(AppTheme.textPrimary)
                        .lineSpacing(6)
                }

                // Keywords - minimal pills
                if !analysis.keywords.isEmpty {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                        Text("Topics")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.textTertiary)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        FlowLayout(spacing: AppTheme.Spacing.sm) {
                            ForEach(analysis.keywords, id: \.self) { keyword in
                                Text(keyword)
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.textSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(AppTheme.surfaceSecondary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                // Growth areas - if low scores
                if !analysis.report.missingPoints.isEmpty {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                        Text("Next Time")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.textTertiary)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            ForEach(analysis.report.missingPoints, id: \.self) { point in
                                HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                                    Text("·")
                                        .foregroundColor(AppTheme.accent)
                                        .fontWeight(.bold)

                                    Text(point)
                                        .font(.subheadline)
                                        .foregroundColor(AppTheme.textSecondary)
                                        .lineSpacing(4)
                                }
                            }
                        }
                    }
                }

                // Follow-up - minimal
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    Text("Continue")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.textTertiary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    Text(analysis.followUpQuestion)
                        .font(.body)
                        .foregroundColor(AppTheme.textPrimary)
                        .lineSpacing(5)
                }
            }
            .padding(AppTheme.Spacing.xl)
        }
        .frame(maxHeight: 500)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
        .shadow(color: Color.black.opacity(0.03), radius: 12, x: 0, y: 4)
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.bottom, AppTheme.Spacing.xl)
    }

    // MARK: - Interaction Overlay

    private func interactionOverlay(_ question: String) -> some View {
        VStack {
            Spacer()

            VStack(spacing: AppTheme.Spacing.lg) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .foregroundColor(AppTheme.secondary)

                    Text("AI Prompt")
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)

                    Spacer()

                    Button(action: {
                        viewModel.dismissInteractionQuestion()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.textTertiary)
                            .font(.title3)
                    }
                }

                Text(question)
                    .font(.body)
                    .foregroundColor(AppTheme.textSecondary)
                    .lineSpacing(5)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(AppTheme.Spacing.xl)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
            .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
            .padding(.horizontal, AppTheme.Spacing.xl)
            .padding(.bottom, 160)
        }
        .background(
            Color.black.opacity(0.25)
                .edgesIgnoringSafeArea(.all)
        )
        .transition(.opacity)
    }

    // MARK: - Error Alert

    private func errorAlert(_ error: String) -> some View {
        VStack {
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.white)

                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.md)
            .background(AppTheme.recording)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
            .shadow(color: AppTheme.recording.opacity(0.3), radius: 8, x: 0, y: 4)
            .padding(.top, AppTheme.Spacing.xl)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Back Button

    private var backButton: some View {
        Button(action: {
            if viewModel.state == .recording {
                viewModel.stopSession()
            }
            presentationMode.wrappedValue.dismiss()
        }) {
            HStack {
                Image(systemName: "chevron.left")
                Text("Back")
            }
        }
    }
}

struct SessionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SessionView(mode: .solo)
        }
    }
}
