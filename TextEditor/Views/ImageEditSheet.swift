//
//  ImageEditSheet.swift
//  TextEditor
//
//  Created by Assistant
//

import SwiftUI
import SwiftData

struct ImageEditSheet: View {
    @Binding var isPresented: Bool
    var imageData: ImageData
    
    @State private var urlString = ""
    @State private var altText = ""
    @State private var widthString = ""
    @State private var heightString = ""
    @Environment(\.modelContext) var context
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Image")
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
                
                Button("Save") {
                    imageData.urlString = urlString
                    imageData.altText = altText.isEmpty ? nil : altText
                    imageData.width = Double(widthString)
                    imageData.height = Double(heightString)
                    try? context.save()
                    isPresented = false
                }
                .disabled(urlString.isEmpty)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400, height: 350)
        .onAppear {
            urlString = imageData.urlString
            altText = imageData.altText ?? ""
            if let width = imageData.width {
                widthString = String(format: "%.0f", width)
            }
            if let height = imageData.height {
                heightString = String(format: "%.0f", height)
            }
        }
    }
}
