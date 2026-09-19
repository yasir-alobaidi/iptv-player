import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/failure_message.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/onboarding/presentation/connect_result_card.dart';
import 'package:iptv_player/features/onboarding/presentation/onboarding_frame.dart';
import 'package:iptv_player/features/onboarding/presentation/onboarding_state.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/sources/domain/source_form.dart';

/// Onboarding step 2 (canvas `Onboarding · Connect`): pick the source
/// type, fill in its details, test them, then start the first sync.
///
/// The form validates inline once the user first asks to test; "Start
/// sync" appears only after a test passed, and any edit afterwards sends
/// the user back to testing.
///
/// With [editSourceId] it edits a configured source instead (Settings →
/// Sources → Edit): the same form filled in, the type fixed, the password
/// left blank to keep the saved one, and **Save** in place of Start sync.
/// Only a change to where or how it signs in needs a passing test first.
class ConnectScreen extends ConsumerStatefulWidget {
  const new({this.preset, this.editSourceId, super.key});

  /// Welcome's "Open a file instead" opens this on the M3U file type.
  final ConnectPreset? preset;

  final String? editSourceId;

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> {
  SourceType _type = SourceType.xtream;
  LiveFormat _liveFormat = LiveFormat.ts;
  var _advanced = false;

  /// Errors show once the user has tried to go on.
  var _submitted = false;
  ConnectCheck _check = const CheckIdle();
  var _saving = false;

  /// Bumped by every edit and every test, so a test result that arrives
  /// after the form changed is dropped.
  var _generation = 0;

  /// What the current or last test tried.
  SourceDraft? _tested;

  /// Set when the server field filled in the username and password from
  /// a pasted link.
  var _filledFromLink = false;

  /// Edit mode: the source being edited, once loaded, and the form as it
  /// was loaded, to tell a sign-in change from a rename.
  Source? _editing;
  SourceDraft? _loaded;

  /// Edit mode: the saved password, used by a test while the field is
  /// blank. In memory only, for as long as the screen is open.
  String? _storedPassword;
  AppFailure? _loadFailure;

  bool get _isEdit => widget.editSourceId != null;

  final _server = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _playlistUrl = TextEditingController();
  final _file = TextEditingController();
  final _name = TextEditingController();
  final _userAgent = TextEditingController();
  final _epg = TextEditingController();

  final _urlNode = FocusNode(debugLabel: 'connect url');
  final _usernameNode = FocusNode(debugLabel: 'connect username');
  final _passwordNode = FocusNode(debugLabel: 'connect password');
  final _nameNode = FocusNode(debugLabel: 'connect name');
  final _epgNode = FocusNode(debugLabel: 'connect epg');
  final _primaryNode = FocusNode(debugLabel: 'connect primary');
  final GlobalKey _cardKey = GlobalKey(debugLabel: 'connect result');

  List<TextEditingController> get _controllers => [
    _server,
    _username,
    _password,
    _playlistUrl,
    _file,
    _name,
    _userAgent,
    _epg,
  ];

  @override
  void initState() {
    super.initState();
    // Back from a cancelled or failed first sync: the form as it was.
    final pending = ref.read(pendingSourceDraftProvider);
    if (_isEdit) {
      unawaited(_loadEdit());
    } else if (pending != null) {
      _restore(pending);
    } else if (widget.preset case final preset?) {
      _type = preset.type;
      if (preset.path != null) _file.text = preset.path!;
    }
    for (final controller in _controllers) {
      controller.addListener(_onEdited);
    }
  }

  /// Edit mode: fills the form from the source and its keyring entry. A
  /// playlist URL is only in the keyring (the database keeps its origin),
  /// so it has to be read to be edited; an Xtream password is kept for
  /// tests and never shown.
  Future<void> _loadEdit() async {
    final id = widget.editSourceId!;
    final repo = ref.read(sourceRepositoryProvider);
    final found = await repo.byId(id);
    if (!mounted) return;
    final source = found.valueOrNull;
    if (source == null) {
      setState(
        () =>
            _loadFailure = found.failureOrNull ?? NotFoundFailure('source $id'),
      );
      return;
    }
    final secrets = await repo.credentialsFor(id);
    if (!mounted) return;
    final SourceCredentials? credentials;
    switch (secrets) {
      case Ok(:final value):
        credentials = value;
      // No saved password (a reset keyring): the user types it again.
      case Err(failure: AuthFailure()) when source.type == SourceType.xtream:
        credentials = null;
      case Err(:final failure):
        setState(() => _loadFailure = failure);
        return;
    }
    final draft = SourceDraft(
      type: source.type,
      name: source.name,
      url: credentials?.url ?? source.displayUrl,
      username: source.username,
      epgUrl: credentials?.epgUrl,
      userAgent: source.userAgent,
      liveFormat: source.liveFormat,
      epgOffsetMinutes: source.epgOffsetMinutes,
      refreshHours: source.refreshHours,
      maxConnectionsOverride: source.maxConnectionsOverride,
    );
    for (final controller in _controllers) {
      controller.removeListener(_onEdited);
    }
    _restore(draft);
    // The name is shown as it is, even when it matches the suggestion.
    _name.text = source.name;
    for (final controller in _controllers) {
      controller.addListener(_onEdited);
    }
    setState(() {
      _editing = source;
      _loaded = draft;
      _storedPassword = credentials?.password;
    });
  }

  /// Edit mode: true when what the source signs in with changed, which a
  /// test has to pass before it is saved.
  bool get _signInChanged {
    final loaded = _loaded;
    if (loaded == null) return true;
    final draft = _draft();
    return draft.url != loaded.url ||
        (draft.username ?? '') != (loaded.username ?? '') ||
        _password.text.isNotEmpty ||
        (draft.userAgent ?? '') != (loaded.userAgent ?? '');
  }

  void _restore(SourceDraft draft) {
    _type = draft.type;
    _liveFormat = draft.liveFormat;
    switch (draft.type) {
      case SourceType.xtream:
        _server.text = draft.url;
      case SourceType.m3uUrl:
        _playlistUrl.text = draft.url;
      case SourceType.m3uFile:
        _file.text = draft.url;
    }
    _username.text = draft.username ?? '';
    _password.text = draft.password ?? '';
    if (draft.name != suggestedSourceName(draft.type, draft.url)) {
      _name.text = draft.name;
    }
    _userAgent.text = draft.userAgent ?? '';
    _epg.text = draft.epgUrl ?? '';
    _advanced =
        (_name.text.isNotEmpty && !_isEdit) ||
        _userAgent.text.isNotEmpty ||
        _epg.text.isNotEmpty ||
        _liveFormat != LiveFormat.ts;
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in [
      _urlNode,
      _usernameNode,
      _passwordNode,
      _nameNode,
      _epgNode,
      _primaryNode,
    ]) {
      node.dispose();
    }
    super.dispose();
  }

