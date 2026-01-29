import SwiftUI

struct EmojiPickerView: View {
    @Binding var emoji: String?
    @Environment(\.dismiss) var dismiss
    
    let presets = ["📄", "📝", "⭐️", "❗️", "✅", "📅", "💡", "🔥", "🚀", "📁", "📂", "🎉", "❤️", "🟢", "🟦", "🔔"]
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Select Icon")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 36))], spacing: 8) {
                ForEach(presets, id: \.self) { preset in
                    Button {
                        emoji = preset
                        dismiss()
                    } label: {
                        Text(preset)
                            .font(.system(size: 28))
                            .frame(width: 36, height: 36)
                            .background(emoji == preset ? Color.accentColor.opacity(0.15) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            
            Divider()
            
            HStack {
                Text("Custom:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextField("...", text: Binding(
                    get: { emoji ?? "" },
                    set: { val in
                        if !val.isEmpty {
                            emoji = String(val.last!)
                        } else {
                            // Don't clear on empty string input immediately, allows typing replacement
                        }
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 40)
                .multilineTextAlignment(.center)
                .onChange(of: emoji) { oldValue, newValue in
                     // Optional: dismiss if typed? No, explicitly close or click away.
                }
                
                Spacer()
                
                if emoji != nil {
                    Button("Remove") {
                        emoji = nil
                        dismiss()
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .padding(.top, 12)
        .frame(width: 260)
    }
}
