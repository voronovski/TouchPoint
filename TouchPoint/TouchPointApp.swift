//
//  TouchPointApp.swift
//  TouchPoint
//
//  Created by Aleksei Voronovskii on 9/2/26.
//

import SwiftUI
import UserNotifications

@main
struct TouchPointApp: App {
    init() {
        // Install before the first scene is created so taps received during launch
        // are routed to the shared navigation state.
        UNUserNotificationCenter.current().delegate = TouchPointNotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