  TextEditingController get _urlController => switch (_type) {
    SourceType.xtream => _server,
    SourceType.m3uUrl => _playlistUrl,
    SourceType.m3uFile => _file,
  };

  SourceDraft _draft() {
    final url = _urlController.text.trim();
    final name = _name.text.trim();
    final xtream = _type == SourceType.xtream;
    return SourceDraft(
      type: _type,
      name: name.isEmpty ? suggestedSourceName(_type, url) : name,
      url: url,
      username: xtream ? _username.text.trim() : null,
      password: xtream ? _password.text : null,
      epgUrl: _blankToNull(_epg.text),
      userAgent: _type == SourceType.m3uFile
          ? null
          : _blankToNull(_userAgent.text),
      liveFormat: _liveFormat,
    );
  }

  /// Any change to what would be tested makes the last result stale.
  /// Compared by value: controllers also notify when only the selection
  /// moves, and focusing a field must not cancel a test.
  void _onEdited() {
    final stale = _check is! CheckIdle && _tested != _draft();
    if (stale) {
      _generation++;
      setState(() => _check = const CheckIdle());
    } else if (_submitted || _isEdit) {
      // Inline errors follow the text; so does edit mode's "Save tests
      // the new details first".
      setState(() {});
    }
  }

  void _onServerChanged(String text) {
    final login = xtreamLinkLogin(text);
    if (login == null) {
      if (_filledFromLink) setState(() => _filledFromLink = false);
      return;
    }
    // A pasted get.php / player_api.php link: take it apart.
    _server.text = login.server;
    _username.text = login.username;
    _password.text = login.password;
    setState(() => _filledFromLink = true);
  }

