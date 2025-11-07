import SwiftUI

struct AuthView: View {
    @StateObject private var supabase = SupabaseService.shared

    @State private var screen: Screen = .landing
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading = false
    @State private var feedback: FeedbackMessage?
    @State private var showResetSheet = false
    @State private var pendingResendEmail: String?

    @FocusState private var focusedField: Field?

    private let passwordValidator = PasswordValidator()
    private let primaryColor = Color(red: 0.18, green: 0.36, blue: 0.98)

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ZStack {
                    if screen == .landing {
                        landingView
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        formView(
                            title: screen == .signIn ? "Sign In" : "Create Account",
                            subtitle: screen == .signIn
                                ? "Access your sessions, transcripts, and insights."
                                : "Start recording, reflecting, and improving every time you speak.",
                            showChecklist: screen == .signUp
                        )
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: screen)
                .padding(.horizontal, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if screen != .landing {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { present(.landing) }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 17, weight: .semibold))
                                Text("Back")
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showResetSheet) {
            PasswordResetSheet(initialEmail: email)
        }
    }

    // MARK: Landing
    private var landingView: some View {
        VStack(alignment: .leading, spacing: 40) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Welcome to Out Loud")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(.label))

                Text("Your space to speak freely, capture every insight, and grow with clarity.")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color(.secondaryLabel))
                    .frame(maxWidth: 420, alignment: .leading)
            }
            .padding(.top, 32)

            Spacer()

            VStack(spacing: 12) {
                CTAButton(title: "Sign In", isPrimary: true, color: primaryColor) {
                    present(.signIn)
                }

                CTAButton(title: "Create Account", isPrimary: false, color: primaryColor) {
                    present(.signUp)
                }
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: Form
    private func formView(title: String, subtitle: String, showChecklist: Bool) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(title)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(.label))
                    Text(subtitle)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color(.secondaryLabel))
                        .lineSpacing(3)
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color(.label))

                            TextField("", text: $email, prompt: Text("you@example.com").foregroundColor(Color(.placeholderText)))
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .textContentType(.username)
                                .autocorrectionDisabled()
                                .font(.system(size: 16))
                                .foregroundStyle(Color(.label))
                                .tint(primaryColor)
                                .padding(16)
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(focusedField == .email ? primaryColor.opacity(0.5) : Color(.systemGray4), lineWidth: 1.5)
                                )
                                .focused($focusedField, equals: .email)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color(.label))

                            SecureField("Enter password", text: $password)
                                .textContentType(showChecklist ? .newPassword : .password)
                                .font(.system(size: 16))
                                .padding(16)
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(focusedField == .password ? primaryColor.opacity(0.5) : Color(.systemGray4), lineWidth: 1.5)
                                )
                                .focused($focusedField, equals: .password)
                        }

                        if screen == .signIn {
                            Button("Forgot password?") {
                                showResetSheet = true
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(primaryColor)
                        }

                        if screen == .signIn, let resendEmail = pendingResendEmail {
                            Button("Resend confirmation email") {
                                resendConfirmationEmail(email: resendEmail)
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(primaryColor)
                        }
                    }

                    if showChecklist {
                        PasswordChecklist(requirements: passwordValidator.requirements, password: password)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let feedback {
                        FeedbackBanner(feedback: feedback)
                    }

                    Button(action: authenticate) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(screen == .signUp ? "Create Account" : "Sign In")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(primaryColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .shadow(color: primaryColor.opacity(0.3), radius: 12, x: 0, y: 6)
                    .disabled(isLoading)
                    .opacity(isLoading ? 0.6 : 1)
                }
                .padding(24)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                HStack(spacing: 4) {
                    Text(screen == .signIn ? "New to Out Loud?" : "Already have an account?")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(.secondaryLabel))
                    Button(screen == .signIn ? "Create an account" : "Sign in") {
                        present(screen == .signIn ? .signUp : .signIn)
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(primaryColor)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                Spacer(minLength: 24)
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: Helpers
    private func present(_ target: Screen, preserveFeedback: Bool = false) {
        withAnimation {
            screen = target
        }

        switch target {
        case .landing:
            email = ""
            password = ""
            feedback = nil
            focusedField = nil
            pendingResendEmail = nil

        case .signIn, .signUp:
            if !preserveFeedback {
                feedback = nil
                pendingResendEmail = nil
            }
            password = ""
            focusedField = .email
        }
    }

    private func authenticate() {
        guard screen == .signIn || screen == .signUp else { return }
        feedback = nil

        guard Validators.emailIsValid(email) else {
            feedback = .error("Enter a valid email address.")
            focusedField = .email
            return
        }

        if screen == .signUp && !passwordValidator.validate(password) {
            feedback = .error("Choose a stronger password that meets every requirement.")
            focusedField = .password
            return
        }

        if password.isEmpty {
            feedback = .error("Password is required.")
            focusedField = .password
            return
        }

        isLoading = true

        Task {
            do {
                if screen == .signUp {
                    let confirmationRequired = try await supabase.signUp(email: email.trimmedLowercased(), password: password)
                    if confirmationRequired {
                        await MainActor.run {
                            pendingResendEmail = email.trimmedLowercased()
                            present(.signIn, preserveFeedback: true)
                            feedback = .info("Check your inbox to confirm your email, then sign in.")
                        }
                    } else {
                        await MainActor.run {
                            feedback = .success("Account created. You're all set!")
                        }
                    }
                } else {
                    try await supabase.signIn(email: email.trimmedLowercased(), password: password)
                    await MainActor.run {
                        pendingResendEmail = nil
                    }
                }
            } catch {
                let message = error.localizedDescription
                let lower = message.lowercased()

                if screen == .signIn && lower.contains("confirm") {
                    await MainActor.run {
                        pendingResendEmail = email.trimmedLowercased()
                        feedback = .info("Please confirm your email before signing in. Tap below to resend the confirmation email.")
                    }
                } else if screen == .signUp && lower.contains("registered") {
                    await MainActor.run {
                        pendingResendEmail = email.trimmedLowercased()
                        feedback = .info("This email is already registered. If you still need to verify it, resend the confirmation email from here.")
                        present(.signIn, preserveFeedback: true)
                    }
                } else {
                    await MainActor.run {
                        pendingResendEmail = nil
                        feedback = .error(message)
                    }
                }
            }

            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func resendConfirmationEmail(email: String) {
        Task {
            do {
                try await supabase.resendConfirmationEmail(email: email)
                await MainActor.run {
                    pendingResendEmail = nil
                    feedback = .success("Confirmation email sent to \(email).")
                }
            } catch {
                await MainActor.run {
                    feedback = .error(error.localizedDescription)
                }
            }
        }
    }

enum Field {
        case email, password
    }

    private enum Screen {
        case landing
        case signIn
        case signUp
    }
}

// MARK: Components
private struct CTAButton: View {
    let title: String
    let isPrimary: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isPrimary ? color : Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isPrimary ? Color.clear : Color(.systemGray4), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isPrimary ? .white : Color(.label))
        .shadow(color: isPrimary ? color.opacity(0.3) : Color.clear, radius: 12, x: 0, y: 6)
    }
}

private struct PasswordValidator {
    struct Requirement: Identifiable {
        let id = UUID()
        let description: String
        let validation: (String) -> Bool
    }

    let requirements: [Requirement] = [
        Requirement(description: "At least 8 characters") { $0.count >= 8 },
        Requirement(description: "Includes a lowercase letter") { $0.range(of: "[a-z]", options: .regularExpression) != nil },
        Requirement(description: "Includes an uppercase letter") { $0.range(of: "[A-Z]", options: .regularExpression) != nil },
        Requirement(description: "Includes a digit") { $0.range(of: "[0-9]", options: .regularExpression) != nil },
        Requirement(description: "Includes a symbol (e.g. !@#$)") { $0.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil }
    ]

    func validate(_ password: String) -> Bool {
        requirements.allSatisfy { $0.validation(password) }
    }
}

private struct PasswordChecklist: View {
    let requirements: [PasswordValidator.Requirement]
    let password: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(requirements) { requirement in
                let satisfied = requirement.validation(password)
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: satisfied ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14))
                        .foregroundStyle(satisfied ? Color(.systemGreen) : Color(.tertiaryLabel))

                    Text(requirement.description)
                        .font(.system(size: 14))
                        .foregroundStyle(satisfied ? Color(.label) : Color(.secondaryLabel))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
}

private struct FeedbackBanner: View {
    let feedback: FeedbackMessage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: feedback.iconName)
                .font(.system(size: 14))
            Text(feedback.message)
                .font(.system(size: 14))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .foregroundStyle(feedback.foregroundColor)
        .background(feedback.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct PasswordResetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email: String
    @State private var isSubmitting = false
    @State private var feedback: FeedbackMessage?

    private let supabase = SupabaseService.shared

    init(initialEmail: String) {
        _email = State(initialValue: initialEmail)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Account email")) {
                    TextField("you@example.com", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                }

                if let feedback {
                    Section {
                        FeedbackBanner(feedback: feedback)
                    }
                }
            }
            .navigationTitle("Reset password")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send link", action: sendReset)
                        .disabled(isSubmitting)
                }
            }
        }
    }

    private func sendReset() {
        feedback = nil
        guard Validators.emailIsValid(email) else {
            feedback = .error("Enter a valid email address.")
            return
        }

        isSubmitting = true
        Task {
            do {
                try await supabase.sendPasswordReset(email: email.trimmedLowercased())
                await MainActor.run {
                    feedback = .success("Password reset email sent. Follow the link to choose a new password.")
                }
            } catch {
                await MainActor.run {
                    feedback = .error(error.localizedDescription)
                }
            }

            await MainActor.run {
                isSubmitting = false
            }
        }
    }
}

private struct FeedbackMessage: Equatable {
    enum Style { case success, error, info }

    let message: String
    let style: Style

    static func success(_ message: String) -> FeedbackMessage { FeedbackMessage(message: message, style: .success) }
    static func error(_ message: String) -> FeedbackMessage { FeedbackMessage(message: message, style: .error) }
    static func info(_ message: String) -> FeedbackMessage { FeedbackMessage(message: message, style: .info) }

    var iconName: String {
        switch style {
        case .success: return "checkmark.seal.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .info: return "envelope.fill"
        }
    }

    var foregroundColor: Color {
        switch style {
        case .success: return Color(.systemGreen)
        case .error: return Color(.systemRed)
        case .info: return Color(.systemBlue)
        }
    }

    var backgroundColor: Color {
        switch style {
        case .success: return Color(.systemGreen).opacity(0.12)
        case .error: return Color(.systemRed).opacity(0.12)
        case .info: return Color(.systemBlue).opacity(0.12)
        }
    }
}

private enum Validators {
    static func emailIsValid(_ email: String) -> Bool {
        email.contains("@") && email.contains(".")
    }
}

private extension String {
    func trimmedLowercased() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
