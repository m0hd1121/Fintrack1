# MAP_Models.md — Data Models Reference

Part of PROJECT_MAP.md (see root for navigation). All files under `FinTrack/Core/Models/`.

**Schema check**: all 53 `@Model` classes are registered in `Schema([...])` in `FinTrack/App/FinTrackApp.swift` (~line 37-90). No orphaned models. No `@Attribute(.unique)` anywhere (CloudKit compatibility).

Notation: `TypeName { prop:Type, ..., relationship→OtherType?, computed:name:Type }`

## Account.swift
`Account { id:UUID, name:String, type:AccountType, currency:String, balance:Double, initialBalance:Double, bankName:String, customBankName:String?, accountNumber:String?, color:String, icon:String, isDefault:Bool, isArchived:Bool, isHidden:Bool, isBusiness:Bool, isLinked:Bool, walletProvider:String?, retirementType:String?, sharedMembers:[String], createdAt:Date, updatedAt:Date, notes:String?, minimumBalanceEnabled:Bool, minimumBalance:Double, transactions→[Transaction] (cascade, inverse: Transaction.account), computed:effectiveBankName:String }`
`AccountType: String enum, 9 cases` · `WalletProvider: String enum, 8 cases` (stored as raw `walletProvider: String?`)

## AssetModels.swift
`RealEstateProperty { id:UUID, name:String, propertyTypeRaw:String, address:String?, purchasePrice:Double, purchaseDate:Date, currentValue:Double, mortgageBalance:Double, ownershipPercentage:Double, currency:String, area:Double?, areaUnit:String?, notes:String?, isArchived:Bool, createdAt:Date, updatedAt:Date, computed:equity:Double, computed:ownedValue:Double }`
`RealEstateType: String enum, 7 cases`
`Vehicle { id:UUID, make:String, model:String, year:Int, purchasePrice:Double, purchaseDate:Date, currency:String, registrationNumber:String?, registrationExpiry:Date?, insuranceProvider:String?, insuranceExpiry:Date?, depreciationRate:Double, depreciationMethodRaw:String, manualCurrentValue:Double?, color:String?, notes:String?, isArchived:Bool, createdAt:Date, updatedAt:Date, computed:currentValue:Double }`
`VehicleDepreciationMethod: String enum, 2 cases`
`PersonalAsset { id:UUID, name:String, categoryRaw:String, purchasePrice:Double, purchaseDate:Date, insuranceValue:Double, estimatedMarketValue:Double, currency:String, serialNumber:String?, brand:String?, notes:String?, isArchived:Bool, createdAt:Date, updatedAt:Date }`
`PersonalAssetCategory: String enum, 7 cases`
`DigitalAsset { id:UUID, name:String, typeRaw:String, acquisitionValue:Double, acquisitionDate:Date, currentValue:Double, currency:String, platform:String?, identifier:String?, expiryDate:Date?, notes:String?, isArchived:Bool, createdAt:Date, updatedAt:Date }`
`DigitalAssetType: String enum, 7 cases`
`NetWorthSnapshot { id:UUID, date:Date, totalAssets:Double, totalLiabilities:Double, netWorth:Double, currency:String, breakdownData:Data (externalStorage) → breakdown:[String:Double] }`
`NetWorthMilestone { id:UUID, amount:Double, currency:String, achievedAt:Date, isAcknowledged:Bool }`

## BNPL.swift
`BNPLPlan { id:UUID, name:String, provider:BNPLProvider, customProvider:String?, merchant:String, totalAmount:Double, currency:String, installmentAmount:Double, totalInstallments:Int, paidInstallments:Int, startDate:Date, nextPaymentDate:Date, notes:String?, isCompleted:Bool, createdAt:Date }`
`BNPLProvider: String enum, 5 cases`

