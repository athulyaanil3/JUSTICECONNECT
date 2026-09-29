import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:archive/archive.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';

class EvidenceEncryptionResult {
  final File encryptedFile;
  final String keyBase64;
  final String nonceBase64;
  final String algorithm;
  final String version;

  EvidenceEncryptionResult({
    required this.encryptedFile,
    required this.keyBase64,
    required this.nonceBase64,
    required this.algorithm,
    required this.version,
  });
}

class EvidenceEncryptionService {
  final _uuid = const Uuid();
  final String _algorithmName = 'AES-256-GCM';
  final String _version = '1.0';

  /// Packages multiple files into a single ZIP and encrypts it using AES-256-GCM.
  Future<EvidenceEncryptionResult> encryptEvidencePackage(List<File> evidenceFiles) async {
    // 1. Create a ZIP package in memory
    final archive = Archive();
    for (var file in evidenceFiles) {
      final fileName = file.path.split(Platform.pathSeparator).last;
      final fileBytes = await file.readAsBytes();
      final archiveFile = ArchiveFile(fileName, fileBytes.length, fileBytes);
      archive.addFile(archiveFile);
    }
    
    final zipEncoder = ZipEncoder();
    // Use level 0 (No Compression) to dramatically speed up video/large file zipping
    final zipData = zipEncoder.encode(archive, level: 0);
    
    if (zipData == null) {
      throw Exception('Failed to create evidence package (ZIP).');
    }

    // 2. Prepare Cryptography
    final algorithm = AesGcm.with256bits();
    final secretKey = await algorithm.newSecretKey();
    final nonce = algorithm.newNonce(); // 12 bytes standard for GCM

    // 3. Encrypt the ZIP data
    final secretBox = await algorithm.encrypt(
      zipData,
      secretKey: secretKey,
      nonce: nonce,
    );

    // 4. Save to temporary encrypted file
    final tempDir = await getTemporaryDirectory();
    final tempFilePath = '${tempDir.path}/${_uuid.v4()}.enc';
    final encryptedFile = File(tempFilePath);
    
    // The SecretBox concatenates cipherText + mac
    await encryptedFile.writeAsBytes(secretBox.concatenation(), flush: true);

    // 5. Extract keys safely (only meant to be sent securely to Edge Function)
    final keyBytes = await secretKey.extractBytes();
    final keyBase64 = _bytesToBase64(keyBytes);
    final nonceBase64 = _bytesToBase64(nonce);

    return EvidenceEncryptionResult(
      encryptedFile: encryptedFile,
      keyBase64: keyBase64,
      nonceBase64: nonceBase64,
      algorithm: _algorithmName,
      version: _version,
    );
  }

  /// Decrypts an evidence package and extracts files to a secure temporary directory.
  Future<List<File>> decryptEvidencePackage(
    File encryptedFile, 
    String keyBase64, 
    String nonceBase64
  ) async {
    final encryptedBytes = await encryptedFile.readAsBytes();

    final algorithm = AesGcm.with256bits();
    final secretKey = SecretKey(_base64ToBytes(keyBase64));

    // SecretBox concatenation is [nonce] + [cipherText] + [mac]
    final secretBox = SecretBox.fromConcatenation(
      encryptedBytes, 
      nonceLength: 12, 
      macLength: 16,
    );

    try {
      final decryptedData = await algorithm.decrypt(
        secretBox,
        secretKey: secretKey,
      );

      // Extract ZIP
      final archive = ZipDecoder().decodeBytes(decryptedData);
      
      final tempDir = await getTemporaryDirectory();
      final secureExtractionPath = '${tempDir.path}/decrypted_${_uuid.v4()}';
      final extractionDir = Directory(secureExtractionPath);
      await extractionDir.create(recursive: true);

      List<File> extractedFiles = [];

      for (var file in archive) {
        if (file.isFile) {
          final extractedFile = File('${extractionDir.path}/${file.name}');
          final fileData = file.content as List<int>;
          await extractedFile.writeAsBytes(fileData, flush: true);
          extractedFiles.add(extractedFile);
        }
      }

      return extractedFiles;
    } on SecretBoxAuthenticationError {
      throw Exception('Decryption failed. The evidence package may be tampered with or the key is invalid.');
    }
  }

  /// Securely deletes decrypted files after they are viewed
  Future<void> cleanupDecryptedFiles(List<File> files) async {
    for (var file in files) {
      if (await file.exists()) {
        try {
          // Optional: Overwrite with 0s before deletion for maximum security, but simple delete is fine for mini-project
          await file.delete();
        } catch (e) {
          // Ignore delete failures safely
        }
      }
    }
  }

  String _bytesToBase64(List<int> bytes) {
    return base64Encode(bytes);
  }

  List<int> _base64ToBytes(String b64) {
    return base64Decode(b64);
  }
}
