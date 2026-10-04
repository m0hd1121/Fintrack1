import SwiftData

/// The single list of persisted model types.
///
/// `FinTrackApp` builds its `Schema` from this, and `DataResetService` walks it
/// to wipe user data. "Clear All Data" used to delete from its own hand-kept
/// list, which fell 5 types behind the schema — including the review queue —
/// so anything added here is now covered automatically instead of silently
/// surviving a reset. Register new `@Model` types here and nowhere else.
enum AppSchema {
    static let modelTypes: [any PersistentModel.Type] = [
        Account.self,
        Transaction.self,
        DocumentAttachment.self,
        CustomCategory.self,
        CategorizationRule.self,
        Budget.self,
        SavingsGoal.self,
        BudgetEnvelope.self,
        BudgetTemplate.self,
        Bill.self,
        Loan.self,
        CreditCard.self,
        Investment.self,
        CryptoHolding.self,
        Dividend.self,
        BNPLPlan.self,
        UserProfile.self,
        AppSettings.self,
        GoldHolding.self,
        GiftCard.self,
        LoyaltyProgram.self,
        SalaryRecord.self,
        FreelanceProject.self,
        RentalProperty.self,
        MoneyLent.self,
        MoneyBorrowed.self,
        RealEstateProperty.self,
        Vehicle.self,
        PersonalAsset.self,
        DigitalAsset.self,
        NetWorthSnapshot.self,
        NetWorthMilestone.self,
        TaxRecord.self,
        TaxDocument.self,
        ZakatRecord.self,
        TaxConfiguration.self,
        FamilyGroup.self,
        ChildProfile.self,
        SharedFamilyGoal.self,
        ClientProfile.self,
        BusinessInvoice.self,
        MileageTrip.self,
        BusinessProject.self,
        ImportedFile.self,
        EmailAccount.self,
        PendingEmailTransaction.self,
        BankEmailRule.self,
        AuditLogEntry.self,
        RemittanceRecord.self,
        InsurancePolicy.self,
        RetirementPlan.self,
        LifeEventPlan.self,
        AdvisorAccess.self,
    ]
}
