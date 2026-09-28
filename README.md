# SwipeIQ

A mobile app (Android + iOS) for technical interview practice. Questions appear as a vertical swipe feed — answer by voice, AI evaluates, pass to move on or retry on fail.

---

## External Services

### Google Cloud Speech-to-Text
- **What it does**: Transcribes the candidate's voice recording to text
- **API**: `https://speech.googleapis.com/v1/speech:recognize`
- **Audio format**: WAV (LINEAR16, 16kHz mono)
- **Model**: `latest_long`
- **Auth**: Service account (`assets/service_account.json`) — not committed to git
- **Console**: console.cloud.google.com → APIs & Services → Cloud Speech-to-Text API

### Claude (Anthropic)
- **What it does**: Evaluates the transcript against the question, returns verdict (PASS/FAIL) + feedback
- **API**: `https://api.anthropic.com/v1/messages`
- **Model**: `claude-haiku-4-5-20251001`
- **Auth**: `ANTHROPIC_API_KEY` in `.env` — not committed to git
- **Dashboard**: console.anthropic.com

### Sentry
- **What it does**: Error monitoring — captures exceptions with stack traces and question context
- **SDK**: `sentry_flutter`
- **DSN**: stored in `.env` as `SENTRY_DSN` — not committed to git
- **Dashboard**: sentry.io

---

## Setup

### Prerequisites
- Flutter SDK
- Android Studio / Xcode
- Google Cloud project with billing enabled
- Sentry account (free tier is fine)

### Credentials

Two files are required locally but excluded from git:

**`.env`** — in project root:
```
ANTHROPIC_API_KEY=sk-ant-...
SENTRY_DSN=https://your-key@oXXXX.ingest.sentry.io/XXXX
```

> **Note**: `.env` may also contain `GEMINI_API_KEY` and `GOOGLE_GEMINI_API_KEY` from earlier experiments. These are **not used** — `GEMINI_API_KEY` (AI Studio) was abandoned due to a 20 requests/day free tier cap. The app uses Google Cloud STT (service account) + Claude API (Anthropic key) for evaluation.

**`assets/service_account.json`** — Google Cloud service account key:
- Go to Google Cloud Console → IAM & Admin → Service Accounts
- Create a service account with role: `Cloud Speech-to-Text Service Agent`
- Create a JSON key and place it at `assets/service_account.json`

### Google Cloud APIs to enable
In your Google Cloud project, enable:
1. **Cloud Speech-to-Text API**

### Run
```bash
flutter pub get
flutter run
```

---

## Adding New Question Topics

No code logic changes needed — just three steps:

1. **Create the JSON file** at `assets/questions/<topic>.json`:
   ```json
   [
     {
       "id": "kafka_001",
       "subject": "Kafka",
       "level": "SDE-2",
       "question": "Explain how Kafka achieves high throughput."
     }
   ]
   ```
   The `subject` field must match exactly what you'll put in step 3.

2. **Register the asset** in `pubspec.yaml` under `flutter > assets`:
   ```yaml
       - assets/questions/kafka.json
   ```

3. **Add the subject name** to `kAllSubjects` in `lib/providers/settings_provider.dart`:
   ```dart
   const kAllSubjects = ['Java', 'Spring Boot', 'HLD Concepts', 'HLD Scenarios', 'Kafka'];
   ```

The new topic will appear as a checkbox in Settings and questions will start showing in the feed immediately.

---

## Architecture

```
lib/
  models/
    question.dart             # Question data model
    evaluation_result.dart    # AI response model { transcript, said_well, expected_answer, verdict }
  services/
    google_auth_client.dart   # Shared service account auth (googleapis_auth)
    stt_service.dart          # Google Cloud Speech-to-Text
    ai/
      ai_service.dart         # Abstract interface
      claude_service.dart     # Claude/Anthropic (active — evaluation)
      vertex_gemini_service.dart  # Vertex Gemini (inactive)
      gemini_service.dart     # AI Studio Gemini (legacy, unused)
  repositories/
    question_repository.dart  # Loads JSONs, random selection
  providers/
    card_provider.dart        # CardState + CardNotifier; orchestrates STT → Claude
    settings_provider.dart    # Selected subjects state
  screens/
    feed_screen.dart          # Single screen; two-array feed logic
  widgets/
    question_card.dart
    answer_input.dart
    evaluation_card.dart
    app_header.dart
assets/
  questions/                  # One JSON file per subject
  service_account.json        # Google Cloud credentials (not in git)
```

### Evaluation flow
1. User records voice answer (`record` package → `.m4a` file)
2. Audio bytes → Google Cloud STT → transcript text
3. Transcript + question → Claude API (Anthropic) → `{ said_well, expected_answer, verdict }`
4. Result displayed on card; PASS advances feed, FAIL re-queues same question
