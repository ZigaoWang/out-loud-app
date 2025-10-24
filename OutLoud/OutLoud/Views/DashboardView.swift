import SwiftUI
import AVFoundation

enum DashboardTheme {
    static let primary = Color.black
    static let secondary = Color(red: 0.20, green: 0.78, blue: 0.35)
    static let surface = Color(.systemBackground)
    static let surfaceSecondary = Color(red: 0.98, green: 0.98, blue: 0.98)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color(white: 0.6)
}

struct DashboardView: View {
    @StateObject private var sessionManager = SessionManager.shared
    @State private var navigateToSession = false

    var body: some View {
        NavigationView {
            ZStack {
                DashboardTheme.surfaceSecondary
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        headerSection
                        statsSection
                        startButton

                        if !sessionManager.savedSessions.isEmpty {
                            historySection
                        }
                    }
                    .padding(.horizontal, adaptivePadding)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                    .frame(maxWidth: 700)
                }
                .frame(maxWidth: .infinity)

                NavigationLink(
                    destination: SessionView(),
                    isActive: $navigateToSession
                ) {
                    EmptyView()
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
    }

    private var adaptivePadding: CGFloat {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad ? 40 : 20
        #else
        return 40
        #endif
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Out Loud")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundColor(DashboardTheme.textPrimary)

            Text("Speak to learn. Think out loud.")
                .font(.system(size: 17))
                .foregroundColor(DashboardTheme.textSecondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 30)
        .padding(.bottom, 10)
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Total Time",
                value: sessionManager.formattedTotalTime,
                icon: "clock.fill",
                color: DashboardTheme.primary
            )

            StatCard(
                title: "Sessions",
                value: "\(sessionManager.sessionCount)",
                icon: "mic.fill",
                color: DashboardTheme.secondary
            )
        }
    }

    // MARK: - Start Button

    private var startButton: some View {
        Button(action: {
            navigateToSession = true
        }) {
            Text("Start Recording")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [Color.black, Color.black.opacity(0.9)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recent")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(DashboardTheme.textPrimary)

            VStack(spacing: 10) {
                ForEach(sessionManager.savedSessions.prefix(10)) { session in
                    NavigationLink(destination: SessionDetailView(session: session, isPresented: .constant(true))) {
                        SessionRow(session: session)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contextMenu {
                        Button(role: .destructive) {
                            sessionManager.deleteSession(session)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(DashboardTheme.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)

            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(DashboardTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(DashboardTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.black.opacity(0.04), lineWidth: 1)
                )
        )
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: SavedSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.displayTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(DashboardTheme.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Text(session.formattedDuration)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(DashboardTheme.textSecondary)

                        if let followUpCount = session.followUpSessionIds?.count, followUpCount > 0 {
                            Text("•")
                                .font(.caption2)
                                .foregroundColor(DashboardTheme.textTertiary)

                            Text("+\(followUpCount) follow-ups")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(DashboardTheme.secondary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DashboardTheme.textTertiary.opacity(0.4))
            }

            Text(session.formattedDate)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DashboardTheme.textTertiary)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DashboardTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.black.opacity(0.04), lineWidth: 1)
                )
        )
    }
}


struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
    }
}
