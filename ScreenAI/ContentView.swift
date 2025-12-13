//
//  ContentView.swift
//  ScreenAI
//
//  Created by Thomas Lynch on 29/11/2025.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ChatView(apiKey: AppConfig.openAIAPIKey, model: AppConfig.openAIModel)
        }
    }
}

#Preview {
    ContentView()
}
