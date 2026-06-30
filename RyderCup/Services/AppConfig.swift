import Foundation

/// Build-conditional defaults. Debug builds (simulator, Xcode → Run) talk to a
/// local backend. Release builds (TestFlight, App Store) hit the deployed
/// Railway URL.
///
/// To override at runtime — useful when testing a Debug build against the live
/// API, or pointing a single device at a staging URL — use Settings → "Change
/// API URL". The override is stored in UserDefaults.
enum AppConfig {

    static var defaultAPIBaseURL: String {
        #if DEBUG
        return "http://localhost:5050"
        #else
        return "https://REPLACE-WITH-RAILWAY-URL.up.railway.app"
        #endif
    }

    /// True when this is a Debug build. Use sparingly — generally prefer config
    /// over branching on this directly.
    static var isDebugBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
