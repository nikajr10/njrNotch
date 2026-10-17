//
//  NotchView.swift
//  njrNotch
//

import SwiftUI

/// Black notch shape pinned to the top edge; grows on hover, shrinks back on exit.
struct NotchView: View {
    static let expandedSize = CGSize(width: 420, height: 180)

    let notchSize: CGSize
    @State private var isExpanded = false

    var body: some View {
        let size = isExpanded ? Self.expandedSize : notchSize
        let radius: CGFloat = isExpanded ? 28 : 10

        UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius)
            .fill(.black)
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded = hovering
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

#Preview {
    NotchView(notchSize: CGSize(width: 200, height: 32))
        .frame(width: 420, height: 180)
}
