//
//  ReminderBlockView.swift
//  TextEditor
//
//  Created by Assistant on 2026-01-27.
//

import SwiftUI
import SwiftData

struct ReminderBlockView: View {
    @Bindable var reminder: ReminderData
    var note: RichTextNote?
    var onDelete: () -> Void = {}
    
    @Environment(\.modelContext) var context
    @State private var showEditPopover = false
    @State private var isHovering = false
    
    // For date editing state
    @State private var tempDate = Date()
    @State private var selectionMode: SelectionMode = .relative
    
    enum SelectionMode: String, CaseIterable {
        case relative = "Relative"
        case time = "Time"
        case dateTime = "Date & Time"
    }
    
    var body: some View {
        HStack {
            // Checkbox
            Button {
                withAnimation {
                    reminder.isCompleted = !(reminder.isCompleted ?? false)
                    updateNotification()
                    try? context.save()
                }
            } label: {
                Image(systemName: (reminder.isCompleted ?? false) ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle((reminder.isCompleted ?? false) ? .green : .secondary)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                // Title (Editable)
                TextField("Reminder", text: Binding(
                    get: { reminder.title ?? "" },
                    set: { reminder.title = $0 }
                ))
                    .font(.headline)
                    .textFieldStyle(.plain)
                    .foregroundStyle((reminder.isCompleted ?? false) ? .secondary : .primary)
                    .strikethrough(reminder.isCompleted ?? false)
                    .onSubmit {
                        updateNotification()
                        try? context.save()
                    }
                
                // Date Display
                Button {
                    showEditPopover = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text(formatDate(reminder.dueDate ?? Date()))
                        if isOverdue && !(reminder.isCompleted ?? false) {
                            Text("Overdue")
                                .fontWeight(.bold)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(isOverdue && !(reminder.isCompleted ?? false) ? .red : .blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showEditPopover) {
                    ReminderEditPopover(currentDate: reminder.dueDate ?? Date()) { newDate in
                        reminder.dueDate = newDate
                        updateNotification()
                        try? context.save()
                        showEditPopover = false
                    }
                    .padding()
                    .frame(width: 300)
                }
            }
            
            Spacer()
            
            // Delete button (on hover)
            if isHovering {
                Button(role: .destructive) {
                    // Cancel notification before deleting
                    if let id = reminder.notificationIdentifier {
                        NotificationManager.shared.cancelNotification(id: id)
                    }
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.gray)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isOverdue && !(reminder.isCompleted ?? false) ? Color.red.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }
    
    var isOverdue: Bool {
        (reminder.dueDate ?? Date()) < Date()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "'Today at' h:mm a"
        } else if Calendar.current.isDateInTomorrow(date) {
             formatter.dateFormat = "'Tomorrow at' h:mm a"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
        }
        return formatter.string(from: date)
    }
    
    // MARK: - Notification Logic
    
    private func updateNotification() {
        // First cancel any existing
        if let id = reminder.notificationIdentifier {
             NotificationManager.shared.cancelNotification(id: id)
             reminder.notificationIdentifier = nil
        }
        
        // Schedule new if needed
        if !(reminder.isCompleted ?? false) && (reminder.dueDate ?? Date()) > Date() {
             // Request permissions if not already granted (just safely calling it)
             NotificationManager.shared.requestAuthorization()
             
             let newID = UUID().uuidString
             reminder.notificationIdentifier = newID
             
             // Safely unwrap note ID to string (SwiftData UUID is persistent)
             var noteInfo: [AnyHashable: Any] = [:]
             if let n = note, let noteId = n.id {
                 noteInfo["noteID"] = noteId.uuidString
             }
             
             NotificationManager.shared.scheduleNotification(
                id: newID,
                title: "Reminder: \(reminder.title ?? "Reminder")",
                body: "Due now",
                date: reminder.dueDate ?? Date(),
                userInfo: noteInfo
             )
        }
    }
}

struct ReminderEditPopover: View {
    @State var currentDate: Date
    var onSave: (Date) -> Void
    
    // Local state for the editing process
    @State private var tempDate: Date
    @State private var selectionMode: SelectionMode
    @Environment(\.dismiss) var dismiss
    
    enum SelectionMode: String, CaseIterable {
        case relative = "Relative"
        case time = "Time"
        case dateTime = "Date & Time"
    }
    
    init(currentDate: Date, onSave: @escaping (Date) -> Void) {
        self._currentDate = State(initialValue: currentDate)
        self.onSave = onSave
        
        // Initialize logic for mode
        self._tempDate = State(initialValue: currentDate)
        
        if Calendar.current.isDateInToday(currentDate) {
            self._selectionMode = State(initialValue: .time)
        } else {
            self._selectionMode = State(initialValue: .dateTime)
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Picker("Mode", selection: $selectionMode) {
                ForEach(SelectionMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            
            Group {
                switch selectionMode {
                case .relative:
                    relativeTimePicker
                case .time:
                    DatePicker("Time", selection: $tempDate, displayedComponents: [.hourAndMinute])
                        .datePickerStyle(.graphical)
                        .padding(.vertical, 4)
                case .dateTime:
                    DatePicker("Date & Time", selection: $tempDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.graphical)
                }
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Set Reminder") {
                    onSave(tempDate)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
    }
    
    private var relativeTimePicker: some View {
        VStack(spacing: 8) {
            HStack {
                relativeButton("15m", minutes: 15)
                relativeButton("30m", minutes: 30)
                relativeButton("45m", minutes: 45)
            }
            HStack {
                relativeButton("1h", minutes: 60)
                relativeButton("2h", minutes: 120)
                relativeButton("Tomorrow", minutes: 0) // Special case
            }
        }
    }
    
    private func relativeButton(_ label: String, minutes: Int) -> some View {
        Button(action: {
            if minutes == 0 {
                // Tomorrow Morning 9 AM
                var components = DateComponents()
                components.day = 1
                components.hour = 9
                components.minute = 0
                if let next = Calendar.current.date(byAdding: components, to: Calendar.current.startOfDay(for: Date())) {
                     tempDate = next
                }
            } else {
                if let next = Calendar.current.date(byAdding: .minute, value: minutes, to: Date()) {
                    tempDate = next
                }
            }
        }) {
            Text(label)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}
