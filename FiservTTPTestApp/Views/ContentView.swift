//  ContentView
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

import SwiftUI
import ProximityReader
import FiservTTP

extension Encodable {
    var prettyJSON: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(self),
            let output = String(data: data, encoding: .utf8)
            else { return "Error converting \(self) to JSON string" }
        return output
    }
}

struct ContentView: View {

    @State private var amount: String = "5.00"
    
//    @State var showSpinner = false
    @State var linkButtonTitle: String = "Link Apple Account"

    // CHARGE RESPONSE
    @State private var responseWrapper: FiservTTPResponseWrapper?
    
    // USED FOR ALL ERRORS
    @State private var errorWrapper: FiservTTPErrorWrapper?
    @Environment(\.dismiss) private var dismiss
    
    // VIEW MODEL
    @StateObject var viewModel = FiservTTPViewModel()
    
    @Environment(\.scenePhase) var scenePhase
    
    var body: some View {
        
        NavigationView {
            
            Form {
                VStack(alignment:.leading) {
                    Spacer()
                    
                    HStack {
                        
                        Image("Fiserv_logo.svg")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 30)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    
                    Spacer()
                    
                    Text("Apple TTP Test Tool")
                        .font(Font.title.weight(.bold))
                    
                }
                
                Section("Merchant Info") {
                    
                    Text(FiservTTPViewModel.configuration().merchantId)
                    
                    Text(FiservTTPViewModel.configuration().merchantName)
                }
                
                if( viewModel.isBusy == true ) {
                    TTPProgressView()
                }
                
                Section("1. Obtain session token") {
                    HStack() {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(viewModel.hasToken ? Color.green : Color.gray)
                        Button("Create Session Token", action: {
            
                            
                            print("Getting session token...")
                            Task {
                                do {
                                    try await viewModel.requestSessionToken()
                                    
                                    print("Obtained Session Token")
                                } catch let error as FiservTTPCardReaderError {
                                    errorWrapper = FiservTTPErrorWrapper(error: error, guidance: "Check the configuration settings and try again.")
                                }
                            }
                        })
                    }
                }

                Section("2. (Optional) Link Apple Account to MID") {
                    HStack() {
                        
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(viewModel.accountLinked ? Color.green : Color.gray)
                        Button(linkButtonTitle, action: {
                        
                            
                            print("Linking account...")
                            
                            Task {
                                do {
                                    try await viewModel.linkAccount()

                                    print("Account Linked")
                                } catch let error as FiservTTPCardReaderError {
                                    errorWrapper = FiservTTPErrorWrapper(error: error, guidance: "Did you obtain a session token?")
                                }
                            }
                        })
                    }
                }
                
                Section("3. Start Accepting TTP Payments") {
                    HStack() {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(viewModel.cardReaderActive ? Color.green : Color.gray)
                        Button("Start TTP Session", action: {
                            
                            print("Initializing TTP session...")
                            
                            Task {
                                do {
                                    try await viewModel.initializeSession()
                                    print("Reader Activated")
                                } catch let error as FiservTTPCardReaderError {
                                    errorWrapper = FiservTTPErrorWrapper(error: error, guidance: "Did you obtain a session token?")
                                }
                            }
                        })
                    }
                }
                
                Section("4. Accept a TTP Payment") {
                    TextField("Amount:", text: $amount)
                        .keyboardType(.decimalPad)
                    
                    Button("Accept Payment",action: {
                        
                        print("Accepting payment...")
                        
                        Task {
                            if let decimalValue = Decimal(string:amount) {
                                
                                do {
                                    let chargeResponse = try await viewModel.readCard(amount: decimalValue, merchantOrderId: "oid123", merchantTransactionId: "tid987")
                                    responseWrapper = FiservTTPResponseWrapper(response: chargeResponse)
                                    print("Got charge response")
                                    print(chargeResponse)
                                } catch let error as FiservTTPCardReaderError {
                                    errorWrapper = FiservTTPErrorWrapper(error: error, guidance: "Did you initialize the reader?")
                                }
                            } else {
                                print("String does not contain Decimal value")
                                return
                            }
                        }
                    })
                }
            }
            .onAppear {
                if !self.viewModel.readerIsSupported() {
                    
                    let error = FiservTTPCardReaderError(title: "Reader not supported.",
                                                         localizedDescription: NSLocalizedString("This device does not support Apple Tap to Pay.", comment: ""))
                    
                    errorWrapper = FiservTTPErrorWrapper(error: error, guidance: "You will need to use a newer device.")
                }
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active && viewModel.hasToken && viewModel.cardReaderActive == false {
                    Task {
                        do {
                            try await viewModel.initializeSession()
                        } catch let error as FiservTTPCardReaderError {
                            errorWrapper = FiservTTPErrorWrapper(error: error, guidance: "Check the configuration settings and try again.")
                        }
                    }
                }
            }
            .sheet(item: $responseWrapper) { wrapper in
                
                FiservTTPChargeResponseView(responseWrapper: wrapper)
            }
            .sheet(item: $errorWrapper) { wrapper in
                FiservTTPErrorView(errorWrapper: wrapper)
            }
        }
    }
}

// CHARGE RESPONSE VIEW
struct FiservTTPChargeResponseView: View {

    let responseWrapper: FiservTTPResponseWrapper?

    @Environment(\.dismiss) private var dismiss

    var body: some View {

        NavigationView {

            VStack {
                
                if let response = responseWrapper?.response {
                    
                    Text("Charge Response")
                        .font(.title)
                        .padding(.bottom)
                    
                    ScrollView {
                        
                        VStack {
                            
                            Text(response.prettyJSON)

                        }.frame(maxWidth: .infinity)
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Dismiss") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// ERROR VIEW
struct FiservTTPErrorView: View {
    
    let errorWrapper: FiservTTPErrorWrapper?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        
        NavigationView {
            
            VStack {
                
                if let error_wrapper = errorWrapper {
                    Text("An error has occurred!")
                        .font(.title)
                        .padding(.bottom)
                    Text(error_wrapper.error.title)
                        .font(.headline)
                    Text(error_wrapper.error.localizedDescription)
                        .font(.headline)
                    Text(error_wrapper.guidance)
                        .font(.caption)
                        .padding(.top)
                    Spacer()
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Dismiss") {
                        dismiss()
                    }
                }
            }
        }
    }
}
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
