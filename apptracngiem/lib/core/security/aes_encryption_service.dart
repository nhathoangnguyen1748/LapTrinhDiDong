import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import '../constants/ble_constants.dart';

class AesEncryptionService {
  /// Encrypt raw bytes with AES-256-CBC
  static Uint8List encryptBytes(
    Uint8List plainBytes, {
    String keyString = BleConstants.defaultExamSecretKey,
    String ivString = BleConstants.defaultExamIv,
  }) {
    final keyBytes = utf8.encode(keyString.padRight(32, '0').substring(0, 32));
    final ivBytes = utf8.encode(ivString.padRight(16, '0').substring(0, 16));

    final key = enc.Key(Uint8List.fromList(keyBytes));
    final iv = enc.IV(Uint8List.fromList(ivBytes));
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    final encrypted = encrypter.encryptBytes(plainBytes, iv: iv);
    return encrypted.bytes;
  }

  /// Decrypt cipher bytes with AES-256-CBC
  static Uint8List decryptBytes(
    Uint8List cipherBytes, {
    String keyString = BleConstants.defaultExamSecretKey,
    String ivString = BleConstants.defaultExamIv,
  }) {
    final keyBytes = utf8.encode(keyString.padRight(32, '0').substring(0, 32));
    final ivBytes = utf8.encode(ivString.padRight(16, '0').substring(0, 16));

    final key = enc.Key(Uint8List.fromList(keyBytes));
    final iv = enc.IV(Uint8List.fromList(ivBytes));
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    final decrypted = encrypter.decryptBytes(enc.Encrypted(cipherBytes), iv: iv);
    return Uint8List.fromList(decrypted);
  }

  /// Encrypt string to Base64
  static String encryptString(
    String plainText, {
    String keyString = BleConstants.defaultExamSecretKey,
    String ivString = BleConstants.defaultExamIv,
  }) {
    final plainBytes = Uint8List.fromList(utf8.encode(plainText));
    final cipher = encryptBytes(plainBytes, keyString: keyString, ivString: ivString);
    return base64Encode(cipher);
  }

  /// Decrypt Base64 string to plain string
  static String decryptString(
    String base64CipherText, {
    String keyString = BleConstants.defaultExamSecretKey,
    String ivString = BleConstants.defaultExamIv,
  }) {
    final cipherBytes = base64Decode(base64CipherText);
    final decryptedBytes = decryptBytes(cipherBytes, keyString: keyString, ivString: ivString);
    return utf8.decode(decryptedBytes);
  }
}
