//
//  ContentView.swift
//  Waves
//
//  Created by Sahil Mahendrakar on 2/28/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        #if os(macOS)
        ScreenCaptureView()
        #else
        Text("Waves")
        #endif
    }
}

#Preview {
    ContentView()
}
