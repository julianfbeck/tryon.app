import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var viewModel: TryOnViewModel
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Constants.largeSpacing) {
                    if viewModel.historyItems.isEmpty {
                        emptyHistoryView
                    } else {
                        historyList
                    }
                }
                .padding()
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        Task {
                            await viewModel.clearHistory()
                        }
                    }) {
                        Text("Clear")
                            .foregroundColor(.red)
                    }
                    .disabled(viewModel.historyItems.isEmpty)
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadHistory()
            }
        }
    }
    
    // Empty state view
    private var emptyHistoryView: some View {
        VStack(spacing: Constants.spacing) {
            Image(systemName: "tray.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
                .padding()
            
            Text("No History")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Your virtual try-on history will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            NavigationLink {
                TryOnView()
            } label: {
                Text("Try On Something New")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(Constants.cornerRadius)
                    .padding(.top, 20)
            }
        }
        .padding(.vertical, 60)
    }
    
    // History list view
    private var historyList: some View {
        LazyVStack(spacing: Constants.spacing) {
            ForEach(viewModel.historyItems) { item in
                historyCard(item: item)
            }
        }
    }
    
    // Individual history card
    private func historyCard(item: TryOnResult) -> some View {
        VStack(alignment: .leading, spacing: Constants.spacing) {
            Text("Try-On • \(viewModel.formatDate(item.timestamp))")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Result image
            Image(uiImage: item.resultImage)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 400)
                .cornerRadius(Constants.cornerRadius)
            
            // Original images in smaller format
            HStack(spacing: Constants.spacing) {
                VStack(alignment: .leading) {
                    Text("Person")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Image(uiImage: item.personImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                VStack(alignment: .leading) {
                    Text("Clothing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Image(uiImage: item.clothImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(Constants.cornerRadius)
    }
}

#Preview {
    HistoryView()
        .environmentObject(TryOnViewModel())
} 