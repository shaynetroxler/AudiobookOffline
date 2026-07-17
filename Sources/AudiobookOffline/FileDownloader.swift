import Foundation

/// Downloads a URL to a temp file with progress callbacks, using a delegate-based
/// URLSessionDownloadTask so large files (audiobooks are often 100-300MB) stream to
/// disk instead of buffering in memory.
final class ProgressDownloadDelegate: NSObject, URLSessionDownloadDelegate {
    private let onProgress: (Double) -> Void
    private let onFinish: (Result<URL, Error>) -> Void
    private let lock = NSLock()
    private var finished = false

    init(onProgress: @escaping (Double) -> Void, onFinish: @escaping (Result<URL, Error>) -> Void) {
        self.onProgress = onProgress
        self.onFinish = onFinish
    }

    private func finishOnce(_ result: Result<URL, Error>) {
        lock.lock()
        let alreadyFinished = finished
        finished = true
        lock.unlock()
        guard !alreadyFinished else { return }
        onFinish(result)
    }

    func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        onProgress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.moveItem(at: location, to: tmp)
            finishOnce(.success(tmp))
        } catch {
            finishOnce(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            finishOnce(.failure(error))
        }
    }
}

func downloadFile(from url: URL, onProgress: @escaping (Double) -> Void) async throws -> URL {
    try await withCheckedThrowingContinuation { continuation in
        var resumed = false
        let resumeLock = NSLock()
        func resumeOnce(_ result: Result<URL, Error>) {
            resumeLock.lock()
            let already = resumed
            resumed = true
            resumeLock.unlock()
            guard !already else { return }
            continuation.resume(with: result)
        }

        let delegate = ProgressDownloadDelegate(
            onProgress: onProgress,
            onFinish: { result in
                resumeOnce(result)
            }
        )
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let task = session.downloadTask(with: url)
        task.resume()
    }
}
