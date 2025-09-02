//
//  DeviceStorage.swift
//  MyBLE
//
//  Created by Edwin Bosire on 02/09/2025.
//

import Foundation
import CoreBluetooth

struct DeviceViewModel: Identifiable {
	let id: UUID
	let displayName: String
	let customName: String?
	let isConnected: Bool
	let batteryLevel: Int?
}

final class DeviceStore {
	struct Device {
		let peripheral: CBPeripheral
		var customName: String?
		var batteryLevel: Int?
		var discovered: Bool
		var isConnected: Bool { peripheral.state == .connected }
	}

	private var devices: [UUID: Device] = [:]
	var onChange: (() -> Void)?

	// MARK: Queries
	var connectedDevices: [DeviceViewModel] {
		devices.values.filter { $0.isConnected }.map { vm(from: $0) }.sorted { $0.displayName < $1.displayName }
	}
	var discoveredDevices: [DeviceViewModel] {
		devices.values
			.filter { !$0.isConnected }
			.sorted { ($0.peripheral.name ?? "Unknown") < ($1.peripheral.name ?? "Unknown") }
			.map { vm(from: $0) }
	}

	func device(for id: UUID) -> Device? { devices[id] }

	// MARK: Mutations
	func upsertPeripheral(_ p: CBPeripheral, discovered: Bool) {
		var entry = devices[p.identifier] ?? Device(peripheral: p, customName: nil, batteryLevel: nil, discovered: discovered)
		entry.peripheral.delegate = p.delegate
		entry.discovered = entry.discovered || discovered
		devices[p.identifier] = entry
		onChange?()
	}

	func markConnected(_ p: CBPeripheral) {
		if var entry = devices[p.identifier] {
			devices[p.identifier] = entry
			onChange?()
		}
	}

	func markDisconnected(_ p: CBPeripheral) { onChange?() }

	func updateBattery(_ p: CBPeripheral, level: Int) {
		if var entry = devices[p.identifier] {
			entry.batteryLevel = level
			devices[p.identifier] = entry
			onChange?()
		}
	}

	func setCustomName(for id: UUID, name: String?) {
		if var entry = devices[id] {
			entry.customName = name
			devices[id] = entry
			onChange?()
		}
	}

	// MARK: Helpers
	private func vm(from d: Device) -> DeviceViewModel {
		DeviceViewModel(
			id: d.peripheral.identifier,
			displayName: d.customName ?? d.peripheral.name ?? "Unknown",
			customName: d.customName,
			isConnected: d.isConnected,
			batteryLevel: d.batteryLevel
		)
	}
}
