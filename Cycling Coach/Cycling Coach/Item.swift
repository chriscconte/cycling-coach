//
//  Item.swift
//  Cycling Coach
//
//  Created by Christopher Conte on 11/4/25.
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
