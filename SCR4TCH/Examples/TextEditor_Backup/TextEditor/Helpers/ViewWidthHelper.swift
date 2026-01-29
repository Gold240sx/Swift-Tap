import SwiftUI

struct ViewWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension View {
    func measureWidth(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: ViewWidthKey.self, value: proxy.size.width)
            }
        )
        .onPreferenceChange(ViewWidthKey.self, perform: onChange)
    }
}
