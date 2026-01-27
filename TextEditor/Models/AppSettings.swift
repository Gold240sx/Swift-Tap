import Foundation
import SwiftData

@Model
class AppSettings {
    var defaultStatus: RichTextNote.NoteStatus
    var tempDurationHours: Int
    
    init(defaultStatus: RichTextNote.NoteStatus = .saved, tempDurationHours: Int = 24) {
        self.defaultStatus = defaultStatus
        self.tempDurationHours = tempDurationHours
    }
    
    static var `default`: AppSettings {
        AppSettings(defaultStatus: .saved, tempDurationHours: 24)
    }
}
