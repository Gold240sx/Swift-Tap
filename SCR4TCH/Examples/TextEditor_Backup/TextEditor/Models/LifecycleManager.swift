import Foundation
import SwiftData

@MainActor
class LifecycleManager {
    static let shared = LifecycleManager()
    
    private init() {}
    
    func runCleanup(context: ModelContext) {
        // Fetch settings
        let settingsFetch = FetchDescriptor<AppSettings>()
        guard let settings = try? context.fetch(settingsFetch).first else { return }
        
        let now = Date.now
        
        // 1. Check for Temp notes that should be Deleted
        let tempFetch = FetchDescriptor<RichTextNote>(
            predicate: #Predicate<RichTextNote> { $0.statusRaw == "temp" }
        )
        if let tempNotes = try? context.fetch(tempFetch) {
            for note in tempNotes {
                let expirationDate = Calendar.current.date(byAdding: .hour, value: settings.tempDurationHours, to: note.createdOn) ?? now
                if expirationDate < now {
                    note.status = .deleted
                    note.movedToDeletedOn = now
                }
            }
        }
        
        // 2. Check for Deleted notes that should be purged permanently
        let deletedFetch = FetchDescriptor<RichTextNote>(
            predicate: #Predicate<RichTextNote> { $0.statusRaw == "deleted" }
        )
        if let deletedNotes = try? context.fetch(deletedFetch) {
            for note in deletedNotes {
                if let movedOn = note.movedToDeletedOn {
                    let purgeDate = Calendar.current.date(byAdding: .day, value: 30, to: movedOn) ?? now
                    if purgeDate < now {
                        // Permanent deletion
                        // Note: cascade handles blocks/tables
                        context.delete(note)
                    }
                } else {
                    // Safety: if movedToDeletedOn is missing for some reason, set it now
                    note.movedToDeletedOn = now
                }
            }
        }
        
        try? context.save()
    }
}