## Bill.swift
`BillingCycle: String enum, 5 cases` · `BillCategory: String enum, 10 cases`
`PriceHistoryEntry: Codable struct { id:UUID, amount:Double, date:Date, note:String? }` — native array element (not Data-encoded)
`Bill { id:UUID, name:String, provider:String?, billCategoryRaw:String, colorName:String, icon:String, amount:Double, currency:String, billingCycleRaw:String, nextDueDate:Date, isAutoPay:Bool, autoPayWindowDays:Int, paymentMethodRaw:String, notes:String?, isActive:Bool, isSubscription:Bool, reminderDaysBefore:[Int], priceHistory:[PriceHistoryEntry], lastPaidDate:Date?, lastPaidAmount:Double?, isDismissedWasteAlert:Bool, notifiedOverdueDateRaw:Date?, notifiedAutoPayMissed:Bool, createdAt:Date }`

## Budget.swift
`BudgetPeriod: String enum, 4 cases` · `TemplateSeason: String enum, 4 cases`
`TemplateItem: Codable struct { id:UUID, category:TransactionCategory, suggestedAmount:Double, notes:String? }`
`Budget { id:UUID, name:String, category:TransactionCategory, customCategory:String?, amount:Double, currency:String, period:BudgetPeriod, startDate:Date, endDate:Date?, alertThreshold:Double, isActive:Bool, color:String, createdAt:Date, spent:Double, merchantFilter:String?, isRollover:Bool, rolloverAmount:Double, isShared:Bool, sharedMembers:[String], notifiedThresholds:[Double], notifiedMonth:Int, computed:remaining:Double, computed:progress:Double }`
`SavingsGoalType: String enum, 8 cases` · `GoalContributionFrequency: String enum, 3 cases`
`SavingsGoal { id:UUID, name:String, targetAmount:Double, currentAmount:Double, currency:String, targetDate:Date?, icon:String, color:String, notes:String?, isCompleted:Bool, createdAt:Date, goalTypeRaw:String, linkedAccountId:UUID?, autoContributionEnabled:Bool, autoContributionAmount:Double, autoContributionFrequencyRaw:String, autoContributionDay:Int, roundUpEnabled:Bool, salaryPercentage:Double, conflictPriority:Int, isArchived:Bool, updatedAt:Date, notifiedMilestones:[Double], propertyTargetPrice:Double, downPaymentPercent:Double, educationInstitution:String?, hajjTravelYear:Int, emergencyMonthsTarget:Int, computed:progress:Double, computed:projectedCompletionDate:Date? }` — `linkedAccountId` is a loose UUID, not a relationship
`BudgetEnvelope { id:UUID, name:String, icon:String, colorHex:String, allocatedAmount:Double, category:TransactionCategory, currency:String, sortOrder:Int, notes:String?, createdAt:Date }` — has a `currency` field but no UI picker sets it yet (see STATE in root map)
`BudgetTemplate { id:UUID, name:String, icon:String, colorHex:String, templateDescription:String, seasonRaw:String, isBuiltIn:Bool, items:[TemplateItem], createdAt:Date }`

## BusinessModels.swift
`BusinessInvoiceStatus/ClientStatus/MileageVehicleType/MileagePurpose: String enums`
`InvoiceLineItem: Codable struct { id:UUID, description:String, quantity:Double, unitPrice:Double, vatRate:Double }`
`InvoicePaymentRecord: Codable struct { id:UUID, date:Date, amount:Double, method:String, notes:String? }`
`ClientProfile { id:UUID, name:String, company:String?, email:String?, phone:String?, address:String?, currency:String, statusRaw:String, vatNumber:String?, notes:String?, colorHex:String, createdAt:Date, updatedAt:Date }`
`BusinessInvoice { id:UUID, invoiceNumber:String, clientId:String, clientName:String, clientEmail:String?, currency:String, statusRaw:String, issueDate:Date, dueDate:Date, notes:String?, vatIncluded:Bool, projectName:String?, lineItemsData:Data, paymentsData:Data, createdAt:Date, updatedAt:Date }` — `clientId` loose String ref to ClientProfile.id
`MileageTrip { id:UUID, date:Date, fromLocation:String, toLocation:String, distanceKm:Double, ratePerKm:Double, vehicleTypeRaw:String, purposeRaw:String, clientName:String?, projectName:String?, notes:String?, isReimbursable:Bool, isReimbursed:Bool, currency:String, createdAt:Date }`
`BusinessProject { id:UUID, name:String, clientId:String?, clientName:String?, projectDescription:String?, currency:String, budget:Double, statusRaw:String, startDate:Date, endDate:Date?, colorHex:String, notes:String?, tagKey:String, createdAt:Date, updatedAt:Date }`

