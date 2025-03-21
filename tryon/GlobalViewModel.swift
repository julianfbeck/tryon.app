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
    @Published var isShowingRatingView = false
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
    
    private let maxUsageCount: Int = 3
    private let featureKey = "finalUsageCountforReal!11"
    let maxDownlaods: Int = 3
    
    init() {
        self.isPro = UserDefaults.standard.bool(forKey: "isPro")
        self.downloadCount = UserDefaults.standard.integer(forKey: "downloadCount")
        let currentUsage = PersistentUserDefaults.shared.integer(forKey: featureKey)
        self.remainingUses = max(0, maxUsageCount - currentUsage)
        self.canUseForFree = currentUsage < maxUsageCount
        if self.isPro {
            self.canUseForFree = true
        }
        
        self.isPro = true
        self.remainingUses = 0
        self.canUseForFree = true
        
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
    
    func useFeature() {
        if isPro {
            return
        }
        let currentUsage = PersistentUserDefaults.shared.integer(forKey: featureKey)
        if currentUsage <= maxUsageCount {
            PersistentUserDefaults.shared.set(currentUsage + 1, forKey: featureKey)
            updateUsageStatus()
        }
    }
    
    func resetUsage() {
        PersistentUserDefaults.shared.set(0, forKey: featureKey)
        updateUsageStatus()
    }
    
    private func updateUsageStatus() {
        let currentUsage = PersistentUserDefaults.shared.integer(forKey: featureKey)
        remainingUses = max(0, maxUsageCount - currentUsage)
        canUseForFree = currentUsage < maxUsageCount || isPro
    }
    
    func incrementDownloadCount() {
        downloadCount += 1
    }
}

