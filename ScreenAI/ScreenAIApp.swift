//
//  ScreenAIApp.swift
//  ScreenAI
//
//  Created by Thomas Lynch on 29/11/2025.
//

import SwiftUI

@main
struct ScreenAIApp: App {
    @StateObject private var supabaseService = SupabaseService.shared
    
    init() {
        // Initialize Supabase service (creates singleton)
        _ = SupabaseService.shared
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if supabaseService.isAuthenticated {
                    ContentView()
                } else {
                    AuthView()
                }
            }
            .task {
                // Check for existing session on app launch
                await supabaseService.checkSession()
            }
        }
    }
}
