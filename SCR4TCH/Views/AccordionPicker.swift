//
//  AccordionPicker.swift
//  TextEditor
//
//  Picker for choosing heading level when inserting an accordion block.
//

import SwiftUI

struct AccordionPicker: View {
    var onSelect: (AccordionData.HeadingLevel) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Insert Accordion")
                .font(.headline)
                .padding(.bottom, 4)

            Button {
                onSelect(.h1)
            } label: {
                HStack {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("Heading 1")
                        .font(.title)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                onSelect(.h2)
            } label: {
                HStack {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("Heading 2")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                onSelect(.h3)
            } label: {
                HStack {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("Heading 3")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding()
        .frame(width: 200)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    AccordionPicker { level in
        print("Selected: \(level)")
    }
}
