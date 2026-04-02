import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/material.dart';
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

  Future<bool> checkQuota(String apiKey) async {
    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
      // Minimal request to check key
      await model.generateContent([Content.text('hi')]);
      return true; // Works
    } catch (e) {
      debugPrint('Quota check failed: $e');
      if (e.toString().contains('quota') || e.toString().contains('429')) {
        return false; // Limited
      }
      return true; // Other error, but keep as "not limited" for now
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
    final keysToUse = isCustomApi ? [apiKey.trim()] : _integratedApiKeys;

    final summary = _generateDataSummary(transactions, dateRange);

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
          // If not quota, try fallback models
          try {
            final model2 = GenerativeModel(
                model: 'gemini-1.5-flash-latest', apiKey: currentKey);
            final chat2 = model2.startChat(history: limitedHistory ?? []);
            final manualQuery =
                "$systemPrompt\n\nPertanyaan Pengguna: $userQuery";
            finalResponse = await chat2.sendMessage(Content.text(manualQuery));
            break;
          } catch (e2) {
            try {
              final model3 = GenerativeModel(
                  model: 'gemini-1.5-flash', apiKey: currentKey);
              final chat3 = model3.startChat(history: limitedHistory ?? []);
              final manualQuery =
                  "$systemPrompt\n\nPertanyaan Pengguna: $userQuery";
              finalResponse =
                  await chat3.sendMessage(Content.text(manualQuery));
              break;
            } catch (e3) {
              lastQuotaException =
                  e3 is Exception ? e3 : Exception(e3.toString());
              continue; // Try next key
            }
          }
        }
      }

      if (finalResponse == null) {
        if (lastQuotaException != null) {
          debugPrint(
              'All keys exhausted or failed. Last exception: $lastQuotaException');
        }
        if (isCustomApi) {
          if (lastQuotaException.toString().toLowerCase().contains('invalid') ||
              lastQuotaException
                  .toString()
                  .toLowerCase()
                  .contains('api key not valid')) {
            return 'API Key tidak valid.';
          }
          // Throw so that the report screen can switch to another user custom key if available
          throw Exception('QUOTA_EXCEEDED');
        } else {
          if (lastQuotaException.toString().toLowerCase().contains('invalid') ||
              lastQuotaException
                  .toString()
                  .toLowerCase()
                  .contains('api key not valid')) {
            return 'Terjadi masalah pada konfigurasi token bawaan aplikasi. Coba gunakan API Key milik Anda sendiri di halaman Kelola API.';
          }
          return 'Maaf, seluruh token AI bawaan sedang mencapai batas wajar (Limit). Silakan tunggu beberapa saat atau gunakan API Key milik Anda sendiri di halaman Kelola API.';
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
