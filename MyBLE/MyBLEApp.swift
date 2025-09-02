//
//  MyBLEApp.swift
//  MyBLE
//
//  Created by Edwin Bosire on 02/09/2025.
//

import SwiftUI
import SwiftData

@main
struct MyBLEApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

//	var body: some Scene {
//		WindowGroup {
//			ContentView()
//		}
//		.modelContainer(sharedModelContainer)
//	}

	@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
	var body: some Scene {
		Settings { EmptyView() } // no settings window
			.modelContainer(sharedModelContainer)
	}

}

final class AppDelegate: NSObject, NSApplicationDelegate {
	private var statusBarController: StatusBarController!

	func applicationDidFinishLaunching(_ notification: Notification) {
		let store = DeviceStore()
		let bluetooth = BluetoothManager(store: store)
		statusBarController = StatusBarController(store: store, bluetooth: bluetooth)
		bluetooth.start() // set up CBCentralManager, defer scanning until user taps “Scan”
	}
}
