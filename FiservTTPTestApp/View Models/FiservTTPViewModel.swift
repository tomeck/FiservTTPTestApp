//  FiservTTPViewModel
//
//  Copyright (c) 2022 - 2023 Fiserv, Inc.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import Foundation
import Combine
import FiservTTP

class FiservTTPViewModel: ObservableObject {
    
    @Published var isBusy: Bool = false
    @Published var hasToken: Bool = false
    @Published var accountLinked: Bool = false
    @Published var cardValid: Bool = false
    @Published var cardReaderActive: Bool = false
    
    // Used to re-initialize session if lost, requires that we have already established a session at least once
    private var readyForPayments: Bool = false
    
    private let fiservTTPCardReader: FiservTTPCardReader
    
    private lazy var cancellables: Set<AnyCancellable> = .init()
    
    init() {
        self.fiservTTPCardReader = FiservTTPCardReader.init(configuration: FiservTTPViewModel.configuration())
        
        self.fiservTTPCardReader.sessionReadySubject
            .receive(on: DispatchQueue.main)
            .sink { sessionReady in
                self.cardReaderActive = sessionReady
            }
            .store(in: &cancellables)
    }
    
    // CARD READER IS SUPPORTED
    public func readerIsSupported() -> Bool {
        return  self.fiservTTPCardReader.readerIsSupported()
    }

    // REQUEST SESSION TOKEN
    public func requestSessionToken() async throws {
        do {
            await MainActor.run { self.isBusy = true }
            try await self.fiservTTPCardReader.requestSessionToken()
            await MainActor.run {
                self.hasToken = true
                self.isBusy = false
            }
        } catch {
            await MainActor.run { self.isBusy = false }
            throw error
        }
    }
    
    // LINK ACCOUNT
    public func linkAccount() async throws {
        do {
            await MainActor.run { self.isBusy = true }
            try await self.fiservTTPCardReader.linkAccount()
            await MainActor.run {
                self.isBusy = false
                self.accountLinked = true
            }
        } catch {
            await MainActor.run { self.isBusy = false }
            throw error
        }
    }
    
    // REINITIALIZE SESSION
    public func reinitializeSession() async throws {
        
        if self.readyForPayments && !self.cardReaderActive {
            
            try await self.initializeSession()
        }
    }
    
    // INITIALIZE SESSION
    public func initializeSession() async throws {
        do {
            await MainActor.run { self.isBusy = true }
            try await self.fiservTTPCardReader.initializeSession()
            await MainActor.run {
                self.isBusy = false
                self.cardReaderActive = true
                self.readyForPayments = true
            }
        } catch {
            await MainActor.run { self.isBusy = false }
            throw error
        }
    }
    
    // VALIDATE CARD
    public func validateCard() async throws -> FiservTTPValidateCardResponse {
        do {
            await MainActor.run { self.isBusy = true }
            let response = try await self.fiservTTPCardReader.validateCard()
            
            await MainActor.run {
                self.isBusy = false
                if let _ = response.generalCardData, let _ = response.paymentCardData {
                    self.cardValid = true
                }
            }
            return response
            
        } catch {
            await MainActor.run { self.isBusy = false }
            throw error
        }
    }
    
    // READ CARD
    public func readCard(amount: Decimal,
                         merchantOrderId: String,
                         merchantTransactionId: String) async throws -> FiservTTPChargeResponse {
        do {
            await MainActor.run { self.isBusy = true }
            let response = try await self.fiservTTPCardReader.readCard(amount: amount,
                                                                       merchantOrderId: merchantOrderId,
                                                                       merchantTransactionId: merchantTransactionId)
            
            
            await MainActor.run { self.isBusy = false }
            return response
        } catch {
            await MainActor.run { self.isBusy = false }
            throw error
        }
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
