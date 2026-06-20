// FinTrackWatchApp.swift
// Apple Watch companion app for FinTrack.
//
// Setup in Xcode:
//   1. File > New > Target > watchOS > Watch App (standalone)
//   2. Name: FinTrackWatch, Bundle: com.mohd.fintrackpro.FinTrackWatch
//   3. Add App Group "group.com.fintrack.shared" to both watch and main app targets
//   4. Delete generated ContentView and use this file + Views/

import SwiftUI

@main
struct FinTrackWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
    }
}