  void _selectType(SourceType type) {
    if (type == _type) return;
    _generation++;
    setState(() {
      _type = type;
      _check = const CheckIdle();
      _submitted = false;
      _filledFromLink = false;
    });
  }

  Future<void> _chooseFile() async {
    final path = await ref.read(playlistFilePickerProvider)();
    if (path == null || !mounted) return;
    _file.text = path;
    _urlNode.requestFocus();
  }

  Map<DraftField, DraftProblem> _problems(SourceDraft draft) => validateDraft(
    draft,
    requirePassword: !_isEdit || _storedPassword == null,
  );

  /// What a test tries: in edit mode a blank password means the saved one.
  SourceDraft _testDraft(SourceDraft draft) =>
      _isEdit && _password.text.isEmpty && draft.type == SourceType.xtream
      ? draft.copyWith(password: _storedPassword)
      : draft;

  Future<void> _test() async {
    final draft = _draft();
    final problems = _problems(draft);
    setState(() => _submitted = true);
    if (problems.isNotEmpty) {
      _focusField(problems.keys.first);
      return;
    }
    final generation = ++_generation;
    _tested = draft;
    setState(() => _check = CheckRunning(_where(draft)));
    final result = await ref
        .read(sourceCheckerProvider)
        .check(_testDraft(draft));
    if (!mounted || generation != _generation) return;
    setState(() {
      _check = switch (result) {
        Ok(:final value) => CheckPassed(value, draft),
        Err(:final failure) => CheckFailed(failure),
      };
    });
    _afterResult();
  }

