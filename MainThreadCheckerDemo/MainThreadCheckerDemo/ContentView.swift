//
//  ContentView.swift
//  MainThreadCheckerDemo
//
//  Created by LiYuyang on 2023/3/30.
//

import SwiftUI
import MainThreadChecker

struct ContentView: View {
    private let enableTitle: String = "Block Main Thread"
    private let disableTitle: String = "Checker is not running\nRestart app without debugger being attached"
    private let checkingText: String = "Checking"
    private let uncheckingText: String = "Not checking"
    
    @State private var buttonTitle: String = ""
    @State private var runningStateText: String = ""
    
    private let timeThreshold: Double = 5.0
    
    
    init() {
        MainThreadChecker.shared.start(checking: self.timeThreshold, in: .parentMode) {
            fatalError("Detected main thread block!")
        }
        // Checker starts running from now on...
    }
    
    private func format(_ constantString: String, with aString: String.LocalizationValue) -> AttributedString {
        var string = AttributedString(localized: aString)
        
        var morphology = Morphology()
        
        let number: Morphology.GrammaticalNumber
        
        switch self.timeThreshold {
        case let x where x == 0.0:
            number = .zero
        case let x where x > 0 && x <= 1.0:
            number = .singular
        default:
            number = .plural
        }
        
        morphology.partOfSpeech = .noun
        morphology.number = number
        string.inflect = InflectionRule(morphology: morphology)
        
        let formattedResult = string.inflected()
        return AttributedString(constantString) + formattedResult
    }
    
    var body: some View {
        VStack {
            Text(self.format("\(self.runningStateText) with threshold of ", with: "\(self.timeThreshold, specifier: "%.2lf") second."))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding()

            Button(self.buttonTitle) {
                while true {
                    // Block main thread
                }
            }
            .padding()
            .disabled(!MainThreadChecker.shared.running)
        }
        .padding()
        .onAppear {
            self.buttonTitle = MainThreadChecker.shared.running ? self.enableTitle : self.disableTitle
            self.runningStateText = MainThreadChecker.shared.running ? self.checkingText : self.uncheckingText
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
