/**
       This file is part of Adguard for iOS (https://github.com/AdguardTeam/AdguardForiOS).
       Copyright © Adguard Software Limited. All rights reserved.
 
       Adguard for iOS is free software: you can redistribute it and/or modify
       it under the terms of the GNU General Public License as published by
       the Free Software Foundation, either version 3 of the License, or
       (at your option) any later version.
 
       Adguard for iOS is distributed in the hope that it will be useful,
       but WITHOUT ANY WARRANTY; without even the implied warranty of
       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
       GNU General Public License for more details.
 
       You should have received a copy of the GNU General Public License
       along with Adguard for iOS.  If not, see <http://www.gnu.org/licenses/>.
 */

import Foundation
import StoreKit
import CommonCrypto

// MARK:  service protocol -
/**
 PurchaseService is a service responsible for all purchases.
 The user can get professional status through renewable subscriptions(in-app purchases) or through an Adguard license.
 In-app purchases are carried out directly in this service.
 Work with Adguard Licenses is delegated to LoginController
 */
protocol PurchaseServiceProtocol {
    
   
    /**
     returns true if user has valid renewable subscription or valid adguard license
     */
    var isProPurchased: Bool {get}
    
    /**
     returns true if user has been logged in through login
     */
    var purchasedThroughLogin: Bool {get}
    
    /**
     returns true if premium expired. It works both for in-app purchases and for adguard licenses
     */
    func checkPremiumExpired()
    
    /**
     retuns true if service ready to request purchases through app store
     */
    var ready: Bool {get}
    
    /**
     renewable subscription price
     */
    var price: String {get}
    
    /**
     renewable subscription period
     */
    var period: String {get}
    
    /*  login on backend server and check license information
        the results will be posted through notification center
     
        we can use adguard license in two ways
        1) login throuh oauth in safari and get access_tolken. Then we make auth_token request and get license key. Then bind this key to user device id(app_id) through status request with license key in params
        2) login directly with license key. In this case we immediately send status request with this license key
     */
    func login(withAccessToken token: String?, state: String?)
    func login(withLicenseKey key: String)
    
    /**
     checks the status of adguard license
     */
    func checkLicenseStatus()
    
    /**
     deletes all login information
     */
    func logout()->Bool
    
    /**
     requests an in-app purchase
     */
    func requestPurchase()
    
    /**
     requests restore in-app purchases
     */
    func requestRestore()
    
    /**
     returns url for oauth athorisation
     */
    func authUrlWithName(name: String)->URL?
}

// MARK: - public constants -
extension PurchaseService {
    
    /// NSNotificationCenter notification name
    static let kPurchaseServiceNotification = "kPurchaseServiceNotification"
    
    /// notification user data keys
    static let kPSNotificationTypeKey = "kPSNotificationTypeKey"
    static let kPSNotificationErrorKey = "kPSNotificationErrorKey"
    static let kPSNotificationPremiumExpiredKey = "kPSNotificationPremiumExpiredKey"
    
    /// notification types
    static let kPSNotificationPurchaseSuccess = "kPSNotificationPurchaseSuccess"
    static let kPSNotificationPurchaseFailure = "kPSNotificationPurchaseFailure"
    static let kPSNotificationRestorePurchaseSuccess = "kPSNotificationRestorePurchaseSuccess"
    static let kPSNotificationRestorePurchaseFailure = "kPSNotificationRestorePurchaseFailure"
    static let kPSNotificationRestorePurchaseNothingToRestore = "kPSNotificationRestorePurchaseNothingToRestore"
    static let kPSNotificationLoginSuccess = "kPSNotificationLoginSuccess"
    static let kPSNotificationLoginFailure = "kPSNotificationLoginFailure"
    static let kPSNotificationLoginPremiumExpired = "kPSNotificationLoginPremiumExpired"
    static let kPSNotificationLoginNotPremiumAccount = "kPSNotificationLoginNotPremiumAccount"
    static let kPSNotificationReadyToPurchase = "kPSNotificationReadyToPurchase"
    static let kPSNotificationPremiumExpired = "kPSNotificationPremiumExpired"
    
