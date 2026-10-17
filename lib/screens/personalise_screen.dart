import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/options.dart';
import '../theme/app_theme.dart';
import '../widgets/book_parade.dart';
import '../widgets/pill.dart';
import 'pick_books_screen.dart';

/// Quick slides right after sign-up: three taste questions (pick as many
/// answers as you like) and an optional yearly reading goal. Also reopened
/// from Profile to edit your picks, without the goal slide.
class PersonaliseScreen extends StatefulWidget {
  /// True when opened from Profile: saving goes back instead of on to "Pick books".
  final bool editing;
  const PersonaliseScreen({super.key, this.editing = false});

  @override
  State<PersonaliseScreen> createState() => _PersonaliseScreenState();
}

class _PersonaliseScreenState extends State<PersonaliseScreen> with SingleTickerProviderStateMixin {
  final _pages = PageController();
  late final AnimationController _open = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  int _page = 0;
  bool _saving = false;

  Set<String> _genres = {};
  Set<String> _vibes = {};
  Set<String> _kinds = {};
  int? _goal;
  bool _loaded = false;

  int get _lastPage => widget.editing ? 2 : 3;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final profile = AppScope.of(context).profile;
    _genres = {...profile.genres};
    _vibes = {...profile.vibes};
    _kinds = {...profile.kinds};
    _goal = profile.yearlyGoal;
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _open.forward();
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    _open.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() => _page = page);
    _open.reset();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted && _page == page) _open.forward();
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final profiles = AppScope.of(context).profiles;
    await profiles.saveTaste(genres: _genres.toList(), vibes: _vibes.toList(), kinds: _kinds.toList());
    if (!widget.editing) await profiles.setYearlyGoal(_goal);
  }

  Future<void> _next() async {
    if (_page < _lastPage) {
      _pages.nextPage(duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
      return;
    }
    final navigator = Navigator.of(context);
    await _save();
    if (widget.editing) {
      navigator.pop();
    } else {
      navigator.push(MaterialPageRoute(builder: (_) => PickBooksScreen(genres: _genres.toList())));
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _skip() async {
    final profiles = AppScope.of(context).profiles;
    await _save();
    await profiles.finishOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final steps = [
      _Question(
        title: 'What genres do you love?',
        options: {for (final g in genres) g: g},
        selected: _genres,
        onToggle: (k) => setState(() => _genres.contains(k) ? _genres.remove(k) : _genres.add(k)),
      ),
      _Question(
        title: "What's your reading vibe?",
        options: vibes,
        selected: _vibes,
        onToggle: (k) => setState(() => _vibes.contains(k) ? _vibes.remove(k) : _vibes.add(k)),
      ),
      _Question(
        title: 'What kind of books do you like?',
        options: bookKinds,
        selected: _kinds,
        onToggle: (k) => setState(() => _kinds.contains(k) ? _kinds.remove(k) : _kinds.add(k)),
      ),
      if (!widget.editing)
        _GoalQuestion(
          goal: _goal,
          onPick: (g) => setState(() => _goal = g),
          onSkip: () {
            setState(() => _goal = null);
            _next();
          },
        ),
    ];
    // The goal slide is optional, so Next always works there.
    final picked = _page == 3 || [_genres, _vibes, _kinds][_page].isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 8, 0),
              child: Row(
                children: [
                  for (var i = 0; i <= _lastPage; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.only(right: 6),
                      width: i == _page ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i <= _page ? AppColors.green : scheme.outline,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  const Spacer(),
                  if (widget.editing)
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop())
                  else
                    TextButton(onPressed: _saving ? null : _skip, child: const Text('Skip')),
                ],
              ),
            ),
            Expanded(
              flex: 5,
              child: BookParade(controller: _pages, open: _open, quotes: slideQuotes.take(_lastPage + 1).toList()),
            ),
            Expanded(
              flex: 6,
              child: PageView(controller: _pages, onPageChanged: _onPageChanged, children: steps),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: FilledButton(
                onPressed: picked && !_saving ? _next : null,
                child: Text(_page < _lastPage ? 'Next' : (widget.editing ? 'Save' : 'Next: pick books you love')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Question extends StatelessWidget {
  final String title;
  final Map<String, String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const _Question({required this.title, required this.options, required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.serif(size: 28, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 6),
          Text(
            'Pick as many as you like.',
            style: AppText.sans(size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final MapEntry(:key, :value) in options.entries)
                Pill(label: value, selected: selected.contains(key), onTap: () => onToggle(key)),
            ],
          ),
        ],
      ),
    );
  }
}

/// The last slide: an optional goal for how many books to read this year.
class _GoalQuestion extends StatelessWidget {
  final int? goal;
  final ValueChanged<int?> onPick;
  final VoidCallback onSkip;

  const _GoalQuestion({required this.goal, required this.onPick, required this.onSkip});

  Future<void> _custom(BuildContext context) async {
    final controller = TextEditingController(text: goal != null && !goalChoices.contains(goal) ? '$goal' : '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Books to read this year'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. 30'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
    final value = int.tryParse(result?.trim() ?? '');
    if (value != null && value > 0) onPick(value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final custom = goal != null && !goalChoices.contains(goal);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How many books this year?', style: AppText.serif(size: 28, color: scheme.onSurface)),
          const SizedBox(height: 6),
          Text(
            'Set a reading goal. You can change it any time in Profile.',
            style: AppText.sans(size: 14, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final g in goalChoices)
                Pill(label: '$g books', selected: goal == g, onTap: () => onPick(goal == g ? null : g)),
              Pill(label: custom ? '$goal books' : 'Custom', selected: custom, onTap: () => _custom(context)),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onSkip, child: const Text('Skip for now')),
        ],
      ),
    );
  }
}
