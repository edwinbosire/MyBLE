//
//  BluetoothManager.swift
//  MyBLE
//
//  Created by Edwin Bosire on 02/09/2025.
//

import Foundation
import CoreBluetooth

// GATT Battery Service/Characteristic
private let batteryServiceUUID = CBUUID(string: "180F")
private let batteryLevelCharUUID = CBUUID(string: "2A19")
// Optional: Device Information Service UUIDs could be added if you want to read manufacturer/model.

final class BluetoothManager: NSObject {
	private(set) var central: CBCentralManager!
	private let store: DeviceStore

	var onStateChange: ((CBManagerState) -> Void)?
	private(set) var isScanning = false

	init(store: DeviceStore) {
		self.store = store
		super.init()
	}

	func start() {
		central = CBCentralManager(delegate: self, queue: .main)
	}

	var stateDescription: String {
		guard central != nil else { return "Initializing…" }
		switch central.state {
			case .unknown: return "Unknown"
			case .resetting: return "Resetting"
			case .unsupported: return "Unsupported"
			case .unauthorized: return "Unauthorized"
			case .poweredOff: return "Off"
			case .poweredOn: return "On"
			@unknown default: return "Other"
		}
	}

	func startScan() {
		guard central.state == .poweredOn else { return }
		isScanning = true
		// nil services ⇒ general discovery
		central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
	}

	func stopScan() {
		isScanning = false
		central.stopScan()
	}

	func connect(id: UUID) {
		guard let dev = store.device(for: id) else { return }
		central.connect(dev.peripheral, options: nil)
	}

	func disconnect(id: UUID) {
		guard let dev = store.device(for: id) else { return }
		central.cancelPeripheralConnection(dev.peripheral)
	}

	func readBattery(id: UUID) {
		guard let dev = store.device(for: id) else { return }
		dev.peripheral.delegate = self
		if let services = dev.peripheral.services, services.contains(where: { $0.uuid == batteryServiceUUID }) {
			discoverBattery(on: dev.peripheral)
		} else {
			dev.peripheral.discoverServices([batteryServiceUUID])
		}
	}

	func refreshBatteryForConnected() {
		for dev in store.connectedDevices {
			readBattery(id: dev.id)
		}
	}

	// Connected peripherals already known by the system (for particular services).
	private func retrieveConnected() {
		let connected = central.retrieveConnectedPeripherals(withServices: [batteryServiceUUID])
		for p in connected {
			attach(peripheral: p, discovered: false)
		}
	}

	private func attach(peripheral: CBPeripheral, discovered: Bool) {
		peripheral.delegate = self
		store.upsertPeripheral(peripheral, discovered: discovered)
	}

	private func discoverBattery(on p: CBPeripheral) {
		guard let svc = p.services?.first(where: { $0.uuid == batteryServiceUUID }) else {
			p.discoverServices([batteryServiceUUID]); return
		}
		p.discoverCharacteristics([batteryLevelCharUUID], for: svc)
	}
}

extension BluetoothManager: CBCentralManagerDelegate {
	func centralManagerDidUpdateState(_ central: CBCentralManager) {
		onStateChange?(central.state)
		if central.state == .poweredOn {
			retrieveConnected()
		}
	}

	func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
						advertisementData: [String : Any], rssi RSSI: NSNumber) {
		attach(peripheral: peripheral, discovered: true)
		// You could store RSSI or adv fields in DeviceStore if desired.
	}

	func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
		store.markConnected(peripheral)
		// Kick battery service discovery to populate % quickly
		peripheral.discoverServices([batteryServiceUUID])
	}

	func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
		store.markDisconnected(peripheral)
	}

	func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
		store.markDisconnected(peripheral)
	}
}

extension BluetoothManager: CBPeripheralDelegate {
	func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
		guard error == nil else { return }
		discoverBattery(on: peripheral)
	}

	func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
		guard error == nil else { return }
		if service.uuid == batteryServiceUUID {
			if let char = service.characteristics?.first(where: { $0.uuid == batteryLevelCharUUID }) {
				peripheral.readValue(for: char)
				peripheral.setNotifyValue(true, for: char) // subscribe if supported
			}
		}
	}

	func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
		guard error == nil else { return }
		if characteristic.uuid == batteryLevelCharUUID, let data = characteristic.value, let level = data.first {
			store.updateBattery(peripheral, level: Int(level))
		}
	}
}