    static let kPSNotificationPremiumStatusChanged = "kPSNotificationPremiumStatusChanged"
    
    static let kPSNotificationOauthSucceeded = "kPSNotificationOauthSucceeded"
    
    /// errors
    static let AEPurchaseErrorDomain = "AEPurchaseErrorDomain"
    
    static let AEPurchaseErrorAuthFailed = -1
    static let AEConfirmReceiptError = -2
}

// MARK: - service implementation -
class PurchaseService: NSObject, PurchaseServiceProtocol, SKPaymentTransactionObserver, SKProductsRequestDelegate{
    
    // MARK: constants -
    // store kit constants
    private let kGetProProductID = "com.adguard.AdguardExtension.Premium"
    
    
    // ios_validate_receipt request
    
    private let RECEIPT_DATA_PARAM = "receipt_data"
    private let VALIDATE_RECEIPT_URL = "https://mobile-api.adguard.com/api/1.0/ios_validate_receipt"
    
    // license status
    private let LICENSE_STATUS_NOT_EXISTS = "NOT_EXISTS"
    private let LICENSE_STATUS_EXPIRED = "EXPIRED"
    private let LICENSE_STATUS_MAX_COMPUTERS_EXCEED = "MAX_COMPUTERS_EXCEED"
    private let LICENSE_STATUS_BLOCKED = "BLOCKED"
    private let LICENSE_STATUS_VALID = "VALID"
    
    // subscription status
    private let SIBSCRIPTION_STATUS_ACTIVE = "ACTIVE"
    private let SIBSCRIPTION_STATUS_PAST_DUE = "PAST_DUE"
    private let SIBSCRIPTION_STATUS_DELETED = "DELETED"
    
    // premium values
    private let PREMIUM_STATUS_ACTIVE = "ACTIVE"
    private let PREMIUM_STATUS_FREE = "FREE"
    
    // validate receipt params
    
    private let PRODUCTS_PARAM = "products"
    private let PRODUCT_ID_PARAM = "product_id"
    private let PREMIUM_STATUS_PARAM = "premium_status"
    private let EXPIRATION_DATE_PARAM = "expiration_date"
    
    private let authUrl = "https://auth.adguard.com/oauth/authorize"
    
    // MARK: - private properties
    private let network: ACNNetworkingProtocol
    private let resources: AESharedResourcesProtocol
    private var productRequest: SKProductsRequest?
    private var product: SKProduct?
    private var refreshRequest: SKReceiptRefreshRequest?

    private let loginService: LoginService
    
    private var purchasedThroughInApp: Bool {
        get {
            return resources.sharedDefaults().bool(forKey: AEDefaultsIsProPurchasedThroughInApp)
        }
        set {
            resources.sharedDefaults().set(newValue, forKey: AEDefaultsIsProPurchasedThroughInApp)
        }
    }
    
    // MARK: - public properties
    
    var isProPurchased: Bool {
        return isProPurchasedInternal
    }
    
    var purchasedThroughLogin: Bool {
        get {
            return loginService.loggedIn
        }
    }
    
    @objc dynamic var isProPurchasedInternal: Bool {
        get {
            return (purchasedThroughInApp) ||
                (loginService.loggedIn && loginService.hasPremiumLicense && loginService.active);
        }
    }
    
    var ready: Bool { return product != nil }
    var price: String {
        guard let product = self.product else { return "" }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceLocale
        
        return formatter.string(from: product.price) ?? ""
    }
    
