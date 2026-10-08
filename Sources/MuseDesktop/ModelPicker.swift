import SwiftUI

struct ModelPickerControl: View {
    @ObservedObject var store: WorkspaceStore
    @State private var presented = false

    var body: some View {
        Button { presented.toggle() } label: {
            HStack(spacing: 7) {
                Image(systemName: "cpu").foregroundStyle(MuseTheme.accent)
                Text(composerModelLabel).lineLimit(1).truncationMode(.tail)
                if let effort = store.reasoningEffort { Text("· " + effort.capitalized).foregroundStyle(MuseTheme.secondary) }
                if let notice = store.chosenModel?.dataUseNotice {
                    Text("Data use").font(.system(size: 11, weight: .medium)).foregroundStyle(MuseTheme.attention).help(notice)
                }
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 11, weight: .semibold))
            }
            .font(.system(size: 11, weight: .medium)).foregroundStyle(MuseTheme.text)
            .padding(.horizontal, 10).frame(height: 30)
            .background(MuseTheme.canvas, in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain).frame(maxWidth: 360, alignment: .trailing)
        .help(store.modelLabel + (store.chosenModel?.dataUseNotice.map { "\n" + $0 } ?? "") + "\nChoose model and reasoning level")
        .accessibilityLabel("Choose model").accessibilityValue(store.modelLabel + (store.chosenModel?.dataUseNotice == nil ? "" : ", data-use notice"))
        .popover(isPresented: $presented, arrowEdge: .top) {
            ModelPickerPanel(store: store).task { await store.refreshModels() }
        }
    }

    private var composerModelLabel: String {
        guard !store.echoMode, let model = store.chosenModel else { return store.modelLabel }
        return model.displayName + (model.profileID.map { " · " + $0 } ?? "")
    }
}

private struct ModelPickerPanel: View {
    @ObservedObject var store: WorkspaceStore
    @State private var query = ""

    private var filtered: [ModelEntry] { store.models.filter { $0.matches(query.trimmingCharacters(in: .whitespacesAndNewlines)) } }
    private var providers: [String] { Array(Set(filtered.map(\.providerID))).sorted() }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Choose a model").font(.system(size: 16, weight: .semibold))
                    Text(store.selectedID == nil ? "For new sessions" : "For this session")
                        .font(.system(size: 11)).foregroundStyle(MuseTheme.secondary)
                }
                Spacer()
                if store.modelsLoading { ProgressView().controlSize(.small).frame(width: 30, height: 30) }
                else { IconButton(symbol: "arrow.clockwise", label: "Refresh models") { Task { await store.refreshModels() } } }
            }.padding(12)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(MuseTheme.muted)
                TextField("Search models or providers", text: $query).textFieldStyle(.plain).accessibilityLabel("Search models")
                if !query.isEmpty { IconButton(symbol: "xmark", label: "Clear model search") { query = "" } }
            }
            .font(.system(size: 12)).padding(.horizontal, 11).frame(height: 36)
            .background(MuseTheme.raised, in: RoundedRectangle(cornerRadius: 8)).padding(.horizontal, 12).padding(.bottom, 8)
            Hairline()
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if store.selectedID == nil, query.isEmpty, !store.echoMode {
                        Button { store.useDefaultModel() } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "slider.horizontal.3").foregroundStyle(MuseTheme.secondary).frame(width: 20)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Muse default").font(.system(size: 13, weight: .medium))
                                    Text(store.models.first { $0.raw["isDefault"].bool == true }?.displayName ?? "Default not reported by Muse")
                                        .font(.system(size: 11)).foregroundStyle(MuseTheme.secondary)
                                }
                                Spacer()
                                if store.models.first(where: { $0.raw["isDefault"].bool == true })?.dataUseNotice != nil {
                                    Text("Data use").font(.system(size: 11)).foregroundStyle(MuseTheme.attention)
                                }
                                if store.selectedModelKey.isEmpty { Image(systemName: "checkmark").foregroundStyle(MuseTheme.accent) }
                            }.padding(.horizontal, 10).padding(.vertical, 6).contentShape(Rectangle())
                        }.buttonStyle(.plain).disabled(!store.canChooseModel).accessibilityLabel("Use Muse default model")
                    }
                    if let error = store.modelError {
                        Label(error, systemImage: "exclamationmark.circle")
                            .font(.system(size: 11)).foregroundStyle(MuseTheme.error).textSelection(.enabled).padding(10)
                    }
                    if store.models.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(store.echoMode ? "Offline echo provider" : (store.modelsLoading ? "Loading your models…" : "No models in this catalog"))
                                .font(.system(size: 12, weight: .medium))
                            Text(store.echoMode ? "Model selection is available when connected to your configured Muse provider." : "Muse can still use its configured default. Refresh this list after changing providers in Muse.")
                                .font(.system(size: 11)).foregroundStyle(MuseTheme.secondary)
                        }.padding(12)
                    } else if filtered.isEmpty {
                        Text("No models match “\(query)”.").font(.system(size: 12)).foregroundStyle(MuseTheme.secondary).padding(12)
                    }
                    ForEach(providers, id: \.self) { provider in
                        HStack {
                            Text(provider == "meta" ? "Meta" : provider).font(.system(size: 11, weight: .semibold))
                            Spacer()
                            if store.catalogSource == "fakeCatalog" { Text("Test catalog").font(.system(size: 11)) }
                        }.foregroundStyle(MuseTheme.secondary).padding(.horizontal, 10).padding(.top, 8).padding(.bottom, 2)
                        ForEach(filtered.filter { $0.providerID == provider }) { model in
                            ModelOption(model: model, selected: store.chosenModel?.id == model.id && !(store.selectedID == nil && store.selectedModelKey.isEmpty), showDefault: store.selectedID != nil) { store.setModel(model) }
                                .disabled(!store.canChooseModel || store.modelsLoading)
                        }
                    }
                }.padding(8)
            }.frame(maxHeight: .infinity)
            Hairline()
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("Reasoning").font(.system(size: 12, weight: .medium))
                    Spacer()
                    if let model = store.chosenModel, !model.efforts.isEmpty {
                        Menu {
                            Button("Use Muse default") { store.chooseReasoning(nil) }
                            Divider()
                            ForEach(model.efforts, id: \.self) { effort in
                                Button {
                                    store.chooseReasoning(effort)
                                } label: {
                                    if store.reasoningEffort == effort { Label(effort.capitalized, systemImage: "checkmark") }
                                    else { Text(effort.capitalized) }
                                }
                            }
                        } label: {
                            Text(store.reasoningEffort?.capitalized ?? "Muse default").font(.system(size: 12)).foregroundStyle(MuseTheme.accent)
                        }.menuStyle(.borderlessButton).fixedSize().disabled(!store.canChooseModel).accessibilityLabel("Reasoning level")
                    } else {
                        Text("Muse default").font(.system(size: 11)).foregroundStyle(MuseTheme.secondary)
                    }
                }
                Text(store.isChangingModel ? "Waiting for Muse to confirm the model…" : (store.isRunning ? "Finish the current turn to change models." : "Reasoning applies to messages you send from this app."))
                    .font(.system(size: 11)).foregroundStyle(MuseTheme.secondary)
                if let notice = store.chosenModel?.dataUseNotice {
                    Label(notice, systemImage: "hand.raised").font(.system(size: 11)).foregroundStyle(MuseTheme.attention).fixedSize(horizontal: false, vertical: true)
                }
            }.padding(16)
        }
        .frame(width: 380, height: 500).foregroundStyle(MuseTheme.text).background(MuseTheme.popover).preferredColorScheme(.dark)
    }
}

