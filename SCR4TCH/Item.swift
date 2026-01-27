//
//  Item.swift
//  SCR4TCH
//
//  Created by Michael Martell on 1/27/26.
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
