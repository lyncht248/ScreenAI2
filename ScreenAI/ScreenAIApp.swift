//
//  ScreenAIApp.swift
//  ScreenAI
//
//  Created by Thomas Lynch on 29/11/2025.
//

import SwiftUI
@main
struct ScreenAIApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ChatView(apiKey: AppConfig.openAIAPIKey, model: AppConfig.openAIModel)
            }
        }
    }
}
