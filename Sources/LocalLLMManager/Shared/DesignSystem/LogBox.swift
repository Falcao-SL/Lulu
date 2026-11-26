import SwiftUI
import AppKit

func logBox(_ text: String, empty: String) -> some View {
    ScrollView {
        Text(text.isEmpty ? empty : text)
            .font(LuluTheme.TypeStyle.caption.monospaced())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .textSelection(.enabled)
    }
    .frame(height: 120)
    .background(LuluTheme.subtle)
    .clipShape(RoundedRectangle(cornerRadius: LuluTheme.Radius.control))
}
