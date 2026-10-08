import SwiftUI

struct PendingRequestDock: View {
    @ObservedObject var store: WorkspaceStore
    @State private var selectedID: String?
    var body: some View {
        let requests = store.pendingRequests
        if let selected = requests.first(where: { $0.id == selectedID }) ?? requests.first {
            VStack(spacing: 8) {
                if requests.count > 1 {
                    HStack(spacing: 12) {
                        Text("Muse is waiting for you").foregroundStyle(MuseTheme.attention)
                        Spacer()
                        let index = requests.firstIndex { $0.id == selected.id } ?? 0
                        Button { selectedID = requests[max(0, index - 1)].id } label: { Image(systemName: "chevron.left") }.disabled(index == 0)
                        Text("\(index + 1) of \(requests.count)").monospacedDigit()
                        Button { selectedID = requests[min(requests.count - 1, index + 1)].id } label: { Image(systemName: "chevron.right") }.disabled(index == requests.count - 1)
                    }.font(.system(size: 11)).foregroundStyle(MuseTheme.secondary)
                }
                if selected.question { QuestionCard(request: selected.request, store: store).id(selected.id) }
                else { ApprovalCard(request: selected.request, store: store) }
            }.padding(.top, 8)
        }
    }
}