    var period: String {
        guard let product = self.product else { return "" }
        
        
        if #available(iOS 11.2, *) {
            guard let periodUnit = product.subscriptionPeriod?.unit,
                let numberOfUnits = product.subscriptionPeriod?.numberOfUnits else { return "" }
            
            var unitString = ""
            switch periodUnit {
            case .day:
                unitString = ACLocalizedString("day_period", nil)
            case .week:
                unitString = ACLocalizedString("week_period", nil)
            case .month:
                unitString = ACLocalizedString("month_period", nil)
            case .year:
                unitString = ACLocalizedString("year_period", nil)
            }
            
            let format = ACLocalizedString("period_format", nil)
            
            return String(format: format, numberOfUnits, unitString)
        } else {
            return ""
        }
    }
    
    // MARK: - public methods
    init(network: ACNNetworkingProtocol, resources: AESharedResourcesProtocol) {
        self.network = network
        self.resources = resources
        loginService = LoginService(defaults: resources.sharedDefaults(), network: network, keychain: KeychainService(resources: resources))
        
        super.init()
        
        start()
        
        loginService.activeChanged = { [weak self] in
            self?.postNotification(PurchaseService.kPSNotificationPremiumStatusChanged)
        }
    }
    
    func start() {
        setObserver()
        requestProduct()
    }
    
    func checkLicenseStatus() {
        loginService.checkStatus { [weak self] (error) in
            self?.processLoginResult(error)
        }
    }
    
    func login(withLicenseKey key: String) {
        loginService.login(licenseKey: key){ [weak self] (error) in
            self?.processLoginResult(error)
        }
    }
    
    @objc
    func login(withAccessToken token: String?, state: String?) {
        
        let expectedState = resources.sharedDefaults().string(forKey: AEDefaultsAuthStateString)
        
        if token == nil || state == nil || expectedState == nil || state! != expectedState! {
            DDLogError("(PurchaseService) login with access token failed " + (token == nil ? "token == nil" : "") + (state == nil ? "state == nil" : "") + (expectedState == nil ? "expectedState == nil" : "") + (state != expectedState ? "state != expectedState" : ""))
            postNotification(PurchaseService.kPSNotificationLoginFailure, nil)
            return
        }
        
        postNotification(PurchaseService.kPSNotificationOauthSucceeded, nil)
        
        loginService.login(accessToken: token!) { [weak self]  (error) in
            guard let sSelf = self else { return }
            
            sSelf.processLoginResult(error)
        }
    }
    
    func validateReceipt(onComplete complete:@escaping ((Error?)->Void)){
        
        // get receipt
        guard let receiptUrlStr = Bundle.main.appStoreReceiptURL,
            let data = try? Data(contentsOf: receiptUrlStr)
        else {
            complete(NSError(domain: PurchaseService.AEPurchaseErrorDomain, code: PurchaseService.AEConfirmReceiptError, userInfo: nil))
            return
        }
        
        let base64Str = data.base64EncodedString()
        
        // post receipt to our backend
        
        let jsonToSend = "{\"\(RECEIPT_DATA_PARAM)\":\"\(base64Str)\"}"
        
        guard let url = URL(string: VALIDATE_RECEIPT_URL) else  {
            
            DDLogError("(PurchaseService) validateReceipt error. Can not make URL from String \(VALIDATE_RECEIPT_URL)")
            return
        }
        
        let request: URLRequest = ABECRequest.post(for: url, json: jsonToSend)
        
        network.data(with: request) { [weak self] (dataOrNil, response, error) in
            guard let strongSelf = self else {
                return
            }
            
            if error != nil {
                complete(error!)
                return
            }
            
            guard let data = dataOrNil  else{
                complete(NSError(domain: PurchaseService.AEPurchaseErrorDomain, code: PurchaseService.AEConfirmReceiptError, userInfo: nil))
                return
            }
            
            do {
                let jsonResponse = try JSONSerialization.jsonObject(with: data) as! [String: Any]
                
                let validateSuccess = strongSelf.processValidateResponse(json: jsonResponse)
                
                if !validateSuccess {
                    complete(NSError(domain: PurchaseService.AEPurchaseErrorDomain, code: PurchaseService.AEConfirmReceiptError, userInfo: nil))
                    return
                }

                strongSelf.purchasedThroughInApp = strongSelf.isRenewableSubscriptionActive()

                strongSelf.postNotification(PurchaseService.kPSNotificationPremiumStatusChanged)
                complete(nil)
            }
            catch {
                complete(NSError(domain: PurchaseService.AEPurchaseErrorDomain, code: PurchaseService.AEConfirmReceiptError, userInfo: nil))
            }
        }
    }
    
    func logout()->Bool {
        return loginService.logout()
    }
    
    func requestPurchase() {
        if product == nil {
            postNotification(PurchaseService.kPSNotificationPurchaseFailure)
        }
        else  {
            let payment = SKMutablePayment(product: product!)
            payment.quantity = 1
            SKPaymentQueue.default().add(payment)
        }
    }
    
    func requestRestore() {
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
    func getReceipt() -> String? {
        // Load the receipt from the app bundle.
        guard let receiptURL = Bundle.main.appStoreReceiptURL,
              let receiptData = try? Data(contentsOf: receiptURL) else { return nil }
        let encReceipt = receiptData.base64EncodedString()
        
        return encReceipt
    }
    
    func authUrlWithName(name: String) -> URL? {
        
        guard let dataParam = encryptName(name: name) else { return nil }
        
        let state =  String.randomString(length: 10)
        resources.sharedDefaults().set(state, forKey: AEDefaultsAuthStateString)
        
        let params = ["response_type"   : "token",
                      "client_id"       : "adguard-ios",
                      "redirect_uri"    : "adguard://auth",
                      "scope"           : "trust",
                      "state"           : state,
                      "data"            : dataParam
        ]
        
        let paramsString = ACNUrlUtils.createString(fromParameters: params, xmlStrict: false)
        
        let urlString = "\(authUrl)?\(paramsString)"
        return URL(string: urlString)
    }
    
    private func encryptName(name: String)->String? {
        let stringToEncrypt = "email=\(name)"
        guard   let dataToEncrypt = stringToEncrypt.data(using: .utf8)
            else { return nil }
        
        let keyData = "87502E2BDC2382C048FBD2B1986A0561".dataFromHex()
        guard let encryptedData = crypt(data: dataToEncrypt, keyData: keyData, operation: kCCEncrypt) else { return nil }
        
        let encryptedBase64String = encryptedData.base64EncodedString()
        
        return encryptedBase64String
    }
    
    @objc
    func checkPremiumExpired() {
        
        DDLogInfo("(PurchaseService) checkPremiumExpired")
        if(purchasedThroughInApp && !isRenewableSubscriptionActive()) {
            
            DDLogInfo("(PurchaseService) checkPremiumExpired - validateReceipt")
            validateReceipt { [weak self] (error) in
                if self?.isRenewableSubscriptionActive() ?? false {
                    self?.notifyPremiumExpired()
                }
            }
        }
        
        if(loginService.loggedIn && loginService.hasPremiumLicense) {
            
            DDLogInfo("(PurchaseService) checkPremiumExpired - сheck adguard license status")
            loginService.checkStatus { [weak self] (error) in
                if error != nil || !(self?.loginService.active ?? false) {
                    self?.notifyPremiumExpired()
                }
            }
        }
    }
    
    // MARK: - private methods
    // MARK: storekit
    private func setObserver() {
        SKPaymentQueue.default().add(self)
    }
    
    private func requestProduct() {
        productRequest = SKProductsRequest(productIdentifiers: [kGetProProductID])
        productRequest?.delegate = self
        productRequest?.start()
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        
        var restored = false
        var purchased = false
        
        for transaction in transactions {
            if(transaction.payment.productIdentifier != kGetProProductID) { continue }
            
            switch transaction.transactionState {
            case .purchasing, .deferred:
                break
                
            case .failed:
                postNotification(PurchaseService.kPSNotificationPurchaseFailure, transaction.error)
                
            case .purchased:
                purchased = true
                SKPaymentQueue.default().finishTransaction(transaction)
                    
            case .restored:
                restored = true
                SKPaymentQueue.default().finishTransaction(transaction)
                
            default:
                break
            }
        }
        
        if purchased || restored {
            validateReceipt { [weak self](error) in
                guard let sSelf = self else { return }
                
                if error == nil && sSelf.purchasedThroughInApp {
                    let result = purchased ? PurchaseService.kPSNotificationPurchaseSuccess : PurchaseService.kPSNotificationRestorePurchaseSuccess
                    
                    sSelf.postNotification(result)
                }
                
                if error == nil && !sSelf.purchasedThroughInApp {
                    sSelf.postNotification(PurchaseService.kPSNotificationRestorePurchaseNothingToRestore)
                }
            }
        }
    }
    
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        product = response.products.first
        postNotification(PurchaseService.kPSNotificationReadyToPurchase)
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        productRequest = nil
    }
    
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        
        for transaction in queue.transactions {
            if transaction.payment.productIdentifier == kGetProProductID { return }
        }
        
        // nothing to restore
        postNotification(PurchaseService.kPSNotificationRestorePurchaseNothingToRestore)
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        postNotification(PurchaseService.kPSNotificationRestorePurchaseFailure, error)
    }
    
     
    // MARK: helper methods
    
    private func processLoginResult(_ error: Error?) {
        
        DDLogInfo("(PurchaseService) processLoginResult")
        if error != nil {
            
            DDLogError("(PurchaseService) processLoginResult error \(error!.localizedDescription)")
            postNotification(PurchaseService.kPSNotificationLoginFailure, error)
            return
        }
        
        // check state
        if !loginService.hasPremiumLicense {
            postNotification(PurchaseService.kPSNotificationLoginNotPremiumAccount)
            return
        }
        
        let userInfo = [PurchaseService.kPSNotificationTypeKey: PurchaseService.kPSNotificationLoginSuccess,
                        PurchaseService.kPSNotificationLoginPremiumExpired: !loginService.active] as [String : Any]
        
        NotificationCenter.default.post(name: Notification.Name(PurchaseService.kPurchaseServiceNotification), object: self, userInfo: userInfo)
    }
    
    private func isRenewableSubscriptionActive()->Bool {

        if let expirationDate = resources.sharedDefaults().object(forKey: AEDefaultsRenewableSubscriptionExpirationDate) as? Date {
            return expirationDate > Date()
        }
        
        return false
    }
    
    private func processValidateResponse(json: [String: Any])->Bool {
        
        guard let products = json[PRODUCTS_PARAM] as? [[String: Any]] else { return false }
        
        for product in products {
            let status = product[PREMIUM_STATUS_PARAM] as? String
            guard let expirationDate = product[EXPIRATION_DATE_PARAM] as? Double else { continue }
            
            if status == PREMIUM_STATUS_ACTIVE {
                if (expirationDate / 1000) > Date().timeIntervalSince1970 {
                    
                    let date = Date(timeIntervalSince1970: expirationDate / 1000)
                    resources.sharedDefaults().set(date, forKey: AEDefaultsRenewableSubscriptionExpirationDate)
                    
                    break
                }
            }
        }
        
        return true
    }
    
    private func notifyPremiumExpired() {
        
        postNotification(PurchaseService.kPSNotificationPremiumExpired)
    }
    
    private func postNotification(_ type: String,_ error: Any? = nil) {
        var userInfo = [PurchaseService.kPSNotificationTypeKey: type] as [String: Any]
        if(error != nil) {
            userInfo[PurchaseService.kPSNotificationErrorKey] = error!
        }
        
        NotificationCenter.default.post(name: Notification.Name(PurchaseService.kPurchaseServiceNotification), object: self, userInfo: userInfo)
    }
    
    func crypt(data:Data, keyData:Data, operation:Int) -> Data? {
        let cryptLength  = size_t(data.count + kCCBlockSizeAES128)
        var cryptData = Data(count:cryptLength)
        
        
        let keyLength = size_t(kCCKeySizeAES128)
        let options = CCOptions(kCCOptionPKCS7Padding)
        
        
        var numBytesEncrypted :size_t = 0
        
        let cryptStatus = cryptData.withUnsafeMutableBytes {cryptBytes in
            data.withUnsafeBytes {dataBytes in
                keyData.withUnsafeBytes {keyBytes in
                    CCCrypt(CCOperation(operation),
                            CCAlgorithm(kCCAlgorithmAES),
                            options,
                            keyBytes, keyLength,
                            nil,
                            dataBytes, data.count,
                            cryptBytes, cryptLength,
                            &numBytesEncrypted)
                }
            }
        }
        
        if UInt32(cryptStatus) == UInt32(kCCSuccess) {
            cryptData.removeSubrange(numBytesEncrypted..<cryptData.count)
        } else {
            return nil
        }
        
        return cryptData;
    }
}
