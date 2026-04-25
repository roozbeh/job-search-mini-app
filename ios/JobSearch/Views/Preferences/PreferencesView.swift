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
                Section {
                    JourneyStepBar(currentStep: 3)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

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

                // MARK: Job Type (multi-select)
                Section {
                    ForEach(JobPreferences.JobType.allCases) { type in
                        Toggle(isOn: Binding(
                            get: { vm.preferences.jobTypes.contains(type) },
                            set: { checked in
                                if checked { vm.preferences.jobTypes.insert(type) }
                                else       { vm.preferences.jobTypes.remove(type) }
                            }
                        )) {
                            Text(type.rawValue)
                        }
                        .tint(.indigo)
                    }
                } header: {
                    Label("Employment Type", systemImage: "clock.fill")
                } footer: {
                    Text("Select all that apply. Leave all off to include any type.")
                }

                // MARK: Salary (minimum only, chip picker)
                Section {
                    SalaryChipRow(value: Binding(
                        get: { vm.preferences.salaryMin ?? 0 },
                        set: { vm.preferences.salaryMin = $0 == 0 ? nil : $0 }
                    ))
                } header: {
                    Label("Minimum Salary (USD/year)", systemImage: "dollarsign.circle.fill")
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

// MARK: - Salary Chip Row

struct SalaryChipRow: View {
    @Binding var value: Int

    private let presets = [0, 50_000, 80_000, 100_000, 120_000, 150_000, 200_000]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { amount in
                    let selected = value == amount
                    Button(amount == 0 ? "Any" : "$\(amount / 1000)K+") {
                        value = amount
                    }
                    .font(.subheadline.weight(selected ? .semibold : .regular))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(selected ? Color.indigo : Color(.systemGray5),
                                in: Capsule())
                    .foregroundStyle(selected ? .white : .primary)
                    .animation(.easeInOut(duration: 0.15), value: selected)
                }
            }
            .padding(.vertical, 4)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 0))
    }
}
