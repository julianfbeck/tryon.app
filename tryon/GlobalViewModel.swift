//
//  GlobalViewModel.swift
//  tryon
//
//  Created by Julian Beck on 21.03.25.
//


//
//  GlobalViewModel.swift
//  iEmoji
//
//  Created by Julian Beck on 02.01.25.
//
import Foundation
import RevenueCat

class GlobalViewModel: ObservableObject {
    @Published var offering: Offering?
    @Published var customerInfo: CustomerInfo?
    @Published var isPurchasing = false
    @Published var errorMessage: String?
    @Published var isShowingPayWall = false
    @Published var isShowingOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(!isShowingOnboarding, forKey: "hasSeenOnboarding")
        }
    }
    @Published var isShowingRatings = false
    @Published var remainingUses: Int
    @Published var canUseForFree: Bool
    @Published var downloadCount: Int {
        didSet {
            UserDefaults.standard.set(downloadCount, forKey: "downloadCount")
        }
    }
    @Published var isPro: Bool {
        didSet {
            UserDefaults.standard.set(isPro, forKey: "isPro")
        }
    }
    
    // Sentiment tracking
    @Published var userSentiment: Double {
        didSet {
            UserDefaults.standard.set(userSentiment, forKey: "userSentiment")
            updateDailyLimit()
        }
    }
    @Published var dailyUsageLimit: Int {
        didSet {
            UserDefaults.standard.set(dailyUsageLimit, forKey: "dailyUsageLimit")
        }
    }
    @Published var dailyUsageCount: Int {
        didSet {
            UserDefaults.standard.set(dailyUsageCount, forKey: "dailyUsageCount")
        }
    }
    @Published var lastUsageDate: Date? {
        didSet {
            if let date = lastUsageDate {
                UserDefaults.standard.set(date, forKey: "lastUsageDate")
            }
        }
    }
    @Published var shouldShowFeedback: Bool = false
    @Published var lastResultID: UUID?
    
    private let maxUsageCount: Int = 3
    private let featureKey = "finalUsageCountforReal"
    private let baseDailyLimit: Int = 2
    private let maxDailyLimit: Int = 4
    private let sentimentThreshold: Double = 4.0
    let maxDownlaods: Int = 3
    
    // Track if this is the first launch
    private var isFirstLaunch: Bool {
        return isShowingOnboarding
    }
    
    init() {
        // Initialize all properties first
        self.isPro = UserDefaults.standard.bool(forKey: "isPro")
        self.downloadCount = UserDefaults.standard.integer(forKey: "downloadCount")
        
        // Check if the user has seen the onboarding
        self.isShowingOnboarding = !UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
        
        let currentUsage = PersistentUserDefaults.shared.integer(forKey: featureKey)
        self.remainingUses = max(0, maxUsageCount - currentUsage)
        self.canUseForFree = currentUsage < maxUsageCount
        
        // Initialize sentiment tracking
        self.userSentiment = UserDefaults.standard.double(forKey: "userSentiment")
        self.dailyUsageLimit = UserDefaults.standard.integer(forKey: "dailyUsageLimit")
        self.dailyUsageCount = UserDefaults.standard.integer(forKey: "dailyUsageCount")
        
        if let savedDate = UserDefaults.standard.object(forKey: "lastUsageDate") as? Date {
            self.lastUsageDate = savedDate
        } else {
            self.lastUsageDate = Date()
        }
        
        // Now that all properties are initialized, we can perform additional setup
        
        // Reset daily count if it's a new day
        if let savedDate = self.lastUsageDate, !Calendar.current.isDate(savedDate, inSameDayAs: Date()) {
            self.dailyUsageCount = 0
        }
        
        // Set initial daily limit if needed
        if self.dailyUsageLimit == 0 {
            self.dailyUsageLimit = baseDailyLimit
        } else {
            // Update daily limit based on sentiment
            self.updateDailyLimit()
        }
        
        if self.isPro {
            self.canUseForFree = true
        }
        
        // If user is not pro and has already seen onboarding, show paywall
        if !self.isPro && !self.isShowingOnboarding {
            self.isShowingPayWall = true
        }
        
        setupPurchases()
        fetchOfferings()
    }
    
    private func setupPurchases() {
        self.isPro = UserDefaults.standard.bool(forKey: "isPro")
        Purchases.shared.getCustomerInfo { [weak self] (customerInfo, _) in
            DispatchQueue.main.async {
                let isProActive = customerInfo?.entitlements["PRO"]?.isActive == true
                UserDefaults.standard.set(isProActive, forKey: "isPro")
                self?.isPro = isProActive
            }
        }
    }
    
    private func fetchOfferings() {
        Purchases.shared.getOfferings { [weak self] (offerings, error) in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                } else if let defaultOffering = offerings?.offering(identifier: "default") {
                    self?.offering = defaultOffering
                }
            }
        }
    }
    
    func purchase(package: Package) {
        isPurchasing = true
        Purchases.shared.purchase(package: package) { [weak self] (_, customerInfo, _, userCancelled) in
            DispatchQueue.main.async {
                self?.isPurchasing = false
                if let isProActive = customerInfo?.entitlements["PRO"]?.isActive {
                    self?.updateProStatus(isProActive)
                }
            }
        }
    }
    
    func restorePurchase() {
        Purchases.shared.restorePurchases { [weak self] customerInfo, _ in
            let isProActive = customerInfo?.entitlements["PRO"]?.isActive == true
            self?.updateProStatus(isProActive)
        }
    }
    
    private func updateProStatus(_ isPro: Bool) {
        self.isPro = isPro
        UserDefaults.standard.set(isPro, forKey: "isPro")
        if isPro {
            self.isShowingPayWall = false
        }
    }
    
    func useFeature() -> Bool {
        if isPro {
            return true
        }
        
        // Check if it's a new day
        if let lastDate = lastUsageDate, !Calendar.current.isDate(lastDate, inSameDayAs: Date()) {
            dailyUsageCount = 0
            lastUsageDate = Date()
        } else if lastUsageDate == nil {
            lastUsageDate = Date()
        }
        
        // Check daily limit
        if dailyUsageCount >= dailyUsageLimit {
            isShowingPayWall = true
            return false
        }
        
        // Increment usage count
        dailyUsageCount += 1
        lastUsageDate = Date()
        
        // Legacy usage tracking
        let currentUsage = PersistentUserDefaults.shared.integer(forKey: featureKey)
        if currentUsage <= maxUsageCount {
            PersistentUserDefaults.shared.set(currentUsage + 1, forKey: featureKey)
            updateUsageStatus()
        }
        
        return true
    }
    
    func recordSentiment(rating: Int, for resultID: UUID) {
        // Prevent double-rating
        if lastResultID == resultID {
            return
        }
        
        lastResultID = resultID
        
        // Update sentiment (on a scale of 1-5)
        let newRating = Double(rating)
        
        // If sentiment was previously 0 (not set), just use the new rating
        if userSentiment == 0 {
            userSentiment = newRating
        } else {
            // Otherwise, do a weighted average (30% new rating, 70% previous sentiment)
            userSentiment = (userSentiment * 0.7) + (newRating * 0.3)
        }
        
        // Update daily limit based on new sentiment
        updateDailyLimit()
    }
    
    private func updateDailyLimit() {
        if userSentiment >= sentimentThreshold {
            // High satisfaction, give more uses
            dailyUsageLimit = min(maxDailyLimit, baseDailyLimit + Int(userSentiment - sentimentThreshold) * 2)
        } else if userSentiment > 0 {
            // Lower satisfaction, reduce uses
            dailyUsageLimit = max(1, baseDailyLimit - Int(sentimentThreshold - userSentiment))
        } else {
            // Default if no sentiment recorded
            dailyUsageLimit = baseDailyLimit
        }
    }
    
    func resetUsage() {
        PersistentUserDefaults.shared.set(0, forKey: featureKey)
        updateUsageStatus()
        dailyUsageCount = 0
    }
    
    private func updateUsageStatus() {
        let currentUsage = PersistentUserDefaults.shared.integer(forKey: featureKey)
        remainingUses = max(0, maxUsageCount - currentUsage)
        canUseForFree = currentUsage < maxUsageCount || isPro
    }
    
    func incrementDownloadCount() {
        downloadCount += 1
    }
    
    // Return remaining uses for today
    var remainingUsesToday: Int {
        return max(0, dailyUsageLimit - dailyUsageCount)
    }
    
    func getLastRating(for resultID: UUID) -> Int? {
        // If this is the last rated result, return the sentiment converted to 1-5 scale
        if resultID == lastResultID {
            if userSentiment == 0 {
                return nil
            }
            // Convert sentiment to an integer rating
            return Int(userSentiment.rounded())
        }
        return nil
    }
}

