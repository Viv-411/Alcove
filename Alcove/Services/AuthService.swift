import Foundation
import GoogleSignIn
import Observation
import UIKit

struct UserProfile: Codable, Equatable {
    var id: String
    var name: String
    var email: String?
    var imageURL: URL?
    /// Local-only account used in debug builds and UI tests.
    var isGuest = false

    var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }
}

/// Google sign-in. The account gives each person an identity now, so homes can
/// be shared with family once sync is added.
@Observable
final class AuthService {
    enum State: Equatable {
        case checking
        case signedOut
        case signedIn(UserProfile)
    }

    private(set) var state: State = .checking

    var profile: UserProfile? {
        if case .signedIn(let profile) = state { return profile }
        return nil
    }

    /// False until a real OAuth client ID is pasted into Config/Google.xcconfig.
    static var isConfigured: Bool {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String else { return false }
        return id.hasSuffix(".apps.googleusercontent.com")
    }

    private static let guestKey = "auth.guestProfile"

    func restore() async {
        if let data = UserDefaults.standard.data(forKey: Self.guestKey),
           let guest = try? JSONDecoder().decode(UserProfile.self, from: data) {
            state = .signedIn(guest)
            return
        }
        guard Self.isConfigured, GIDSignIn.sharedInstance.hasPreviousSignIn() else {
            state = .signedOut
            return
        }
        do {
            let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            state = .signedIn(Self.profile(from: user))
        } catch {
            state = .signedOut
        }
    }

    func signInWithGoogle() async throws {
        guard Self.isConfigured else { throw AuthError.notConfigured }
        guard let presenter = Self.topViewController() else { throw AuthError.noWindow }
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        state = .signedIn(Self.profile(from: result.user))
    }

    /// A device-only account for trying the app before Google is set up.
    func continueAsGuest(name: String = "You") {
        let guest = UserProfile(id: "guest-\(UUID().uuidString)", name: name, isGuest: true)
        if let data = try? JSONEncoder().encode(guest) {
            UserDefaults.standard.set(data, forKey: Self.guestKey)
        }
        state = .signedIn(guest)
    }

    func signOut() {
        UserDefaults.standard.removeObject(forKey: Self.guestKey)
        if Self.isConfigured { GIDSignIn.sharedInstance.signOut() }
        state = .signedOut
    }

    func handle(_ url: URL) {
        guard Self.isConfigured else { return }
        _ = GIDSignIn.sharedInstance.handle(url)
    }

    // MARK: - Helpers

    private static func profile(from user: GIDGoogleUser) -> UserProfile {
        UserProfile(
            id: user.userID ?? UUID().uuidString,
            name: user.profile?.name ?? user.profile?.email ?? "You",
            email: user.profile?.email,
            imageURL: user.profile?.imageURL(withDimension: 200)
        )
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ?? UIApplication.shared.connectedScenes.first as? UIWindowScene
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

enum AuthError: LocalizedError {
    case notConfigured, noWindow

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Google sign-in isn't set up in this build yet. Add your Google client ID to Config/Google.xcconfig."
        case .noWindow:
            "Couldn't open the sign-in screen. Please try again."
        }
    }
}
