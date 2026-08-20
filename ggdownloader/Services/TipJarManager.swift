import Foundation
import StoreKit
import Observation

@Observable
@MainActor
final class TipJarManager {
    static let shared = TipJarManager()

    private(set) var tips: [Product] = []
    private(set) var isLoading = true
    private(set) var purchaseState: PurchaseState = .idle

    enum PurchaseState: Equatable {
        case idle
        case purchasing
        case success
        case failed(String)
    }

    private let productIDs: Set<String> = [
        "com.sanuki.ggdownloader.tip.small",
        "com.sanuki.ggdownloader.tip.medium",
        "com.sanuki.ggdownloader.tip.large",
        "com.sanuki.ggdownloader.tip.huge"
    ]

    private init() {}

    func loadProducts() async {
        isLoading = true
        do {
            let products = try await Product.products(for: productIDs)
            tips = products.sorted { $0.price < $1.price }
        } catch {
            tips = []
        }
        isLoading = false
    }

    func purchase(_ product: Product) async {
        purchaseState = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    purchaseState = .success
                case .unverified(_, let error):
                    purchaseState = .failed(error.localizedDescription)
                }
            case .userCancelled:
                purchaseState = .idle
            case .pending:
                purchaseState = .idle
            @unknown default:
                purchaseState = .idle
            }
        } catch {
            purchaseState = .failed(error.localizedDescription)
        }
    }
}