  /// The button that had focus was disabled while the test ran, and may
  /// have been replaced ("Start sync"), so focus goes to what is next once
  /// it is built; a narrow window scrolls the result card into view.
  void _afterResult() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _primaryNode.requestFocus();
      final card = _cardKey.currentContext;
      if (card != null) {
        Scrollable.ensureVisible(
          card,
          duration: context.tokens.motion.base,
          curve: context.tokens.motion.baseCurve,
        );
      }
    });
  }

  Future<void> _start() async {
    final check = _check;
    if (check is! CheckPassed || _saving) {
      await _test();
      return;
    }
    setState(() => _saving = true);
    final draft = check.draft;
    final added = await ref.read(sourceRepositoryProvider).add(draft);
    if (!mounted) return;
    switch (added) {
      case Ok(value: final source):
        ref.read(pendingSourceDraftProvider.notifier).draft = draft;
        unawaited(ref.read(syncServiceProvider).sync(source.id));
        context.go(sourceSyncPath(source.id));
      case Err(:final failure):
        setState(() {
          _saving = false;
          _check = CheckFailed(failure);
        });
        _afterResult();
    }
  }

  /// Edit mode: saves the form. A blank password keeps the saved one. A
  /// changed sign-in syncs again, since it may point at other data.
  Future<void> _save() async {
    if (_saving) return;
    final draft = _draft();
    final problems = _problems(draft);
    setState(() => _submitted = true);
    if (problems.isNotEmpty) {
      _focusField(problems.keys.first);
      return;
    }
    final resync = _signInChanged;
    if (resync && _check is! CheckPassed) {
      await _test();
      return;
    }
    setState(() => _saving = true);
    final id = widget.editSourceId!;
    final saved = await ref
        .read(sourceRepositoryProvider)
        .update(
          id,
          draft.copyWith(
            password: _password.text.isEmpty ? null : draft.password,
          ),
        );
    if (!mounted) return;
    switch (saved) {
      case Ok():
        if (resync) unawaited(ref.read(syncServiceProvider).sync(id));
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(AppDestination.settings.path);
        }
      case Err(:final failure):
        setState(() {
          _saving = false;
          _check = CheckFailed(failure);
        });
        _afterResult();
    }
  }

  /// Enter in any field: test, or start once the test has passed. When
  /// editing: save, which tests first if the sign-in changed.
  void _submit() {
    if (_isEdit) {
      unawaited(_save());
      return;
    }
    unawaited(_check is CheckPassed ? _start() : _test());
  }

  Future<void> _back() async {
    if (!_isEdit) ref.read(pendingSourceDraftProvider.notifier).draft = null;
    if (context.canPop()) {
      context.pop();
      return;
    }
    if (_isEdit) {
      context.go(AppDestination.settings.path);
      return;
    }
    final back = ref.read(onboardingReturnPathProvider);
    final sources = await ref.read(sourceRepositoryProvider).all();
    if (!mounted) return;
    final any = sources.valueOrNull?.isNotEmpty ?? false;
    context.go(any ? back ?? '/' : welcomeRoutePath);
  }

  void _focusField(DraftField field) {
    final node = switch (field) {
      DraftField.url => _urlNode,
      DraftField.username => _usernameNode,
      DraftField.password => _passwordNode,
      DraftField.name => _nameNode,
      DraftField.epgUrl => _epgNode,
      _ => _urlNode,
    };
    if ((field == DraftField.name && !_isEdit) || field == DraftField.epgUrl) {
      setState(() => _advanced = true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => node.requestFocus());
  }

  static String _where(SourceDraft draft) {
    if (draft.type == SourceType.m3uFile) {
      return draft.url.split(RegExp(r'[/\\]')).last;
    }
    final server = draft.type == SourceType.xtream
        ? normalizeServerUrl(draft.url)
        : draft.url;
    return Uri.tryParse(server ?? '')?.host ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final spacing = tokens.spacing;
    final narrow = MediaQuery.sizeOf(context).width < onboardingNarrowWidth;
    final draft = _draft();
    final problems = _submitted
        ? _problems(draft)
        : const <DraftField, DraftProblem>{};
    final checking = _check is CheckRunning;
    final passed = _check is CheckPassed;

    final card = ConnectResultCard(
      key: _cardKey,
      type: _type,
      check: _check,
      now: ref.watch(onboardingClockProvider)(),
    );
    final form = _form(context, problems, card: narrow ? card : null);

    if (_isEdit) return _editFrame(context, form, card, narrow: narrow);

    return OnboardingFrame(
      step: 1,
      title: 'Connect your provider',
      subtitle:
          'Your password is kept in your system keychain, never in the '
          "app's files.",
      body: narrow
          ? form
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 620, child: form),
                SizedBox(width: spacing.s48),
                Expanded(
                  child: Center(child: SingleChildScrollView(child: card)),
                ),
              ],
            ),
      footer: OnboardingFooter(
        leading: AppButton(
          label: 'Back',
          variant: AppButtonVariant.ghost,
          size: AppButtonSize.l,
          onPressed: _saving ? null : () => unawaited(_back()),
        ),
        actions: [
          if (passed)
            AppButton(
              label: 'Test again',
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.l,
              onPressed: _saving ? null : () => unawaited(_test()),
            ),
          if (passed)
            AppButton(
              label: 'Start sync',
              trailingIcon: AppIcons.arrowRight,
              size: AppButtonSize.l,
              focusNode: _primaryNode,
              loading: _saving,
              onPressed: () => unawaited(_start()),
            )
          else
            AppButton(
              label: _check is CheckFailed ? 'Test again' : 'Test connection',
              size: AppButtonSize.l,
              focusNode: _primaryNode,
              loading: checking,
              onPressed: () => unawaited(_test()),
            ),
        ],
      ),
    );
  }

  /// Edit mode's page: no step indicator, the source's name in the
  /// title, and Test connection beside Save.
  Widget _editFrame(
    BuildContext context,
    Widget form,
    Widget card, {
    required bool narrow,
  }) {
    final spacing = context.tokens.spacing;
    final source = _editing;
    final back = AppButton(
      label: 'Back',
      variant: AppButtonVariant.ghost,
      size: AppButtonSize.l,
      onPressed: _saving ? null : () => unawaited(_back()),
    );

    if (_loadFailure case final failure?) {
      return OnboardingFrame(
        title: 'Edit source',
        subtitle: 'Change how this source signs in, or what it is called.',
        body: ErrorState(
          title: "Couldn't open this source",
          message: failureMessage(failure),
          details: failure.detail,
          onRetry: () {
            setState(() => _loadFailure = null);
            unawaited(_loadEdit());
          },
        ),
        footer: OnboardingFooter(leading: back, actions: const []),
      );
    }
    if (source == null) {
      return OnboardingFrame(
        title: 'Edit source',
        subtitle: 'Change how this source signs in, or what it is called.',
        body: Semantics(
          label: 'Loading the source',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < 3; i++) ...[
                const Skeleton(width: 620, height: 56),
                SizedBox(height: spacing.s16),
              ],
            ],
          ),
        ),
        footer: OnboardingFooter(leading: back, actions: const []),
      );
    }

    final checking = _check is CheckRunning;
    return OnboardingFrame(
      title: 'Edit ${source.name}',
      subtitle: source.type == SourceType.xtream
          ? 'Leave the password empty to keep the saved one. A new server '
                'or sign-in is tested before it is saved.'
          : 'A new playlist is tested before it is saved.',
      body: narrow
          ? form
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 620, child: form),
                SizedBox(width: spacing.s48),
                Expanded(
                  child: Center(child: SingleChildScrollView(child: card)),
                ),
              ],
            ),
      footer: OnboardingFooter(
        leading: back,
        note: _signInChanged && _check is! CheckPassed
            ? 'Save tests the new details first.'
            : null,
        actions: [
          AppButton(
            label: _check is CheckIdle ? 'Test connection' : 'Test again',
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.l,
            loading: checking,
            onPressed: _saving ? null : () => unawaited(_test()),
          ),
          AppButton(
            label: 'Save',
            size: AppButtonSize.l,
            focusNode: _primaryNode,
            loading: _saving,
            onPressed: checking ? null : () => unawaited(_save()),
          ),
        ],
      ),
    );
  }

  Widget _form(
    BuildContext context,
    Map<DraftField, DraftProblem> problems, {
    Widget? card,
  }) {
    final tokens = context.tokens;
    final spacing = tokens.spacing;
    final gap = SizedBox(height: spacing.s20 + 2);

    return FocusTraversalGroup(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_isEdit) ...[
              Row(
                children: [
                  for (final (index, type) in SourceType.values.indexed) ...[
                    if (index > 0) SizedBox(width: spacing.s8 + 2),
                    Expanded(
                      child: ChoiceCard(
                        title: _typeTitle(type),
                        subtitle: _typeSubtitle(type),
                        selected: type == _type,
                        onPressed: () => _selectType(type),
                      ),
                    ),
                  ],
                ],
              ),
              gap,
            ],
            ..._fields(context, problems),
            // Renaming is the commonest edit, so it isn't tucked away.
            if (_isEdit) ...[
              SizedBox(height: spacing.s16 - 2),
              _nameField(problems),
            ],
            SizedBox(height: spacing.s16),
            _AdvancedToggle(
              open: _advanced,
              label: switch ((_type, _isEdit)) {
                (SourceType.xtream, false) =>
                  'Advanced: name, User-Agent, guide link, live format',
                (SourceType.xtream, true) =>
                  'Advanced: User-Agent, guide link, live format',
                (SourceType.m3uUrl, false) =>
                  'Advanced: name, User-Agent, guide link',
                (SourceType.m3uUrl, true) => 'Advanced: User-Agent, guide link',
                (SourceType.m3uFile, false) => 'Advanced: name, guide link',
                (SourceType.m3uFile, true) => 'Advanced: guide link',
              },
              onPressed: () => setState(() => _advanced = !_advanced),
            ),
            if (_advanced) ...[
              SizedBox(height: spacing.s16),
              ..._advancedFields(context, problems),
            ],
            if (card != null) ...[gap, card],
          ],
        ),
      ),
    );
  }

  List<Widget> _fields(
    BuildContext context,
    Map<DraftField, DraftProblem> problems,
  ) {
    final spacing = context.tokens.spacing;
    final url = AppTextField(
      key: ValueKey('url-${_type.name}'),
      controller: _urlController,
      focusNode: _urlNode,
      autofocus: _urlController.text.isEmpty,
      label: switch (_type) {
        SourceType.xtream => 'Server address',
        SourceType.m3uUrl => 'Playlist URL',
        SourceType.m3uFile => 'Playlist file',
      },
      hint: switch (_type) {
        SourceType.xtream => 'http://line.example-provider.tv:8080',
        SourceType.m3uUrl => 'http://lists.example-provider.tv/get.php?…',
        SourceType.m3uFile => 'Choose a file, or type its path',
      },
      keyboardType: _type == SourceType.m3uFile ? null : TextInputType.url,
      errorText: _urlError(problems[DraftField.url]),
      helperText: _filledFromLink
          ? 'Filled in the username and password from the link.'
          : null,
      onChanged: _type == SourceType.xtream ? _onServerChanged : null,
      onSubmitted: (_) => _submit(),
    );

    return switch (_type) {
      SourceType.xtream => [
        url,
        SizedBox(height: spacing.s16 - 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                controller: _username,
                focusNode: _usernameNode,
                label: 'Username',
                errorText: problems.containsKey(DraftField.username)
                    ? 'Enter your username.'
                    : null,
                onSubmitted: (_) => _submit(),
              ),
            ),
            SizedBox(width: spacing.s16 - 2),
            Expanded(
              child: AppTextField(
                controller: _password,
                focusNode: _passwordNode,
                label: 'Password',
                obscure: true,
                showClear: false,
                hint: _isEdit && _storedPassword != null
                    ? 'Saved; leave empty to keep it'
                    : null,
                errorText: problems.containsKey(DraftField.password)
                    ? 'Enter your password.'
                    : null,
                onSubmitted: (_) => _submit(),
              ),
            ),
          ],
        ),
      ],
      SourceType.m3uUrl => [url],
      SourceType.m3uFile => [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: url),
            SizedBox(width: spacing.s12),
            Padding(
              // Level with the field, not with its error line.
              padding: EdgeInsets.only(
                bottom: problems.containsKey(DraftField.url) ? spacing.s24 : 0,
              ),
              child: AppButton(
                label: 'Choose file',
                icon: AppIcons.folder,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.l,
                onPressed: () => unawaited(_chooseFile()),
              ),
            ),
          ],
        ),
      ],
    };
  }

  List<Widget> _advancedFields(
    BuildContext context,
    Map<DraftField, DraftProblem> problems,
  ) {
    final spacing = context.tokens.spacing;
    final gap = SizedBox(height: spacing.s16 - 2);
    return [
      if (!_isEdit) _nameField(problems),
      if (_type != SourceType.m3uFile) ...[
        if (!_isEdit) gap,
        AppTextField(
          controller: _userAgent,
          label: 'User-Agent',
          hint: 'Leave empty unless your provider asks for one',
          onSubmitted: (_) => _submit(),
        ),
      ],
      if (!_isEdit || _type != SourceType.m3uFile) gap,
      AppTextField(
        controller: _epg,
        focusNode: _epgNode,
        label: 'Guide (EPG) link',
        hint: "Leave empty to use your provider's guide",
        keyboardType: TextInputType.url,
        errorText: problems.containsKey(DraftField.epgUrl)
            ? 'Enter a web address that starts with http:// or https://.'
            : null,
        onSubmitted: (_) => _submit(),
      ),
      if (_type == SourceType.xtream) ...[
        gap,
        _LiveFormatChoice(
          value: _liveFormat,
          onChanged: (format) => setState(() => _liveFormat = format),
        ),
      ],
    ];
  }

  Widget _nameField(Map<DraftField, DraftProblem> problems) => AppTextField(
    controller: _name,
    focusNode: _nameNode,
    label: 'Name',
    hint: suggestedSourceName(_type, _urlController.text),
    errorText: problems[DraftField.name] == DraftProblem.tooLong
        ? 'Keep the name under $maxSourceNameLength characters.'
        : null,
    onSubmitted: (_) => _submit(),
  );

  String? _urlError(DraftProblem? problem) => switch ((problem, _type)) {
    (null, _) => null,
    (DraftProblem.missing, SourceType.xtream) => 'Enter the server address.',
    (DraftProblem.missing, SourceType.m3uUrl) => 'Enter the playlist URL.',
    (DraftProblem.missing, SourceType.m3uFile) => 'Choose a playlist file.',
    (_, SourceType.xtream) =>
      'Enter a web address, like http://line.example.tv:8080.',
    (_, _) => 'Enter a web address that starts with http:// or https://.',
  };

  static String _typeTitle(SourceType type) => switch (type) {
    SourceType.xtream => 'Xtream Codes',
    SourceType.m3uUrl => 'M3U link',
    SourceType.m3uFile => 'M3U file',
  };

  static String _typeSubtitle(SourceType type) => switch (type) {
    SourceType.xtream => 'Server, username, password',
    SourceType.m3uUrl => 'Playlist URL',
    SourceType.m3uFile => 'From this computer',
  };
}