## CategorizationRule.swift
`RuleConditionType: String enum, 6 cases`
`CategorizationRule { id:UUID, name:String, isEnabled:Bool, priority:Int, conditionTypeRaw:String, conditionValue:String, amountMin:Double?, amountMax:Double?, targetCategoryRaw:String, targetCustomCategoryID:UUID?, autoTags:[String], createdAt:Date }`

## CreditCard.swift
`CreditCard { id:UUID, name:String, bankName:String, last4Digits:String, creditLimit:Double, outstandingBalance:Double, minimumPayment:Double, dueDate:Date, statementDate:Int, interestRate:Double, currency:String, color:String, icon:String, isActive:Bool, createdAt:Date, notes:String?, computed:availableCredit:Double, computed:utilizationRate:Double }`

## CustomCategory.swift
`CustomCategory { id:UUID, name:String, icon:String, colorHex:String, isArchived:Bool, sortOrder:Int, transactionTypeFilter:String, createdAt:Date, parent→CustomCategory? (nullify), children→[CustomCategory] (cascade, inverse: parent) }` — self-referential hierarchy

## DebtModels.swift
`RepaymentRecord: Codable struct { id:UUID, date:Date, amount:Double, notes:String? }`
`PersonalDebtStatus: String enum, 5 cases`
`MoneyLent { id:UUID, borrowerName:String, contactInfo:String?, amount:Double, currency:String, lendingDate:Date, dueDate:Date?, notes:String?, status:PersonalDebtStatus, reminderEnabled:Bool, reminderDaysBefore:Int, color:String, createdAt:Date, updatedAt:Date, repaymentsData:Data (externalStorage) → repayments:[RepaymentRecord], computed:remainingBalance:Double, computed:computedStatus:PersonalDebtStatus }`
`MoneyBorrowed { ...same shape as MoneyLent, mirror pair (lenderName instead of borrowerName)... }`

## DocumentAttachment.swift
`DocumentAttachment { id:UUID, data:Data (externalStorage), filename:String, mimeType:String, createdAt:Date, transaction→Transaction? }` — inverse of Transaction.documents cascade

## EmailImportModels.swift
`EmailProvider: String enum, 4 cases`
`EmailAccount { id:UUID, emailAddress:String, providerRaw:String, connectedAt:Date, lastSyncAt:Date?, syncEnabled:Bool, totalEmailsScanned:Int, totalTransactionsParsed:Int, seenMessageIdsData:Data → Set<String>, imapHost:String }` — OAuth tokens kept in Keychain only, never in SwiftData
`BankEmailRule { id:UUID, bankName:String, nickname:String, senderEmail:String, senderDomain:String, subjectPattern:String, keywords:[String], currency:String, country:String, timezoneIdentifier:String, accountTypeRaw:String, linkedAccountId:UUID?, autoApprove:Bool, confidenceThreshold:Double, isEnabled:Bool, createdAt:Date, matchedCount:Int }`
`PendingImportStatus: String enum, 3 cases` · `ParsedDirection: String enum, 2 cases`
`PendingEmailTransaction { id:UUID, createdAt:Date, accountId:UUID?, bankName:String, senderAddress:String, emailSubject:String, emailSnippet:String, receivedAt:Date, messageId:String, amount:Double, currency:String, merchantRaw:String, merchantNormalized:String, transactionDate:Date, cardLast4:String?, directionRaw:String, availableBalance:Double?, referenceNumber:String?, suggestedCategoryRaw:String, confidence:Double, suggestedTags:[String], parseExplanation:String, isSuspiciousParse:Bool, suspiciousReason:String?, fingerprint:String, isPossibleDuplicate:Bool, duplicateReason:String?, statusRaw:String, reviewedAt:Date?, approvedTransactionId:UUID?, wasAutoApproved:Bool, matchedRuleId:UUID?, matchedAccountId:UUID?, accountMatchReason:String?, bnplSelectionRaw:String? }` — largest field count; all cross-refs are loose UUIDs

