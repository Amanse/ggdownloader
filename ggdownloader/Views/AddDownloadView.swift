import SwiftUI

struct AddDownloadView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var urlString = ""
    @State private var fileName = ""
    @State private var showURLError = false

    private var parsedURL: URL? {
        guard
            let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
            let scheme = url.scheme,
            scheme.hasPrefix("http")
        else { return nil }
        return url
    }

    private var isValid: Bool { parsedURL != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://example.com/file.zip", text: $urlString, axis: .vertical)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .lineLimit(3)
                        .onChange(of: urlString) { _, newValue in
                            showURLError = false
                            if fileName.isEmpty, let url = URL(string: newValue) {
                                let name = url.lastPathComponent
                                if !name.isEmpty { fileName = name }
                            }
                        }
                } header: {
                    Text("URL")
                } footer: {
                    if showURLError {
                        Text("Enter a valid http or https URL")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    TextField("Auto-detected from URL", text: $fileName)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("File Name (Optional)")
                } footer: {
                    Text("Leave blank to use the name from the URL")
                }

                Section {
                    Button(action: pasteFromClipboard) {
                        Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                    }
                }
            }
            .navigationTitle("Add Download")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Download") {
                        guard let url = parsedURL else {
                            showURLError = true
                            return
                        }
                        DownloadManager.shared.startDownload(
                            url: url,
                            fileName: fileName.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
        }
    }

    private func pasteFromClipboard() {
        guard let string = UIPasteboard.general.string else { return }
        urlString = string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    AddDownloadView()
}
