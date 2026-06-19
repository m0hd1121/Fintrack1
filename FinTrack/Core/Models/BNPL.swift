import Foundation
import SwiftData

@Model
final class BNPLPlan {
    var id: UUID
    var name: String
    var provider: BNPLProvider
    var customProvider: String?
    var merchant: String
    var totalAmount: Double
    var currency: String
    var installmentAmount: Double
    var totalInstallments: Int
    var paidInstallments: Int
    var startDate: Date
    var nextPaymentDate: Date
    var notes: String?
    var isCompleted: Bool
    var createdAt: Date

    var remainingAmount: Double { Double(remainingInstallments) * installmentAmount }
    var remainingInstallments: Int { totalInstallments - paidInstallments }
    var progress: Double { Double(paidInstallments) / Double(max(totalInstallments, 1)) }
    var isPaymentDueSoon: Bool {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: nextPaymentDate).day ?? 0
        return days <= 3 && days >= 0
    }

    init(
        id: UUID = UUID(),
        name: String,
        provider: BNPLProvider = .tabby,
        customProvider: String? = nil,
        merchant: String,
        totalAmount: Double,
        currency: String = "AED",
        installmentAmount: Double,
        totalInstallments: Int,
        paidInstallments: Int = 0,
        startDate: Date = Date(),
        nextPaymentDate: Date,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.customProvider = customProvider
        self.merchant = merchant
        self.totalAmount = totalAmount
        self.currency = currency
        self.installmentAmount = installmentAmount
        self.totalInstallments = totalInstallments
        self.paidInstallments = paidInstallments
        self.startDate = startDate
        self.nextPaymentDate = nextPaymentDate
        self.notes = notes
        self.isCompleted = false
        self.createdAt = Date()
    }
}

enum BNPLProvider: String, Codable, CaseIterable {
    case tabby = "Tabby"
    case tamara = "Tamara"
    case postpay = "Postpay"
    case spotii = "Spotii"
    case custom = "Custom"

    var logo: String {
        switch self {
        case .tabby: return "t.circle.fill"
        case .tamara: return "t.square.fill"
        case .postpay: return "p.circle.fill"
        case .spotii: return "s.circle.fill"
        case .custom: return "ellipsis.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .tabby: return "green"
        case .tamara: return "purple"
        case .postpay: return "blue"
        case .spotii: return "orange"
        case .custom: return "gray"
        }
    }
}
