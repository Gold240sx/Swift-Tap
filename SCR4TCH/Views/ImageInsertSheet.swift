//
//  ImageInsertSheet.swift
//  TextEditor
//
//  Created by Assistant
//

import SwiftUI

struct ImageInsertSheet: View {
    @Binding var isPresented: Bool
    var onInsert: (String, String?, Double?, Double?) -> Void
    
    @State private var urlString = ""
    @State private var altText = ""
    @State private var widthString = ""
    @State private var heightString = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Insert Image")
                .font(.headline)
            
            Form {
                Section {
                    TextField("Image URL", text: $urlString)
                        .textFieldStyle(.roundedBorder)
                    TextField("Alt Text (Optional)", text: $altText)
                        .textFieldStyle(.roundedBorder)
                }
                
                Section {
                    HStack {
                        TextField("Width", text: $widthString)
                            .textFieldStyle(.roundedBorder)
                        Text("px")
                        
                        TextField("Height", text: $heightString)
                            .textFieldStyle(.roundedBorder)
                        Text("px")
                    }
                } header: {
                    Text("Dimensions (Optional)")
                }
            }
            .formStyle(.grouped)
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Insert") {
                    let width = Double(widthString)
                    let height = Double(heightString)
                    let alt = altText.isEmpty ? nil : altText
                    onInsert(urlString, alt, width, height)
                    isPresented = false
                }
                .disabled(urlString.isEmpty)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400, height: 350)
    }
}
