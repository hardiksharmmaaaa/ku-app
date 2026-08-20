//
//  KUTheme.swift
//  ku-onboarding
//
//  Created by Hardik Sharma on 20/08/26.
//
//  Khalifa University brand theme: deep KU Blue + White.
//  Official brand colors sourced from KU visual identity guidelines
//  (primary blue #1C4F9D, verified from the official KU logo asset).

import SwiftUI

enum KUTheme {

    // MARK: - Palette (official KU brand)
    /// KU Blue — primary brand color (#1C4F9D)
    static let blue = Color("KU Blue")
    /// Deep KU Navy — used for gradients / darker accents (#123B8A)
    static let blueDeep = Color("KU Blue Deep")
    /// Soft ice-blue tint — subtle fills and backgrounds (#EBF6FC)
    static let blueSoft = Color("KU Blue Soft")
    /// White — surface / text on brand blue
    static let white = Color("KU White")
    /// Near-black text color for light surfaces
    static let text = Color("KU Text")

    // MARK: - Typography
    static let displayFont = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let titleFont = Font.system(.title2, design: .rounded, weight: .semibold)
    static let bodyFont = Font.system(.body, design: .rounded)
    static let captionFont = Font.system(.caption, design: .rounded)

    // MARK: - Styling helpers
    static let cornerRadius: CGFloat = 14
    static let buttonHeight: CGFloat = 54

    /// Primary brand background gradient (navy → blue)
    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [blueDeep, blue],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}