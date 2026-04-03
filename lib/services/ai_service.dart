import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/transaction_model.dart';
import '../utils/tone_dictionary.dart';
import 'package:intl/intl.dart';

class AIService {
  static const String _modelName = 'gemini-3.1-pro-preview';
  static final ValueNotifier<String> statusNotifier = ValueNotifier("ok");

  static List<String> _integratedApiKeys = [];

  static Future<Map<String, dynamic>> getAIConfig() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('ai_config')
          .get();
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
          .get(const GetOptions(source: Source.serverAndCache));
      
      final config = configDoc.data() ?? {};
      final limit = config['max_chats_per_hour'] ?? 10;
      final resetMinutes = config['reset_duration_minutes'] ?? 60;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.serverAndCache));
      
      final data = userDoc.data() ?? {};
      final int count = data['aiCount'] ?? 0;
      final Timestamp? cycleStartTs = data['aiCycleStart'] as Timestamp?;
      final DateTime now = DateTime.now();

      // Check if cycle expired (Logic mirror from _checkUserQuota)
      if (cycleStartTs != null) {
        final cycleStart = cycleStartTs.toDate();
        if (now.difference(cycleStart).inMinutes >= resetMinutes) {
          // Cycle expired, effectively 0 in UI (next chat will trigger DB reset)
          return {'count': 0, 'limit': limit};
        }
      }

      return {
        'count': count,
        'limit': limit,
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
    try {
      // 3. Fallback Gemini Models (Updated for 2026)
      final fallbackModels = ['gemini-3.1-pro-preview', 'gemini-2.5-flash', 'gemini-2.0-flash'];
      final model = GenerativeModel(model: fallbackModels.first, apiKey: apiKey);
      // Use a more standard prompt, 2.5-flash might reject 'hi' as low-entropy or test Junk
      debugPrint('>>> Checking Gemini Key: ${apiKey.substring(0, 5)}...');
      await model.generateContent(
          [Content.text('Halo, tes koneksi API. Biarkan ini tetap singkat.')]);
      return {
        'isValid': true,
        'status': 'ok',
        'message': 'API Key bekerja dengan baik!'
      };
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      debugPrint('>>> API KEY CHECK ERROR DETAILS: $e');

      if (errorStr.contains('quota') ||
          errorStr.contains('429') ||
          errorStr.contains('exhausted') ||
          errorStr.contains('limit:') ||
          errorStr.contains('limit reached')) {
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
          errorStr.contains('role: model') ||
          errorStr.contains('content: {role: model}')) {
        debugPrint(
            '>>> SUCCESS BYPASS: Detected SDK format error but treating as OK (key works)');
        return {
          'isValid': true,
          'status': 'ok',
          'message': 'API Key bekerja (melewati bug format SDK).'
        };
      }

      return {
        'isValid': false,
        'status': 'error',
        'message': 'Gagal verifikasi: ${e.toString().split('\n').first}'
      };
    }
  }

  Future<String> getDetailedStatus(String apiKey) async {
    final status = await checkKeyStatus(apiKey);
    return status['status'] as String? ?? 'error';
  }

  Future<bool> checkQuota(String apiKey) async {
    final status = await checkKeyStatus(apiKey);
    return status['isValid'] == true;
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
        'max_tokens': 2048,
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
    try {
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {'role': 'user', 'content': 'Test. Reply OK.'}
          ],
          'max_tokens': 5,
        }),
      );
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
      } else {
        return {
          'isValid': false,
          'status': 'error',
          'message': 'Error: HTTP ${response.statusCode}'
        };
      }
    } catch (e) {
      return {
        'isValid': false,
        'status': 'error',
        'message': 'Gagal: ${e.toString().split('\n').first}'
      };
    }
  }

  Future<String> getFinancialAdvice({
    required String? apiKey,
    required List<TransactionModel> transactions,
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

    // Logic: Use personal key first, then fallback to ALL integrated keys
    final List<String> keysToUse = [];
    if (isCustomApi) {
      keysToUse.add(apiKey.trim());
    }
    keysToUse.addAll(integratedKeys);

    // Remove duplicates while preserving order
    final uniqueKeys = <String>[];
    for (var k in keysToUse) {
      if (!uniqueKeys.contains(k)) uniqueKeys.add(k);
    }

    final summary = _generateDataSummary(transactions, dateRange);

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
''';

    try {
      final limitedHistory = (history != null && history.length > 6)
          ? history.sublist(history.length - 6)
          : history;

      GenerateContentResponse? finalResponse;
      Exception? lastQuotaException;

      for (String currentKey in uniqueKeys) {
        final isLastKey = currentKey == uniqueKeys.last;
        final isPersonalKey = isCustomApi && currentKey == uniqueKeys.first;

        Future<bool> tryWithModel(String mName) async {
          try {
            debugPrint('>>> CALLING GEMINI: $mName with key ${currentKey.substring(0, 10)}...');
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
          statusNotifier.value = 'exhausted';
        } else if (isPersonalKey) {
          statusNotifier.value = 'limit';
        }
      }

      // === GROQ FALLBACK ===
      if (finalResponse == null) {
        final groqKeys = await getGroqApiKeysAsync();
        if (groqKeys.isNotEmpty) {
          debugPrint('>>> Gemini ALL LIMIT. FALLING BACK TO GROQ...');
          final groqModels = [
            'llama-3.3-70b-versatile',
            'gemma2-9b-it',
            'llama-3.1-8b-instant'
          ];
          for (String groqKey in groqKeys) {
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
                  statusNotifier.value = 'limit';
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
      List<TransactionModel> transactions, DateTimeRange range) {
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

    return '''
RINGKASAN TRANSAKSI:
- Total Pemasukan: Rp ${totalIncome.toStringAsFixed(0)}
- Total Pengeluaran: Rp ${totalExpense.toStringAsFixed(0)}
- Saldo Bersih: Rp ${(totalIncome - totalExpense).toStringAsFixed(0)}

RINCIAN PENGELUARAN PER KATEGORI:
$breakdownStr

DAFTAR TRANSAKSI TERAKHIR (Sample 20 item):
${transactions.take(20).map((t) => "[${DateFormat('dd/MM').format(t.date)}] ${t.type == 'income' ? '+' : '-'} Rp ${t.amount.toStringAsFixed(0)} (${t.category}: ${t.note})").join("\n")}
''';
  }
}
