import SwiftUI

@main
struct OutLoudApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationView {
                ZStack {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.97, green: 0.97, blue: 0.98),
                            Color(red: 0.99, green: 0.99, blue: 1.0)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()

                    VStack(spacing: 0) {
                        Spacer()

                        VStack(spacing: 16) {
                            Text("Out Loud")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)

                            Text("讲出来,才能真正学会")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .tracking(0.5)
                        }
                        .padding(.bottom, 80)

                        Spacer()

                        NavigationLink(destination: SessionView()) {
                            HStack(spacing: 12) {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 20, weight: .semibold))

                                Text("Start Session")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.32, green: 0.45, blue: 0.91),
                                        Color(red: 0.28, green: 0.40, blue: 0.82)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color(red: 0.32, green: 0.45, blue: 0.91).opacity(0.3), radius: 12, x: 0, y: 6)
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 60)
                    }
                }
                .navigationBarHidden(true)
            }
        }
    }
}
