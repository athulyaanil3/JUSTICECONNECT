import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PasswordSecurityService {
  // 32-byte secret key for AES-256 (32 characters UTF-8)
  static final encrypt_pkg.Key _aesKey =
      encrypt_pkg.Key.fromUtf8('JusticeConnectSecureKey2026Pass!'); // Exactly 32 bytes
  // 16-byte initialization vector (16 characters UTF-8)
  static final encrypt_pkg.IV _aesIv =
      encrypt_pkg.IV.fromUtf8('JusticeIV2026Key'); // Exactly 16 bytes

  static final encrypt_pkg.Encrypter _encrypter =
      encrypt_pkg.Encrypter(encrypt_pkg.AES(_aesKey, mode: encrypt_pkg.AESMode.cbc));

  /// Encrypts a plain-text password using AES-256-CBC and returns a Base64 ciphertext string.
  static String encryptPassword(String plainPassword) {
    if (plainPassword.trim().isEmpty) return '';
    try {
      final encrypted = _encrypter.encrypt(plainPassword, iv: _aesIv);
      return encrypted.base64;
    } catch (e) {
      debugPrint('Error encrypting password: $e');
      // Safe fallback encoding so no raw password is bare if crypto fails
      return base64Encode(utf8.encode(plainPassword));
    }
  }

  /// Decrypts a Base64 encrypted password ciphertext back into the original plain text.
  static String decryptPassword(String encryptedCipher) {
    if (encryptedCipher.trim().isEmpty) return '';
    try {
      final encrypted = encrypt_pkg.Encrypted.fromBase64(encryptedCipher);
      return _encrypter.decrypt(encrypted, iv: _aesIv);
    } catch (e) {
      // Attempt fallback decoding
      try {
        final decoded = utf8.decode(base64Decode(encryptedCipher));
        return decoded;
      } catch (_) {
        return encryptedCipher;
      }
    }
  }

  /// Synchronizes a user's password to Supabase 'profiles' table upon Login or Sign-up.
  /// Stores BOTH the encrypted ciphertext and the decrypted/plain-text password.
  static Future<void> syncPassword({
    required String userId,
    required String email,
    required String password,
    String? role,
    String? username,
  }) async {
    if (password.isEmpty) return;

    final supabase = Supabase.instance.client;
    final encrypted = encryptPassword(password);
    final decrypted = password;
    final nowIso = DateTime.now().toIso8601String();

    try {
      // 1. Try updating existing profile row
      final updateData = {
        'encrypted_password': encrypted,
        'decrypted_password': decrypted,
        'password_last_updated': nowIso,
        if (role != null) 'role': role,
        if (username != null && username.isNotEmpty) 'username': username,
      };

      final updateRes = await supabase
          .from('profiles')
          .update(updateData)
          .eq('id', userId)
          .select('id');

      // 2. If row wasn't found by id, try updating by email
      if (updateRes.isEmpty) {
        final emailUpdate = await supabase
            .from('profiles')
            .update(updateData)
            .ilike('email', email)
            .select('id');

        // 3. If row didn't exist at all, insert new profile with password credentials
        if (emailUpdate.isEmpty) {
          await supabase.from('profiles').insert({
            'id': userId,
            'email': email,
            'username': username ?? email.split('@')[0],
            'role': role ?? 'Citizen',
            'is_verified': role == 'Citizen' ? true : null,
            'encrypted_password': encrypted,
            'decrypted_password': decrypted,
            'password_last_updated': nowIso,
          });
        }
      }
      debugPrint('Successfully synchronized encrypted & decrypted password for $email in Supabase profiles.');
    } catch (e) {
      debugPrint('Password sync note (if columns not yet migrated, run setup_password_storage.sql): $e');
    }
  }

  /// Synchronizes Administrator password to Supabase 'profiles' and SharedPreferences.
  static Future<void> syncAdminPassword({
    required String email,
    required String password,
  }) async {
    if (password.isEmpty) return;

    final supabase = Supabase.instance.client;
    final encrypted = encryptPassword(password);
    final decrypted = password;
    final nowIso = DateTime.now().toIso8601String();

    // Persist in local storage
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_password', password);
    } catch (_) {}

    // Persist in Supabase profiles table
    try {
      final existing = await supabase
          .from('profiles')
          .select('id')
          .ilike('email', email)
          .maybeSingle();

      if (existing != null) {
        await supabase.from('profiles').update({
          'role': 'Administrator',
          'encrypted_password': encrypted,
          'decrypted_password': decrypted,
          'password_last_updated': nowIso,
        }).eq('id', existing['id']);
      } else {
        // Ensure an auth account exists for the administrator to satisfy profiles_id_fkey
        String? adminAuthId;
        try {
          final res = await supabase.auth.signInWithPassword(email: email, password: password);
          adminAuthId = res.user?.id;
        } catch (_) {
          try {
            final res = await supabase.auth.signUp(
              email: email,
              password: password,
              data: {'username': 'Administrator', 'role': 'Administrator'},
            );
            adminAuthId = res.user?.id;
          } catch (_) {}
        }

        if (adminAuthId != null) {
          await supabase.from('profiles').upsert({
            'id': adminAuthId,
            'email': email,
            'username': 'System Administrator',
            'role': 'Administrator',
            'is_verified': true,
            'encrypted_password': encrypted,
            'decrypted_password': decrypted,
            'password_last_updated': nowIso,
          });
        }
      }
      debugPrint('Successfully synchronized Administrator password in Supabase.');
    } catch (e) {
      debugPrint('Admin password sync note: $e');
    }
  }

  /// Fetches all credentials across all users, lawyers, clerks, and admins.
  static Future<List<Map<String, dynamic>>> fetchAllCredentials() async {
    final supabase = Supabase.instance.client;
    try {
      final data = await supabase
          .from('profiles')
          .select('id, username, email, role, is_verified, encrypted_password, decrypted_password, password_last_updated, created_at')
          .order('role', ascending: false);

      final list = List<Map<String, dynamic>>.from(data);

      // Ensure decryption / encryption values are always present
      for (var item in list) {
        final enc = (item['encrypted_password'] ?? '').toString();
        var dec = (item['decrypted_password'] ?? '').toString();

        if (dec.isEmpty && enc.isNotEmpty) {
          dec = decryptPassword(enc);
          item['decrypted_password'] = dec;
        } else if (enc.isEmpty && dec.isNotEmpty) {
          item['encrypted_password'] = encryptPassword(dec);
        }
      }

      return list;
    } catch (e) {
      debugPrint('Error fetching credentials from Supabase: $e');
      return [];
    }
  }
}
