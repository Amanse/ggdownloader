import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    private let appGroupID = "group.sanuki.ggdownloader"
    private let pendingKey = "pendingDownloadURLs"

    private var detectedURLString: String?
    private var cardView: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)

        let tap = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        view.addGestureRecognizer(tap)

        extractURL { [weak self] urlString in
            DispatchQueue.main.async {
                self?.detectedURLString = urlString
                self?.setupCard(urlString: urlString)
            }
        }
    }

    // MARK: - URL Extraction

    private func extractURL(completion: @escaping (String?) -> Void) {
        guard
            let item = extensionContext?.inputItems.first as? NSExtensionItem,
            let providers = item.attachments
        else {
            completion(nil)
            return
        }

        let urlType = UTType.url.identifier
        let textType = UTType.plainText.identifier

        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(urlType) }) {
            provider.loadItem(forTypeIdentifier: urlType, options: nil) { value, _ in
                if let url = value as? URL {
                    completion(url.absoluteString)
                } else if let str = value as? String {
                    completion(str)
                } else {
                    completion(nil)
                }
            }
        } else if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(textType) }) {
            provider.loadItem(forTypeIdentifier: textType, options: nil) { value, _ in
                completion(value as? String)
            }
        } else {
            completion(nil)
        }
    }

    // MARK: - UI

    private func setupCard(urlString: String?) {
        let card = UIView()
        card.backgroundColor = UIColor.secondarySystemGroupedBackground
        card.layer.cornerRadius = 16
        card.layer.masksToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        cardView = card

        let titleLabel = UILabel()
        titleLabel.text = "Add to GGDownloader"
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let urlLabel = UILabel()
        urlLabel.text = urlString ?? "No URL detected"
        urlLabel.font = .systemFont(ofSize: 13)
        urlLabel.textColor = .secondaryLabel
        urlLabel.numberOfLines = 3
        urlLabel.textAlignment = .center
        urlLabel.translatesAutoresizingMaskIntoConstraints = false

        let separator1 = makeSeparator()
        let separator2 = makeSeparator()

        let downloadButton = UIButton(type: .system)
        downloadButton.setTitle("Download", for: .normal)
        downloadButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        downloadButton.isEnabled = urlString != nil
        downloadButton.addTarget(self, action: #selector(downloadTapped), for: .touchUpInside)
        downloadButton.translatesAutoresizingMaskIntoConstraints = false

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 17)
        cancelButton.tintColor = .secondaryLabel
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        [titleLabel, urlLabel, separator1, downloadButton, separator2, cancelButton].forEach {
            card.addSubview($0)
        }
        view.addSubview(card)

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            card.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.85),

            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            urlLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            urlLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            urlLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            separator1.topAnchor.constraint(equalTo: urlLabel.bottomAnchor, constant: 20),
            separator1.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            separator1.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            separator1.heightAnchor.constraint(equalToConstant: 0.5),

            downloadButton.topAnchor.constraint(equalTo: separator1.bottomAnchor),
            downloadButton.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            downloadButton.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            downloadButton.heightAnchor.constraint(equalToConstant: 44),

            separator2.topAnchor.constraint(equalTo: downloadButton.bottomAnchor),
            separator2.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            separator2.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            separator2.heightAnchor.constraint(equalToConstant: 0.5),

            cancelButton.topAnchor.constraint(equalTo: separator2.bottomAnchor),
            cancelButton.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            cancelButton.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            cancelButton.heightAnchor.constraint(equalToConstant: 44),
            cancelButton.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])
    }

    private func makeSeparator() -> UIView {
        let v = UIView()
        v.backgroundColor = .separator
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    // MARK: - Actions

    @objc private func backgroundTapped() {
        finish(cancelled: true)
    }

    @objc private func downloadTapped() {
        guard
            let raw = detectedURLString?.trimmingCharacters(in: .whitespacesAndNewlines),
            let url = URL(string: raw),
            let scheme = url.scheme,
            scheme.hasPrefix("http")
        else {
            finish(cancelled: true)
            return
        }

        let defaults = UserDefaults(suiteName: appGroupID)
        var pending = defaults?.stringArray(forKey: pendingKey) ?? []
        pending.append(raw)
        defaults?.set(pending, forKey: pendingKey)
        defaults?.synchronize()

        finish(cancelled: false)
    }

    @objc private func cancelTapped() {
        finish(cancelled: true)
    }

    private func finish(cancelled: Bool) {
        if cancelled {
            extensionContext?.cancelRequest(
                withError: NSError(domain: "ggdownloader.share", code: 0)
            )
        } else {
            extensionContext?.completeRequest(returningItems: nil)
        }
    }
}