private struct ModelOption: View {
    let model: ModelEntry
    let selected: Bool
    let showDefault: Bool
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16)).foregroundStyle(selected ? MuseTheme.accent : MuseTheme.muted).padding(.top, 1)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(model.displayName).font(.system(size: 13, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        if model.dataUseNotice != nil { Text("Data use").font(.system(size: 11, weight: .medium)).foregroundStyle(MuseTheme.attention).fixedSize() }
                        if showDefault && model.raw["isDefault"].bool == true {
                            Text("Default").font(.system(size: 11, weight: .medium)).foregroundStyle(MuseTheme.accent)
                        }
                    }
                    HStack(spacing: 5) {
                        if let limit = model.raw["contextLimit"].int { Text("\(limit.formatted(.number.notation(.compactName))) context") }
                        if let limit = model.raw["outputLimit"].int { Text("· \(limit.formatted(.number.notation(.compactName))) output") }
                        if let profile = model.profileID { Text("· \(profile)").lineLimit(1).truncationMode(.middle) }
                    }.font(.system(size: 11)).foregroundStyle(MuseTheme.secondary)
                    if selected {
                        Text(model.modelID).font(.system(size: 11, design: .monospaced)).foregroundStyle(MuseTheme.secondary).textSelection(.enabled)
                        Text("Route: \(model.providerName)" + (model.profileID.map { " · profile " + $0 } ?? ""))
                            .font(.system(size: 11)).foregroundStyle(MuseTheme.secondary)
                        if let description = model.raw["description"].string, !description.isEmpty {
                            Text(description).font(.system(size: 11)).foregroundStyle(model.dataUseNotice == nil ? MuseTheme.secondary : MuseTheme.attention).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 6).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            .background(selected ? MuseTheme.accent.opacity(0.12) : (hovered ? MuseTheme.raised : .clear), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain).onHover { hovered = $0 }
        .help("\(model.providerName) · \(model.modelID)\nContext: \(model.raw["contextLimit"].int?.formatted() ?? "unspecified") tokens\nOutput: \(model.raw["outputLimit"].int?.formatted() ?? "unspecified") tokens")
        .accessibilityLabel("Choose \(model.displayName) via \(model.providerName)\(model.profileID.map { " profile " + $0 } ?? "")")
        .accessibilityValue(selected ? "Selected" : "")
    }
}
