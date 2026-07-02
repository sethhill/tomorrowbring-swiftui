//
//  CheckInView.swift
//  tomorrowbring
//
//  Created by Seth Hill on 30.06.2026.
//

import SwiftUI
import SwiftData

/// A single predetermined answer: a label and an optional leading emoji.
///
/// Expressible directly from a string literal, so an answer can be written as
/// either `"Great"` or `CheckInAnswer("Great", emoji: "😄")`.
struct CheckInAnswer: Identifiable, ExpressibleByStringLiteral {
    let id = UUID()
    let label: String
    let emoji: String?

    init(_ label: String, emoji: String? = nil) {
        self.label = label
        self.emoji = emoji
    }

    init(stringLiteral value: String) {
        self.init(value)
    }

    /// The label prefixed with its emoji, when present.
    var display: String {
        guard let emoji else { return label }
        return "\(emoji)  \(label)"
    }
}

/// A single step in the check-in flow: a prompt and either a set of answers to
/// choose from or, when `placeholder` is set, an open-ended text response.
struct CheckInQuestion: Identifiable {
    let id = UUID()
    let prompt: String
    let answers: [CheckInAnswer]
    /// When non-nil, this step is open-ended and shows a text field with this placeholder.
    let placeholder: String?

    init(prompt: String, answers: [CheckInAnswer] = [], placeholder: String? = nil) {
        self.prompt = prompt
        self.answers = answers
        self.placeholder = placeholder
    }

    /// Whether this step expects free-form text instead of a button choice.
    var isOpenEnded: Bool { placeholder != nil }
}

/// Drives a stepped question-and-answer flow, presenting one question at a time
/// with a set of predetermined answer buttons.
struct CheckInView: View {
    /// The questions to ask, in order. Replace or extend with your own content.
    let questions: [CheckInQuestion]

    /// Called once the check-in is completed and saved. When provided, the flow
    /// finishes here (e.g. navigating away) instead of showing the summary.
    let onComplete: (() -> Void)?

    @Environment(\.modelContext) private var modelContext

    /// Index of the question currently being shown.
    @State private var currentIndex = 0

    /// The selected answer for each question, keyed by question id.
    @State private var responses: [UUID: String] = [:]

    init(
        questions: [CheckInQuestion] = CheckInView.sampleQuestions,
        onComplete: (() -> Void)? = nil
    ) {
        self.questions = questions
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 32) {
            if currentIndex < questions.count {
                questionStep(questions[currentIndex])
            } else {
                summaryStep
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.appBackground.ignoresSafeArea())
        .animation(.easeInOut, value: currentIndex)
        .onChange(of: currentIndex) { _, newValue in
            // Save once all questions are answered, then hand off to the caller
            // (e.g. navigate to the briefing) or fall back to the summary.
            if newValue == questions.count {
                saveCheckIn()
                onComplete?()
            }
        }
    }

    // MARK: - Steps

    /// Shows a single question with a progress indicator and answer buttons.
    private func questionStep(_ question: CheckInQuestion) -> some View {
        VStack(spacing: 32) {
            ProgressView(value: Double(currentIndex), total: Double(questions.count))
                .tint(.brandGreen)

            Text("Question \(currentIndex + 1) of \(questions.count)")
                .font(.appSubheadline)
                .foregroundColor(.secondary)

            Text(question.prompt)
                .font(.appTitle2)
                .multilineTextAlignment(.center)

            if question.isOpenEnded {
                openEndedStep(question)
            } else {
                VStack(spacing: 12) {
                    ForEach(question.answers) { answer in
                        Button {
                            select(answer.label, for: question)
                        } label: {
                            Text(answer.display)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.brandGreen)
                        .controlSize(.large)
                    }
                }
            }

            if currentIndex > 0 {
                Button("Back", action: goBack)
                    .buttonStyle(.borderless)
            }
        }
    }

