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
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environment(authService)
                    .task {
                        await authService.initialize()
                    }
                    .opacity(showSplash ? 0 : 1)

                if showSplash {
                    SplashView {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showSplash = false
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
    }
}
