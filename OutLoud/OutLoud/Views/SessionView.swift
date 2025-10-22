import SwiftUI

private enum SessionTheme {
    static let primary = Color(red: 0.32, green: 0.45, blue: 0.91)
    static let secondary = Color(red: 0.31, green: 0.68, blue: 0.59)
    static let accent = Color(red: 0.88, green: 0.54, blue: 0.32)
    static let recording = Color(red: 0.92, green: 0.26, blue: 0.3)
    static let success = Color(red: 0.35, green: 0.68, blue: 0.48)
    static let surface = Color(.systemBackground)
    static let surfaceSecondary = Color(red: 0.97, green: 0.97, blue: 0.98)
    static let surfaceTertiary = Color(red: 0.95, green: 0.95, blue: 0.96)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color(white: 0.55)

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    enum Radius {
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
    }
}

struct SessionView: View {
    @StateObject private var viewModel = SessionViewModel()
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            SessionTheme.surfaceTertiary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: SessionTheme.Spacing.xxxl) {
                        headerSection
                        stateSection

                        if viewModel.state == .preparing {
                            preparingView
                        } else if viewModel.state == .processing {
                            processingView
                        }

                        if viewModel.state == .recording {
                            captureView
                        }

                        if hasTranscriptContent {
                            transcriptView
                        } else if viewModel.state == .idle {
                            idlePlaceholder
                        }

                        if viewModel.state == .completed, let analysis = viewModel.analysisResult {
                            analysisView(analysis)
                        }
                    }
                    .padding(.horizontal, SessionTheme.Spacing.xl)
                    .padding(.top, SessionTheme.Spacing.xxxl)
                    .padding(.bottom, SessionTheme.Spacing.xxxl * 2)
                }

                controlButton
                    .padding(.horizontal, SessionTheme.Spacing.xl)
                    .padding(.bottom, SessionTheme.Spacing.xxxl)
            }

            if let question = viewModel.interactionQuestion {
                interactionOverlay(question)
            }

            if let error = viewModel.errorMessage {
                errorBanner(error)
            }
        }
        .navigationBarBackButtonHidden(viewModel.state == .recording)
        .navigationBarItems(leading: backButton)
        .animation(.easeInOut(duration: 0.25), value: viewModel.state)
        .animation(.easeInOut(duration: 0.25), value: viewModel.analysisResult != nil)
        .onAppear {
            if viewModel.state == .idle {
                viewModel.startSession()
            }
        }
    }

    // MARK: - Header & Status

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: SessionTheme.Spacing.sm) {
            Text("Out Loud")
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundColor(SessionTheme.textPrimary)

            Text(stateSubtitle)
                .font(.subheadline)
                .foregroundColor(SessionTheme.textSecondary)
        }
    }

    private var stateSection: some View {
        HStack(spacing: SessionTheme.Spacing.sm) {
            Circle()
                .fill(stateColor)
                .frame(width: 8, height: 8)

            Text(stateTitle)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(stateColor)

            Spacer()

            Text(stateHint)
                .font(.footnote)
                .foregroundColor(SessionTheme.textTertiary)
        }
        .padding(.horizontal, SessionTheme.Spacing.lg)
        .padding(.vertical, SessionTheme.Spacing.md)
        .background(SessionTheme.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: SessionTheme.Radius.lg))
    }

    private var stateTitle: String {
        switch viewModel.state {
        case .idle:
            return "Ready"
        case .preparing:
            return "Setting up"
        case .recording:
            return "Recording"
        case .processing:
            return "Processing"
        case .completed:
            return "Complete"
        }
    }

    private var stateSubtitle: String {
        switch viewModel.state {
        case .idle:
            return "Press start when you are ready to capture your thoughts."
        case .preparing:
            return "Getting the room ready – we will begin in a moment."
        case .recording:
            return "Speak naturally. We will take care of the transcript."
        case .processing:
            return "Finishing up your transcript and pulling insights."
        case .completed:
            return "Review what you covered or start another pass."
        }
    }

    private var stateHint: String {
        switch viewModel.state {
        case .idle:
            return "Nothing is being recorded."
        case .preparing:
            return "Connecting to the mic and Soniox."
        case .recording:
            return "Tap finish when you are done."
        case .processing:
            return "Hang tight while we tidy things up."
        case .completed:
            return "Saved locally until you reset."
        }
    }

    private var stateColor: Color {
        switch viewModel.state {
        case .idle:
            return SessionTheme.primary
        case .preparing:
            return SessionTheme.secondary
        case .recording:
            return SessionTheme.recording
        case .processing:
            return SessionTheme.textTertiary
        case .completed:
            return SessionTheme.success
        }
    }

    // MARK: - Recording helpers

    private var captureView: some View {
        VStack(alignment: .leading, spacing: SessionTheme.Spacing.lg) {
            if !viewModel.displayedCaption.isEmpty {
                Text(viewModel.displayedCaption)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(SessionTheme.secondary)
                    .padding(.horizontal, SessionTheme.Spacing.lg)
                    .padding(.vertical, SessionTheme.Spacing.md)
                    .background(SessionTheme.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: SessionTheme.Radius.md))
            }

            AudioWaveformView(
                audioLevel: viewModel.audioLevel,
                isRecording: viewModel.state == .recording
            )
            .frame(height: 86)
            .padding(.top, SessionTheme.Spacing.sm)
        }
        .padding(SessionTheme.Spacing.xl)
        .background(SessionTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: SessionTheme.Radius.xl))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    private var preparingView: some View {
        VStack(alignment: .leading, spacing: SessionTheme.Spacing.md) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: SessionTheme.secondary))

            Text("Connecting session")
                .font(.headline)
                .foregroundColor(SessionTheme.textPrimary)

            Text("Warming up the mic and pairing with Soniox.")
                .font(.subheadline)
                .foregroundColor(SessionTheme.textSecondary)
        }
        .padding(SessionTheme.Spacing.xl)
        .background(SessionTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: SessionTheme.Radius.xl))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    private var processingView: some View {
        VStack(alignment: .leading, spacing: SessionTheme.Spacing.md) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: SessionTheme.primary))

            Text("Wrapping things up")
                .font(.headline)
                .foregroundColor(SessionTheme.textPrimary)

            Text("We are cleaning the transcript and summarizing your session.")
                .font(.subheadline)
                .foregroundColor(SessionTheme.textSecondary)
        }
        .padding(SessionTheme.Spacing.xl)
        .background(SessionTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: SessionTheme.Radius.xl))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    private var idlePlaceholder: some View {
        VStack(alignment: .leading, spacing: SessionTheme.Spacing.md) {
            Text("No transcript yet")
                .font(.headline)
                .foregroundColor(SessionTheme.textPrimary)

            Text("Hit start and speak freely. We will break everything into clean paragraphs automatically.")
                .font(.subheadline)
                .foregroundColor(SessionTheme.textSecondary)
        }
        .padding(SessionTheme.Spacing.xl)
        .background(SessionTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: SessionTheme.Radius.xl))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    // MARK: - Transcript

    private var hasTranscriptContent: Bool {
        !viewModel.fullTranscript.isEmpty
    }

    private var transcriptView: some View {
        VStack(alignment: .leading, spacing: SessionTheme.Spacing.lg) {
            HStack {
                Text("Transcript")
                    .font(.headline)
                    .foregroundColor(SessionTheme.textPrimary)

                Spacer()

                if viewModel.state == .recording {
                    Text("Live")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(SessionTheme.recording)
                        .padding(.horizontal, SessionTheme.Spacing.md)
                        .padding(.vertical, SessionTheme.Spacing.xs)
                        .background(SessionTheme.recording.opacity(0.08))
                        .clipShape(Capsule())
                }
            }

            Text(viewModel.fullTranscript)
                .font(.body)
                .foregroundColor(SessionTheme.textPrimary)
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(SessionTheme.Spacing.xl)
        .background(SessionTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: SessionTheme.Radius.xl))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    // MARK: - Analysis

    private func analysisView(_ analysis: AnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: SessionTheme.Spacing.xxl) {
            VStack(alignment: .leading, spacing: SessionTheme.Spacing.xs) {
                Text("Session summary")
                    .font(.headline)
                    .foregroundColor(SessionTheme.textPrimary)

                Text("Here is what stood out.")
                    .font(.subheadline)
                    .foregroundColor(SessionTheme.textSecondary)
            }

            metricsRow(for: analysis)

            Divider()
                .opacity(0.2)

            VStack(alignment: .leading, spacing: SessionTheme.Spacing.md) {
                Text("Summary")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(SessionTheme.textTertiary)
                    .textCase(.uppercase)

                Text(sanitizedSentences(from: analysis.summary))
                    .font(.body)
                    .foregroundColor(SessionTheme.textPrimary)
                    .lineSpacing(6)
            }

            if !analysis.keywords.isEmpty {
                VStack(alignment: .leading, spacing: SessionTheme.Spacing.md) {
                    Text("Topics")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(SessionTheme.textTertiary)
                        .textCase(.uppercase)

                    FlowLayout(spacing: SessionTheme.Spacing.sm) {
                        ForEach(uniqueStrings(analysis.keywords), id: \.self) { keyword in
                            Text(keyword)
                                .font(.subheadline)
                                .foregroundColor(SessionTheme.textSecondary)
                                .padding(.horizontal, SessionTheme.Spacing.md)
                                .padding(.vertical, SessionTheme.Spacing.xs)
                                .background(SessionTheme.surfaceSecondary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            let nextSteps = uniqueStrings(analysis.report.missingPoints)
            if !nextSteps.isEmpty {
                VStack(alignment: .leading, spacing: SessionTheme.Spacing.md) {
                    Text("Next time")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(SessionTheme.textTertiary)
                        .textCase(.uppercase)

                    VStack(alignment: .leading, spacing: SessionTheme.Spacing.sm) {
                        ForEach(nextSteps, id: \.self) { point in
                            HStack(alignment: .top, spacing: SessionTheme.Spacing.sm) {
                                Text("·")
                                    .font(.headline)
                                    .foregroundColor(SessionTheme.accent)

                                Text(point)
                                    .font(.subheadline)
                                    .foregroundColor(SessionTheme.textSecondary)
                                    .lineSpacing(4)
                            }
                        }
                    }
                }
            }

            let followUp = sanitizedSentences(from: analysis.followUpQuestion)
            if !followUp.isEmpty {
                VStack(alignment: .leading, spacing: SessionTheme.Spacing.md) {
                    Text("Keep exploring")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(SessionTheme.textTertiary)
                        .textCase(.uppercase)

                    Text(followUp)
                        .font(.body)
                        .foregroundColor(SessionTheme.textPrimary)
                        .lineSpacing(5)
                }
            }
        }
        .padding(SessionTheme.Spacing.xl)
        .background(SessionTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: SessionTheme.Radius.xl))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    private func metricsRow(for analysis: AnalysisResult) -> some View {
        let metrics = [
            Metric(title: "Depth", value: analysis.report.thinkingIntensity, caption: "Thinking intensity", color: SessionTheme.primary),
            Metric(title: "Flow", value: analysis.report.coherenceScore, caption: "Coherence", color: SessionTheme.secondary),
            Metric(title: "Pause", value: analysis.report.pauseTime, caption: "Seconds silent", color: SessionTheme.accent)
        ]

        let columns = [
            GridItem(.flexible(), spacing: SessionTheme.Spacing.lg),
            GridItem(.flexible(), spacing: SessionTheme.Spacing.lg)
        ]

        return LazyVGrid(columns: columns, spacing: SessionTheme.Spacing.lg) {
            ForEach(metrics) { metric in
                metricView(metric)
            }
        }
    }

    private func metricView(_ metric: Metric) -> some View {
        VStack(alignment: .leading, spacing: SessionTheme.Spacing.sm) {
            Text(String(metric.value))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(metric.color)

            Text(metric.title)
                .font(.headline)
                .foregroundColor(SessionTheme.textPrimary)

            Text(metric.caption)
                .font(.footnote)
                .foregroundColor(SessionTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, SessionTheme.Spacing.lg)
        .padding(.horizontal, SessionTheme.Spacing.lg)
        .background(SessionTheme.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: SessionTheme.Radius.lg))
    }

    private struct Metric: Identifiable {
        let id = UUID()
        let title: String
        let value: Int
        let caption: String
        let color: Color
    }

    // MARK: - Actions

    private var controlButton: some View {
        Button(action: handlePrimaryAction) {
            HStack {
                Spacer()

                if viewModel.state == .processing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(buttonTitle)
                        .font(.headline)
                        .fontWeight(.semibold)
                }

                Spacer()
            }
            .padding(.vertical, SessionTheme.Spacing.lg)
            .foregroundColor(.white)
            .background(buttonColor)
            .clipShape(RoundedRectangle(cornerRadius: SessionTheme.Radius.lg))
            .opacity((viewModel.state == .processing || viewModel.state == .preparing) ? 0.7 : 1.0)
        }
        .disabled(viewModel.state == .processing || viewModel.state == .preparing)
    }

    private func handlePrimaryAction() {
        switch viewModel.state {
        case .idle:
            viewModel.startSession()
        case .preparing:
            break
        case .recording:
            viewModel.stopSession()
        case .processing:
            break
        case .completed:
            viewModel.resetSession()
        }
    }

    private var buttonTitle: String {
        switch viewModel.state {
        case .idle:
            return "Start Recording"
        case .preparing:
            return "Preparing…"
        case .recording:
            return "Finish Recording"
        case .processing:
            return "Processing"
        case .completed:
            return "Start Again"
        }
    }

    private var buttonColor: Color {
        switch viewModel.state {
        case .idle:
            return SessionTheme.primary
        case .preparing:
            return SessionTheme.secondary
        case .recording:
            return SessionTheme.recording
        case .processing:
            return SessionTheme.textTertiary
        case .completed:
            return SessionTheme.success
        }
    }

    private var backButton: some View {
        Button(action: {
            if viewModel.state == .recording {
                viewModel.stopSession()
            }
            presentationMode.wrappedValue.dismiss()
        }) {
            HStack(spacing: SessionTheme.Spacing.xs) {
                Image(systemName: "chevron.left")
                Text("Back")
            }
            .foregroundColor(SessionTheme.textPrimary)
        }
    }

    // MARK: - Overlays

    private func interactionOverlay(_ question: String) -> some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.dismissInteractionQuestion()
                }

            VStack(alignment: .leading, spacing: SessionTheme.Spacing.lg) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(SessionTheme.secondary)

                    Text("AI Prompt")
                        .font(.headline)
                        .foregroundColor(SessionTheme.textPrimary)

                    Spacer()

                    Button(action: viewModel.dismissInteractionQuestion) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(SessionTheme.textTertiary)
                            .font(.title3)
                    }
                }

                Text(question)
                    .font(.body)
                    .foregroundColor(SessionTheme.textSecondary)
                    .lineSpacing(5)
            }
            .padding(SessionTheme.Spacing.xl)
            .background(SessionTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: SessionTheme.Radius.xl))
            .shadow(color: Color.black.opacity(0.16), radius: 16, x: 0, y: 10)
            .padding(.horizontal, SessionTheme.Spacing.xl)
        }
        .transition(.opacity)
    }

    private func errorBanner(_ error: String) -> some View {
        VStack {
            HStack(spacing: SessionTheme.Spacing.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.white)

                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, SessionTheme.Spacing.lg)
            .padding(.vertical, SessionTheme.Spacing.md)
            .background(SessionTheme.recording)
            .clipShape(RoundedRectangle(cornerRadius: SessionTheme.Radius.md))
            .shadow(color: SessionTheme.recording.opacity(0.25), radius: 10, x: 0, y: 6)
            .padding(.top, SessionTheme.Spacing.xl)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Helpers

    private func splitIntoSentences(from text: String) -> [String] {
        var sentences: [String] = []
        var buffer = ""

        for character in text {
            buffer.append(character)
            if ".!?".contains(character) {
                let sentence = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
                if !sentence.isEmpty {
                    sentences.append(sentence)
                }
                buffer.removeAll(keepingCapacity: false)
            }
        }

        let tail = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty {
            sentences.append(tail)
        }

        return sentences
    }

    private func sanitizedSentences(from text: String) -> String {
        let components = splitIntoSentences(from: text)
        let sentences = components.isEmpty ? [text] : components

        var seen = Set<String>()
        var unique: [String] = []

        for rawSentence in sentences {
            let sentence = rawSentence.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sentence.isEmpty else { continue }
            let canonical = normalizedForDuplicateCheck(sentence)
            if seen.insert(canonical).inserted {
                unique.append(sentence)
            }
        }

        return unique.joined(separator: " ")
    }

    private func uniqueStrings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for rawValue in values {
            let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { continue }
            let key = normalizedForDuplicateCheck(value)
            if seen.insert(key).inserted {
                result.append(value)
            }
        }

        return result
    }

    private func normalizedForDuplicateCheck(_ text: String) -> String {
        text
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: " .!?,;:\n\t"))
    }
}

// MARK: - FlowLayout used for keywords

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
            subview.place(
                at: CGPoint(
                    x: bounds.minX + result.frames[index].minX,
                    y: bounds.minY + result.frames[index].minY
                ),
                proposal: .unspecified
            )
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
