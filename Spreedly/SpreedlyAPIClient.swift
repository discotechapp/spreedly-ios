//
//  SpreedlyAPIClient.swift
//  Spreedly
//
//  Created by David Santoso on 9/22/15.
//  Copyright © 2015 Spreedly Inc. All rights reserved.
//

import Foundation
import PassKit

public class SpreedlyAPIClient {
    public typealias SpreedlyAPICompletionBlock = (paymentMethod: PaymentMethod?, response: NSURLResponse?, error: NSError?) -> Void
    
    public var environmentKey: String
    public var apiUrl: String
    
    public init(environmentKey: String, apiUrl: String) {
        self.environmentKey = environmentKey
        self.apiUrl = apiUrl
    }
    
    convenience public init(environmentKey: String) {
        let apiUrl = "http://core.spreedly.com/v1/payment_methods.json"
        self.init(environmentKey: environmentKey, apiUrl: apiUrl)
    }
    
    public func createPaymentMethodTokenWithCreditCard(creditCard: CreditCard, completion: SpreedlyAPICompletionBlock) {
        let serializedRequest = RequestSerializer.serialize(creditCard)
        
        if serializedRequest.error == nil {
            if let data = serializedRequest.data {
                self.createPaymentMethodTokenWithData(data, completion: completion)
            }
        }
    }
    
    public func createPaymentMethodTokenWithApplePay(payment: PKPayment, completion: SpreedlyAPICompletionBlock) {
        self.createPaymentMethodTokenWithData(RequestSerializer.serialize(payment.token.paymentData), completion: completion)
    }

    func createPaymentMethodTokenWithData(data: NSData, completion: SpreedlyAPICompletionBlock) {
        let url = NSURL(string: apiUrl + "?environment_key=\(self.environmentKey)")

        let request = NSMutableURLRequest(URL: url!)
        let session = NSURLSession.sharedSession()

        request.HTTPBody = data
        request.HTTPMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let task = session.dataTaskWithRequest(request) { data, response, error -> Void in
            if (error != nil) {
                completion(paymentMethod: nil, response: response, error: error)
            } else {
                do {
                    if let json = try NSJSONSerialization.JSONObjectWithData(data!, options: []) as? NSDictionary {
                        if let transactionDict = json["transaction"] as? NSDictionary {
                            if let paymentMethodDict = transactionDict["payment_method"] as? [String: AnyObject] {
                                let paymentMethod = PaymentMethod(attributes: paymentMethodDict)
                                completion(paymentMethod: paymentMethod, response: response, error: nil)
                            }
                        } else {
                            // Eventually, we'll want to loop through the errors and send back those with
                            // if let errorsDict = json["errors"] as? NSDictionary
                            let userInfo = ["ProcessingError": "Unable to create payment method token with values sent"]
                            let apiError = NSError(domain: "com.spreedly.lib", code: 60, userInfo: userInfo)
                            completion(paymentMethod: nil, response: response, error: apiError)
                        }
                    }
                } catch let parseError as NSError {
                    completion(paymentMethod: nil, response: response, error: parseError)
                }
            }
        }
        
        task.resume()
    }
}
