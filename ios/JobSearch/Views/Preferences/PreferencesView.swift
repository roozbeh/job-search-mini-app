import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var newJobTitle = ""
    @State private var newLocation = ""
    @FocusState private var focusedField: Field?

    enum Field { case jobTitle, location }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Job Titles
                Section {
                    ForEach(vm.preferences.jobTitles, id: \.self) { title in
                        Text(title)
                    }
                    .onDelete { vm.preferences.jobTitles.remove(atOffsets: $0) }

                    HStack {
                        TextField("Add role (e.g. iOS Engineer)", text: $newJobTitle)
                            .focused($focusedField, equals: .jobTitle)
                            .submitLabel(.done)
                            .onSubmit(addJobTitle)
                        if !newJobTitle.isEmpty {
                            Button(action: addJobTitle) {
                                Image(systemName: "plus.circle.fill").foregroundStyle(.indigo)
                            }
                        }
                    }
                } header: {
                    Label("Target Roles", systemImage: "briefcase.fill")
                } footer: {
                    Text("We'll search for these job titles. Add 2-3 for best results.")
                }

                // MARK: Locations
                Section {
                    ForEach(vm.preferences.locations, id: \.self) { loc in
                        Text(loc)
                    }
                    .onDelete { vm.preferences.locations.remove(atOffsets: $0) }

                    HStack {
                        TextField("Add city or region", text: $newLocation)
                            .focused($focusedField, equals: .location)
                            .submitLabel(.done)
                            .onSubmit(addLocation)
                        if !newLocation.isEmpty {
                            Button(action: addLocation) {
                                Image(systemName: "plus.circle.fill").foregroundStyle(.indigo)
                            }
                        }
                    }
                } header: {
                    Label("Locations", systemImage: "location.fill")
                }

                // MARK: Remote
                Section {
                    Toggle(isOn: $vm.preferences.isRemote) {
                        Label("Include Remote Roles", systemImage: "house.fill")
                    }
                    .tint(.indigo)
                } header: {
                    Text("Work Style")
                }

                // MARK: Job Type
                Section {
                    Picker("Job Type", selection: $vm.preferences.jobType) {
                        ForEach(JobPreferences.JobType.allCases) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Label("Employment Type", systemImage: "clock.fill")
                }

                // MARK: Salary
                Section {
                    SalaryRangeRow(
                        label: "Minimum",
                        value: Binding(
                            get: { vm.preferences.salaryMin ?? 0 },
                            set: { vm.preferences.salaryMin = $0 == 0 ? nil : $0 }
                        )
                    )
                    SalaryRangeRow(
                        label: "Maximum",
                        value: Binding(
                            get: { vm.preferences.salaryMax ?? 0 },
                            set: { vm.preferences.salaryMax = $0 == 0 ? nil : $0 }
                        )
                    )
                } header: {
                    Label("Salary Range (USD/year)", systemImage: "dollarsign.circle.fill")
                } footer: {
                    Text("Set to 0 to skip salary filtering.")
                }
            }
            .navigationTitle("Job Preferences")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") { vm.phase = .resumeAnalysis }
                        .foregroundStyle(.indigo)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    focusedField = nil
                    Task { await vm.startJobSearch() }
                } label: {
                    Label("Find My Jobs", systemImage: "sparkles")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            vm.preferences.jobTitles.isEmpty
                                ? Color.secondary : Color.indigo,
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                        .foregroundStyle(.white)
                }
                .disabled(vm.preferences.jobTitles.isEmpty)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .background(.ultraThinMaterial)
            }
        }
    }

    // MARK: - Helpers

    private func addJobTitle() {
        let trimmed = newJobTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !vm.preferences.jobTitles.contains(trimmed) else { return }
        vm.preferences.jobTitles.append(trimmed)
        newJobTitle = ""
    }

    private func addLocation() {
        let trimmed = newLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !vm.preferences.locations.contains(trimmed) else { return }
        vm.preferences.locations.append(trimmed)
        newLocation = ""
    }
}

// MARK: - Salary Row

struct SalaryRangeRow: View {
    let label: String
    @Binding var value: Int

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            if value > 0 {
                Text(value, format: .currency(code: "USD").precision(.fractionLength(0)))
                    .foregroundStyle(.primary)
            } else {
                Text("Any").foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            ForEach([0, 50_000, 80_000, 100_000, 120_000, 150_000, 180_000, 200_000], id: \.self) { amount in
                Button(amount == 0 ? "Any" : amount.formatted(.currency(code: "USD").precision(.fractionLength(0)))) {
                    value = amount
                }
            }
        }
    }
}
