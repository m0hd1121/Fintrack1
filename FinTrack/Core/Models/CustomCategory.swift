import Foundation
import SwiftData
import SwiftUI

// MARK: - Custom Category Model

@Model
final class CustomCategory {
    var id: UUID
    var name: String
    var icon: String
    var colorHex: String
    var isArchived: Bool
    var sortOrder: Int
    var transactionTypeFilter: String  // "any", "expense", "income"
    var createdAt: Date

    @Relationship(deleteRule: .nullify)
    var parent: CustomCategory?

    @Relationship(deleteRule: .cascade, inverse: \CustomCategory.parent)
    var children: [CustomCategory]

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "tag",
        colorHex: String = "#0E9C8A",
        isArchived: Bool = false,
        sortOrder: Int = 0,
        transactionTypeFilter: String = "any",
        parent: CustomCategory? = nil
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.isArchived = isArchived
        self.sortOrder = sortOrder
        self.transactionTypeFilter = transactionTypeFilter
        self.parent = parent
        self.children = []
        self.createdAt = Date()
    }
}

// MARK: - Computed helpers

extension CustomCategory {
    var color: Color { Color(hex: colorHex) }

    var isRoot: Bool { parent == nil }

    var fullPath: String {
        if let p = parent { return "\(p.fullPath) → \(name)" }
        return name
    }

    var depth: Int {
        var d = 0
        var cur: CustomCategory? = parent
        while let p = cur { d += 1; cur = p.parent }
        return d
    }

    var sortedActiveChildren: [CustomCategory] {
        children.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }

    func matchesType(_ type: TransactionType) -> Bool {
        switch transactionTypeFilter {
        case "expense": return type == .expense
        case "income":  return type == .income
        default:        return true
        }
    }
}

// MARK: - Icon / Color palette

extension CustomCategory {
    static let paletteColors: [(name: String, hex: String)] = [
        ("Teal",   "#0E9C8A"), ("Blue",   "#2E78C8"), ("Purple", "#7C5BD0"),
        ("Coral",  "#E5736B"), ("Gold",   "#C8902B"), ("Green",  "#1FA463"),
        ("Red",    "#E5484D"), ("Indigo", "#4B53C5"), ("Pink",   "#E8507B"),
        ("Brown",  "#8B6244"), ("Cyan",   "#00A9CC"), ("Mint",   "#3BA87A"),
    ]

    static let iconSections: [(section: String, icons: [String])] = [
        ("Finance", [
            "banknote", "creditcard", "dollarsign.circle", "percent",
            "chart.line.uptrend.xyaxis", "chart.bar", "chart.pie",
            "building.columns", "arrow.left.arrow.right", "hand.raised.fill",
            "lock.shield", "briefcase",
        ]),
        ("Shopping", [
            "bag", "cart", "gift", "tag", "star", "heart",
            "sparkles", "crown", "tshirt", "eyeglasses",
        ]),
        ("Food & Health", [
            "fork.knife", "cup.and.saucer", "carrot", "pills",
            "cross.circle", "heart.fill", "figure.walk", "leaf",
        ]),
        ("Home & Life", [
            "house", "house.fill", "building", "lightbulb",
            "bolt", "drop", "flame", "wrench",
        ]),
        ("Transport", [
            "car", "fuelpump", "airplane", "bus",
            "tram", "ferry", "bicycle", "scooter",
        ]),
        ("Entertainment", [
            "tv", "gamecontroller", "headphones", "camera",
            "book", "music.note", "ticket", "theatermasks",
        ]),
        ("Work & Tech", [
            "laptopcomputer", "iphone", "desktopcomputer",
            "printer", "envelope", "phone", "wifi",
        ]),
        ("Other", [
            "tag.fill", "ellipsis.circle", "questionmark.circle",
            "folder", "archivebox", "doc", "person.circle", "globe",
        ]),
    ]
}
