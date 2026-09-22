---
name: localquiz-ble
description: Comprehensive expert guidance, architectural rules, protocols, and verification workflows for developing, debugging, and maintaining the LocalQuiz BLE mobile offline examination app.
---

# LocalQuiz BLE - AI Agent Expert Skill

This skill guides AI agents on developing, maintaining, and extending the **LocalQuiz BLE** Flutter project. Use this skill whenever interacting with BLE services, chunking/reassembly protocols, RSSI geofencing, Kiosk anti-cheat features, or Flutter Riverpod state providers.

---

## 1. Quick Architecture Reference

- **Central Service (`lib/services/ble_central_service.dart`):** Scans for `SERVICE_UUID`, requests MTU 512, receives chunks via `CHAR_EXAM_DATA` notification, streams RSSI via periodic `readRssi()`, and submits results via `CHAR_SUBMIT_RESULT`.
- **Peripheral Service (`lib/services/ble_peripheral_service.dart`):** Advertises GATT server, broadcasts exam chunks, listens for incoming submissions.
- **Mock Simulator (`lib/services/mock_ble_service.dart`):** Hardware-free emulator for desktop, single devices, or CI. Emits chunks and simulated RSSI stream.
- **Packet Chunking (`lib/core/security/chunk_protocol.dart`):** GZip $\rightarrow$ AES-256 $\rightarrow$ CRC32 $\rightarrow$ 8-byte Header `[chunkIndex(2B), totalChunks(2B), totalCrc32(4B), payload]`.
- **Geofencing (`lib/providers/proximity_geofence_provider.dart`):** Optimal $\ge -75\text{ dBm}$, Warning $-85\text{ dBm} \le \text{RSSI} < -75\text{ dBm}$, Critical $< -85\text{ dBm}$ (freezes timer).
- **Kiosk Manager (`lib/core/security/kiosk_manager.dart`):** `FLAG_SECURE` + `WidgetsBindingObserver` (auto-submit after 3 violations).

---

## 2. Workflows & Runbooks

### Workflow A: Adding or Editing Exam Questions
1. Open `lib/models/exam_model.dart`.
2. Locate `ExamModel.sampleExam()` or the JSON schema.
3. Every question must adhere to `QuestionModel`:
   ```dart
   QuestionModel(
     id: <int>,
     content: '<String>',
     options: [
       OptionModel(id: 'A', text: '...'),
       OptionModel(id: 'B', text: '...'),
       OptionModel(id: 'C', text: '...'),
       OptionModel(id: 'D', text: '...'),
     ],
     correctOptionId: '<A|B|C|D>',
   )
   ```
4. Verify by running `flutter test` to ensure serialization and chunking roundtrip passes.

### Workflow B: Debugging Chunk Reassembly or Integrity Errors
If `IntegrityException` occurs:
1. Verify AES key and IV match between sender and receiver (`BleConstants.defaultExamSecretKey`, `BleConstants.defaultExamIv`).
2. Verify that `totalCrc32` is computed on the **complete unfragmented ciphertext** before splitting into chunks.
3. In `ReassemblyBuffer`, ensure all chunks from `0` to `totalChunks - 1` are received without missing indices.
4. Check that chunk payload size does not exceed negotiated MTU minus 3 bytes ATT header.

### Workflow C: Modifying Geofencing Thresholds
1. All RSSI thresholds are located in `lib/core/constants/ble_constants.dart`:
   - `rssiOptimalThreshold = -75`
   - `rssiWarningThreshold = -85`
   - `maxDisconnectSeconds = 10`
2. Update unit tests in `test/chunk_protocol_test.dart` if thresholds change.

### Workflow D: Code Quality & Verification
Always execute:
```bash
cd apptracngiem
flutter analyze
flutter test
```
Both commands must exit with code 0 before completing any user task.
