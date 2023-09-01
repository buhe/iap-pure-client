//
//
//  Created by 顾艳华 on 2023/1/17.
//

import Foundation
import StoreKit

public class IAPManager: NSObject, ObservableObject {
    
    var callback: ((_ pid: String) -> Void)? = nil
    public static let shared = IAPManager()
    @Published public var products = [SKProduct]()
    fileprivate var productRequest: SKProductsRequest!

    public func setCallback(callback: @escaping (_ pid: String) -> Void){
        self.callback = callback
    }
    public func checkSubscriptionStatus(password: String, timeoutHandler: () -> Bool) -> Bool {
        
        let semaphore = DispatchSemaphore(value: 0)
        let request = SKReceiptRefreshRequest()
        request.start()
        var vaild = true
#if DEBUG
        print("Debug mode")
        let storeURL = URL(string: "https://sandbox.itunes.apple.com/verifyReceipt")
#else
        print("Release mode")
        let storeURL = URL(string: "https://buy.itunes.apple.com/verifyReceipt")
#endif
        print("store url: \(storeURL!.absoluteString)")
        
        if let receiptUrl = Bundle.main.appStoreReceiptURL {
            do {
                let receiptData = try Data(contentsOf: receiptUrl)
                let receiptString = receiptData.base64EncodedString(options: [])
                let requestContents: [String : Any] = ["receipt-data": receiptString,
                                                       "password": password,
                                                       "exclude-old-transactions": true]
                
                let requestData = try JSONSerialization.data(withJSONObject: requestContents,
                                                             options: [])
                
                var request = URLRequest(url: storeURL!)
                request.httpMethod = "POST"
                request.httpBody = requestData
                
                let session = URLSession.shared
                let task = session.dataTask(with: request, completionHandler: { (data, response, error) in
                    if let data = data {
                        do {
                            if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                               let receiptInfo = jsonResponse["latest_receipt_info"] as? [[String: Any]] {
                                let last = receiptInfo.first!
                                let expires = Int(last["expires_date_ms"] as! String)!
                                let now = Date()
                                
                                let utcMilliseconds = Int(now.timeIntervalSince1970 * 1000)
                                if utcMilliseconds > expires {
                                    // timeout
                                    vaild = false
                                }
                            } else {
                                print("no latest_receipt_info. ")
                                vaild = false
                            }
                        } catch {
                            print("Pasre server error: \(error)")
                            vaild = false
                        }
                    }
                    
                    semaphore.signal()
                })
                task.resume()
            } catch {
                print("Can not load receipt：\(error), user not subscriptio.")
                vaild = false
                semaphore.signal()
            }
            
        } else {
            vaild = false
            semaphore.signal()
        }
        semaphore.wait()
        if !vaild {
         return timeoutHandler()
       } else {
           return true
       }
    }
    
    public func getProducts(productIds: [String]) {
        let productIdsSet = Set(productIds)
        productRequest = SKProductsRequest(productIdentifiers: productIdsSet)
        productRequest.delegate = self
        productRequest.start()
    }
    
    public func buy(product: SKProduct) {
        if SKPaymentQueue.canMakePayments() {
            let payment = SKPayment(product: product)
            SKPaymentQueue.default().add(payment)
        } else {
            // show error
        }
    }
    
    public func restore() {
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
}
extension IAPManager: SKProductsRequestDelegate {
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        response.products.forEach {
            print($0.localizedTitle, $0.price, $0.localizedDescription)
        }
        DispatchQueue.main.async {
            self.products = response.products
        }
    }
    
}

extension IAPManager: SKPaymentTransactionObserver {
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        
        transactions.forEach {
            print($0.payment.productIdentifier, $0.transactionState.rawValue)
            switch $0.transactionState {
            case .purchased:
                IAPViewModel.shared.loading = false
                SKPaymentQueue.default().finishTransaction($0)
                if let callback = self.callback {
                    callback($0.payment.productIdentifier)
                }
            case .failed:
                print($0.error ?? "")
                if ($0.error as? SKError)?.code != .paymentCancelled {
                    // show error
                }
                SKPaymentQueue.default().finishTransaction($0)
                IAPViewModel.shared.loading = false
            case .restored:
                IAPViewModel.shared.loading = false
                SKPaymentQueue.default().finishTransaction($0)
            case .purchasing, .deferred:
                break
            @unknown default:
                break
            }
            
        }
    }
    
}

extension SKProduct {
    public var regularPrice: String? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = self.priceLocale
        return formatter.string(from: self.price)
    }
}