## FamilyModels.swift
`FamilyPermissionLevel/FamilyMemberRole/AllowanceFrequency: String enums`
`FamilyPermissionRecord/FamilyMemberData/AllowancePayment/SharedGoalContribution: Codable structs` (embedded via Data+JSON on the parent models below)
`FamilyGroup { id:UUID, name:String, adminName:String, currency:String, isActive:Bool, notes:String?, createdAt:Date, updatedAt:Date, membersData:Data → members:[FamilyMemberData] }`
`ChildProfile { id:UUID, name:String, dateOfBirth:Date?, monthlyAllowance:Double, currency:String, allowanceFrequencyRaw:String, savingsGoalName:String, savingsGoalAmount:Double, currentSavings:Double, colorHex:String, icon:String, paymentsData:Data → payments:[AllowancePayment], isActive:Bool, notes:String?, createdAt:Date, updatedAt:Date }`
`SharedFamilyGoal { id:UUID, name:String, goalDescription:String, targetAmount:Double, currency:String, targetDate:Date?, icon:String, colorHex:String, isCompleted:Bool, isArchived:Bool, contributionsData:Data → contributions:[SharedGoalContribution], createdAt:Date, updatedAt:Date }`

## GiftCard.swift
`GiftCard { id:UUID, merchant:String, balance:Double, initialBalance:Double, currency:String, cardNumber:String?, pinCode:String?, expiryDate:Date?, purchaseDate:Date, notes:String?, color:String, isUsedUp:Bool, createdAt:Date, updatedAt:Date, computed:isExpired:Bool, computed:usagePercent:Double }` — `pinCode` stored in plaintext (not Keychain)

## GoldHolding.swift
`GoldHolding { id:UUID, name:String, metal:PreciousMetal, form:GoldForm, weightGrams:Double, weightUnit:WeightUnit, purchasePricePerGram:Double, currentPricePerGram:Double, currency:String, storageLocation:String?, locationPurchased:String?, isDubaiGoldSoukPurchase:Bool, purchaseDate:Date, notes:String?, isArchived:Bool, createdAt:Date, updatedAt:Date, computed:currentValue:Double, computed:profitLoss:Double }` — weight always stored in grams; unit is presentation-only
`PreciousMetal: String enum, 4 cases` · `GoldForm: String enum, 5 cases`

## ImportModels.swift
`ImportFileType/ImportStatus: String enums`
`ParsedTransactionItem: Codable struct { id:UUID, date:Date, description:String, amount:Double, currency:String, transactionType:String, suggestedCategory:String, isSelected:Bool, isDuplicate:Bool, notes:String? }` — type/category as plain Strings, not typed enums (unlike most models)
`ImportedFile { id:UUID, fileName:String, fileTypeRaw:String, statusRaw:String, bankName:String?, accountName:String?, importedAt:Date, totalTransactions:Int, importedCount:Int, skippedCount:Int, errorMessage:String?, parsedItemsData:Data → parsedItems:[ParsedTransactionItem] }`

## IncomeModels.swift (largest model file, 602 lines)
`PaymentFrequency/SalaryPaymentStatus/ProjectStatus/InvoiceStatus/RentalPropertyType: String enums` (`ProjectStatus` shared by FreelanceProject + BusinessProject)
`SalaryPayment/FreelanceInvoice/OccupancyPeriod/RentPaymentRecord: Codable structs`
`SalaryRecord { id:UUID, employerName:String, jobTitle:String, currency:String, expectedAmount:Double, expectedPaymentDay:Int, paymentFrequencyRaw:String, isActive:Bool, colorName:String, notes:String?, lastSalaryAlertDate:Date?, paymentsData:Data (externalStorage) → payments:[SalaryPayment], createdAt:Date, updatedAt:Date }`
`FreelanceProject { id:UUID, projectName:String, clientName:String, projectDescription:String?, currency:String, totalValue:Double, statusRaw:String, startDate:Date, endDate:Date?, invoicesData:Data (externalStorage) → invoices:[FreelanceInvoice], notes:String?, colorName:String, isArchived:Bool, createdAt:Date, updatedAt:Date }`
`RentalProperty { id:UUID, propertyName:String, propertyTypeRaw:String, address:String?, currency:String, monthlyRentExpected:Double, isOccupied:Bool, rentDueDay:Int, lastRentAlertDate:Date?, occupancyPeriodsData:Data (externalStorage) → occupancyPeriods:[OccupancyPeriod], paymentHistoryData:Data (externalStorage) → paymentHistory:[RentPaymentRecord], notes:String?, colorName:String, isActive:Bool, createdAt:Date, updatedAt:Date }`

