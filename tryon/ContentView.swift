//
//  ContentView.swift
//  tryon
//
//  Created by Julian Beck on 17.03.25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var globalViewModel: GlobalViewModel
    
    var body: some View {
        MainTabView()
            .fullScreenCover(isPresented: $globalViewModel.isShowingPayWall) {
                PayWallView()
            }
    }
}

#Preview {
    ContentView()
        .environmentObject(GlobalViewModel())
}
