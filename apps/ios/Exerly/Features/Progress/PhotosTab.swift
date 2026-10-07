import SwiftUI
import PhotosUI
import SwiftData

struct PhotosTab: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var typeSize
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
            if photos.isEmpty {
                ExEmptyState(icon: "camera", title: "Progress photos",
                             message: "Compare changes over time. Photos stay on this device.",
                             action: "Add photo") { choosingPhoto = true }
            } else {
                ExSectionHeading("Photo record", detail: photos.count.formatted())
                Text("Saved on this device").font(.exCaption).foregroundStyle(Color.exTextSecondary)
                toolbar
                if compareMode, let compareA, let compareB {
                    ExCard {
                        ExSectionHeading("Side by side")
                        let layout = typeSize.isAccessibilitySize
                            ? AnyLayout(VStackLayout(spacing: ExSpacing.item))
                            : AnyLayout(HStackLayout(alignment: .top, spacing: ExSpacing.small))
                        layout {
                            comparisonPhoto(compareA)
                            comparisonPhoto(compareB)
                        }
                    }.accessibilityIdentifier("progress.photoComparison")
                } else if compareMode {
                    Text("Choose two photos below.").font(.exCaption).foregroundStyle(Color.exTextSecondary)
                }
                LazyVGrid(columns: typeSize.isAccessibilitySize ? Array(columns.prefix(2)) : columns, spacing: 4) {
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
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: ExSpacing.small))
            : AnyLayout(HStackLayout())
        return layout {
            PhotosPicker(selection: $selectedItem, matching: .images) {
                Label("Add Photo", systemImage: "plus.circle.fill")
                    .font(.exLabel)
                    .foregroundStyle(.exPrimaryText)
            }.accessibilityIdentifier("progress.addPhoto")

            if !typeSize.isAccessibilitySize { Spacer() }

            Button {
                compareMode.toggle()
                if !compareMode { compareA = nil; compareB = nil }
            } label: {
                Label(compareMode ? "Done" : "Compare", systemImage: "arrow.left.arrow.right")
                    .font(.exLabel)
                    .foregroundStyle(compareMode ? .exPrimaryText : .exTextSecondary)
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
                            Image(systemName: "checkmark")
                                .foregroundStyle(.white)
                                .font(.system(size: 16, weight: .bold))
                                .padding(8)
                                .background(Color.exActionFill, in: Circle())
                        }
                    }
                }.buttonStyle(.plain)
                    .accessibilityIdentifier("progress.photo.\(photo.id)")
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
