import Combine
import CoreTransferable
import ExerlyCore
import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

struct NutritionLabelScan: Identifiable, Sendable {
    let id = UUID()
    let imageData: Data
    let lines: [String]
    let reading: LabelReading
}

enum NutritionLabelRecognitionError: LocalizedError, Equatable {
    case image, tooLarge, noLabel

    var errorDescription: String? {
        switch self {
        case .image: "This photo could not be opened. Choose another photo or enter the label manually."
        case .tooLarge: "This photo is too large. Crop it to the nutrition label and try again."
        case .noLabel: "No readable nutrition label was found. Try a closer, well-lit photo or enter the label manually."
        }
    }
}

struct NutritionLabelPhoto: Transferable, Sendable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            let attributes = try FileManager.default.attributesOfItem(atPath: received.file.path)
            guard let size = attributes[.size] as? NSNumber,
                  size.intValue <= NutritionLabelRecognition.maximumBytes else { throw NutritionLabelRecognitionError.tooLarge }
            let data = try Data(contentsOf: received.file)
            guard data.count <= NutritionLabelRecognition.maximumBytes else { throw NutritionLabelRecognitionError.tooLarge }
            return NutritionLabelPhoto(data: data)
        }
    }
}

enum NutritionLabelRecognition {
    static let maximumBytes = 40 * 1024 * 1024

    static func recognize(_ data: Data) async throws -> NutritionLabelScan {
        let worker = Task.detached(priority: .userInitiated) { try recognizeImage(data) }
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: { worker.cancel() }
    }

    private static func recognizeImage(_ data: Data) throws -> NutritionLabelScan {
        try autoreleasepool {
            try Task.checkCancellation()
            guard data.count <= maximumBytes else { throw NutritionLabelRecognitionError.tooLarge }
            guard !data.isEmpty,
                  let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
                  let height = properties[kCGImagePropertyPixelHeight] as? NSNumber else { throw NutritionLabelRecognitionError.image }
            guard width.doubleValue > 0, height.doubleValue > 0,
                  width.doubleValue <= 20_000, height.doubleValue <= 20_000,
                  width.doubleValue * height.doubleValue <= 120_000_000 else { throw NutritionLabelRecognitionError.tooLarge }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 2400,
                kCGImageSourceShouldCacheImmediately: true
            ]
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                throw NutritionLabelRecognitionError.image
            }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = false
            try VNImageRequestHandler(cgImage: image).perform([request])
            try Task.checkCancellation()
            let lines = readingLines(request.results ?? [])
            guard let reading = NutritionLabel.read(lines) else { throw NutritionLabelRecognitionError.noLabel }
            let output = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
                throw NutritionLabelRecognitionError.image
            }
            CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary)
            guard CGImageDestinationFinalize(destination) else { throw NutritionLabelRecognitionError.image }
            return NutritionLabelScan(imageData: output as Data, lines: lines, reading: reading)
        }
    }

    /// Vision can separate a nutrient name, its amount and its daily percentage.
    /// Join fragments on the same visual row, then read rows from top to bottom.
    private static func readingLines(_ observations: [VNRecognizedTextObservation]) -> [String] {
        var rows: [[VNRecognizedTextObservation]] = []
        for observation in observations.sorted(by: { $0.boundingBox.midY > $1.boundingBox.midY }) {
            if let index = rows.indices.last, let first = rows[index].first,
               abs(first.boundingBox.midY - observation.boundingBox.midY) <= min(first.boundingBox.height, observation.boundingBox.height) * 0.6 {
                rows[index].append(observation)
            } else { rows.append([observation]) }
        }
        return rows.map { row in
            row.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
                .compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
        }.filter { !$0.isEmpty }
    }
}

@MainActor
final class NutritionLabelScanner: ObservableObject {
    @Published private(set) var result: NutritionLabelScan?
    @Published private(set) var error: String?
    @Published private(set) var isReading = false
    private var work: Task<Void, Never>?
    private var requestID = UUID()
    private let recognize: @Sendable (Data) async throws -> NutritionLabelScan

    init(recognize: @escaping @Sendable (Data) async throws -> NutritionLabelScan = { try await NutritionLabelRecognition.recognize($0) }) {
        self.recognize = recognize
    }

    func read(_ data: Data) {
        cancel()
        let id = requestID
        isReading = true
        work = Task { [weak self, recognize] in
            do {
                let result = try await recognize(data)
                guard !Task.isCancelled, let self, self.requestID == id else { return }
                self.result = result
                self.isReading = false
            } catch {
                guard !Task.isCancelled, let self, self.requestID == id else { return }
                self.error = (error as? NutritionLabelRecognitionError)?.localizedDescription
                    ?? "The label could not be read. Try another photo or enter it manually."
                self.isReading = false
            }
        }
    }

    func fail(_ error: Error) {
        cancel()
        self.error = (error as? NutritionLabelRecognitionError)?.localizedDescription
            ?? "The photo could not be loaded. Choose another photo or enter the label manually."
    }

    func cancel() {
        requestID = UUID()
        work?.cancel()
        work = nil
        result = nil
        error = nil
        isReading = false
    }
}
