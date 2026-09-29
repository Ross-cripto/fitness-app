import SwiftUI

/// Every finished workout, newest first, grouped by month.
struct HistoryView: View {
    @EnvironmentObject private var store: AppStore
    @State private var pendingDelete: WorkoutSession?

    var body: some View {
        let months = SessionSummary.months(store.sessions)
        Group {
            if months.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath")
                        .scaledFont(size: 40)
                        .foregroundStyle(.secondary)
                    Text(L("No workouts yet. Finish one and it will show up here."))
                        .scaledFont(size: 15)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(months) { month in
                        Section(Loc.date(month.start, "MMMMy")) {
                            ForEach(month.sessions) { session in
                                NavigationLink {
                                    SessionDetailView(session: session)
                                } label: {
                                    row(session)
                                }
                                .swipeActions {
                                    Button(L("Delete"), role: .destructive) { pendingDelete = session }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(L("All workouts"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            L("Delete this workout?"),
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button(L("Delete"), role: .destructive) {
                if let session = pendingDelete { store.delete(session) }
                pendingDelete = nil
            }
            Button(L("Cancel"), role: .cancel) { pendingDelete = nil }
        } message: {
            Text(L("It is removed from your history and progress. This can't be undone."))
        }
    }

    private func row(_ session: WorkoutSession) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title).scaledFont(size: 16, weight: .semibold)
                Text(Loc.date(session.date, "EEEdMMMjm"))
                    .scaledFont(size: 12)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(L("{0} min · {1} cal", session.durationSeconds / 60, session.calories))
                .scaledFont(size: 13, weight: .medium)
                .foregroundStyle(.secondary)
        }
    }
}

/// What was actually done in one workout.
struct SessionDetailView: View {
    let session: WorkoutSession
    @EnvironmentObject private var store: AppStore

    var body: some View {
        let units = store.profile.units
        List {
            Section {
                LabeledContent(L("Date"), value: Loc.date(session.date, "EEEEdMMMMjm"))
                LabeledContent(L("Duration"), value: L("{0} min", session.durationSeconds / 60))
                LabeledContent(L("Calories"), value: "\(session.calories)")
                LabeledContent(L("Sets"), value: "\(session.completedSets)/\(session.plannedSets)")
                if let feedback = session.feedback {
                    LabeledContent(L("How it felt")) {
                        Label(feedback.title, systemImage: feedback.symbol)
                    }
                }
                if session.wasDeload == true {
                    Label(L("Deload week"), systemImage: "arrow.down.heart.fill")
                        .foregroundStyle(Theme.amber)
                }
            }

            ForEach(session.logs) { log in
                Section {
                    Text(SessionSummary.summary(of: log, units: units))
                        .scaledFont(size: 14)
                    if let effort = log.effort {
                        Text(L("Felt: {0}", effort.title))
                            .scaledFont(size: 12)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(ExerciseLibrary.byID[log.exerciseID]?.name ?? log.exerciseID)
                }
            }
        }
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
