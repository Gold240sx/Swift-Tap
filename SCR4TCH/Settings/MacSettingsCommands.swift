//
//  MacSettingsCommands.swift
//  SCR4TCH
//
//  Created by Michael Martell on 1/28/26.
//
import SwiftUI

enum SaveEnum {
    case temporary
    case permanent
}

enum FontSizeEnum {
    case small
    case large
}

@Observable
class DefaultSettings {
    var defaultSave: String = "Default"
    var animationsEnabled: Bool = true
    var DarkMode: Bool = false
    var language: String = "en"
    var fontSize: FontSizeEnum = .small
    
    static let shared = DefaultSettings()
    private init() {}
}

struct MacSettingsCommands: Commands {
    @Bindable private var settings = DefaultSettings.shared
    var body: some Commands {
        CommandMenu("Settings") {
            Button("Open Settings...") {
                NotificationCenter.default.post(name: .openSettings, object: nil)
            }
            .keyboardShortcut(",", modifiers: .command)
            
            Divider()
            
            Toggle("Enable Animations", isOn: $settings.animationsEnabled)
                .keyboardShortcut("a")
            Toggle("Dark Mode", isOn: $settings.DarkMode)
                .keyboardShortcut("m")
            Menu("Font Size") {
                Button("Small") { settings.fontSize = .small }
                Button("Large") { settings.fontSize = .large }
            }
            Picker("Language", selection: $settings.language) {
                Text("English").tag("en")
                Text("Spanish").tag("es")
            }
        }
    }
}

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
}