## InsurancePolicy.swift
`InsurancePolicyType: String enum, 8 cases` · `PremiumFrequency: String enum, 3 cases`
`InsurancePolicy { id:UUID, typeRaw:String, policyName:String, provider:String, policyNumber:String?, startDate:Date, endDate:Date, premium:Double, premiumCurrency:String, premiumFrequencyRaw:String, coverageAmount:Double, deductible:Double, beneficiary:String?, notes:String?, isActive:Bool, computed:annualPremium:Double, computed:isExpiringSoon:Bool }`

## Investment.swift
`Investment { id:UUID, name:String, symbol:String, type:InvestmentType, quantity:Double, averageCost:Double, currentPrice:Double, currency:String, exchange:String?, notes:String?, purchaseDate:Date, expenseRatio:Double, dividendYield:Double, lotsData:Data (externalStorage) → lots:[PurchaseLot], salesData:Data (externalStorage) → sales:[SaleRecord], realizedPnL:Double, createdAt:Date, updatedAt:Date, computed:currentValue:Double, computed:totalReturn:Double }`
`InvestmentType: String enum, 7 cases`
`CryptoHolding { ...structurally near-duplicate of Investment, separate model rather than InvestmentType.crypto case... }`
`Dividend { id:UUID, investmentId:UUID, amount:Double, currency:String, date:Date, paymentDate:Date?, notes:String?, securityName:String?, exDividendDate:Date?, taxWithholding:Double, computed:netAmount:Double }` — `investmentId` loose UUID ref

## InvestmentModels.swift (plain value types, no @Model)
`PurchaseLot/SaleRecord: Codable structs` · `CostBasisMethod: String enum, 3 cases` (FIFO/LIFO/average) · `WeightUnit: String enum, 4 cases` · `ContributionFrequency/BenchmarkType: String enums`
`ProjectionPoint, MonteCarloResult, AllocationSlice, CapitalGainsSummary` — calculation-result structs, never persisted

## Loan.swift
`Loan { id:UUID, name:String, loanType:LoanType, principalAmount:Double, outstandingBalance:Double, interestRate:Double, emiAmount:Double, startDate:Date, endDate:Date, nextPaymentDate:Date, currency:String, lenderName:String, notes:String?, isActive:Bool, createdAt:Date, paidInstallments:Int, reminderDaysBefore:Int, lenderPersonName:String?, lenderContactInfo:String?, computed:amortizationSchedule:[AmortizationEntry] }`
`LoanType: String enum, 4 cases` · `AmortizationEntry: plain struct` (computed on the fly, never persisted)

## LoyaltyProgram.swift
`LoyaltyProgram { id:UUID, name:String, programType:LoyaltyProgramType, customProgramName:String?, points:Double, pointsValuePerUnit:Double, currency:String, membershipNumber:String?, tier:String?, expiryDate:Date?, notes:String?, color:String, createdAt:Date, updatedAt:Date, totalPointsEarned:Double, totalPointsRedeemed:Double, computed:estimatedValue:Double }`
`LoyaltyProgramType: String enum, 14 cases`

## PremiumModels.swift
`RetirementPlan { id:UUID, currentAge:Int, targetRetirementAge:Int, currentSavings:Double, monthlyContribution:Double, expectedReturnRate:Double, expectedInflationRate:Double, targetMonthlyIncome:Double, currency:String, yearsOfServiceUAE:Int, monthlyBasicSalary:Double, lastUpdated:Date, computed:projectedGratuity:Double (UAE gratuity formula), computed:projectedFutureValue:Double, computed:readinessScore:Double }`
`LifeEventType: String enum, 8 cases` · `LifeEventChecklistItem: Codable struct`
`LifeEventPlan { id:UUID, eventTypeRaw:String, title:String, targetDate:Date, estimatedCost:Double, currency:String, savedAmount:Double, notes:String?, isCompleted:Bool, checklistData:Data → checklist:[LifeEventChecklistItem] }`
`AdvisorRole: String enum, 2 cases`
`AdvisorAccess { id:UUID, advisorName:String, advisorEmail:String, roleRaw:String, invitedDate:Date, lastAccessDate:Date?, isActive:Bool, accessCode:String, canViewTransactions:Bool, canViewAccounts:Bool, canViewGoals:Bool, canViewDebts:Bool, canAddNotes:Bool, notesData:Data → notes:[AdvisorNote] }`

