import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/transaction_model.dart';
import '../utils/tone_dictionary.dart';
import 'package:intl/intl.dart';

class AIService {
  static const String _modelName = 'gemini-3-flash-preview';
  static final List<String> _integratedApiKeys = [
    'AIzaSyANErZPMI1PezicLl5lwM8LRdsuSpOiKQY',
    'AIzaSyAOt1e72ijkbkaA73wefa_dCX9YqguxOvo',
    'AIzaSyDpnZI5UroCEK7K7BgzXGAeZHUQxyF01nM',
  ];

  // Common Indonesian female name patterns/prefixes
  static const List<String> _femaleNamePatterns = [
    'siti',
    'nur',
    'sri',
    'dewi',
    'rina',
    'ani',
    'lina',
    'wati',
    'yuni',
    'ratna',
    'indah',
    'sari',
    'putri',
    'ayu',
    'dian',
    'eka',
    'fitri',
    'nita',
    'maya',
    'lia',
    'tia',
    'nia',
    'mia',
    'rini',
    'wulan',
    'mega',
    'intan',
    'citra',
    'novia',
    'vina',
    'yanti',
    'lestari',
    'rahayu',
    'dwi',
    'tri',
    'linda',
    'sarah',
    'maria',
    'anna',
    'lisa',
    'rosa',
    'diana',
    'jessica',
    'angel',
    'grace',
    'bella',
    'nadia',
    'nadya',
    'farah',
    'zahra',
    'aisyah',
    'karin',
    'karen',
    'melani',
    'selvi',
    'silvi',
    'tina',
    'mila',
    'della',
    'stella',
    'aulia',
    'nazwa',
    'naura',
    'salsa',
    'nabila',
    'cantika',
    'anisa',
    'annisa',
    'rahma',
    'tasya',
    'tiara',
    'bunga',
    'mawar',
    'melati',
    'dahlia',
    'cinta',
    'kasih',
    'kartika',
    'lusi',
    'suci',
    'mutiara',
    'permata',
    'berlian',
    'safira',
    'amanda',
    'chelsea',
    'patricia',
    'natasha',
    'felicia',
    'olivia',
    'sophia',
    'keisha',
    'alesha',
    'aqila',
    'shinta',
    'laras',
    'galuh',
    'retno',
    'endang',
    'ningsih',
    'wulandari',
    'handayani',
    'puspita',
    'novita',
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
      final model = GenerativeModel(model: _modelName, apiKey: apiKey);
      // Minimal request to check key validity
      await model.generateContent([Content.text('hi')],
          generationConfig: GenerationConfig(maxOutputTokens: 1));
      return {
        'isValid': true,
        'status': 'ok',
        'message': 'API Key bekerja dengan baik!'
      };
    } catch (e) {
      debugPrint('Detailed Key Check failed: $e');
      final errorStr = e.toString().toLowerCase();

      if (errorStr.contains('quota') || errorStr.contains('429')) {
        return {
          'isValid': true,
          'status': 'limit',
          'message':
              'API Key valid, tapi sedang mencapai limit (Quota Exceeded).'
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

      if (errorStr.contains('not found')) {
        return {
          'isValid': true,
          'status': 'ok',
          'message': 'API Key valid (Model mungkin berbeda).'
        };
      }

      return {
        'isValid': false,
        'status': 'error',
        'message': 'Terjadi kesalahan koneksi atau internal.'
      };
    }
  }

  Future<bool> checkQuota(String apiKey) async {
    final status = await checkKeyStatus(apiKey);
    return status['status'] == 'ok';
  }

  // Helper to expose integrated keys status check
  List<String> getIntegratedKeys() => _integratedApiKeys;

  Future<String> getFinancialAdvice({
    required String? apiKey,
    required List<TransactionModel> transactions,
    required String userQuery,
    required DateTimeRange dateRange,
    AppTone tone = AppTone.normal,
    List<Content>? history,
  }) async {
    final isCustomApi = apiKey != null && apiKey.trim().isNotEmpty;
    final keysToUse = isCustomApi ? [apiKey.trim()] : _integratedApiKeys;

    final summary = _generateDataSummary(transactions, dateRange);

    // Get user name and gender for pasangan mode
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
            "Pake gaya bahasa Gen-Z yang asik, banyak slang (Luh, Gue, Cuan, Boncos, Spill), sering pake emoji, dan agak frontal tapi jujur.";
        break;
      case AppTone.milenial:
        toneInstruction =
            "Pake gaya bahasa Milenial yang santai, campur dikit bahasa Inggris (lifestyle, cashflow, struggle), fokus ke keseimbangan hidup dan 'healing' keuangan.";
        break;
      case AppTone.boomer:
        toneInstruction =
            "Pake gaya bahasa orang tua yang bijak dan sangat sopan. Panggil pengguna 'Nak' atau 'Ananda', sering ucapkan 'Alhamdulillah' atau 'MasyaAllah', dan fokus ke penghematan demi masa depan.";
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

      for (String currentKey in keysToUse) {
        try {
          final model = GenerativeModel(
            model: _modelName,
            apiKey: currentKey,
            systemInstruction: Content.system(systemPrompt),
            generationConfig:
                GenerationConfig(temperature: 0.8, maxOutputTokens: 2048),
          );
          final chat = model.startChat(history: limitedHistory ?? []);
          finalResponse = await chat.sendMessage(Content.text(userQuery));
          break; // success
        } catch (e) {
          lastQuotaException = e is Exception ? e : Exception(e.toString());
          if (e.toString().contains('quota') || e.toString().contains('429')) {
            continue; // Immediately try next key
          }
          // If not quota, try fallback model
          try {
            final model2 =
                GenerativeModel(model: 'gemini-2.5-flash', apiKey: currentKey);
            final chat2 = model2.startChat(history: limitedHistory ?? []);
            final manualQuery =
                "$systemPrompt\n\nPertanyaan Pengguna: $userQuery";
            finalResponse = await chat2.sendMessage(Content.text(manualQuery));
            break;
          } catch (e2) {
            lastQuotaException =
                e2 is Exception ? e2 : Exception(e2.toString());
            continue; // Try next key
          }
        }
      }

      if (finalResponse == null) {
        if (lastQuotaException != null) {
          debugPrint(
              'All keys exhausted or failed. Last exception: $lastQuotaException');
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
          // Throw so that the report screen can switch to another user custom key if available
          throw Exception('QUOTA_EXCEEDED');
        } else {
          return 'Maaf, seluruh token AI bawaan sedang mencapai batas wajar (Limit). Agar tetap bisa berkonsultasi, kami sarankan masukkan API Key milik Anda sendiri (Gratis) di menu Kelola API.';
        }
      }

      return finalResponse.text ?? 'Maaf, jawaban kosong.';
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
