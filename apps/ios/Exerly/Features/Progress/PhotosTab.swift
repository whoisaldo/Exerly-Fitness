import SwiftUI
import PhotosUI
import SwiftData

struct PhotosTab: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var photos: [ProgressPhoto] = []
    @State private var selectedItem: PhotosPickerItem?
    @State private var compareMode = false
    @State private var compareA: ProgressPhoto?
    @State private var compareB: ProgressPhoto?

    private let columns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
    ]

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            if photos.isEmpty {
                EmptyStateView(
                    icon: "camera",
                    title: "No progress photos",
                    message: "Take photos to visually track your transformation"
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(photos) { photo in
                            photoCell(photo)
                        }
                    }
                    .padding(4)
                    .padding(.bottom, 100)
                }
            }
        }
        .onAppear { fetchPhotos() }
    }

    private var toolbar: some View {
        HStack {
            PhotosPicker(selection: $selectedItem, matching: .images) {
                Label("Add Photo", systemImage: "plus.circle.fill")
                    .font(.exLabel)
                    .foregroundStyle(.exPrimary)
            }
            .onChange(of: selectedItem) { _, item in
                Task { await loadPhoto(item) }
            }

            Spacer()

            Button {
                withAnimation { compareMode.toggle() }
            } label: {
                Label(compareMode ? "Done" : "Compare", systemImage: "arrow.left.arrow.right")
                    .font(.exLabel)
                    .foregroundStyle(compareMode ? .exAccent : .exTextSecondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func photoCell(_ photo: ProgressPhoto) -> some View {
        Group {
            if let data = photo.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
                    .overlay {
                        if compareMode && (compareA?.id == photo.id || compareB?.id == photo.id) {
                            Color.exPrimary.opacity(0.3)
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.exPrimary)
                                .font(.system(size: 24))
                        }
                    }
                    .onTapGesture {
                        if compareMode {
                            handleCompareSelect(photo)
                        }
                    }
            } else {
                Color.exSurface2
                    .aspectRatio(1, contentMode: .fill)
            }
        }
    }

    private func handleCompareSelect(_ photo: ProgressPhoto) {
        if compareA == nil {
            compareA = photo
        } else if compareB == nil {
            compareB = photo
        } else {
            compareA = photo
            compareB = nil
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        let userId = authVM.currentUser?.email
        let photo = ProgressPhoto(imageData: data, userId: userId)
        modelContext.insert(photo)
        fetchPhotos()
    }

    private func fetchPhotos() {
        let userEmail = authVM.currentUser?.email ?? ""
        var descriptor = FetchDescriptor<ProgressPhoto>(
            predicate: #Predicate { $0.userId == userEmail },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        photos = (try? modelContext.fetch(descriptor)) ?? []
    }
}