    /// Shows a text field for an open-ended question plus a button to finish.
    private func openEndedStep(_ question: CheckInQuestion) -> some View {
        VStack(spacing: 16) {
            TextField(question.placeholder ?? "", text: response(for: question), axis: .vertical)
                .lineLimit(3...6)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.white)
                        .stroke(Color.secondary.opacity(0.4))
                )

            Button("Done") {
                currentIndex += 1
            }
            .buttonStyle(.borderedProminent)
            .tint(.brandGreen)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
        }
    }

    /// Shown once every question has been answered.
    private var summaryStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.appLargeTitle)
                .foregroundColor(.brandGreen)

            Text("All done!")
                .font(.appTitle)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(questions) { question in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(question.prompt)
                            .font(.appSubheadline)
                            .foregroundColor(.secondary)
                        Text(answerText(for: question))
                            .font(.appBodySemibold)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("Start Over", action: restart)
                .buttonStyle(.borderedProminent)
                .tint(.brandGreen)
                .controlSize(.large)
        }
    }

    // MARK: - Actions

    /// Records the chosen answer and advances to the next question.
    private func select(_ answer: String, for question: CheckInQuestion) {
        responses[question.id] = answer
        currentIndex += 1
    }

    /// A two-way binding into `responses` for an open-ended question's text.
    private func response(for question: CheckInQuestion) -> Binding<String> {
        Binding(
            get: { responses[question.id] ?? "" },
            set: { responses[question.id] = $0 }
        )
    }

    /// The recorded answer for the summary, or a fallback when nothing was entered.
    private func answerText(for question: CheckInQuestion) -> String {
        let answer = responses[question.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if answer.isEmpty {
            return question.isOpenEnded ? "No notes" : "—"
        }
        return answer
    }

    private func goBack() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
    }

    private func restart() {
        responses.removeAll()
        currentIndex = 0
    }

    /// Persists the completed check-in, skipping any unanswered (e.g. optional) questions.
    private func saveCheckIn() {
        let records = questions.compactMap { question -> CheckInResponse? in
            let answer = responses[question.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !answer.isEmpty else { return nil }
            return CheckInResponse(prompt: question.prompt, answer: answer)
        }
        guard !records.isEmpty else { return }
        modelContext.insert(CheckInEntry(responses: records))
    }
}

// MARK: - Sample Content

extension CheckInView {
    /// Placeholder questions to demonstrate the flow.
    static let sampleQuestions: [CheckInQuestion] = [
        CheckInQuestion(
            prompt: "How’s your energy today?",
            answers: [
                CheckInAnswer("Great", emoji: "⚡️"),
                CheckInAnswer("Good", emoji: "🙂"),
                CheckInAnswer("Okay", emoji: "😐"),
                CheckInAnswer("Low", emoji: "🥱"),
                CheckInAnswer("Drained", emoji: "🪫")
            ]
        ),
        CheckInQuestion(
            prompt: "How’s your stress level?",
            answers: [
                CheckInAnswer("Chill", emoji: "😌"),
                CheckInAnswer("A bit", emoji: "🙂"),
                CheckInAnswer("Stressed", emoji: "😰"),
                CheckInAnswer("Overwhelmed", emoji: "🤯")
            ]
        ),
        CheckInQuestion(
            prompt: "How’s your work stress specifically?",
            answers: [
                CheckInAnswer("Under control", emoji: "✅"),
                CheckInAnswer("Manageable", emoji: "🙂"),
                CheckInAnswer("Elevated", emoji: "😣"),
                CheckInAnswer("A lot right now", emoji: "🔥")
            ]
        ),
        CheckInQuestion(
            prompt: "Overall mood?",
            answers: [
                CheckInAnswer("Good", emoji: "😄"),
                CheckInAnswer("Decent", emoji: "🙂"),
                CheckInAnswer("Mixed", emoji: "😕"),
                CheckInAnswer("Low", emoji: "😔")
            ]
        ),
        CheckInQuestion(
            prompt: "Anything you want to note?",
            placeholder: "What’s on your mind? (optional)"
        )
    ]
}

#Preview {
    CheckInView()
}
