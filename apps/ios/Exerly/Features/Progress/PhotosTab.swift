import SwiftUI
import PhotosUI
import SwiftData

struct PhotosTab: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var photos: [ProgressPhoto] = []
    @State private var selectedItem: PhotosPickerItem?
    @State private var choosingPhoto = false
    @State private var compareMode = false
    @State private var compareA: ProgressPhoto?
    @State private var compareB: ProgressPhoto?
    @State private var viewingPhoto: ProgressPhoto?

    private let columns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
    ]

    var body: some View {
        ExScreen {
            VStack(alignment: .leading, spacing: ExSpacing.small) {
                ExEyebrow("Visual record", color: .exPrimaryText)
                Text("Progress photos").font(.exH1)
                Text("Saved on this device. Choose the moments you want to compare.").font(.exBody).foregroundStyle(Color.exTextSecondary)
            }
            if photos.isEmpty {
                ExEmptyState(icon: "camera", title: "Start your photo record",
                             message: "Use a similar pose and lighting when you take the next one.",
                             action: "Add photo") { choosingPhoto = true }
            } else {
                toolbar
                if compareMode, let compareA, let compareB {
                    ExCard {
                        ExSectionHeading("Side by side")
                        HStack(alignment: .top, spacing: ExSpacing.small) {
                            comparisonPhoto(compareA)
                            comparisonPhoto(compareB)
                        }
                    }
                } else if compareMode {
                    Text("Choose two photos below.").font(.exCaption).foregroundStyle(Color.exTextSecondary)
                }
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(photos) { photo in photoCell(photo) }
                }.clipShape(RoundedRectangle(cornerRadius: ExRadius.control))
            }
        }
        .photosPicker(isPresented: $choosingPhoto, selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) { _, item in Task { await loadPhoto(item) } }
        .onAppear { fetchPhotos() }
        .sheet(item: $viewingPhoto) { photo in
            NavigationStack {
                ExScreen { comparisonPhoto(photo) }
                    .navigationTitle("Progress photo").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { viewingPhoto = nil } } }
            }
        }
    }

    private func comparisonPhoto(_ photo: ProgressPhoto) -> some View {
        VStack(alignment: .leading, spacing: ExSpacing.small) {
            if let data = photo.imageData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFit().accessibilityLabel("Progress photo")
            }
            Text(photo.date, format: .dateTime.month().day().year()).font(.exCaption).foregroundStyle(Color.exTextSecondary)
        }.frame(maxWidth: .infinity)
    }

    private var toolbar: some View {
        HStack {
            PhotosPicker(selection: $selectedItem, matching: .images) {
                Label("Add Photo", systemImage: "plus.circle.fill")
                    .font(.exLabel)
                    .foregroundStyle(.exPrimaryText)
            }

            Spacer()

            Button {
                compareMode.toggle()
                if !compareMode { compareA = nil; compareB = nil }
            } label: {
                Label(compareMode ? "Done" : "Compare", systemImage: "arrow.left.arrow.right")
                    .font(.exLabel)
                    .foregroundStyle(compareMode ? .exPrimary : .exTextSecondary)
            }
        }
        .frame(minHeight: 44)
    }

    private func photoCell(_ photo: ProgressPhoto) -> some View {
        Group {
            if let data = photo.imageData, let uiImage = UIImage(data: data) {
                Button {
                    if compareMode { handleCompareSelect(photo) } else { viewingPhoto = photo }
                } label: {
                    Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
                    .overlay {
                        if compareMode && (compareA?.id == photo.id || compareB?.id == photo.id) {
                            Color.exPrimary.opacity(0.3)
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.exPrimaryText)
                                .font(.system(size: 24))
                        }
                    }
                }.buttonStyle(.plain)
                    .accessibilityLabel("Photo from \(photo.date.formatted(date: .abbreviated, time: .omitted))")
                    .accessibilityAddTraits(compareMode && (compareA?.id == photo.id || compareB?.id == photo.id) ? .isSelected : [])
            } else {
                Color.exSurface2
                    .aspectRatio(1, contentMode: .fill)
            }
        }
    }

    private func handleCompareSelect(_ photo: ProgressPhoto) {
        if compareA?.id == photo.id {
            compareA = compareB
            compareB = nil
        } else if compareB?.id == photo.id {
            compareB = nil
        } else if compareA == nil {
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
        let descriptor = FetchDescriptor<ProgressPhoto>(
            predicate: #Predicate { $0.userId == userEmail },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        photos = (try? modelContext.fetch(descriptor)) ?? []
    }
}
