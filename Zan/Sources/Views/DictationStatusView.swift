import SwiftUI
import KeyboardShortcuts

/// Always-visible dictation status: recording indicator, mic-permission prompt,
/// a hint if no trigger is set, and the last saved recording (with Reveal).
struct DictationStatusView: View {
    @EnvironmentObject var dictation: DictationController

    private var hasTrigger: Bool {
        KeyboardShortcuts.getShortcut(for: .dictationTrigger) != nil
    }
    private var micBlocked: Bool {
        dictation.micPermission == .denied || dictation.micPermission == .restricted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(dictation.isRecording ? Color.red : Color.secondary)
                    .frame(width: 8, height: 8)
                Text(dictation.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if dictation.isRecording {
                    Button(action: { dictation.stop() }) {
                        Label("Stop", systemImage: "stop.fill")
                            .font(.caption2.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.small)
                } else if !hasTrigger {
                    Text("Set a trigger key ↓")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            if micBlocked {
                permissionWarning
            }

            if dictation.needsAccessibility {
                accessibilityWarning
            }

            if dictation.isTranscribing {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Transcribing…").font(.caption2).foregroundStyle(.secondary)
                }
            }

            if let error = dictation.lastError {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
                    Text(error).font(.caption2).foregroundStyle(.secondary)
                }
            }

            if !dictation.transcript.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        Text("Transcript").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Button("Insert") { dictation.insertAtCursor(dictation.transcript) }
                            .font(.caption2)
                            .buttonStyle(.link)
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(dictation.transcript, forType: .string)
                        }
                        .font(.caption2)
                        .buttonStyle(.link)
                    }
                    ScrollView {
                        Text(dictation.transcript)
                            .font(.caption)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 90)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(.textBackgroundColor)))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(.separatorColor)))
                }
            }

            if let url = dictation.lastRecordingURL, !dictation.isRecording {
                HStack(spacing: 6) {
                    Image(systemName: "waveform.circle").foregroundStyle(.tint)
                    Text(url.lastPathComponent)
                        .font(.caption2.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let bytes = dictation.lastRecordingBytes {
                        Text("(\(byteString(bytes)))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Reveal") {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                    .font(.caption2)
                    .buttonStyle(.link)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(.windowBackgroundColor).opacity(0.4))
    }

    private var permissionWarning: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text("Microphone access is off.")
                .font(.caption2)
            Button("Open Settings") { dictation.openMicrophoneSettings() }
                .font(.caption2)
                .buttonStyle(.link)
        }
    }

    private var accessibilityWarning: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text("Allow Accessibility to paste at the cursor.")
                .font(.caption2)
            Button("Enable") { dictation.requestAccessibility() }
                .font(.caption2)
                .buttonStyle(.link)
        }
    }

    private func byteString(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
