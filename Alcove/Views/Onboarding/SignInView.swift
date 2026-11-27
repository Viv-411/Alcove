import SwiftUI

struct SignInView: View {
    @Environment(AuthService.self) private var auth

    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 18) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 104, height: 104)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 16, y: 8)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("Alcove")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    Text("Sign in to set up your home.\nYour family will be able to join it later.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()

            VStack(spacing: 14) {
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }

                ContinueWithGoogleButton(isWorking: isWorking) {
                    Task { await signIn() }
                }
                .accessibilityIdentifier("signin.google")

                #if DEBUG
                Button("Continue without an account") {
                    auth.continueAsGuest()
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier("signin.guest")

                if !AuthService.isConfigured {
                    Text("Debug build: Google sign-in needs a client ID in Config/Google.xcconfig.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                #endif

                Text("Alcove only uses your name, email and photo to set up your home.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background {
            LinearGradient(colors: [Color.accentColor.opacity(0.14), Color(.systemBackground)],
                           startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
        }
    }

    private func signIn() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await auth.signInWithGoogle()
            errorMessage = nil
        } catch let error as NSError where error.domain == "com.google.GIDSignIn" && error.code == -5 {
            // The person closed the Google sheet; nothing to report.
        } catch {
            withAnimation { errorMessage = error.localizedDescription }
        }
    }
}

/// "Continue with Google", following Google's branding rules: the official
/// G logo, approved wording, and Google's light and dark colours.
struct ContinueWithGoogleButton: View {
    var isWorking = false
    var action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Image("GoogleG")
                        .resizable()
                        .frame(width: 20, height: 20)
                        .opacity(isWorking ? 0 : 1)
                    if isWorking {
                        ProgressView().controlSize(.small)
                    }
                }
                .frame(width: 20, height: 20)
                Text("Continue with Google")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(fill, in: Capsule())
            .overlay(Capsule().strokeBorder(border, lineWidth: 1))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.06), radius: 10, y: 4)
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .disabled(isWorking)
        .accessibilityLabel("Continue with Google")
    }

    // Google's published button colours.
    private var fill: Color { colorScheme == .dark ? Color(hex: 0x131314) : .white }
    private var border: Color { colorScheme == .dark ? Color(hex: 0x8E918F) : Color(hex: 0xDADCE0) }
    private var textColor: Color { colorScheme == .dark ? Color(hex: 0xE3E3E3) : Color(hex: 0x1F1F1F) }
}

/// Shrinks slightly while pressed.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
