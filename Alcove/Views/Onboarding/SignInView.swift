import GoogleSignInSwift
import SwiftUI

struct SignInView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.colorScheme) private var colorScheme

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

                ZStack {
                    GoogleSignInButton(
                        scheme: colorScheme == .dark ? .dark : .light,
                        style: .wide,
                        state: isWorking ? .disabled : .normal
                    ) {
                        Task { await signIn() }
                    }
                    .frame(maxWidth: 320)
                    .accessibilityIdentifier("signin.google")

                    if isWorking { ProgressView() }
                }

                #if DEBUG
                Button("Continue without an account") {
                    auth.continueAsGuest()
                }
                .font(.subheadline.weight(.medium))
                .padding(.top, 4)
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
