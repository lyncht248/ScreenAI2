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
            ChatView(model: AppConfig.openAIModel)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(destination: SettingsView()) {
                            Image(systemName: "gearshape")
                        }
                    }
                }
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ContentView()
}
