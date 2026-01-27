import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) var context
    @Query private var allSettings: [AppSettings]
    
    private var settings: AppSettings {
        allSettings.first ?? AppSettings.default
    }
    
    var body: some View {
        Form {
            Section("General") {
                Picker("Default Save Location", selection: Binding(
                    get: { settings.defaultStatus },
                    set: { 
                        settings.defaultStatus = $0
                        try? context.save()
                    }
                )) {
                    Text("Saved Notes").tag(RichTextNote.NoteStatus.saved)
                    Text("Temp Notes").tag(RichTextNote.NoteStatus.temp)
                }
                .help("Select where new notes are saved by default.")
            }
            
            Section("Purpose Management") {
                Picker("Temp Note Duration", selection: Binding(
                    get: { settings.tempDurationHours },
                    set: { 
                        settings.tempDurationHours = $0
                        try? context.save()
                    }
                )) {
                    Text("1 hour").tag(1)
                    Text("12 hours").tag(12)
                    Text("24 hours").tag(24)
                    Text("48 hours").tag(48)
                    Text("7 days").tag(168)
                }
                .help("How long a note stays in 'Temp' before being moved to 'Deleted'.")
                
                Text("Deleted notes are permanently removed after 30 days.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 250)
        .navigationTitle("Settings")
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: AppSettings.self, inMemory: true)
}
