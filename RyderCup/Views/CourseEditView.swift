import SwiftUI

struct CourseEditView: View {
    @EnvironmentObject var vm: TournamentViewModel
    @State private var courseName: String = ""
    @State private var holes: [Hole] = []
    @State private var dirty: Bool = false

    var body: some View {
        Form {
            Section("Course") {
                TextField("Course name", text: $courseName)
                    .onChange(of: courseName) { _, _ in dirty = true }
            }
            Section {
                ForEach($holes) { $h in
                    HoleEditRow(hole: $h) { dirty = true }
                }
            } header: {
                HStack {
                    Text("18 Holes")
                    Spacer()
                    Text("Total par: \(holes.reduce(0) { $0 + $1.par })")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } footer: {
                Text("HCP Index 1 = hardest hole. These ratings drive net stroke allocation for Saturday PM.")
            }
            if dirty {
                Section { Button("Save course") { persist() } }
            }
        }
        .navigationTitle("Course")
        .onAppear {
            if holes.isEmpty {
                courseName = vm.tournament?.course.name ?? ""
                holes = vm.tournament?.course.holes ?? Course.blank().holes
            }
        }
    }

    private func persist() {
        let course = Course(name: courseName, holes: holes.sorted { $0.number < $1.number })
        Task { await vm.setCourse(course) }
        dirty = false
    }
}

private struct HoleEditRow: View {
    @Binding var hole: Hole
    var onChange: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("Hole \(hole.number)").font(.body.bold()).frame(width: 70, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text("Par").font(.caption2).foregroundStyle(.secondary)
                Picker("", selection: $hole.par) {
                    ForEach(3...5, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 110)
                .onChange(of: hole.par) { _, _ in onChange() }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("HCP").font(.caption2).foregroundStyle(.secondary)
                Stepper(value: $hole.handicapIndex, in: 1...18) {
                    Text("\(hole.handicapIndex)").monospacedDigit().frame(width: 24, alignment: .trailing)
                }
                .onChange(of: hole.handicapIndex) { _, _ in onChange() }
            }
        }
        .padding(.vertical, 2)
    }
}
