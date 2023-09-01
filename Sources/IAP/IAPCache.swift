//
//  File.swift
//  
//
//  Created by 顾艳华 on 2023/8/27.
//

import Foundation

public struct IAPCache {
    public static var five = IAPCache()
    
    var cacheRetry: Int
    public init(cacheRetry: Int = 5) {
        self.cacheRetry = cacheRetry
    }
    private var timeout = true
    private var cacheCount = 0
    
    public mutating func checkSubscriptionStatus(password: String, timeoutHandler: () -> Bool) -> Bool {
        if timeout && cacheCount < cacheRetry {
            let result = IAPManager.shared.checkSubscriptionStatus(password: password, timeoutHandler: timeoutHandler)
            cacheCount = 0
            timeout = !result
            
            return result
        } else {
            cacheCount += 1
            return true
        }
    }
}
