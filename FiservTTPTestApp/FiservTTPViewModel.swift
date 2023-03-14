//
//  FiservTTP__ViewModel.swift
//  TTPTester
//
//  Created by Richard Tilt on 3/10/23.
//

import Foundation
import FiservTTP

class FiservTTPViewModel: ObservableObject {
    
    private let fiservTTPCardReader: FiservTTPCardReader
    
    init() {
        self.fiservTTPCardReader = FiservTTPCardReader(configuration: FiservTTPViewModel.configuration())
    }
    
    public func requestSessionToken() async throws {
        try await self.fiservTTPCardReader.requestSessionToken()
    }
    
    public func linkAccount() async throws {
        try await self.fiservTTPCardReader.linkAccount()
    }

    public func activateReader() async throws {
        try await self.fiservTTPCardReader.initializeSession()
    }
    
    public func readCard(amount: Decimal,
                         merchantOrderId: String,
                         merchantTransactionId: String) async throws -> FiservTTPChargeResponse {
        return try await self.fiservTTPCardReader.readCard(amount: amount, merchantOrderId: merchantOrderId, merchantTransactionId: merchantTransactionId)
    }

}


extension FiservTTPViewModel {

    static func configuration() -> FiservTTPConfig {
        
        return FiservTTPConfig.init(secretKey: "RH2aSkDW8J3OeKtmsTXNnXnGQqVRQ2NnEBv9pts9Gm6",
                                    apiKey: "0JvVe4QCtT3srMmflNuUrs1zxZLswmmi",
                                    environment: .Sandbox,
                                    currencyCode: "USD",
                                    merchantId: "190009000000700",
                                    merchantName: "Tom's Tacos",
                                    merchantCategoryCode: "1000",
                                    terminalId: "10000001",
                                    terminalProfileId: "3c00e000-a00e-2043-6d63-936859000002")
    }
}
