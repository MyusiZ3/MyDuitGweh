import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

class ReceiptData {
  final double? amount;
  final String? merchant;
  final DateTime? date;
  final String? category;

  ReceiptData({this.amount, this.merchant, this.date, this.category});
}

class ReceiptOCRService {
  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);
  final ImagePicker _picker = ImagePicker();

  Future<ReceiptData?> scanReceipt(
      {ImageSource source = ImageSource.camera}) async {
    debugPrint('OCR: Checking permissions...');

    if (source == ImageSource.camera) {
      // Check Camera Permission
      var cameraStatus = await Permission.camera.status;
      if (!cameraStatus.isGranted) {
        debugPrint('OCR: Camera not granted, requesting...');
        cameraStatus = await Permission.camera.request();
      }
      if (!cameraStatus.isGranted) {
        throw Exception('Izin kamera ditolak. Aktifkan di pengaturan ya!');
      }
    }

    // Check Storage/Photos (Some devices need this for temporary files from camera or for gallery)
    var storageStatus = await Permission.photos.status;
    if (!storageStatus.isGranted) {
      storageStatus = await Permission.storage.status;
    }

    if (!storageStatus.isGranted) {
      debugPrint('OCR: Storage not granted, requesting...');
      await Permission.photos.request();
      await Permission.storage.request();
    }

    debugPrint('OCR: Picking image from $source...');
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (image == null) {
        debugPrint('OCR: User cancelled picking.');
        return null;
      }
      debugPrint('OCR: Image picked: ${image.path}');

      return await scanReceiptFromFile(image);
    } catch (e) {
      debugPrint('OCR: Error during pickImage: $e');
      rethrow;
    }
  }

  Future<ReceiptData?> scanReceiptFromFile(XFile image) async {
    try {
      debugPrint('OCR: Processing image from file: ${image.path}');
      final inputImage = InputImage.fromFilePath(image.path);

      debugPrint('OCR: Initializing text recognizer...');
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);
      debugPrint('OCR: Recognition finished.');

      final result = _parseReceipt(recognizedText);
      return result;
    } catch (e) {
      debugPrint('OCR: Error during file process: $e');
      rethrow;
    }
  }

  ReceiptData _parseReceipt(RecognizedText recognizedText) {
    String text = recognizedText.text;
    final Map<String, String> categoryMap = {
      'ALFAMART': 'Belanja',
      'INDOMARET': 'Belanja',
      'SUPERINDO': 'Belanja',
      'HYPERMART': 'Belanja',
      'TRANSMART': 'Belanja',
      'GRAB': 'Transportasi',
      'GOJEK': 'Transportasi',
      'PERTAMINA': 'Transportasi',
      'SHELL': 'Transportasi',
      'STARBUCKS': 'Makanan',
      'MCDONALDS': 'Makanan',
      'KFC': 'Makanan',
      'WAROENG': 'Makanan',
      'ALFA': 'Belanja',
      'INDO': 'Belanja',
      'LAWSON': 'Makanan',
      'FAMILY MART': 'Makanan',
    };

    double? amount;
    String? merchant;
    DateTime? date;
    String? category;

    // --- 1. Merchant Detection ---
    for (var m in categoryMap.keys) {
      if (text.toUpperCase().contains(m)) {
        merchant = m;
        category = categoryMap[m];
        break;
      }
    }

    // --- 2. Advanced Spatial Amount Detection ---
    debugPrint('OCR: Starting Spatial Analysis for Amount...');

    // Priority Map: Higher value = Higher confidence
    final Map<String, int> keywordPriority = {
      'TOTAL': 10,
      'GRAND TOTAL': 12,
      'TOTAL BAYAR': 11,
      'JUMLAH': 8,
      'AMOUNT': 7,
      'NET': 5,
      'BILL': 5,
      'TAGIHAN': 8,
      'SUBTOTAL': 3, // Lower priority
    };

    final List<String> skipKeywords = [
      'KEMBALI',
      'CHANGE',
      'TUNAI',
      'CASH',
      'POIN',
      'POINT',
      'ITEMS',
      'PCS',
      'DISKON',
      'DISCOUNT',
      'TAX',
      'PAJAK',
      'PPN'
    ];

    List<({double amount, int priority, double y})> candidates = [];

    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        String lineText = line.text.toUpperCase();

        // Find if this line contains any of our priority keywords
        int currentPriority = 0;
        String? matchedKeyword;

        for (var entry in keywordPriority.entries) {
          if (lineText.contains(entry.key)) {
            if (entry.value > currentPriority) {
              currentPriority = entry.value;
              matchedKeyword = entry.key;
            }
          }
        }

        if (matchedKeyword != null) {
          // Check for negative/skip keywords in the same line
          bool shouldSkipLine = false;
          for (var skip in skipKeywords) {
            if (lineText.contains(skip)) {
              shouldSkipLine = true;
              break;
            }
          }
          if (shouldSkipLine) continue;

          debugPrint(
              'OCR: Found Keyword "$matchedKeyword" on line: "${line.text}"');

          // Search for numbers in THIS block or OTHER blocks on the same Y level
          // Total is usually to the right of the keyword or below it
          for (TextBlock b2 in recognizedText.blocks) {
            for (TextLine l2 in b2.lines) {
              double yDiff =
                  (l2.boundingBox.center.dy - line.boundingBox.center.dy).abs();

              // Only consider lines that are horizontally aligned (yDiff < 30)
              // AND either the same line or to the right (x > keyword_line_center_x - buffer)
              if (yDiff < 30) {
                final matches = RegExp(r'([\d\.,]{4,})').allMatches(l2.text);
                for (var m in matches) {
                  String val = m.group(0)!;

                  // Smart strip: if it ends with .00 or ,00, it's likely decimal
                  double? parsedAmount;
                  if (RegExp(r'[.,]\d{2}$').hasMatch(val)) {
                    // It's a decimal, strip the last 3 chars and separators
                    String mainPart = val
                        .substring(0, val.length - 3)
                        .replaceAll(RegExp(r'[^0-9]'), '');
                    if (mainPart.isNotEmpty)
                      parsedAmount = double.tryParse(mainPart);
                  } else {
                    // Regular number, just strip all non-digits
                    String clean = val.replaceAll(RegExp(r'[^0-9]'), '');
                    if (clean.isNotEmpty) parsedAmount = double.tryParse(clean);
                  }

                  if (parsedAmount != null) {
                    // Receipt amount sanity check: between 1k and 10m, not a date (e.g., 20241010)
                    if (parsedAmount >= 1000 &&
                        parsedAmount < 10000000 &&
                        val.length <= 11) {
                      // Reject if it looks like a year (e.g., 2024, 2025)
                      if (parsedAmount == 2024 || parsedAmount == 2025)
                        continue;

                      candidates.add((
                        amount: parsedAmount,
                        priority: currentPriority,
                        y: l2.boundingBox.center.dy
                      ));
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    // Sort candidates by priority desc, then Y position desc (lower on receipt = more likely total)
    if (candidates.isNotEmpty) {
      candidates.sort((a, b) {
        if (a.priority != b.priority) return b.priority.compareTo(a.priority);
        return b.y.compareTo(a.y);
      });

      amount = candidates.first.amount;
      debugPrint(
          'OCR: Best candidate chosen: $amount (Priority: ${candidates.first.priority})');
    }

    // Fallback: If no keyword-based match, look for any large number in the bottom half
    if (amount == null) {
      debugPrint('OCR: Fallback to largest number in bottom region...');
      double maxY = 0;
      for (TextBlock block in recognizedText.blocks) {
        if (block.boundingBox.center.dy > maxY)
          maxY = block.boundingBox.center.dy;
      }

      List<({double amount, double y})> fallbackCandidates = [];
      for (TextBlock block in recognizedText.blocks) {
        if (block.boundingBox.center.dy > maxY * 0.5) {
          // Bottom 50%
          final matches = RegExp(r'([\d\.,]{4,})').allMatches(block.text);
          for (var m in matches) {
            String val = m.group(0)!;
            double? d;
            if (RegExp(r'[.,]\d{2}$').hasMatch(val)) {
              String mainPart = val
                  .substring(0, val.length - 3)
                  .replaceAll(RegExp(r'[^0-9]'), '');
              if (mainPart.isNotEmpty) d = double.tryParse(mainPart);
            } else {
              String clean = val.replaceAll(RegExp(r'[^0-9]'), '');
              if (clean.isNotEmpty) d = double.tryParse(clean);
            }

            if (d != null && d >= 1000 && d < 5000000) {
              if (d == 2024 || d == 2025) continue;
              fallbackCandidates
                  .add((amount: d, y: block.boundingBox.center.dy));
            }
          }
        }
      }

      if (fallbackCandidates.isNotEmpty) {
        // Sort by largest amount, then by Y desc
        fallbackCandidates.sort((a, b) => b.amount.compareTo(a.amount));
        amount = fallbackCandidates.first.amount;
        debugPrint('OCR: Fallback match: $amount');
      }
    }

    // --- 3. Date Detection ---
    final dateRegExp = RegExp(r'(\d{1,2})[\/-](\d{1,2})[\/-](\d{2,4})');
    final dateMatch = dateRegExp.firstMatch(text);
    if (dateMatch != null) {
      int day = int.parse(dateMatch.group(1)!);
      int month = int.parse(dateMatch.group(2)!);
      int yearRaw = int.parse(dateMatch.group(3)!);
      int year = yearRaw < 100 ? 2000 + yearRaw : yearRaw;
      try {
        date = DateTime(year, month, day);
      } catch (_) {}
    }

    return ReceiptData(
      amount: amount,
      merchant: merchant,
      date: date,
      category: category,
    );
  }

  void dispose() {
    _textRecognizer.close();
  }
}
