import AppKit
import SwiftUI
import UniformTypeIdentifiers

@main
struct WhisperGUIApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        print("WhisperGUI: App starting...")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var modelURL: URL? = nil
    @State private var inputURL: URL? = nil
    @State private var whisperPath: String = WhisperCLI.defaultWhisperPath
    @State private var statusText: String = ""
    @State private var transcriptText: String = ""
    @State private var isRunning: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Whisper Offline Transcriber")
                .font(.title2)

            HStack {
                Text("Whisper binary:")
                TextField("/opt/homebrew/bin/whisper", text: $whisperPath)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Text("Model file:")
                Text(modelURL?.path ?? "No model selected")
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Choose…") {
                    modelURL = openFilePanel(allowedTypes: ["bin"])
                }
            }

            HStack {
                Text("Input media:")
                Text(inputURL?.path ?? "No input selected")
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Choose…") {
                    inputURL = openFilePanel(allowedTypes: [
                        "mp4", "mov", "m4a", "wav", "mp3", "aac", "mkv",
                    ])
                }
            }

            HStack {
                Button(isRunning ? "Transcribing…" : "Transcribe") {
                    Task { await runTranscription() }
                }
                .disabled(isRunning || modelURL == nil || inputURL == nil || whisperPath.isEmpty)

                Button("Clear") {
                    transcriptText = ""
                    statusText = ""
                }
            }

            Text("Status")
                .font(.headline)
            Text(statusText)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Transcript")
                .font(.headline)
            TextEditor(text: $transcriptText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 280)
        }
        .padding(16)
        .frame(minWidth: 720, minHeight: 560)
    }

    private func runTranscription() async {
        guard let modelURL, let inputURL else { return }
        let modelPath = modelURL.path
        let inputPath = inputURL.path
        let whisperPathLocal = whisperPath

        await MainActor.run {
            isRunning = true
            statusText = "Preparing audio…"
            transcriptText = ""
        }

        let result = await Task.detached {
            let tempWav = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("whisper_input_\(UUID().uuidString).wav")
            do {
                let ffmpeg = WhisperCLI.resolveFFmpegPath()
                let ffmpegResult = try WhisperCLI.runProcess(
                    executable: ffmpeg,
                    args: [
                        "-y", "-i", inputPath, "-ar", "16000", "-ac", "1", "-c:a", "pcm_s16le",
                        tempWav.path,
                    ]
                )
                if ffmpegResult.exitCode != 0 {
                    return (status: "ffmpeg failed:\n\(ffmpegResult.stderr)", transcript: "")
                }

                let whisperResult = try WhisperCLI.runProcess(
                    executable: whisperPathLocal,
                    args: [
                        "-m", modelPath, "-f", tempWav.path, "-otxt", "-of",
                        tempWav.deletingPathExtension().path,
                    ]
                )
                if whisperResult.exitCode != 0 {
                    return (status: "whisper failed:\n\(whisperResult.stderr)", transcript: "")
                }

                let outputTxt = tempWav.deletingPathExtension().appendingPathExtension("txt")
                let transcript = (try? String(contentsOf: outputTxt)) ?? ""
                return (status: "Done. Output: \(outputTxt.path)", transcript: transcript)
            } catch {
                return (status: "Error: \(error.localizedDescription)", transcript: "")
            }
        }.value

        await MainActor.run {
            statusText = result.status
            if !result.transcript.isEmpty {
                transcriptText = result.transcript
            }
            isRunning = false
        }
    }

    private func openFilePanel(allowedTypes: [String]) -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = allowedTypes.compactMap { UTType(filenameExtension: $0) }
        let result = panel.runModal()
        return result == .OK ? panel.url : nil
    }
}

enum WhisperCLI {
    static let defaultWhisperPath: String = {
        let candidates = [
            "/opt/homebrew/bin/whisper",
            "/usr/local/bin/whisper",
            "/opt/homebrew/bin/whisper-cpp",
            "/usr/local/bin/whisper-cpp",
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return "/opt/homebrew/bin/whisper"
    }()

    static func resolveFFmpegPath() -> String {
        let candidates = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return "ffmpeg"
    }

    static func runProcess(executable: String, args: [String]) throws -> (
        exitCode: Int32, stdout: String, stderr: String
    ) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: outData, encoding: .utf8) ?? ""
        let stderr = String(data: errData, encoding: .utf8) ?? ""

        return (process.terminationStatus, stdout, stderr)
    }
}
