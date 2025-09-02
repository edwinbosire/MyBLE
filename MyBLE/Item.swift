//
//  Item.swift
//  MyBLE
//
//  Created by Edwin Bosire on 02/09/2025.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
