import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../utils/tone_dictionary.dart';
import 'package:intl/intl.dart';

class AIService {
  static const String _modelName = 'gemini-3-flash-preview';
  static const String _defaultApiKey = 'AIzaSyANErZPMI1PezicLl5lwM8LRdsuSpOiKQY';


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
    final effectiveApiKey = (apiKey == null || apiKey.trim().isEmpty) 
        ? _defaultApiKey 
        : apiKey.trim();
        
    final summary = _generateDataSummary(transactions, dateRange);

    String toneInstruction = "";
    switch (tone) {
      case AppTone.genZ:
        toneInstruction = "Pake gaya bahasa Gen-Z yang asik, banyak slang (Luh, Gue, Cuan, Boncos, Spill), sering pake emoji, dan agak frontal tapi jujur.";
        break;
      case AppTone.milenial:
        toneInstruction = "Pake gaya bahasa Milenial yang santai, campur dikit bahasa Inggris (lifestyle, cashflow, struggle), fokus ke keseimbangan hidup dan 'healing' keuangan.";
        break;
      case AppTone.boomer:
        toneInstruction = "Pake gaya bahasa orang tua yang bijak dan sangat sopan. Panggil pengguna 'Nak' atau 'Ananda', sering ucapkan 'Alhamdulillah' atau 'MasyaAllah', dan fokus ke penghematan demi masa depan.";
        break;
      default:
        toneInstruction = "Pake bahasa Indonesia yang formal tapi ramah dan profesional.";
    }

    final systemPrompt = '''
Kamu adalah "MyDuitGweh AI", asisten keuangan pintar yang profesional, ramah, dan solutif.
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

      GenerateContentResponse response;
      try {
        final model = GenerativeModel(
          model: _modelName,
          apiKey: effectiveApiKey,
          systemInstruction: Content.system(systemPrompt),
          generationConfig: GenerationConfig(temperature: 0.8, maxOutputTokens: 2048),
        );
        final chat = model.startChat(history: limitedHistory ?? []);
        response = await chat.sendMessage(Content.text(userQuery));
      } catch (e) {
        if (e.toString().contains('quota') || e.toString().contains('429')) {
          if (apiKey != null && apiKey.isNotEmpty) {
             throw Exception('QUOTA_EXCEEDED');
          }
        }
        
        // Fallbacks for internal errors/not found
        try {
          final model2 = GenerativeModel(model: 'gemini-1.5-flash-latest', apiKey: effectiveApiKey);
          final chat2 = model2.startChat(history: limitedHistory ?? []);
          final manualQuery = "$systemPrompt\n\nPertanyaan Pengguna: $userQuery";
          response = await chat2.sendMessage(Content.text(manualQuery));
        } catch (e2) {
          try {
             final model3 = GenerativeModel(model: 'gemini-1.5-flash', apiKey: effectiveApiKey);
             final chat3 = model3.startChat(history: limitedHistory ?? []);
             final manualQuery = "$systemPrompt\n\nPertanyaan Pengguna: $userQuery";
             response = await chat3.sendMessage(Content.text(manualQuery));
          } catch (e3) {
             if (e3.toString().contains('quota') || e3.toString().contains('429')) {
                throw Exception('QUOTA_EXCEEDED');
             }
             return 'Maaf, layanan AI sedang sibuk. Silakan coba lagi.';
          }
        }
      }
      
      return response.text ?? 'Maaf, jawaban kosong.';
    } catch (e) {
      if (e.toString().contains('QUOTA_EXCEEDED')) throw e;
      if (e.toString().contains('Invalid API key')) return 'API Key tidak valid.';
      return 'Terjadi kesalahan: $e';
    }
  }

  String _generateDataSummary(List<TransactionModel> transactions, DateTimeRange range) {
    double totalIncome = 0;
    double totalExpense = 0;
    Map<String, double> categoryBreakdown = {};
    
    // Group transactions
    for (var tx in transactions) {
      if (tx.isIncome) {
        totalIncome += tx.amount;
      } else {
        totalExpense += tx.amount;
        categoryBreakdown[tx.category] = (categoryBreakdown[tx.category] ?? 0) + tx.amount;
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
