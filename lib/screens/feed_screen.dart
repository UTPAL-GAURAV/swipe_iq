import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/question.dart';
import '../providers/card_provider.dart';
import '../providers/settings_provider.dart';
import '../repositories/question_repository.dart';
import '../widgets/app_header.dart';
import '../widgets/question_card.dart';

const _kQueueSize = 5;

// Right 20% of the screen is the reel-switch zone.
const double _kReelZoneFraction = 0.20;

// Minimum vertical drag distance (px) to trigger a reel switch from the zone.
const double _kReelDragThreshold = 40.0;

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _pageController = PageController();
  final _repo = QuestionRepository();

  final List<Question> _visible = [];
  final List<Question> _queue = [];

  int _currentPageIndex = 0;
  bool _isLoadingQueue = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _refillQueue();
    if (mounted && _queue.isNotEmpty) {
      setState(() => _visible.add(_queue.removeAt(0)));
      _refillQueue();
    }
  }

  Future<void> _refillQueue() async {
    if (_isLoadingQueue) return;
    _isLoadingQueue = true;
    try {
      final subjects = ref.read(selectedSubjectsProvider);
      while (_queue.length < _kQueueSize) {
        final q = await _repo.randomQuestion(subjects: subjects);
        if (!mounted) return;
        _queue.add(q);
      }
    } finally {
      _isLoadingQueue = false;
    }
  }

  void _onVerdictFor(int pageIndex, bool isPassed) {
    if (pageIndex < _currentPageIndex) return;
    final question = _visible[pageIndex];
    if (isPassed) {
      if (_queue.isNotEmpty) setState(() => _visible.add(_queue.removeAt(0)));
      _refillQueue();
    } else {
      setState(() => _visible.add(question));
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentPageIndex = index);
  }

  void _advance() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _goBack() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  bool _canSwipeForward() {
    if (_currentPageIndex >= _visible.length) return false;
    final cardState = ref.read(
        cardProvider((_currentPageIndex, _visible[_currentPageIndex])));
    return cardState.result != null;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(selectedSubjectsProvider, (_, __) {
      _queue.clear();
      _refillQueue();
    });

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          if (_visible.isEmpty)
            const Center(child: CircularProgressIndicator())
          else
            // PageView has NeverScrollableScrollPhysics — all reel navigation
            // is driven by the right-strip gesture detector below.
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _visible.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) => _CardPage(
                key: ValueKey('slot_$index'),
                slotIndex: index,
                question: _visible[index],
                onVerdictReceived: (isPassed) => _onVerdictFor(index, isPassed),
                onAdvance: _advance,
              ),
            ),

          // Right 20% strip — vertical drag switches reels.
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: _kReelZoneFraction,
                child: _ReelSwipeZone(
                  onSwipeUp: _canSwipeForward() ? _advance : null,
                  onSwipeDown: _currentPageIndex > 0 ? _goBack : null,
                  dragThreshold: _kReelDragThreshold,
                ),
              ),
            ),
          ),

          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AppHeader(),
          ),
        ],
      ),
    );
  }
}

/// Transparent overlay that detects vertical drags and fires [onSwipeUp] /
/// [onSwipeDown] once the drag exceeds [dragThreshold] pixels.
class _ReelSwipeZone extends StatefulWidget {
  final VoidCallback? onSwipeUp;
  final VoidCallback? onSwipeDown;
  final double dragThreshold;

  const _ReelSwipeZone({
    required this.onSwipeUp,
    required this.onSwipeDown,
    required this.dragThreshold,
  });

  @override
  State<_ReelSwipeZone> createState() => _ReelSwipeZoneState();
}

class _ReelSwipeZoneState extends State<_ReelSwipeZone> {
  double _dragStart = 0;
  bool _triggered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (d) {
        _dragStart = d.localPosition.dy;
        _triggered = false;
      },
      onVerticalDragUpdate: (d) {
        if (_triggered) return;
        final delta = d.localPosition.dy - _dragStart;
        if (delta < -_kReelDragThreshold && widget.onSwipeUp != null) {
          _triggered = true;
          widget.onSwipeUp!();
        } else if (delta > _kReelDragThreshold && widget.onSwipeDown != null) {
          _triggered = true;
          widget.onSwipeDown!();
        }
      },
      child: const SizedBox.expand(),
    );
  }
}

class _CardPage extends ConsumerWidget {
  final int slotIndex;
  final Question question;
  final void Function(bool isPassed) onVerdictReceived;
  final VoidCallback onAdvance;

  const _CardPage({
    super.key,
    required this.slotIndex,
    required this.question,
    required this.onVerdictReceived,
    required this.onAdvance,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(cardProvider((slotIndex, question)), (prev, next) {
      if (prev?.result == null && next.result != null) {
        onVerdictReceived(next.result!.isPassed);
      }
    });
    return QuestionCard(
      slotIndex: slotIndex,
      question: question,
      onAdvance: onAdvance,
    );
  }
}
