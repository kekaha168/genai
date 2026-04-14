import SwiftUI

struct ContentView: View {
    @State private var vm = InspectorViewModel()

    var body: some View {
        NavigationStack {
            switch vm.state {
            case .empty:
                EmptyStateView(vm: vm)
            case .loading(let msg):
                LoadingView(message: msg)
            case .loaded(let model):
                ModelDetailView(model: model, vm: vm)
            case .error(let msg):
                ErrorView(message: msg, vm: vm)
            }
        }
        .fileImporter(
            isPresented: $vm.showFilePicker,
            allowedContentTypes: [.init(filenameExtension: "mlmodel")!,
                                  .init(filenameExtension: "mlpackage")!,
                                  .init(filenameExtension: "mlmodelc")!],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    let secured = url.startAccessingSecurityScopedResource()
                    vm.loadModel(at: url)
                    if secured { url.stopAccessingSecurityScopedResource() }
                }
            case .failure:
                break
            }
        }
    }
}
