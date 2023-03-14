//
//  ContentView.swift
//  ttpfun
//
//  Created by Tom Eck on 9/21/22.
//

import SwiftUI
import ProximityReader
import FiservTTP

struct ContentView: View {

    @State private var amount: String = "5.00"
    
    @State var sessionTokenCheckmarkColor = Color.gray
    @State var accountLinkedCheckmarkColor = Color.gray
    @State var sessionStartedCheckmarkColor = Color.gray
    
    @State var showSpinner = false
    @State var linkButtonTitle: String = "Link Apple Account"

    // USED FOR ALL ERRORS
    @State private var errorWrapper: FiservTTPErrorWrapper?
    @Environment(\.dismiss) private var dismiss
    
    // VIEW MODEL
    @StateObject var viewModel = FiservTTPViewModel()
    
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
                
                Section("1. Obtain session token") {
                    HStack() {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(sessionTokenCheckmarkColor)
                        Button("Create Session Token", action: {
                            sessionTokenCheckmarkColor = Color.gray
                            
                            print("Getting session token...")
                            Task {
                                do {
                                    try await viewModel.requestSessionToken()
                                    sessionTokenCheckmarkColor = Color.green
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
                            .foregroundColor(accountLinkedCheckmarkColor)
                        Button(linkButtonTitle, action: {
                            accountLinkedCheckmarkColor = Color.gray
                            
                            print("Linking account...")
                            
                            Task {
                                do {
                                    try await viewModel.linkAccount()
                                    accountLinkedCheckmarkColor = Color.green
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
                            .foregroundColor(sessionStartedCheckmarkColor)
                        Button("Start TTP Session", action: {
                            sessionStartedCheckmarkColor = Color.gray
                            
                            print("Initializing TTP session...")
                            
                            Task {
                                do {
                                    try await viewModel.activateReader()
                                    sessionStartedCheckmarkColor = Color.green
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
            .sheet(item: $errorWrapper) { wrapper in
                FiservTTPErrorView(errorWrapper: wrapper)
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
