//
//  ReminderData.swift
//  TextEditor
//
//  Created by Assistant on 2026-01-27.
//

import Foundation
import SwiftData

@Model
class ReminderData {
    var id: UUID?
    var title: String?
    var dueDate: Date?
    var isCompleted: Bool?
    var hasBeenViewed: Bool?
    var notificationIdentifier: String?
    
    var noteBlock: NoteBlock?
    
    init(id: UUID = UUID(), title: String = "Reminder", dueDate: Date, isCompleted: Bool = false, notificationIdentifier: String? = nil, hasBeenViewed: Bool = false) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.notificationIdentifier = notificationIdentifier
        self.hasBeenViewed = hasBeenViewed
    }
}
