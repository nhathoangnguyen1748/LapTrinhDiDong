import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

class CompressionService {
  /// Compress bytes using GZip
  static Uint8List gzipCompress(Uint8List data) {
    final compressed = GZipEncoder().encode(data);
    if (compressed == null) {
      throw Exception('GZip compression failed');
    }
    return Uint8List.fromList(compressed);
  }

  /// Decompress GZip bytes
  static Uint8List gzipDecompress(Uint8List compressedData) {
    final decompressed = GZipDecoder().decodeBytes(compressedData);
    return Uint8List.fromList(decompressed);
  }

  /// Calculate CRC32 checksum as uint32 integer
  static int computeCrc32(List<int> data) {
    return getCrc32(data);
  }

  /// Calculate MD5 hash string
  static String computeMd5(List<int> data) {
    return md5.convert(data).toString();
  }
}
