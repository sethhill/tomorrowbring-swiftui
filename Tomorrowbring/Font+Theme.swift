//
//  Font+Theme.swift
//  tomorrowbring
//

import SwiftUI

extension Font {
    // MARK: Display — BanterGrotesk-Black
    static let appLargeTitle = Font.custom("BanterGrotesk-Black", size: 34, relativeTo: .largeTitle)
    static let appTitle      = Font.custom("BanterGrotesk-Black", size: 28, relativeTo: .title)
    static let appTitle2     = Font.custom("BanterGrotesk-Black", size: 22, relativeTo: .title2)

    // MARK: Section headers — BanterGrotesk-Semibold
    static let appDisplaySemibold     = Font.custom("BanterGrotesk-Semibold", size: 52, relativeTo: .largeTitle)
    static let appLargeTitleSemibold  = Font.custom("BanterGrotesk-Semibold", size: 34, relativeTo: .largeTitle)
    static let appTitle3              = Font.custom("BanterGrotesk-Semibold", size: 20, relativeTo: .title3)
    static let appBodySemibold        = Font.custom("BanterGrotesk-Semibold", size: 17, relativeTo: .body)
    static let appSubheadlineSemibold = Font.custom("BanterGrotesk-Semibold", size: 15, relativeTo: .subheadline)
    static let appCaptionSemibold     = Font.custom("BanterGrotesk-Semibold", size: 12, relativeTo: .caption)

    // MARK: Body — BanterGrotesk-Regular
    static let appBody        = Font.custom("BanterGrotesk-Regular", size: 17, relativeTo: .body)
    static let appSubheadline = Font.custom("BanterGrotesk-Regular", size: 15, relativeTo: .subheadline)
    static let appCaption     = Font.custom("BanterGrotesk-Regular", size: 12, relativeTo: .caption)
    static let appCaption2    = Font.custom("BanterGrotesk-Regular", size: 11, relativeTo: .caption2)
}
