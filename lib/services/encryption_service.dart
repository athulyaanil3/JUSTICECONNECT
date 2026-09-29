import 'package:encrypt/encrypt.dart' as encrypt;

class EncryptionService {
  // Use a secure 32-byte key for AES-256. 
  // In a production environment, NEVER hardcode this. It should be securely stored (e.g., flutter_secure_storage or fetched via secure API).
  static final _key = encrypt.Key.fromUtf8('my32lengthsupersecretnooneknows1'); 

  // Use a 16-byte initialization vector.
  static final _iv = encrypt.IV.fromUtf8('my16lengthsecret'); 

  static final _encrypter = encrypt.Encrypter(encrypt.AES(_key, mode: encrypt.AESMode.cbc));

  /// Encrypts plain text and returns a base64 encoded string.
  static String encryptText(String plainText) {
    if (plainText.isEmpty) return plainText;
    
    try {
      final encrypted = _encrypter.encrypt(plainText, iv: _iv);
      return encrypted.base64;
    } catch (e) {
      print("Encryption error: $e");
      return plainText; // Fallback or handle error appropriately
    }
  }

  /// Decrypts a base64 encoded string back to plain text.
  static String decryptText(String encryptedText) {
    if (encryptedText.isEmpty) return encryptedText;

    try {
      final decrypted = _encrypter.decrypt64(encryptedText, iv: _iv);
      return decrypted;
    } catch (e) {
      // If it fails to decrypt (e.g., if we are reading older unencrypted messages), 
      // just return the original text so we don't break the UI.
      print("Decryption error (might be unencrypted old message): $e");
      return encryptedText; 
    }
  }
}
