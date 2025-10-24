import SwiftUI
import AVFoundation

enum DashboardTheme {
    static let primary = Color(red: 0.32, green: 0.45, blue: 0.91)
    static let secondary = Color(red: 0.31, green: 0.68, blue: 0.59)
    static let accent = Color(red: 0.88, green: 0.54, blue: 0.32)
    static let surface = Color(.systemBackground)
    static let surfaceSecondary = Color(red: 0.97, green: 0.97, blue: 0.98)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color(white: 0.55)
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
                    VStack(spacing: 24) {
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
                    .frame(maxWidth: 800)
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Out Loud")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(DashboardTheme.textPrimary)

            Text("讲出来,才能真正学会")
                .font(.subheadline)
                .foregroundColor(DashboardTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 20)
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 16) {
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
            HStack(spacing: 12) {
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 24, weight: .semibold))

                Text("Start New Session")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        DashboardTheme.primary,
                        DashboardTheme.primary.opacity(0.8)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: DashboardTheme.primary.opacity(0.3), radius: 12, x: 0, y: 6)
        }
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Sessions")
                .font(.headline)
                .foregroundColor(DashboardTheme.textPrimary)

            VStack(spacing: 12) {
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

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(color)
                }

                Spacer()
            }

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(DashboardTheme.textPrimary)

            Text(title)
                .font(.subheadline)
                .foregroundColor(DashboardTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [DashboardTheme.surface, DashboardTheme.surface.opacity(0.95)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: SavedSession

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(DashboardTheme.primary.opacity(0.1))
                    .frame(width: 48, height: 48)

                Image(systemName: "waveform")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(DashboardTheme.primary)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(session.displayTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DashboardTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(session.formattedDate)
                        .font(.caption)
                        .foregroundColor(DashboardTheme.textSecondary)

                    Text("•")
                        .foregroundColor(DashboardTheme.textTertiary)

                    Text(session.formattedDuration)
                        .font(.caption)
                        .foregroundColor(DashboardTheme.textSecondary)

                    if let followUpCount = session.followUpSessionIds?.count, followUpCount > 0 {
                        Text("•")
                            .foregroundColor(DashboardTheme.textTertiary)

                        Text("+\(followUpCount)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(DashboardTheme.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(DashboardTheme.textTertiary)
        }
        .padding(16)
        .background(DashboardTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 3)
    }
}


struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
    }
}
