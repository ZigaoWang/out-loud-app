import SwiftUI

struct ModeSelectionView: View {
    @State private var selectedMode: SessionMode?

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.95, green: 0.95, blue: 0.97),
                        Color(red: 0.98, green: 0.98, blue: 0.99)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 48) {
                    // Title
                    VStack(spacing: 12) {
                        Text("Out Loud")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)

                        Text("讲出来,才能真正学会")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 100)

                    Spacer()

                    // Mode Selection
                    VStack(spacing: 20) {
                        NavigationLink(
                            destination: SessionView(mode: .solo),
                            tag: SessionMode.solo,
                            selection: $selectedMode
                        ) {
                            ModernModeCard(
                                title: "Solo",
                                subtitle: "独自练习",
                                description: "专注讲解,深度反馈",
                                icon: "person.fill",
                                color: Color(red: 0.4, green: 0.5, blue: 0.9)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())

                        NavigationLink(
                            destination: SessionView(mode: .interactive),
                            tag: SessionMode.interactive,
                            selection: $selectedMode
                        ) {
                            ModernModeCard(
                                title: "Interactive",
                                subtitle: "互动模式",
                                description: "AI 实时引导思考",
                                icon: "person.2.fill",
                                color: Color(red: 0.3, green: 0.7, blue: 0.6)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 32)

                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
    }
}

struct ModernModeCard: View {
    let title: String
    let subtitle: String
    let description: String
    let icon: String
    let color: Color
    @State private var isPressed = false

    var body: some View {
        HStack(spacing: 20) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(color.opacity(0.1))
                    .frame(width: 56, height: 56)

                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(color)
            }

            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)

                Text(description)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.8))
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color.opacity(0.5))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.7))
                .shadow(color: Color.black.opacity(0.03), radius: 12, x: 0, y: 6)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

struct ModeSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        ModeSelectionView()
    }
}