## RemittanceRecord.swift
`RemittanceProvider: String enum, 9 cases`
`RemittanceRecord { id:UUID, date:Date, providerRaw:String, customProviderName:String?, senderCurrency:String, receiverCurrency:String, sentAmount:Double, receivedAmount:Double, exchangeRate:Double, fee:Double, recipientName:String, recipientCountry:String, referenceNumber:String?, notes:String?, isPending:Bool, computed:effectiveRate:Double }`

## SecurityModels.swift
`AuditEventType: String enum, 14 cases`
`AuditLogEntry { id:UUID, timestamp:Date, eventTypeRaw:String, eventDescription:String, deviceName:String }` — append-only, immutable

## TaxModels.swift
`TaxDocumentType/VATRecordType/ZakatNisabBasis: String enums`
`TaxRecord { id:UUID, title:String, vendorOrCustomer:String, amount:Double, vatAmount:Double, vatRate:Double, vatTypeRaw:String, date:Date, invoiceNumber:String?, currency:String, taxYear:Int, linkedTransactionId:UUID?, notes:String?, createdAt:Date, computed:totalAmount:Double }`
`TaxDocument { fileData:Data (externalStorage), id:UUID, name:String, documentTypeRaw:String, taxYear:Int, taxCategory:String, mimeType:String, linkedTransactionId:UUID?, linkedVATRecordId:UUID?, notes:String?, tags:[String], isArchived:Bool, createdAt:Date }`
`ZakatRecord { id:UUID, taxYear:Int, cashAndSavings:Double, goldValueAED:Double, silverValueAED:Double, investmentsValue:Double, businessInventory:Double, receivablesValue:Double, immediateDebts:Double, basicExpenses:Double, nisabBasisRaw:String, goldNisabGrams:Double, silverNisabGrams:Double, goldPricePerGramAED:Double, silverPricePerGramAED:Double, useManualOverride:Bool, manualZakatAmount:Double, isPaid:Bool, paidDate:Date?, paidAmount:Double, notes:String?, createdAt:Date, updatedAt:Date, computed:zakatDue:Double (2.5% of net zakatable wealth above nisab) }`
`TaxBracket: Codable struct (not @Model)`
`TaxConfiguration { id:UUID, countryCode:String, countryName:String, isSubjectToIncomeTax:Bool, vatRate:Double, personalAllowance:Double, fiscalYearStartMonth:Int, currency:String, bracketsData:Data → brackets:[TaxBracket], updatedAt:Date }` — ships hardcoded presets for AE/SA/GB/US/AU

## Transaction.swift — central hub model
`Transaction { id:UUID, title:String, amount:Double, currency:String, amountInBaseCurrency:Double, type:TransactionType, category:TransactionCategory, customCategory:String?, date:Date, notes:String?, receiptImageData:Data? (externalStorage), isRecurring:Bool, recurringRule:RecurringRule?, merchant:String?, paymentMethod:PaymentMethod, tags:[String], isVerified:Bool, isDuplicate:Bool, createdAt:Date, updatedAt:Date, isPending:Bool, isScheduled:Bool, scheduledDate:Date?, subtype:TransactionSubtype?, splitItems:[SplitItem], incomeSource:String?, latitude:Double?, longitude:Double?, account→Account?, toAccount→Account?, linkedLoan→Loan?, linkedBNPL→BNPLPlan?, documents→[DocumentAttachment] (cascade), chequeNumber:String?, chequeDate:Date?, chequeReminderDaysBefore:Int? (nil = 3-day default; drives `NotificationService.scheduleChequeReminder`, set from `AddTransactionView`'s cheque Stepper), isTaxDeductible:Bool, isVATReclaimable:Bool, customCategoryID:UUID?, linkedLoyaltyProgramID:UUID?, loyaltyPointsAmount:Double, linkedSalaryRecordId:UUID?, linkedSalaryPaymentId:UUID?, linkedMoneyLentId:UUID?, linkedMoneyBorrowedId:UUID?, linkedDebtRepaymentId:UUID?, computed:spendingPairs:[(TransactionCategory,Double)] }` — only 5 real SwiftData relationships (account, toAccount, linkedLoan, linkedBNPL, documents); everything else cross-model is a loose UUID FK
`TransactionType: String enum, 3 cases` · `TransactionCategory: String enum, 34 cases` (largest enum; includes `loanRepayment`, `bnplRepayment`, `personalLentRepayment`) · `PaymentMethod: String enum, 9 cases`
`RecurringRule: Codable struct (not Identifiable)` · `RecurringFrequency: String enum, 6 cases` · `SplitItem: Codable struct`

