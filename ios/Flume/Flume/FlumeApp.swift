//
//  FlumeApp.swift
//  Flume
//
//  Created by Julian Dixon on 2/26/26.
//

import SwiftUI

@main
struct FlumeApp: App {
    @State private var authService = AuthService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authService)
                .task {
                    await authService.initialize()
                }
        }
    }
}
