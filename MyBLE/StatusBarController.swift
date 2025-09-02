//
//  StatusBarController.swift
//  MyBLE
//
//  Created by Edwin Bosire on 02/09/2025.
//

import AppKit

final class StatusBarController {
	private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
	private let menu = NSMenu()
	private let store: DeviceStore
	private let bluetooth: BluetoothManager
	private var timer: Timer?

	init(store: DeviceStore, bluetooth: BluetoothManager) {
		self.store = store
		self.bluetooth = bluetooth

		if let button = statusItem.button {
			button.image = NSImage(systemSymbolName: "dot.radiowaves.left.and.right", accessibilityDescription: "BLE")
		}
		statusItem.menu = menu

		store.onChange = { [weak self] in self?.rebuildMenu() }
		bluetooth.onStateChange = { [weak self] _ in self?.rebuildMenu() }

		rebuildMenu()
		// optional: periodic battery refresh for connected devices
		timer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
			self?.bluetooth.refreshBatteryForConnected()
		}
	}

	deinit { timer?.invalidate() }

	private func rebuildMenu() {
		menu.removeAllItems()

		// Status row
		let stateTitle = "Bluetooth: \(bluetooth.stateDescription)"
		let stateItem = NSMenuItem(title: stateTitle, action: nil, keyEquivalent: "")
		stateItem.isEnabled = false
		menu.addItem(stateItem)
		menu.addItem(.separator())

		// Connected devices
		let connected = store.connectedDevices
		if connected.isEmpty == false {
			let header = NSMenuItem(title: "Connected", action: nil, keyEquivalent: "")
			header.isEnabled = false
			menu.addItem(header)
			for dev in connected {
				menu.addItem(deviceItem(for: dev, isConnected: true))
			}
			menu.addItem(.separator())
		}

		// Discovered devices
		let discovered = store.discoveredDevices
		let discHeader = NSMenuItem(title: "Discovered", action: nil, keyEquivalent: "")
		discHeader.isEnabled = false
		menu.addItem(discHeader)

		if discovered.isEmpty {
			let none = NSMenuItem(title: "No devices (tap Scan)", action: nil, keyEquivalent: "")
			none.isEnabled = false
			menu.addItem(none)
		} else {
			for dev in discovered {
				menu.addItem(deviceItem(for: dev, isConnected: false))
			}
		}
		menu.addItem(.separator())

		// Actions
		let scanning = bluetooth.isScanning
		let scanTitle = scanning ? "Stop Scan" : "Scan for Devices"
		let scanItem = NSMenuItem(title: scanTitle, action: #selector(toggleScan), keyEquivalent: "s")
		scanItem.target = self
		menu.addItem(scanItem)

		let refreshItem = NSMenuItem(title: "Refresh Battery Levels", action: #selector(refreshBattery), keyEquivalent: "r")
		refreshItem.target = self
		refreshItem.isEnabled = !store.connectedDevices.isEmpty
		menu.addItem(refreshItem)

		let openPrefs = NSMenuItem(title: "Open Bluetooth Settings…", action: #selector(openBluetoothSettings), keyEquivalent: ",")
		openPrefs.target = self
		menu.addItem(openPrefs)

		let unpairHelp = NSMenuItem(title: "Unpair / Remove Device…", action: #selector(openBluetoothSettings), keyEquivalent: "")
		unpairHelp.target = self
		menu.addItem(unpairHelp)

		menu.addItem(.separator())
		let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
		quitItem.target = self
		menu.addItem(quitItem)
	}

	private func deviceItem(for dev: DeviceViewModel, isConnected: Bool) -> NSMenuItem {
		let battery = dev.batteryLevel.map { "\($0)%" } ?? "–"
		var subtitle = "Battery \(battery)"
		if let name = dev.customName { subtitle += " · \(name)" }
		let title = "\(dev.displayName)  (\(subtitle))"

		let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
		let submenu = NSMenu()

		if isConnected {
			let disconnect = NSMenuItem(title: "Disconnect", action: #selector(disconnectDevice(_:)), keyEquivalent: "")
			disconnect.representedObject = dev.id
			disconnect.target = self
			submenu.addItem(disconnect)

			let readBattery = NSMenuItem(title: "Read Battery Now", action: #selector(readBattery(_:)), keyEquivalent: "")
			readBattery.target = self
			readBattery.representedObject = dev.id
			submenu.addItem(readBattery)
		} else {
			let connect = NSMenuItem(title: "Connect", action: #selector(connectDevice(_:)), keyEquivalent: "")
			connect.representedObject = dev.id
			connect.target = self
			submenu.addItem(connect)
		}

		let rename = NSMenuItem(title: "Set Custom Name…", action: #selector(renameDevice(_:)), keyEquivalent: "")
		rename.target = self
		rename.representedObject = dev.id
		submenu.addItem(rename)

		let findInSettings = NSMenuItem(title: "Open in Bluetooth Settings…", action: #selector(openBluetoothSettings), keyEquivalent: "")
		findInSettings.target = self
		submenu.addItem(findInSettings)

		item.submenu = submenu
		return item
	}

	@objc private func toggleScan() {
		bluetooth.isScanning ? bluetooth.stopScan() : bluetooth.startScan()
	}
	@objc private func refreshBattery() { bluetooth.refreshBatteryForConnected() }
	@objc private func connectDevice(_ sender: NSMenuItem) { guard let id = sender.representedObject as? UUID else { return }; bluetooth.connect(id: id) }
	@objc private func disconnectDevice(_ sender: NSMenuItem) { guard let id = sender.representedObject as? UUID else { return }; bluetooth.disconnect(id: id) }
	@objc private func readBattery(_ sender: NSMenuItem) { guard let id = sender.representedObject as? UUID else { return }; bluetooth.readBattery(id: id) }

	@objc private func renameDevice(_ sender: NSMenuItem) {
		guard let id = sender.representedObject as? UUID else { return }
		let alert = NSAlert()
		alert.messageText = "Custom Name"
		alert.informativeText = "Enter a custom name for this device:"
		let tf = NSTextField(frame: .init(x: 0, y: 0, width: 240, height: 24))
		tf.stringValue = ""
		alert.accessoryView = tf
		alert.addButton(withTitle: "Save")
		alert.addButton(withTitle: "Cancel")
		if alert.runModal() == .alertFirstButtonReturn {
			store.setCustomName(for: id, name: tf.stringValue.isEmpty ? nil : tf.stringValue)
		}
	}

	@objc private func openBluetoothSettings() {
		// macOS 13+: opens System Settings → Bluetooth
		NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Bluetooth-Settings.extension")!)
	}
	@objc private func quit() { NSApp.terminate(nil) }
}
