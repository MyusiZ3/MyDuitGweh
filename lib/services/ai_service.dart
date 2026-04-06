import 'dart:convert';
import '../models/feedback_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../utils/tone_dictionary.dart';
import 'package:intl/intl.dart';

class ReceiptData {
  final double? amount;
  final String? merchant;
  final DateTime? date;
  final String? category;

  ReceiptData({this.amount, this.merchant, this.date, this.category});

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'merchant': merchant,
        'date': date?.toIso8601String(),
        'category': category,
      };

  factory ReceiptData.fromJson(Map<String, dynamic> json) {
    return ReceiptData(
      amount: json['amount']?.toDouble(),
      merchant: json['merchant'],
      date: json['date'] != null ? DateTime.tryParse(json['date']) : null,
      category: json['category'],
    );
  }
}

class AIService {
  static const String _modelName = 'gemini-3.1-pro-preview';
  static final ValueNotifier<String> statusNotifier = ValueNotifier("ok");
  static List<String> _integratedApiKeys = [];

  static Future<Map<String, dynamic>> getGlobalConfig() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('global')
          .get()
          .timeout(const Duration(seconds: 3));
      if (doc.exists) return doc.data()!;
    } catch (e) {
      debugPrint('Error getting Global config: $e');
    }
    return {};
  }

  static Future<Map<String, dynamic>> getAIConfig() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('ai_config')
          .get()
          .timeout(const Duration(seconds: 3));
      if (doc.exists) return doc.data()!;
    } catch (e) {
      debugPrint('Error getting AI config: $e');
    }
    return {
      'max_chats_per_hour': 10,
      'reset_duration_minutes': 60,
      'is_ai_enabled': true,
    };
  }

  static Future<bool> isGlobalAiEnabled() async {
    try {
      final config = await getAIConfig();
      return config['is_ai_enabled'] ?? true;
    } catch (e) {
      return true; // Fail safe
    }
  }

  static Future<bool> _checkUserQuota(String uid) async {
    try {
      final config = await getAIConfig();
      final maxChats = config['max_chats_per_hour'] ?? 10;
      final resetMinutes = config['reset_duration_minutes'] ?? 60;

      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = userDoc.data() ?? {};

      final int count = data['aiCount'] ?? 0;
      final Timestamp? cycleStartTs = data['aiCycleStart'] as Timestamp?;
      final DateTime now = DateTime.now();

      if (cycleStartTs == null) {
        // First time
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'aiCycleStart': FieldValue.serverTimestamp(),
          'aiCount': 0,
        }, SetOptions(merge: true));
        return true;
      }

      final cycleStart = cycleStartTs.toDate();
      if (now.difference(cycleStart).inMinutes >= resetMinutes) {
        // Cycle expired, reset
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'aiCycleStart': FieldValue.serverTimestamp(),
          'aiCount': 0,
        });
        return true;
      }

      return count < maxChats;
    } catch (e) {
      debugPrint('Quota check failed: $e');
      return true; // Fail safe
    }
  }

  static Future<void> _incrementUserQuota(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'aiCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('Increment quota failed: $e');
    }
  }

  static Future<List<String>> getIntegratedApiKeysAsync() async {
    try {
      final data = await getAIConfig();
      _integratedApiKeys = List<String>.from(data['gemini_keys'] ?? []);
    } catch (e) {
      debugPrint('Failed to fetch integrated keys: $e');
    }
    return _integratedApiKeys;
  }

  static Future<Map<String, dynamic>> getUserQuotaStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {'count': 0, 'limit': 10};

      // Force server fetch for critical config updates (Real-time sync)
      final configDoc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('ai_config')
          .get(const GetOptions(source: Source.server));

      final config = configDoc.data() ?? {};
      final limit = config['max_chats_per_hour'] ?? 10;
      final resetMinutes = config['reset_duration_minutes'] ?? 60;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server));

      final data = userDoc.data() ?? {};
      final int count = data['aiCount'] ?? 0;
      final Timestamp? cycleStartTs = data['aiCycleStart'] as Timestamp?;
      final DateTime now = DateTime.now();

      // Check if cycle expired (Logic mirror from _checkUserQuota)
      if (cycleStartTs != null) {
        final cycleStart = cycleStartTs.toDate();
        final minutesPassed = now.difference(cycleStart).inMinutes;
        if (minutesPassed >= resetMinutes) {
          // Cycle expired, effectively 0 in UI (next chat will trigger DB reset)
          return {
            'count': 0,
            'limit': limit,
            'nextReset': '-- ${resetMinutes}m',
            'interval': resetMinutes
          };
        }

        final nextResetDateTime =
            cycleStart.add(Duration(minutes: resetMinutes));
        final diff = nextResetDateTime.difference(now);
        final nextResetStr = diff.inHours > 0
            ? '${diff.inHours}j ${diff.inMinutes % 60}m'
            : '${diff.inMinutes}m';

        return {
          'count': count,
          'limit': limit,
          'nextReset': nextResetStr,
          'interval': resetMinutes
        };
      }

      return {
        'count': count,
        'limit': limit,
        'nextReset': '- ${resetMinutes}m',
        'interval': resetMinutes
      };
    } catch (e) {
      debugPrint('Error getting quota status: $e');
      return {'count': 0, 'limit': 10};
    }
  }

  // Common Indonesian female name patterns/prefixes (Sorted A-Z)
  static const List<String> _femaleNamePatterns = [
    'alesha',
    'alya',
    'amanda',
    'amelia',
    'angel',
    'angelica',
    'ani',
    'anisa',
    'anita',
    'anna',
    'annisa',
    'aqila',
    'aulia',
    'ayu',
    'bella',
    'berlian',
    'bunga',
    'cantika',
    'chelsea',
    'cherryelle',
    'chika',
    'cinta',
    'citra',
    'clara',
    'dahlia',
    'della',
    'desi',
    'desy',
    'dewi',
    'dian',
    'diana',
    'dina',
    'dinda',
    'dwi',
    'eka',
    'elisabeth',
    'endang',
    'erika',
    'eva',
    'farah',
    'fatimah',
    'felicia',
    'fika',
    'fina',
    'fitri',
    'fitria',
    'friska',
    'galuh',
    'gisel',
    'grace',
    'handayani',
    'ika',
    'indah',
    'intan',
    'ira',
    'iren',
    'jessica',
    'joti',
    'galih',
    'jihan',
    'karen',
    'karina',
    'khansa',
    'karin',
    'kartika',
    'kasih',
    'keisha',
    'kirana',
    'laras',
    'lestari',
    'lia',
    'lina',
    'linda',
    'lisa',
    'lusi',
    'maria',
    'mawar',
    'maya',
    'mega',
    'mei',
    'meisya',
    'melani',
    'melati',
    'melli',
    'mia',
    'mila',
    'mutiara',
    'nabila',
    'nadia',
    'nadya',
    'nana',
    'natasha',
    'naura',
    'nazwa',
    'nia',
    'ningsih',
    'nisa',
    'nita',
    'novia',
    'novita',
    'nur',
    'nurul',
    'olivia',
    'patricia',
    'permata',
    'pipit',
    'putri',
    'rachma',
    'rahayu',
    'rahma',
    'rani',
    'ratna',
    'resti',
    'retno',
    'rina',
    'rini',
    'risa',
    'riska',
    'rosa',
    'safira',
    'salsa',
    'salsabila',
    'sandra',
    'sarah',
    'sari',
    'sasya',
    'selvi',
    'shinta',
    'silvi',
    'siska',
    'siti',
    'sophia',
    'sri',
    'stella',
    'suci',
    'susi',
    'syifa',
    'tari',
    'tasya',
    'tia',
    'tiara',
    'tina',
    'tri',
    'utami',
    'vina',
    'wati',
    'widya',
    'wulan',
    'wulandari',
    'yani',
    'yanti',
    'yenny',
    'yessi',
    'yulia',
    'yuni',
    'zahra'
  ];

  /// Guess gender based on first name
  /// Returns 'female' or 'male' (defaults to male if unsure)
  static String _guessGender(String? displayName) {
    if (displayName == null || displayName.trim().isEmpty) return 'male';

    final firstName = displayName.trim().split(' ').first.toLowerCase();

    // Check against female name patterns
    for (final pattern in _femaleNamePatterns) {
      if (firstName == pattern || firstName.startsWith(pattern)) {
        return 'female';
      }
    }

    // Common female name endings in Indonesian
    if (firstName.endsWith('a') &&
        !firstName.endsWith('ka') &&
        !firstName.endsWith('ra') &&
        firstName.length > 3) {
      // Many female Indonesian names end with 'a' but some male names too
      // Additional heuristic: if ends with common female suffixes
      if (firstName.endsWith('ina') ||
          firstName.endsWith('ita') ||
          firstName.endsWith('ila') ||
          firstName.endsWith('ela') ||
          firstName.endsWith('ana') ||
          firstName.endsWith('ika') ||
          firstName.endsWith('isa') ||
          firstName.endsWith('iha') ||
          firstName.endsWith('aya')) {
        return 'female';
      }
    }

    return 'male';
  }

  // New Enum locally or use simple strings for simplicity in this context
  // but to keep it compatible with existing code, we'll keep return bool
  // but provide a more detailed check method.

  Future<Map<String, dynamic>> checkKeyStatus(String apiKey) async {
    final modelsToTry = [
      'gemini-1.5-flash', // Most common/reliable
      'gemini-1.5-pro',
      'gemini-2.0-flash',
      'gemini-3.1-pro-preview',
    ];

    Exception? lastErr;

    for (var mName in modelsToTry) {
      try {
        final model = GenerativeModel(model: mName, apiKey: apiKey);
        debugPrint('>>> Verifying Gemini Key with $mName...');
        await model.generateContent([
          Content.text('Hi, verify connectivity. Short reply.')
        ]).timeout(const Duration(seconds: 5));
        return {
          'isValid': true,
          'status': 'ok',
          'message': 'API Key bekerja dengan baik!'
        };
      } catch (e) {
        lastErr = e is Exception ? e : Exception(e.toString());
        final errorStr = e.toString().toLowerCase();

        // If it's a quota issue, it IS valid, just limited
        if (errorStr.contains('quota') ||
            errorStr.contains('429') ||
            errorStr.contains('exhausted') ||
            errorStr.contains('limit')) {
          return {
            'isValid': true,
            'status': 'limit',
            'message': 'API Key valid, tapi mencapai limit (Quota Exceeded).'
          };
        }

        // If it's specifically "model not found", try next model
        if (errorStr.contains('not found') || errorStr.contains('404')) {
          continue;
        }

        // If it's an invalid key error, no need to try other models
        if (errorStr.contains('invalid') ||
            errorStr.contains('expired') ||
            errorStr.contains('api key not valid')) {
          break;
        }
      }
    }

    final e = lastErr;
    if (e == null) {
      return {
        'isValid': false,
        'status': 'error',
        'message': 'Gagal verifikasi: Hubungi support.'
      };
    }

    final errorStr = e.toString().toLowerCase();
    debugPrint('>>> API KEY CHECK ERROR DETAILS: $e');

    if (errorStr.contains('quota') ||
        errorStr.contains('429') ||
        errorStr.contains('exhausted') ||
        errorStr.contains('limitReached') ||
        errorStr.contains('limit:')) {
      return {
        'isValid': true,
        'status': 'limit',
        'message':
            'API Key valid, tapi sedang mencapai limit per detik/menit (Quota Exceeded).'
      };
    }

    if (errorStr.contains('leaked')) {
      return {
        'isValid': false,
        'status': 'error',
        'message': 'API Key diblokir oleh Google krn terekspos (Leaked).'
      };
    }

    if (errorStr.contains('invalid') ||
        errorStr.contains('not valid') ||
        errorStr.contains('expired') ||
        errorStr.contains('forbidden')) {
      return {
        'isValid': false,
        'status': 'invalid',
        'message': 'API Key tidak valid atau salah.'
      };
    }

    if (errorStr.contains('not found') ||
        errorStr.contains('unhandled format') ||
        errorStr.contains('role: model')) {
      return {
        'isValid': true,
        'status': 'ok',
        'message': 'API Key bekerja (bypass format SDK error).'
      };
    }

    return {
      'isValid': false,
      'status': 'error',
      'message': 'Gagal verifikasi: ${e.toString().split('\n').first}'
    };
  }

  Future<String> getDetailedStatus(String apiKey) async {
    final status = await checkKeyStatus(apiKey);
    return status['status'] as String? ?? 'error';
  }

  Future<bool> checkQuota(String apiKey) async {
    final status = await checkKeyStatus(apiKey);
    return status['isValid'] == true;
  }

  Future<bool> checkGroqQuota(String apiKey) async {
    final status = await checkGroqKeyStatus(apiKey);
    return status['isValid'] == true;
  }

  Future<bool> checkPlatformQuota(String apiKey, String platform) async {
    if (platform == 'groq') {
      return checkGroqQuota(apiKey);
    }
    return checkQuota(apiKey);
  }

  // Helper to expose integrated keys status check
  List<String> getIntegratedKeys() => _integratedApiKeys;

  // === GROQ API SUPPORT ===
  static Future<List<String>> getGroqApiKeysAsync() async {
    try {
      final data = await getAIConfig();
      return List<String>.from(data['groq_keys'] ?? []);
    } catch (e) {
      debugPrint('Failed to fetch Groq keys: $e');
      return [];
    }
  }

  static Future<String?> _callGroqApi({
    required String apiKey,
    required String model,
    required String systemPrompt,
    required String userQuery,
    List<Content>? history,
    int maxTokens = 2048,
  }) async {
    final messages = <Map<String, String>>[];
    messages.add({'role': 'system', 'content': systemPrompt});
    if (history != null) {
      for (var content in history) {
        final role = content.role == 'model' ? 'assistant' : 'user';
        final text =
            content.parts.whereType<TextPart>().map((p) => p.text).join('\n');
        if (text.isNotEmpty) {
          messages.add({'role': role, 'content': text});
        }
      }
    }
    messages.add({'role': 'user', 'content': userQuery});

    final response = await http.post(
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'messages': messages,
        'temperature': 0.8,
        'max_tokens': maxTokens,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices']?[0]?['message']?['content'];
    }
    final errorBody = jsonDecode(response.body);
    final errorMsg = errorBody['error']?['message'] ?? 'Unknown error';
    if (response.statusCode == 429) {
      throw Exception('GROQ_RATE_LIMIT: $errorMsg');
    } else if (response.statusCode == 401) {
      throw Exception('GROQ_INVALID_KEY: $errorMsg');
    } else {
      throw Exception('GROQ_ERROR: $errorMsg');
    }
  }

  Future<Map<String, dynamic>> checkGroqKeyStatus(String apiKey) async {
    final modelsToTry = [
      'llama-3.3-70b-versatile',
      'llama-3.1-8b-instant',
    ];

    for (var mName in modelsToTry) {
      try {
        final response = await http
            .post(
              Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
              headers: {
                'Authorization': 'Bearer $apiKey',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'model': mName,
                'messages': [
                  {'role': 'user', 'content': 'Test. Reply OK.'}
                ],
                'max_tokens': 5,
              }),
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          return {
            'isValid': true,
            'status': 'ok',
            'message': 'Groq API Key bekerja!'
          };
        } else if (response.statusCode == 429) {
          return {
            'isValid': true,
            'status': 'limit',
            'message': 'Key valid, rate limit tercapai.'
          };
        } else if (response.statusCode == 401) {
          return {
            'isValid': false,
            'status': 'invalid',
            'message': 'API Key tidak valid.'
          };
        }
      } catch (e) {
        continue;
      }
    }

    return {
      'isValid': false,
      'status': 'error',
      'message': 'Gagal verifikasi atau API sedang down.'
    };
  }

  Future<String> getFinancialAdvice({
    required String? apiKey,
    String? apiPlatform, // 'gemini' or 'groq'
    required List<TransactionModel> transactions,
    List<WalletModel>? wallets,
    required String userQuery,
    required DateTimeRange dateRange,
    AppTone tone = AppTone.normal,
    List<Content>? history,
  }) async {
    final isCustomApi = apiKey != null && apiKey.trim().isNotEmpty;
    final currentUser = FirebaseAuth.instance.currentUser;
    final String? uid = currentUser?.uid;

    if (!isCustomApi && uid != null) {
      final hasQuota = await _checkUserQuota(uid);
      if (!hasQuota) {
        final config = await getAIConfig();
        final maxChats = config['max_chats_per_hour'] ?? 10;
        final resetMin = config['reset_duration_minutes'] ?? 60;
        return 'Maaf, jatah chat gratis kamu sudah habis (Limit: $maxChats chat per $resetMin menit). \n\nJatah ini akan reset otomatis. Biar bisa chat SEPUASNYA tanpa antri, kamu bisa masukkan API Key pribadi kamu (Gratis dari Google) di menu Kelola API ya! 😊';
      }
      // Increment quota IMMEDIATELY to prevent race condition
      // (user sending multiple messages before first response completes)
      await _incrementUserQuota(uid);
    }

    final integratedKeys = await getIntegratedApiKeysAsync();
    final groqIntegratedKeys = await getGroqApiKeysAsync();

    // Logic: Use personal key first, then fallback to ALL integrated keys
    final List<String> geminiKeysToUse = [];
    final List<String> groqKeysToUse = [];

    if (isCustomApi) {
      if (apiPlatform == 'groq') {
        groqKeysToUse.add(apiKey.trim());
      } else {
        geminiKeysToUse.add(apiKey.trim());
      }
    }
    geminiKeysToUse.addAll(integratedKeys);
    groqKeysToUse.addAll(groqIntegratedKeys);

    // Remove duplicates while preserving order
    final uniqueGeminiKeys = <String>[];
    for (var k in geminiKeysToUse) {
      if (!uniqueGeminiKeys.contains(k)) uniqueGeminiKeys.add(k);
    }

    final uniqueGroqKeys = <String>[];
    for (var k in groqKeysToUse) {
      if (!uniqueGroqKeys.contains(k)) uniqueGroqKeys.add(k);
    }

    final summary =
        _generateDataSummary(transactions, dateRange, wallets: wallets);

    // Get user name and gender for pasangan mode
    final userName = currentUser?.displayName ?? 'Sayang';
    final userGender = _guessGender(userName);
    final aiRole = userGender == 'female'
        ? 'boyfriend (pacar cowok)'
        : 'girlfriend (pacar cewek)';
    final aiPanggilan = userGender == 'female'
        ? 'sayang, beb, cinta, my love'
        : 'sayang, beb, cinta, my love, cantik';
    final firstName = userName.split(' ').first;

    String toneInstruction = "";
    switch (tone) {
      case AppTone.genZ:
        toneInstruction =
            "Pake gaya bahasa Gen-Z yang asik, banyak slang (Luh, Gue, Gweh, Cuan, Boncos, Spill, Nggoghey, yokyoii :3, noted, kids, miskir), sering pake emoji, dan agak frontal tapi jujur.";
        break;
      case AppTone.milenial:
        toneInstruction =
            "Pake gaya bahasa Milenial yang santai, campur dikit bahasa Inggris (lifestyle, cashflow, struggle), fokus ke keseimbangan hidup dan 'healing' keuangan.";
        break;
      case AppTone.boomer:
        toneInstruction =
            "Pake gaya bahasa orang tua yang bijak dan sangat sopan. Panggil pengguna 'Nak', 'Adinda', atau 'Ananda', sering ucapkan 'Alhamdulillah' atau 'MasyaAllah', dan fokus ke penghematan demi masa depan.";
        break;
      case AppTone.pasangan:
        toneInstruction = """
Kamu berperan sebagai $aiRole dari pengguna bernama "$firstName".
Gaya bicaramu HARUS sangat romantis, flirty, menggoda, penuh perhatian, dan mesra — seperti pasangan yang sudah lama pacaran atau suami/istri.

ATURAN WAJIB MODE PASANGAN:
- Panggil pengguna dengan panggilan sayang seperti: $aiPanggilan, atau nama mereka "$firstName"
- Gunakan banyak emoji hati dan romantis: 💕💖💗😘🥰❤️💋💑
- Selalu tunjukkan perhatian terhadap kebiasaan belanja mereka, khawatir kalau boros, bangga kalau hemat
- Gunakan bahasa yang manis, menggoda, dan kadang agak manja tapi tetap memberikan nasihat keuangan berguna
- Sisipkan kata-kata flirty seperti: "aku perhatiin kamu..", "jangan lupa makan ya sayang", "aku selalu support kamu", "kita hemat bareng yuk biar bisa jalan-jalan berdua"
- Kalau user boros, tegur dengan manis: "sayang, kok banyak jajan sih? aku khawatir nih~"
- Kalau user hemat, puji: "wah pinter banget sih kamu, bangga deh aku sama kamu! 😘"
- Jangan pernah break character, selalu act sebagai pasangan yang sangat sayang
- Tetap berikan saran keuangan yang valid dan berguna meskipun dengan gaya romantis
""";
        break;
      default:
        toneInstruction =
            "Pake bahasa Indonesia yang formal tapi ramah dan profesional.";
    }

    final systemPrompt = '''
Kamu adalah "Archen", asisten keuangan pintar yang profesional, ramah, dan solutif.
Tugasmu adalah menganalisis data keuangan pengguna dan memberikan saran yang sangat spesifik.

KEPRIBADIAN KAMU:
$toneInstruction

KONTEKS DATA PENGGUNA SAAT INI:
Periode: ${DateFormat('dd MMM yyyy').format(dateRange.start)} - ${DateFormat('dd MMM yyyy').format(dateRange.end)}
$summary

INSTRUKSI:
1. Jawab pertanyaan pengguna dengan bahasa Indonesia yang santai tapi profesional.
2. Jika ada pertanyaan tentang spesifik kategori (contoh: "habis berapa buat kopi?"), cari di data transaksi dan berikan angkanya.
3. Berikan tips hemat yang relevan dengan pola pengeluarannya.
4. Gunakan Markdown untuk format jawaban (bullet point, bold).
5. Jangan berikan nasihat investasi berisiko tinggi.
6. JIKA PENGGUNA HANYA MENYAPA (Halo, Hai, Pagi, Malam, dll) atau memberikan input singkat yang tidak memerlukan analisis mendalam, JANGAN memberondong dengan ringkasan data atau saran panjang. Balaslah sesingkat dan seramah mungkin sesuai kepribadianmu.
''';

    try {
      final limitedHistory = (history != null && history.length > 6)
          ? history.sublist(history.length - 6)
          : history;

      GenerateContentResponse? finalResponse;
      Exception? lastQuotaException;

      for (String currentKey in uniqueGeminiKeys) {
        final isLastKey = currentKey == uniqueGeminiKeys.last;
        final isPersonalKey = isCustomApi &&
            apiPlatform != 'groq' &&
            currentKey == uniqueGeminiKeys.first;

        Future<bool> tryWithModel(String mName) async {
          try {
            debugPrint(
                '>>> CALLING GEMINI: $mName with key ${currentKey.substring(0, 10)}...');
            final model = GenerativeModel(
              model: mName,
              apiKey: currentKey,
              systemInstruction: Content.system(systemPrompt),
              generationConfig:
                  GenerationConfig(temperature: 0.8, maxOutputTokens: 2048),
            );
            final chat = model.startChat(history: limitedHistory ?? []);
            finalResponse = await chat.sendMessage(Content.text(userQuery));
            return true;
          } catch (e) {
            lastQuotaException = e is Exception ? e : Exception(e.toString());
            return false;
          }
        }

        // 2026 ADVANCED ROTATION: Using the latest 3.1 ecosystem
        // Priority: 3.1 Pro (15 RPM) -> 3.1 Flash Lite (15 RPM) -> 3 Flash -> 2.5 Flash
        final models = [
          _modelName, // gemini-3.1-pro-preview
          'gemini-3.1-flash-lite-preview',
          'gemini-3.1-pro',
          'gemini-3.1-flash-lite',
          'gemini-3-flash',
          'gemini-3-pro',
          'gemini-2.5-flash',
          'gemini-2.5-pro',
        ];

        bool keySucceeded = false;
        for (String m in models) {
          if (await tryWithModel(m)) {
            statusNotifier.value =
                (m == _modelName && (!isCustomApi || isPersonalKey))
                    ? 'ok'
                    : 'limit';
            keySucceeded = true;
            break;
          }

          // If it's NOT a quota/429/exhausted error AND NOT a 404 Not Found, rotate key
          final errStr = lastQuotaException.toString().toLowerCase();
          bool isQuotaErr = errStr.contains('quota') ||
              errStr.contains('429') ||
              errStr.contains('exhausted') ||
              errStr.contains('limit');

          bool isNotFound =
              errStr.contains('not found') || errStr.contains('404');

          // If it's not a quota issue AND not a 404, we assume fatal error and break model loop
          if (!isQuotaErr && !isNotFound) break;

          debugPrint(
              '>>> FALLBACK on $currentKey: $m failed (${isNotFound ? "Not Found" : "Limit"}), trying next fallback model...');
        }

        if (keySucceeded) break;

        // If all models failed for this key, rotate to next key
        debugPrint(
            '>>> ROTATION: API Key $currentKey exhausted for all models, switching to next key...');
        if (isLastKey) {
          statusNotifier.value = uniqueGroqKeys.isEmpty ? 'exhausted' : 'limit';
        } else if (isPersonalKey) {
          statusNotifier.value = 'limit';
        }
      }

      // === GROQ FALLBACK ===
      if (finalResponse == null) {
        if (uniqueGroqKeys.isNotEmpty) {
          debugPrint('>>> Gemini ALL LIMIT. FALLING BACK TO GROQ...');
          final groqModels = [
            'qwen/qwen3-32b',
            'llama-3.1-8b-instant',
            'llama-3.3-70b-versatile',
            'openai/gpt-oss-20b',
            'openai/gpt-oss-13b',
            'openai/gpt-oss-7b',
            'meta-llama/llama-prompt-guard-2-22m',
            'meta-llama/llama-prompt-guard-2-86m',
            'moonshotai/kimi-k2-instruct',
            'allam-2-7b',
            'groq/compound',
            'groq/compound-mini'
          ];
          for (String groqKey in uniqueGroqKeys) {
            final isPersonalGroq = isCustomApi &&
                apiPlatform == 'groq' &&
                groqKey == uniqueGroqKeys.first;

            for (String groqModel in groqModels) {
              try {
                debugPrint('>>> CALLING GROQ: $groqModel...');
                final result = await _callGroqApi(
                  apiKey: groqKey,
                  model: groqModel,
                  systemPrompt: systemPrompt,
                  userQuery: userQuery,
                  history: limitedHistory,
                );
                if (result != null && result.isNotEmpty) {
                  statusNotifier.value = isPersonalGroq ? 'ok' : 'limit';
                  return result;
                }
              } catch (e) {
                final errStr = e.toString().toLowerCase();
                if (errStr.contains('rate_limit') || errStr.contains('429')) {
                  debugPrint('>>> GROQ: $groqModel rate limited, next...');
                  continue;
                }
                debugPrint('>>> GROQ: $groqModel error: $e');
                break;
              }
            }
          }
        }
      }

      if (finalResponse == null) {
        if (lastQuotaException != null) {
          debugPrint('All keys exhausted. Last: $lastQuotaException');
        }
        if (isCustomApi) {
          if (lastQuotaException != null &&
              (lastQuotaException
                      .toString()
                      .toLowerCase()
                      .contains('invalid') ||
                  lastQuotaException
                      .toString()
                      .toLowerCase()
                      .contains('api key not valid'))) {
            return 'API Key tidak valid atau salah. Silakan periksa kembali di Pengaturan API.';
          }
          throw Exception('QUOTA_EXCEEDED');
        } else {
          return 'Maaf, seluruh token AI (Gemini + Groq) sedang limit. Masukkan API Key pribadi di menu Kelola API.';
        }
      }

      return finalResponse?.text ?? 'Maaf, jawaban kosong.';
    } catch (e) {
      if (e.toString().contains('QUOTA_EXCEEDED')) throw e;
      if (e.toString().contains('Invalid API key'))
        return 'API Key tidak valid.';
      return 'Terjadi kesalahan: $e';
    }
  }

  String _generateDataSummary(
      List<TransactionModel> transactions, DateTimeRange range,
      {List<WalletModel>? wallets}) {
    double totalIncome = 0;
    double totalExpense = 0;
    Map<String, double> categoryBreakdown = {};

    // Group transactions
    for (var tx in transactions) {
      if (tx.isIncome) {
        totalIncome += tx.amount;
      } else {
        totalExpense += tx.amount;
        categoryBreakdown[tx.category] =
            (categoryBreakdown[tx.category] ?? 0) + tx.amount;
      }
    }

    String breakdownStr = categoryBreakdown.entries
        .map((e) => "- ${e.key}: Rp ${e.value.toStringAsFixed(0)}")
        .join("\n");

    String walletsStr = "";
    if (wallets != null && wallets.isNotEmpty) {
      walletsStr = "\nSTATUS DOMPET SAAT INI:\n" +
          wallets
              .map((w) =>
                  "- ${w.walletName} (${w.type == 'colab' ? 'Tabungan Bersama' : w.type == 'debt' ? 'Hutang/Piutang' : 'Pribadi'}): Rp ${w.balance.toStringAsFixed(0)}")
              .join("\n") +
          "\n";
    }

    return '''
RINGKASAN DATA KEUANGAN (${DateFormat('dd/MM').format(range.start)} - ${DateFormat('dd/MM').format(range.end)}):
- Total Pemasukan: Rp ${totalIncome.toStringAsFixed(0)}
- Total Pengeluaran: Rp ${totalExpense.toStringAsFixed(0)}
- Saldo Bersih: Rp ${(totalIncome - totalExpense).toStringAsFixed(0)}
$walletsStr
RINCIAN PENGELUARAN PER KATEGORI:
$breakdownStr

DAFTAR TRANSAKSI TERAKHIR (Sample 20 item):
${transactions.take(20).map((t) => "[${DateFormat('dd/MM').format(t.date)}] ${t.type == 'income' ? '+' : '-'} Rp ${t.amount.toStringAsFixed(0)} (${t.category}: ${t.note})").join("\n")}
''';
  }

  // === SPECIALIZED FINANCIAL ADVISOR (ANALYTIC) ===
  static Future<String> getAdvisorAnalysis({
    required List<TransactionModel> transactions,
    List<WalletModel>? wallets,
    required DateTimeRange dateRange,
    required double score,
    required String status,
    AppTone tone = AppTone.normal,
  }) async {
    try {
      final config = await getGlobalConfig();
      final bool isEnabled = config['is_advisor_enabled'] ?? true;
      if (!isEnabled)
        return 'Fitur Analisis AI sedang dinonaktifkan oleh Admin.';

      final String provider = config['advisor_provider'] ?? 'gemini';
      final List<String> geminiKeys =
          List<String>.from(config['advisor_gemini_keys'] ?? []);
      final List<String> groqKeys =
          List<String>.from(config['advisor_groq_keys'] ?? []);

      // Migrasi backward-compatibility jika masih nyangkut legacy key lama
      final String legacyKey =
          (config['advisor_api_key'] ?? '').toString().trim();
      if (legacyKey.isNotEmpty) {
        if (legacyKey.startsWith('gsk_') && !groqKeys.contains(legacyKey)) {
          groqKeys.add(legacyKey);
        } else if (legacyKey.startsWith('AIza') &&
            !geminiKeys.contains(legacyKey)) {
          geminiKeys.add(legacyKey);
        }
      }

      if (geminiKeys.isEmpty && groqKeys.isEmpty) {
        return '**Archen Analytic:** Masalah teknis. (API Key Analytic belum dikonfigurasi Admin)';
      }

      final int minTrans = config['advisor_min_transactions'] ?? 5;
      final int cooldownHours = config['advisor_cooldown_hours'] ?? 24;

      final prefs = await SharedPreferences.getInstance();

      // CEK TRIGGER TRANSAKSI
      if (transactions.length < minTrans) {
        return '**Archen Analytic:** Data transaksimu masih kurang (butuh $minTrans transaksi). Kumpulkan lebih banyak data agar Archen bisa menganalisis ya!';
      }

      // CEK COOLDOWN
      final String? lastUpdateStr = prefs.getString('advisor_last_update');
      final String? cachedAnalysis = prefs.getString('advisor_cached_analysis');

      if (lastUpdateStr != null && cachedAnalysis != null) {
        final DateTime lastUpdate = DateTime.parse(lastUpdateStr);
        final Duration difference = DateTime.now().difference(lastUpdate);

        if (difference.inHours < cooldownHours) {
          final int remainingHours = cooldownHours - difference.inHours;
          final int remainingMins = cooldownHours > difference.inHours
              ? (59 - (difference.inMinutes % 60))
              : 0;
          return '$cachedAnalysis(Archen Lagi draining nii, cek lagi ${remainingHours == 0 ? "$remainingMins menit" : "$remainingHours jam $remainingMins menit"} ke depan)';
        }
      }

      final summary = AIService()
          ._generateDataSummary(transactions, dateRange, wallets: wallets);

      final currentUser = FirebaseAuth.instance.currentUser;
      final userName = currentUser?.displayName ?? 'Sayang';
      final userGender = _guessGender(userName);
      final aiRole = userGender == 'female'
          ? 'boyfriend (pacar cowok)'
          : 'girlfriend (pacar cewek)';
      final aiPanggilan = userGender == 'female'
          ? 'sayang, beb, cinta, my love'
          : 'sayang, beb, cinta, my love, cantik';
      final firstName = userName.split(' ').first;

      String toneInstruction = "";
      switch (tone) {
        case AppTone.genZ:
          toneInstruction =
              "Pake gaya bahasa Gen-Z yang asik, banyak slang (Luh, Gue, Gweh, Cuan, Boncos), sering pake emoji, dan agak frontal tapi jujur.";
          break;
        case AppTone.milenial:
          toneInstruction =
              "Pake gaya bahasa Milenial yang santai, campur dikit bahasa Inggris (lifestyle, cashflow, struggle), fokus ke keseimbangan hidup dan 'healing' keuangan.";
          break;
        case AppTone.boomer:
          toneInstruction =
              "Pake gaya bahasa orang tua yang bijak dan sangat sopan. Panggil pengguna 'Nak' atau 'Ananda', sering ucapkan 'Alhamdulillah' atau 'MasyaAllah', dan fokus ke penghematan.";
          break;
        case AppTone.pasangan:
          toneInstruction = """
Kamu berperan sebagai $aiRole dari pengguna bernama "$firstName".
Panggil dengan $aiPanggilan. Gunakan banyak emoji romantis seperti ~(>_<。)＼, (´｡• ᵕ •｡`), (´• ω •`),(。・ω・。),(✿◠‿◠),(*/ω＼*),(〜￣▽￣)〜, dan lainnya.
Gaya bicara sangat romantis,flirty,clingy, manja, Tsundere dikit,sedikit mesum, penuh perhatian, layaknya pacar/suami/istri tersayang.
WAJIB, PAKAI TYPING GANTENG/ TYPING CANTIK dan sedikit MIX Inggris yg romantis.
""";
          break;
        case AppTone.normal:
          toneInstruction =
              "Gunakan bahasa Indonesia yang santai, profesional, dan to-the-point.";
          break;
      }

      final systemPrompt = '''
Kamu adalah "Archen Advisor", pakar analisis keuangan yang tajam, solutif, dan sangat perhatian.
Tugasmu adalah memberikan analisis kesehatan keuangan yang mendalam namun tetap to-the-point berdasarkan data dan skor pengguna.

DATA PENGGUNA:
- Skor Kesehatan: $score/100 (Status: $status)
- Ringkasan Data: $summary

INSTRUKSI ANALISIS:
1. Berikan analisis dalam 2-4 kalimat yang padat (MAKSIMAL 25 KATA).
2. FOKUS PADA HAL PALING KRUSIAL: Identifikasi pola pemborosan, bandingkan pemasukan vs pengeluaran secara logis, atau puji penghematan yang dilakukan.
3. Berikan pesan yang MEMOTIVASI dan ACTIONABLE (saran konkret apa yang harus dilakukan).
4. JANGAN hanya menuliskan angka nominal yang sudah ada di data kecuali sangat perlu untuk penekanan.
5. GAYA BAHASA WAJIB: $toneInstruction
6. Awali jawabanmu HANYA dengan format TEPAT seperti ini:**Archen (´･ω･`):** [spasi] [enter] [spasi]
   Pastikan tidak ada teks lain di depan atau di dalam kurung.
''';

      final userQuery =
          'Berikan analisis kesehatan keuangan singkat saya berdasarkan data tersebut.';

      // FUNCTION GROQ FALLBACK
      Future<String?> tryGroqList() async {
        final List<String> fallbackModels = [
          'llama-3.3-70b-versatile',
          'llama-3.1-8b-instant',
          'qwen/qwen3-32b',
          'allam-2-7b',
          'groq/compound',
          'groq/compound-mini'
        ];

        for (String k in groqKeys) {
          for (String m in fallbackModels) {
            try {
              final res = await _callGroqApi(
                apiKey: k.trim(),
                model: m,
                systemPrompt: systemPrompt,
                userQuery: userQuery,
                maxTokens: 200,
              );
              if (res != null && res.isNotEmpty) return res;
            } catch (e) {
              debugPrint('>>> Advisor Groq Fallback [$k][$m]: $e');
              continue;
            }
          }
        }
        return null;
      }

      // FUNCTION GEMINI FALLBACK
      Future<String?> tryGeminiList() async {
        final List<String> fallbackModels = [
          'gemini-3.1-pro-preview',
          'gemini-2.5-flash',
          'gemini-2.5-pro',
          'gemini-2.0-flash',
          'gemini-2.5-flash-lite',
          'gemini-2.0-flash-lite'
        ];

        for (String k in geminiKeys) {
          for (String m in fallbackModels) {
            try {
              final model = GenerativeModel(
                model: m,
                apiKey: k.trim(),
                systemInstruction: Content.system(systemPrompt),
                generationConfig: GenerationConfig(maxOutputTokens: 500),
              );
              final res =
                  await model.generateContent([Content.text(userQuery)]);
              if (res.text != null && res.text!.isNotEmpty) return res.text;
            } catch (e) {
              debugPrint('>>> Advisor Gemini Fallback [$k][$m]: $e');
              final errStr = e.toString().toLowerCase();
              bool isQuotaErr = errStr.contains('quota') ||
                  errStr.contains('429') ||
                  errStr.contains('exhausted') ||
                  errStr.contains('limit');
              bool isNotFound =
                  errStr.contains('not found') || errStr.contains('404');

              if (!isQuotaErr && !isNotFound) break;
              continue; // Try next fallback model
            }
          }
        }
        return null;
      }

      String? finalAnalysis;

      if (provider == 'groq') {
        finalAnalysis = await tryGroqList();
        finalAnalysis ??= await tryGeminiList();
      } else {
        finalAnalysis = await tryGeminiList();
        finalAnalysis ??= await tryGroqList();
      }

      final result = finalAnalysis ??
          'Gagal melakukan analisis AI (Semua API limit / invalid).';

      // JIKA BERHASIL (Tidak gagal), KITA CACHE
      if (finalAnalysis != null) {
        await prefs.setString('advisor_cached_analysis', result);
        await prefs.setString(
            'advisor_last_update', DateTime.now().toIso8601String());
      }

      return result;
    } catch (e) {
      debugPrint('Error getAdvisorAnalysis: $e');
      return 'Terjadi kerusakan pada koneksi server kesehatan.';
    }
  }

  // === EAGLE EYE AI TREND ANALYSIS ===
  static Future<String> getEagleEyeAnalysis({
    required List<TransactionModel> transactions,
    required DateTimeRange dateRange,
    required int walletCount,
    required int userCount,
    required double totalLiquidity,
  }) async {
    try {
      final config = await getGlobalConfig();
      final String provider = config['advisor_provider'] ?? 'gemini';
      final List<String> geminiKeys =
          List<String>.from(config['advisor_gemini_keys'] ?? []);
      final List<String> groqKeys =
          List<String>.from(config['advisor_groq_keys'] ?? []);

      final String legacyKey =
          (config['advisor_api_key'] ?? '').toString().trim();
      if (legacyKey.isNotEmpty) {
        if (legacyKey.startsWith('gsk_') && !groqKeys.contains(legacyKey)) {
          groqKeys.add(legacyKey);
        } else if (legacyKey.startsWith('AIza') &&
            !geminiKeys.contains(legacyKey)) {
          geminiKeys.add(legacyKey);
        }
      }

      if (geminiKeys.isEmpty && groqKeys.isEmpty) {
        return '**AI Analysis Error:** Konfigurasi API Kosong. Anda harus memasukkannya di panel Server Admin.';
      }

      final summary = AIService()._generateDataSummary(transactions, dateRange);

      final systemPrompt = '''
Kamu adalah "Eagle Eye Insight", analis makroekonomi khusus untuk performa agregat pengguna aplikasi keuangan.
Tugasmu adalah menyajikan laporan tren keuangan seluruh pengguna dalam bentuk Markdown yang lengkap.

DATA PLATFORM (AGGREGATED):
- Total Akun Pengguna Data Ini: $userCount
- Total Wallet Aktif: $walletCount
- Total Uang Beredar (Liquidity): Rp ${totalLiquidity.toStringAsFixed(0)}

$summary

INSTRUKSI FORMAT OUTPUT:
1. Buat laporan profesional layaknya diberikan kepada jajaran Direksi (SuperAdmin).
2. Sorot tiga hal utama: **Status Cash Flow Ekosistem**, **Kategori Paling Menyedot Dana**, dan **Insight Unik**.
3. Gunakan formatting Markdown penuh: heading (##), teks tebal, daftar (bullets), serta emoji relevan.
4. JANGAN SEBUT "Sample 20 item" atau rahasia struktural data. Berpura-puralah kau menganalisis jutaan titik data.
5. PENTING: Laporan HARUS LENGKAP, maksimal 400 kata. SELALU akhiri dengan bagian "## 📌 Kesimpulan" berisi 2-3 kalimat penutup.
6. JANGAN PERNAH memotong laporan di tengah kalimat. Pastikan setiap bagian memiliki penutup yang jelas.
''';

      final userQuery =
          'Analisis data global pengguna ini dan sebutkan 3 insight kunci. Pastikan laporan LENGKAP hingga bagian Kesimpulan.';

      Future<String?> tryGroqList() async {
        final List<String> fallbackModels = [
          'llama-3.3-70b-versatile',
          'qwen/qwen3-32b',
          'llama-3.1-8b-instant',
        ];

        for (String k in groqKeys) {
          for (String m in fallbackModels) {
            try {
              final res = await _callGroqApi(
                apiKey: k.trim(),
                model: m,
                systemPrompt: systemPrompt,
                userQuery: userQuery,
                maxTokens: 4096,
              );
              if (res != null && res.isNotEmpty) return res;
            } catch (e) {
              continue;
            }
          }
        }
        return null;
      }

      Future<String?> tryGeminiList() async {
        final List<String> fallbackModels = [
          'gemini-3.1-pro-preview',
          'gemini-2.5-flash',
          'gemini-2.5-pro',
          'gemini-2.0-flash',
          'gemini-2.5-flash-lite',
          'gemini-2.0-flash-lite'
        ];

        for (String k in geminiKeys) {
          for (String m in fallbackModels) {
            try {
              final model = GenerativeModel(
                model: m,
                apiKey: k.trim(),
                systemInstruction: Content.system(systemPrompt),
                generationConfig: GenerationConfig(maxOutputTokens: 4096),
              );
              final res =
                  await model.generateContent([Content.text(userQuery)]);
              if (res.text != null && res.text!.isNotEmpty) return res.text;
            } catch (e) {
              final errStr = e.toString().toLowerCase();
              if (!errStr.contains('quota') &&
                  !errStr.contains('429') &&
                  !errStr.contains('limit') &&
                  !errStr.contains('not found')) {
                break;
              }
              continue;
            }
          }
        }
        return null;
      }

      String? finalAnalysis;

      if (provider == 'groq') {
        finalAnalysis = await tryGroqList() ?? await tryGeminiList();
      } else {
        finalAnalysis = await tryGeminiList() ?? await tryGroqList();
      }

      return finalAnalysis ??
          'Sistem Gagal. Semua API AI limit atau error. Server Data macet.';
    } catch (e) {
      debugPrint('Error getEagleEyeAnalysis: $e');
      return 'Terjadi kerusakan pada koneksi server kesehatan: $e';
    }
  }

  /// Specialized method for Receipt OCR Refinement
  static Future<ReceiptData?> extractReceiptData(String rawText,
      {String? customApiKey}) async {
    final List<String> keys = [];
    if (customApiKey != null && customApiKey.isNotEmpty) keys.add(customApiKey);
    final integrated = await getIntegratedApiKeysAsync();
    keys.addAll(integrated);

    final String systemPrompt = '''
Ekstrak data dari teks struk belanja mentah di bawah ini.
Return HANYA dalam format JSON murni tanpa markdown code blocks:
{
  "merchant": "Nama Toko (Uppercase)",
  "amount": angka_total_bayar (hanya angka, tanpa titik/koma ribuan),
  "date": "YYYY-MM-DD",
  "category": "Kategori (Belanja, Makanan, Transportasi, Kesehatan, Hiburan, Lainnya)"
}

INSTRUKSI KHUSUS:
- Jika "merchant" tidak jelas, tebak dari kata kunci yang ada.
- "amount" haruslah TOTAL BAYAR akhir (Grand Total). Abaikan diskon, pajak, kembalian (change), atau poin.
- "date" gunakan format ISO-8601 (YYYY-MM-DD). Jika tidak ada tahun, gunakan tahun 2024 atau 2025 (terdekat).
- Jika ada nominal ribuan yang dipisah titik/koma (contoh: 15.000), jadikan angka murni 15000.
''';

    for (String key in keys) {
      try {
        final model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: key,
          systemInstruction: Content.system(systemPrompt),
          generationConfig: GenerationConfig(
            temperature: 0.1,
            responseMimeType: 'application/json',
          ),
        );

        final response = await model.generateContent([Content.text(rawText)]);
        final String? text = response.text;
        if (text != null && text.isNotEmpty) {
          final Map<String, dynamic> data = jsonDecode(text);
          return ReceiptData.fromJson(data);
        }
      } catch (e) {
        debugPrint('OCR Refine Error with key ${key.substring(0, 10)}: $e');
        continue;
      }
    }
    return null;
  }

  // ══════════════════════════════════════════════════
  // FASE 4: AI SENTIMENT AGGREGATOR
  // ══════════════════════════════════════════════════

  Future<String> analyzeFeedbackSentiment(List<FeedbackModel> feedbacks) async {
    if (feedbacks.isEmpty)
      return "Belum ada feedback yang masuk untuk dianalisis.";

    final config = await getAIConfig();
    final groqKeys = List<String>.from(config['groq_keys'] ?? []);
    final geminiKeys = List<String>.from(config['gemini_keys'] ?? []);
    final provider = config['provider'] ?? 'gemini';

    if (groqKeys.isEmpty && geminiKeys.isEmpty) {
      return "Gagal menganalisis: API Key AI tidak ditemukan di konfigurasi.";
    }

    // Sanitize feedback text to prevent JSON-breaking chars
    final String feedbackList = feedbacks
        .map((f) {
          final cleanComment = f.comment
              .replaceAll('"', "'")
              .replaceAll('\n', ' ')
              .replaceAll('\r', ' ')
              .replaceAll('\\', ' ');
          return "- [Rating ${f.rating.toInt()}/5] [Kategori: ${f.category}]: $cleanComment";
        })
        .join("\n");

    final systemPrompt = """
Kamu adalah Archen Analytics, asisten strategis SuperAdmin MyDuitGweh.
Tugasmu adalah merangkum feedback user berikut menjadi insight tajam dan action plan konkret.

DATA FEEDBACK:
$feedbackList

RESPON HARUS DALAM FORMAT JSON SEPERTI INI SAJA (TANPA MARKDOWN ```json):
{
  "sentiment_score": "Sangat Positif / Positif / Netral / Negatif / Sangat Negatif",
  "summary": "Ringkasan tajam dari keseluruhan feedback user (max 80 kata, satu paragraf tanpa newline)",
  "top_feature_requests": [
    "Fitur X sering diminta",
    "Perbaikan Y"
  ]
}

ATURAN KETAT:
1. Output HANYA JSON murni, TANPA teks lain sebelum/sesudah kurung kurawal.
2. JANGAN gunakan karakter newline (\\n) di dalam value string JSON.
3. JANGAN gunakan kutip ganda di dalam value string (gunakan kutip tunggal jika perlu).
4. Pastikan setiap string di JSON TERTUTUP SEMPURNA (tidak terpotong).
5. Array top_feature_requests maksimal 5 item, setiap item max 15 kata.
""";

    final userQuery = "Analisis feedback ini sekarang. Pastikan JSON output lengkap dan valid.";

    Future<String?> tryGroqList() async {
      final List<String> fallbackModels = [
        'llama-3.3-70b-versatile',
        'llama-3.1-8b-instant',
        'allam-2-7b',
        'groq/compound',
        'groq/compound-mini'
      ];
      for (String k in groqKeys) {
        for (String m in fallbackModels) {
          try {
            final res = await _callGroqApi(
              apiKey: k.trim(),
              model: m,
              systemPrompt: systemPrompt,
              userQuery: userQuery,
              maxTokens: 1500,
            );
            if (res != null && res.isNotEmpty) return res;
          } catch (e) {
            continue;
          }
        }
      }
      return null;
    }

    Future<String?> tryGeminiList() async {
      final List<String> fallbackModels = [
        'gemini-3.1-pro-preview',
        'gemini-2.5-flash',
        'gemini-2.0-flash',
        'gemini-2.5-flash-lite',
        'gemini-2.0-flash-lite'
      ];
      for (String k in geminiKeys) {
        for (String m in fallbackModels) {
          try {
            final model = GenerativeModel(
              model: m,
              apiKey: k.trim(),
              systemInstruction: Content.system(systemPrompt),
              generationConfig: GenerationConfig(maxOutputTokens: 1500),
            );
            final res = await model.generateContent([Content.text(userQuery)]);
            if (res.text != null && res.text!.isNotEmpty) return res.text;
          } catch (e) {
            continue;
          }
        }
      }
      return null;
    }

    try {
      String? finalAnalysis;
      if (provider == 'groq') {
        finalAnalysis = await tryGroqList() ?? await tryGeminiList();
      } else {
        finalAnalysis = await tryGeminiList() ?? await tryGroqList();
      }
      return finalAnalysis ??
          "Gagal mendapatkan respon analisis. Semua limit telah tercapai.";
    } catch (e) {
      debugPrint('Error analyzeFeedbackSentiment: $e');
      return "Terjadi kesalahan saat analisis AI: $e";
    }
  }
}
