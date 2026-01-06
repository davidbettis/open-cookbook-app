//
//  MainTabView.swift
//  DoctorRecipe
//
//  Created by Claude Code on 1/6/26.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            // Recipes tab - placeholder for now
            NavigationStack {
                ContentView()
                    .navigationTitle("Recipes")
            }
            .tabItem {
                Label("Recipes", systemImage: "book")
            }

            // Settings tab
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    MainTabView()
        .environment(FolderManager())
}
