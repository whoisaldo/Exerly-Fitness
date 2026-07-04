import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: ChatRole
    let content: String
    let timestamp: Date

    enum ChatRole { case user, assistant }
}

@MainActor
final class AICoachViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = [
        ChatMessage(role: .assistant, content: "Hey! I'm your AI fitness coach. Ask me about workouts, nutrition, or your progress. What can I help with?", timestamp: Date())
    ]
    @Published var inputText = ""
    @Published var isLoading = false
    @Published var credits: AICreditsDTO?
    @Published var savedPlans: [AIPlanDTO] = []
    @Published var showPlans = false

    private let api = APIClient.shared

    func loadCredits() async {
        do { credits = try await api.getAICredits() }
        catch { print("AI credits load failed: \(error)") }
    }

    func loadPlans() async {
        do { savedPlans = try await api.getAIPlans() }
        catch { print("AI plans load failed: \(error)") }
    }

    func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }
        inputText = ""
        messages.append(ChatMessage(role: .user, content: text, timestamp: Date()))
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await api.sendAICoach(type: "custom_question", question: text)
            messages.append(ChatMessage(role: .assistant, content: result.response, timestamp: Date()))
            await loadCredits()
            await loadPlans()
        } catch {
            messages.append(ChatMessage(role: .assistant, content: Self.friendlyMessage(for: error), timestamp: Date()))
        }
    }

    private static func friendlyMessage(for error: Error) -> String {
        if let apiError = error as? APIError {
            // The backend returns 429 with a human-readable reason for rate/credit limits.
            if case .serverError(429, let msg) = apiError { return msg }
            return apiError.errorDescription ?? "Sorry, I couldn't respond right now. Please try again."
        }
        return "Sorry, I couldn't respond right now. Please try again."
    }
}

struct AICoachView: View {
    @StateObject private var vm = AICoachViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                creditBadge
                messageList
                quickActions
                inputBar
            }
            .background(Color.exBackground)
            .navigationTitle("AI Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { vm.showPlans.toggle() } label: {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.exPrimary)
                    }
                }
            }
            .sheet(isPresented: $vm.showPlans) { savedPlansSheet }
            .task {
                await vm.loadCredits()
                await vm.loadPlans()
            }
        }
    }

    @ViewBuilder
    private var creditBadge: some View {
        if let credits = vm.credits {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                Text("\(credits.creditsRemaining) credits remaining")
                    .font(.exSmall)
            }
            .foregroundStyle(.exTextSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .glassCard(cornerRadius: 16)
            .padding(.top, 8)
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(vm.messages) { msg in
                        messageBubble(msg)
                            .id(msg.id)
                    }
                    if vm.isLoading {
                        typingIndicator
                    }
                }
                .padding(16)
            }
            .onChange(of: vm.messages.count) { _, _ in
                if let last = vm.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private func messageBubble(_ msg: ChatMessage) -> some View {
        HStack {
            if msg.role == .user { Spacer(minLength: 60) }

            VStack(alignment: msg.role == .user ? .trailing : .leading, spacing: 4) {
                Text(msg.content)
                    .font(.exBody)
                    .foregroundStyle(msg.role == .user ? .white : .exTextPrimary)
                    .padding(12)
                    .background(
                        msg.role == .user
                            ? AnyShapeStyle(Color.exPrimary)
                            : AnyShapeStyle(Color.exGlassBg)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        if msg.role == .assistant {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.exGlassBorder, lineWidth: 1)
                        }
                    }

                Text(msg.timestamp, style: .time)
                    .font(.system(size: 10))
                    .foregroundStyle(.exTextMuted)
            }

            if msg.role == .assistant { Spacer(minLength: 60) }
        }
    }

    private var typingIndicator: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.exTextMuted)
                        .frame(width: 6, height: 6)
                        .opacity(0.6)
                }
            }
            .padding(12)
            .background(Color.exGlassBg)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            Spacer()
        }
    }

    private var quickActions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                quickChip("Workout plan", icon: "dumbbell")
                quickChip("Meal ideas", icon: "fork.knife")
                quickChip("Form check", icon: "figure.walk")
                quickChip("Recovery tips", icon: "bed.double")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func quickChip(_ title: String, icon: String) -> some View {
        Button {
            vm.inputText = title
            Task { await vm.send() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.exCaption)
            }
            .foregroundStyle(.exPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.exPrimary.opacity(0.1))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.exPrimary.opacity(0.2), lineWidth: 1))
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask your coach...", text: $vm.inputText)
                .font(.exBody)
                .foregroundStyle(.exTextPrimary)
                .padding(12)
                .background(Color.exSurface2)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .onSubmit { Task { await vm.send() } }

            Button {
                Task { await vm.send() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(vm.inputText.isEmpty ? .exTextMuted : .exPrimary)
            }
            .disabled(vm.inputText.isEmpty || vm.isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var savedPlansSheet: some View {
        NavigationStack {
            Group {
                if vm.savedPlans.isEmpty {
                    EmptyStateView(icon: "doc.text", title: "No saved plans",
                                   message: "Plans generated by AI will appear here")
                } else {
                    List(vm.savedPlans) { plan in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(plan.type.capitalized)
                                .font(.exBodyMedium)
                                .foregroundStyle(.exTextPrimary)
                            Text(plan.content)
                                .font(.exCaption)
                                .foregroundStyle(.exTextSecondary)
                                .lineLimit(3)
                        }
                        .listRowBackground(Color.exSurface1)
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color.exBackground)
            .navigationTitle("Saved Plans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { vm.showPlans = false }
                        .foregroundStyle(.exPrimary)
                }
            }
        }
    }
}