## UserProfile.swift
`UserProfile { id:UUID, name:String, email:String?, baseCurrency:String, language:AppLanguage, monthlyIncomeGoal:Double, monthlySavingsGoal:Double, avatarData:Data?, joinDate:Date, isPremium:Bool, hasCompletedOnboarding:Bool }`
`AppLanguage: String enum, 2 cases`
`AppSettings { id:UUID, useBiometrics:Bool, usePIN:Bool, pinHash:String?, autoLockMinutes:Int, showBalanceOnDashboard:Bool, defaultCurrency:String, decoyPINHash:String?, hiddenModeEnabled:Bool, twoFactorEnabled:Bool, twoFactorSecret:String?, auditLogEnabled:Bool, encryptionEnabled:Bool, notificationsEnabled:Bool, budgetAlertsEnabled:Bool, billRemindersEnabled:Bool, salaryReminderEnabled:Bool, reminderDaysBefore:Int, lowBalanceAlertEnabled:Bool, lowBalanceThreshold:Double, largeTransactionAlertEnabled:Bool, largeTransactionThreshold:Double, goalMilestoneAlertEnabled:Bool, budgetAlertAt75:Bool, budgetAlertAt90:Bool, budgetAlertAt100:Bool, weeklyDigestEnabled:Bool, monthlyDigestEnabled:Bool, digestDayOfWeek:Int, digestDayOfMonth:Int, digestHour:Int, cloudSyncEnabled:Bool, backupWifiOnly:Bool, theme:AppTheme, accentColorName:String, oledMode:Bool, highContrastMode:Bool, fiscalYearStartMonth:Int, firstDayOfWeek:Int, dashboardHiddenWidgets:String }` — largest field count (37) of any @Model
`AppTheme: String enum, 4 cases`

## Cross-cutting patterns (read before adding fields)
- **Embedded-array pattern is inconsistent**: most models use `Data + JSONEncoder/Decoder` computed property (per CLAUDE.md convention), but `Bill.priceHistory`, `BudgetTemplate.items`, and `Transaction.splitItems/recurringRule/tags` are stored as **native SwiftData arrays/structs** instead. Check which pattern an existing model uses before extending it.
- **Cross-model references are almost entirely loose `UUID?` foreign keys, not `@Relationship`s.** Only 6 true relationships exist in the whole schema: `Account.transactions↔Transaction.account` (cascade/inverse), `CustomCategory.parent/children` (self-referential, nullify+cascade), and `Transaction.account/toAccount/linkedLoan/linkedBNPL/documents` (documents is cascade). Default to a loose UUID for new cross-model links unless cascade-delete is truly needed — matches the wipe-and-recreate philosophy of avoiding relationship-migration complexity.
- **Duplicate/parallel model shapes**: `MoneyLent`/`MoneyBorrowed` are near-identical mirrors; `Investment`/`CryptoHolding` are near-identical mirrors (crypto kept separate rather than unified under `InvestmentType`).
- `ProjectStatus` enum is shared by both `FreelanceProject` and `BusinessProject`.
- Every money-holding model carries its own `currency: String` field. Anywhere that sums or compares these fields across records **must** convert via `CurrencyService.convert(_:from:to:)` to a common currency first — several real bugs from skipping this were found and fixed in Budget/SavingsGoal totals (see root map STATE section).