class _AdvancedToggle extends StatelessWidget {
  const new({required this.open, required this.label, required this.onPressed});

  final bool open;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        expanded: open,
        child: FocusableSurface(
          onPressed: onPressed,
          semanticLabel: label,
          builder: (context, states) => Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.s4,
              vertical: tokens.spacing.s4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(
                  open ? AppIcons.chevronDown : AppIcons.chevronRight,
                  size: 14,
                  color: states.highlighted
                      ? colors.textPrimary
                      : colors.textSecondary,
                ),
                SizedBox(width: tokens.spacing.s8),
                Text(
                  label,
                  style: tokens.text.caption
                      .withWeight(700)
                      .copyWith(
                        color: states.highlighted
                            ? colors.textPrimary
                            : colors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveFormatChoice extends StatelessWidget {
  const new({required this.value, required this.onChanged});

  final LiveFormat value;
  final ValueChanged<LiveFormat> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Live format',
          style: tokens.text.label.copyWith(color: colors.textSecondary),
        ),
        SizedBox(height: tokens.spacing.s8),
        Row(
          children: [
            SegmentedControl<LiveFormat>(
              options: const [
                SegmentOption(value: LiveFormat.ts, label: 'TS'),
                SegmentOption(value: LiveFormat.hls, label: 'HLS'),
              ],
              value: value,
              onChanged: onChanged,
            ),
            SizedBox(width: tokens.spacing.s12),
            Flexible(
              child: Text(
                'TS starts faster and switches channels quicker.',
                style: tokens.text.caption.copyWith(color: colors.textTertiary),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String? _blankToNull(String text) {
  final trimmed = text.trim();
  return trimmed.isEmpty ? null : trimmed;
}
