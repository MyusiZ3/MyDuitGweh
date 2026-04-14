# Implementation Plan: AI Financial Advisor Refinement

This plan addresses the issues with the AI Financial Advisor logic, specifically focusing on the appearance of unwanted `<think>` tags in responses and improving the accuracy of financial analysis by integrating detailed debt data.

## User Review Required

> [!IMPORTANT]
> The AI responses will now be automatically filtered to remove any inner "thinking" process (tags like `<think>...</think>`). If you wish to see these for debugging purposes, let me know, but for the general UI, they will be hidden.
> tambahin juga Gr di AI Health diagnose agar responnya ga boleh kepotong dan harus full kalimatnya agar ga menggantung

> [!NOTE]
> Detailed debt information (who owes what) will now be passed to the AI. This ensures that the advisor can give much more accurate advice regarding your liabilities and receivables.

## Proposed Changes

### AI Service Layer

#### [MODIFY] [ai_service.dart](file:///c:/Users/muham/Documents/Github/MyDuitGweh/lib/services/ai_service.dart)

- Add `import '../models/debt_model.dart';`.
- Implement `_sanitizeAIResponse` private method using regex to strip `<think>` tags.
- Update `getFinancialAdvice`, `getAdvisorAnalysis`, and `getEagleEyeAnalysis` parameters to optionally accept `List<DebtModel>? debts`.
- Refine `_generateDataSummary` to include a dedicated section for "Active Debts & Receivables" with details like person names, amounts, and completion status.
- Update system instructions (all personas) to explicitly forbid outputs containing thinking tags.

### UI Layer (Reports)

#### [MODIFY] [report_screen.dart](file:///c:/Users/muham/Documents/Github/MyDuitGweh/lib/screens/report_screen.dart)

- Update `_AIAdvisorSheet` to fetch the debts stream from `firestoreService`.
- Pass the fetched debts to `AIService.getAdvisorAnalysis`.
- Update `_handleQuery` to fetch the latest debts before calling `_aiService.getFinancialAdvice`.

### UI Layer (Wallet Chat)

#### [MODIFY] [wallet_chat_screen.dart](file:///c:/Users/muham/Documents/Github/MyDuitGweh/lib/screens/wallet_chat_screen.dart)

- Ensure any AI interactions (if any in the hidden parts of the file) also utilize the sanitized input/output.

## Open Questions

- Are there any specific debt details you want the AI to prioritize? (e.g., nearing due dates, large amounts?)
- Should the AI be allowed to mention the names of people you owe money to, or should we anonymize them slightly in the summary?

## Verification Plan

### Automated Tests

- N/A (Manual UI verification preferred for AI responses)

### Manual Verification

- **Test <think> sanitization:** Trigger an AI response from a reasoning model (like Gemini Flash Thinking) and verify no `<think>` tags are visible in the chat bubbles.
- **Test Debt Accuracy:** Create a debt entry, then ask the AI advisor "How much do I owe in total?" and check if it reflects the newly created debt.
- **Persona Audit:** Switch to "Pasangan" mode and verify it still uses Kaomoji while remaining professional and emoji-free (no standard emojis).
