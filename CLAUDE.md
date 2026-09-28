# SwipeIQ — Project Reference

## What This App Is
A mobile app (Android + iOS) where users swipe up through interview questions like a reels feed.
User answers (text or voice), AI evaluates, verdict determines next question.

---

## Product Decisions (MVP)

- Subject selection via settings (checkbox per subject); defaults to all subjects if none selected
- Single screen + settings overlay — no full navigation stack
- Questions are pre-written, stored in local asset JSON files
- Random question selected on each new card (no history tracking, no persistence)
- Fresh random questions every time app opens — no resume, no "already seen" logic

### Feed Behavior
- Two internal lists: `_visible` (user can see) and `_queue` (prefetched, hidden)
- On boot: queue is filled with 5 questions; first question moved from queue → visible
- On **pass**: pop next from `_queue` → append to `_visible`; queue is refilled async
- On **fail**: re-append the same question to `_visible` as the next slot (fresh card state)
- User can freely scroll up and down within `_visible` (all previously seen + current card)
- Cannot scroll forward past an unanswered card
- Evaluation result is shown on the same card after AI responds
- User reads feedback, then swipes or taps button to advance

### Scroll & Gesture Model
- **Left 80% of screen**: content scroll — `SingleChildScrollView` inside each card owns this zone entirely, no gesture conflict
- **Right 20% of screen**: reel-switch zone — a transparent `_ReelSwipeZone` overlay detects vertical drag; 40px threshold triggers next/prev reel
- `PageView` uses `NeverScrollableScrollPhysics` — all reel navigation is programmatic via `PageController`
- Forward reel switch blocked if current card has no result (unanswered)
- Backward reel switch always allowed (down to first card)
- "Next Question" / "Try Again" button also calls `pageController.nextPage()` directly

### Answer Input
- Two modes: **type** or **voice**
- Voice: tap-to-record → speak → auto-submit on release
- Uses device native speech recognition via `speech_to_text` package
- AI evaluation prompt includes note about possible voice transcription errors

### AI Evaluation
- AI receives: question text + user answer + system instruction
- System instruction: evaluate for SDE-2 level, note what was said well, what was missing, give verdict (pass/fail)
- Response format: { said_well, missing, verdict }
- Verdict is either PASS or FAIL — no partial/retry-later states for MVP

---

## Question Data

### Storage
- Location: `assets/questions/`
- One JSON file per subject
- Registered in `pubspec.yaml` under flutter assets

### Subjects (MVP)
- `java.json` — Core Java concepts
- `java_advanced.json` — Advanced Java concepts
- `spring_boot.json` — Spring Boot
- `hld_concepts.json` — High Level Design concepts
- `hld_scenarios.json` — HLD scenario-based questions

### Adding a New Subject
1. Create `assets/questions/<subject>.json`
2. Register path in `pubspec.yaml`
3. Add subject name to `QuestionRepository.subjects` list
No other code changes needed.

### JSON Format
```json
[
  {
    "id": "java_001",
    "subject": "Java",
    "level": "SDE-2",
    "question": "Explain the difference between HashMap and ConcurrentHashMap."
  }
]
```

---

## Architecture

### Pattern
- **Repository** for data access (questions)
- **Service abstraction** for AI (swap providers without touching UI)
- **Riverpod** for state management
- No BLoC — Riverpod is sufficient for this scale

### Folder Structure
```
lib/
  models/
    question.dart           # Question data model
    evaluation_result.dart  # AI response model { said_well, missing, verdict }
  services/
    ai/
      ai_service.dart       # Abstract interface — AIService
      gemini_service.dart   # Gemini implementation (active)
      claude_service.dart   # Claude implementation (drop-in swap)
  repositories/
    question_repository.dart  # Loads JSONs, random selection logic
  providers/
    card_provider.dart      # CardState + CardNotifier (keyed by (slotIndex, Question))
    settings_provider.dart  # Selected subjects state
  screens/
    feed_screen.dart        # Single screen; _visible/_queue two-array feed logic; _ReelSwipeZone
  widgets/
    question_card.dart      # Full-screen card widget
    answer_input.dart       # Text + voice toggle input
    evaluation_card.dart    # Shows AI feedback + verdict
    app_header.dart         # Overlay header with settings access
assets/
  questions/
    java.json
    java_advanced.json
    spring_boot.json
    hld_concepts.json
    hld_scenarios.json
```

### AI Service Interface
```dart
abstract class AIService {
  Future<EvaluationResult> evaluate({
    required Question question,
    required Uint8List audioBytes,
  });
}
```
Swap AI provider by changing which implementation is injected in `card_provider.dart` — no UI changes needed.

### Switching AI Provider
- In `providers/card_provider.dart`, one line change:
  - `GeminiService()` → `ClaudeService()` → `OpenAIService()`

---

## UI

- **Theme**: supports both light and dark mode via `ThemeData`
- Dark mode follows system setting (no manual toggle for MVP)
- Color scheme: neutral, not purple Flutter default
- Full-screen cards (like reels), no app bar
- Minimal UI — question text, answer input, evaluation result in same card

---

## Coding Conventions

- Dart null safety enabled
- No hardcoded strings — question text lives in JSON, UI labels in constants file
- AI API key loaded from environment / config — never hardcoded
- Each subject JSON independently loadable — no shared state between files
- `speech_to_text` handles voice; AI prompt accounts for transcription imperfections
