import SwiftUI

struct TableGridPicker: View {
    @Binding var selectedRows: Int
    @Binding var selectedCols: Int
    var onSelect: (Int, Int) -> Void
    
    @State private var hoveredRows: Int = 0
    @State private var hoveredCols: Int = 0
    
    let maxRows = 10
    let maxCols = 10
    let cellSize: CGFloat = 25
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Insert Table")
                .font(.headline)
            
            Text("\(hoveredRows > 0 ? hoveredRows : selectedRows) x \(hoveredCols > 0 ? hoveredCols : selectedCols)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 2) {
                ForEach(1...maxRows, id: \.self) { row in
                    HStack(spacing: 2) {
                        ForEach(1...maxCols, id: \.self) { col in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isHighlighted(row: row, col: col) ? Color.accentColor : Color.gray.opacity(0.2))
                                .frame(width: cellSize, height: cellSize)
                                .onHover { hovering in
                                    if hovering {
                                        hoveredRows = row
                                        hoveredCols = col
                                    }
                                }
                                .onTapGesture {
                                    selectedRows = row
                                    selectedCols = col
                                    onSelect(row, col)
                                }
                        }
                    }
                }
            }
            .padding(10)
            .background {
                #if os(macOS)
                Color(NSColor.windowBackgroundColor)
                #else
                Color(UIColor.secondarySystemBackground)
                #endif
            }
            .cornerRadius(12)
        }
        .padding()
        .frame(width: CGFloat(maxCols) * (cellSize + 2) + 40)
    }
    
    private func isHighlighted(row: Int, col: Int) -> Bool {
        let r = hoveredRows > 0 ? hoveredRows : selectedRows
        let c = hoveredCols > 0 ? hoveredCols : selectedCols
        return row <= r && col <= c
    }
}

#Preview {
    TableGridPicker(selectedRows: .constant(0), selectedCols: .constant(0)) { r, c in
        print("Selected \(r)x\(c)")
    }
}
