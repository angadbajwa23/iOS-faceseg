//
//  video_inputApp.swift
//  video_input
//
//  Created by Angad bajwa on 5/29/23.
//

import SwiftUI

@main
struct video_inputApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
