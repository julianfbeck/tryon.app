import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var viewModel: TryOnViewModel
    @State private var selectedHistoryItem: TryOnResult?
    @State private var showDetailView = false
    
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
            .refreshable {
                Task {
                    await viewModel.loadHistory()
                }
            }
        }
        .sheet(isPresented: $showDetailView) {
            if let item = selectedHistoryItem {
                NavigationStack {
                    HistoryDetailView(item: item)
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadHistory()
            }
        }
        .onChange(of: showDetailView) { _, isPresented in
            if !isPresented {
                // Refresh history when detail view is dismissed
                Task {
                    await viewModel.loadHistory()
                }
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
        }
        .padding(.vertical, 60)
    }
    
    // History list view
    private var historyList: some View {
        LazyVStack(spacing: Constants.spacing) {
            ForEach(viewModel.historyItems.sorted(by: { $0.timestamp > $1.timestamp })) { item in
                historyCard(item: item)
                    .onTapGesture {
                        selectedHistoryItem = item
                        showDetailView = true
                    }
            }
        }
    }
    
    // Individual history card
    private func historyCard(item: TryOnResult) -> some View {
        VStack(alignment: .leading, spacing: Constants.spacing) {
            Text("Try-On • \(viewModel.formatDate(item.timestamp))")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Result image - now showing the selected/first image
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

// Detail view for a history item
struct HistoryDetailView: View {
    let item: TryOnResult
    @Environment(\.dismiss) private var dismiss
    @State private var showingSaveSuccess = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: Constants.spacing) {
                // Result image (large view)
                Image(uiImage: item.resultImage)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(Constants.cornerRadius)
                    .padding(.horizontal)
                
                // Source images
                HStack(spacing: Constants.spacing) {
                    VStack {
                        Text("Person")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Image(uiImage: item.personImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 150)
                            .cornerRadius(Constants.cornerRadius)
                    }
                    
                    VStack {
                        Text("Clothing")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Image(uiImage: item.clothImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 150)
                            .cornerRadius(Constants.cornerRadius)
                    }
                }
                .padding(.horizontal)
                
                // Share and save buttons
                HStack(spacing: 20) {
                    // Share button
                    ShareLink(item: Image(uiImage: item.resultImage), preview: SharePreview("Try-On Result", image: Image(uiImage: item.resultImage))) {
                        VStack {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 24))
                            Text("Share")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(Constants.cornerRadius)
                    }
                    
                    // Save button
                    Button {
                        UIImageWriteToSavedPhotosAlbum(item.resultImage, nil, nil, nil)
                        showingSaveSuccess = true
                    } label: {
                        VStack {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 24))
                            Text("Save")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(Constants.cornerRadius)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Try-On from \(formattedDate)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .alert("Image Saved", isPresented: $showingSaveSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The image has been saved to your photo library.")
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: item.timestamp)
    }
}

#Preview {
    HistoryView()
        .environmentObject(TryOnViewModel())
} 
