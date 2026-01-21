//
//  TextBlockView.swift
//  TextEditor
//
//  A wrapper view for NoteBlock text content.
//

import SwiftUI

struct TextBlockView: View {
    @Bindable var block: NoteBlock
    @Binding var selection: AttributedTextSelection
    var focusState: FocusState<UUID?>.Binding

    var body: some View {
        TextEditor(text: Binding(
            get: { block.text ?? "" },
            set: { block.text = $0 }
        ), selection: $selection)
        .focused(focusState, equals: block.id)
        .frame(minHeight: 30)
        .scrollDisabled(true)
    }
}
