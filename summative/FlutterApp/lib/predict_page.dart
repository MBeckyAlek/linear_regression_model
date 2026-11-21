// The main (and only) screen: the form, the Predict button and the result.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'inputs.dart';
import 'theme.dart';

sealed class Outcome {}

class Idle extends Outcome {}

class Loading extends Outcome {}

class Success extends Outcome {
  Success(this.price, this.summary);
  final double price;
  final String summary;
}

class Failure extends Outcome {
  Failure(this.title, this.messages);
  final String title;
  final List<String> messages;
}

class PredictPage extends StatefulWidget {
  const PredictPage({super.key, required this.api, required this.isDark, required this.onToggleTheme});

  final PredictionApi api;
  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  State<PredictPage> createState() => _PredictPageState();
}

class _PredictPageState extends State<PredictPage> {
  // defaults from the design
  static const _initial = {
    Fields.deviceType: 'Solar Lantern',
    Fields.acquisition: 'Fully paid',
    Fields.yearsOwned: '2',
    Fields.county: 'Kisumu',
    Fields.locality: 'Rural',
    Fields.rooms: '3',
    Fields.mobilePhones: '2',
    Fields.ownsDwelling: 'Yes',
    Fields.gridConnected: 'No',
    Fields.hasBankAccount: 'No',
  };

  late final Map<String, TextEditingController> _controllers = {
    for (final f in Fields.all) f: TextEditingController(text: _initial[f]),
  };
  final _deviceFocus = FocusNode();
  final _countyFocus = FocusNode();
  final _resultKey = GlobalKey();

  Map<String, String> _errors = {};
  Set<String> _missing = {};
  Outcome _outcome = Idle();
  bool _slow = false;
  Timer? _slowTimer;

  @override
  void initState() {
    super.initState();
    _scrollUpWhenFocused(_deviceFocus);
    _scrollUpWhenFocused(_countyFocus);
  }

  // give the suggestion list room once the keyboard opens
  void _scrollUpWhenFocused(FocusNode node) {
    node.addListener(() {
      if (!node.hasFocus) return;
      Future.delayed(const Duration(milliseconds: 350), () {
        final ctx = node.context;
        if (mounted && node.hasFocus && ctx != null && ctx.mounted) {
          Scrollable.ensureVisible(ctx, alignment: 0.08, duration: const Duration(milliseconds: 250));
        }
      });
    });
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _deviceFocus.dispose();
    _countyFocus.dispose();
    _slowTimer?.cancel();
    super.dispose();
  }

  void _edited(String field) {
    if (_errors.containsKey(field)) {
      setState(() {
        _errors = Map.of(_errors)..remove(field);
        _missing = Set.of(_missing)..remove(field);
      });
    }
  }

  Future<void> _predict() async {
    FocusScope.of(context).unfocus();

    // catch obvious mistakes before hitting the API
    final check = checkInputs({for (final e in _controllers.entries) e.key: e.value.text});
    setState(() {
      _errors = check.errors;
      _missing = check.missing;
    });
    if (!check.isValid) {
      final n = check.errors.length;
      setState(() => _outcome =
          Failure("Can't predict yet: ${n == 1 ? '1 field needs' : '$n fields need'} fixing",
              check.errors.values.toList()));
      _revealResult();
      return;
    }

    setState(() {
      _outcome = Loading();
      _slow = false;
    });
    _slowTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _slow = true);
    });
    try {
      final price = await widget.api.predict(check.body!);
      final summary = [
        matchDeviceType(_controllers[Fields.deviceType]!.text),
        matchCounty(_controllers[Fields.county]!.text),
        (check.body![Fields.locality] as String).toLowerCase(),
      ].join(' · ');
      if (mounted) setState(() => _outcome = Success(price, summary));
    } on PredictionException catch (e) {
      if (mounted) setState(() => _outcome = Failure(e.title, e.messages));
    } finally {
      _slowTimer?.cancel();
    }
    _revealResult();
  }

  void _revealResult() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _resultKey.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final loading = _outcome is Loading;

    Widget field(String f, {String? helper, required Widget input}) => _Field(
          label: Fields.labels[f]!,
          helper: helper,
          error: _errors.containsKey(f),
          missing: _missing.contains(f),
          child: input,
        );

    Widget input(String f, {required String hint, String? unit, TextInputType? keyboard}) => _Input(
          fieldKey: ValueKey(f),
          controller: _controllers[f]!,
          hint: hint,
          unit: unit,
          keyboard: keyboard,
          error: _errors.containsKey(f),
          onChanged: (_) => _edited(f),
        );

    Widget yesNo(String f) => _YesNoRow(
          label: Fields.labels[f]!,
          input: _Input(
            fieldKey: ValueKey(f),
            controller: _controllers[f]!,
            hint: 'Yes/No',
            textAlign: TextAlign.center,
            error: _errors.containsKey(f),
            onChanged: (_) => _edited(f),
          ),
        );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (widget.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: c.background,
        systemNavigationBarIconBrightness: widget.isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: c.header,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _Header(isDark: widget.isDark, onToggleTheme: widget.onToggleTheme),
              Expanded(
                child: ColoredBox(
                  color: c.background,
                  child: GestureDetector(
                    onTap: () => FocusScope.of(context).unfocus(),
                    child: SingleChildScrollView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(20, 24, 20, 32 + MediaQuery.paddingOf(context).bottom),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('What should this solar device cost?',
                              style: TextStyle(
                                  fontSize: 28, height: 1.2, fontWeight: FontWeight.w800, color: c.text)),
                          const SizedBox(height: 8),
                          Text('Fill in the details below to get an estimate.',
                              style: TextStyle(fontSize: 16, color: c.muted)),
                          const SizedBox(height: 24),

                          const _SectionLabel('DEVICE'),
                          _Card(children: [
                            field(Fields.deviceType,
                                helper: 'Lantern, lighting system or home system',
                                input: _SuggestInput(
                                  fieldKey: const ValueKey(Fields.deviceType),
                                  controller: _controllers[Fields.deviceType]!,
                                  focusNode: _deviceFocus,
                                  options: deviceTypes.keys.toList(),
                                  hint: 'Solar Lantern',
                                  icon: Icons.wb_sunny_outlined,
                                  error: _errors.containsKey(Fields.deviceType),
                                  onChanged: (_) => _edited(Fields.deviceType),
                                )),
                            const SizedBox(height: 18),
                            field(Fields.acquisition,
                                helper: 'Fully paid or Installments',
                                input: input(Fields.acquisition, hint: 'Fully paid')),
                            const SizedBox(height: 18),
                            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Expanded(
                                child: field(Fields.yearsOwned,
                                    helper: 'Up to 30',
                                    input: input(Fields.yearsOwned,
                                        hint: '2',
                                        unit: 'years',
                                        keyboard: const TextInputType.numberWithOptions(decimal: true))),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(child: SizedBox()),
                            ]),
                          ]),
                          const SizedBox(height: 28),

                          const _SectionLabel('LOCATION'),
                          _Card(children: [
                            field(Fields.county,
                                helper: 'Start typing to search, like Kisumu',
                                input: _SuggestInput(
                                  fieldKey: const ValueKey(Fields.county),
                                  controller: _controllers[Fields.county]!,
                                  focusNode: _countyFocus,
                                  options: counties,
                                  hint: 'Kisumu',
                                  icon: Icons.location_on_outlined,
                                  error: _errors.containsKey(Fields.county),
                                  onChanged: (_) => _edited(Fields.county),
                                )),
                            const SizedBox(height: 18),
                            field(Fields.locality,
                                helper: 'Rural or Urban', input: input(Fields.locality, hint: 'Rural')),
                          ]),
                          const SizedBox(height: 28),

                          const _SectionLabel('HOUSEHOLD'),
                          _Card(children: [
                            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Expanded(
                                child: field(Fields.rooms,
                                    helper: '1 to 25',
                                    input: input(Fields.rooms,
                                        hint: '3', unit: 'rooms', keyboard: TextInputType.number)),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: field(Fields.mobilePhones,
                                    helper: '0 to 10',
                                    input: input(Fields.mobilePhones,
                                        hint: '2', unit: 'phones', keyboard: TextInputType.number)),
                              ),
                            ]),
                            const SizedBox(height: 12),
                            Divider(color: c.divider, height: 1),
                            yesNo(Fields.ownsDwelling),
                            Divider(color: c.divider, height: 1),
                            yesNo(Fields.gridConnected),
                            Divider(color: c.divider, height: 1),
                            yesNo(Fields.hasBankAccount),
                          ]),
                          const SizedBox(height: 28),

                          _PredictButton(loading: loading, slow: _slow, onPressed: _predict),
                          const SizedBox(height: 20),

                          Container(
                            key: _resultKey,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: switch (_outcome) {
                                Failure(:final title, :final messages) =>
                                  _ErrorCard(key: ValueKey(title + messages.join()), title: title, messages: messages),
                                Success(:final price, :final summary) => _PriceCard(
                                    key: ValueKey('ok$price$summary'),
                                    price: 'KES ${formatKes(price)}',
                                    summary: summary,
                                    highlight: true),
                                Loading() => const _PriceCard(
                                    key: ValueKey('loading'), price: 'KES …', summary: 'Asking the model…'),
                                Idle() => const _PriceCard(
                                    key: ValueKey('idle'),
                                    price: 'KES —',
                                    summary: 'Fill in the details and press Predict.'),
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Estimate from a model trained on 2016–2018 survey prices by the World Bank. '
                            "Today's price may differ.",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, height: 1.4, color: c.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isDark, required this.onToggleTheme});
  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 10, 10),
      decoration: BoxDecoration(color: c.header, border: Border(bottom: BorderSide(color: c.divider))),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: c.logoFill, borderRadius: BorderRadius.circular(12)),
          child: Stack(alignment: Alignment.center, children: [
            const Icon(Icons.home_rounded, color: Colors.white, size: 26),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                  width: 8, height: 8, decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle)),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        Text('Electra', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: c.text)),
        const Spacer(),
        IconButton(
          tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
          onPressed: onToggleTheme,
          icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, color: c.text),
        ),
      ]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(text,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: context.colors.muted)),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

/// Label, input and a hint that turns red on errors.
class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child, this.helper, this.error = false, this.missing = false});
  final String label;
  final Widget child;
  final String? helper;
  final bool error, missing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hint = helper == null
        ? null
        : missing
            ? 'Required, ${helper![0].toLowerCase()}${helper!.substring(1)}'
            : helper!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text)),
      const SizedBox(height: 8),
      child,
      if (hint != null)
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 2),
          child: Text(hint, style: TextStyle(fontSize: 13, color: error ? c.errorText : c.muted)),
        ),
    ]);
  }
}

class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    required this.hint,
    required this.error,
    required this.onChanged,
    this.focusNode,
    this.fieldKey,
    this.unit,
    this.icon,
    this.trailing,
    this.keyboard,
    this.textAlign = TextAlign.start,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final Key? fieldKey;
  final String hint;
  final String? unit;
  final IconData? icon, trailing;
  final bool error;
  final TextInputType? keyboard;
  final TextAlign textAlign;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: color, width: width));

    Widget? suffix;
    if (unit != null) {
      suffix = Padding(
          padding: const EdgeInsets.only(right: 16, left: 4),
          child: Text(unit!, style: TextStyle(fontSize: 15, color: c.muted)));
    } else if (trailing != null) {
      suffix = Padding(padding: const EdgeInsets.only(right: 12), child: Icon(trailing, color: c.muted));
    }

    return TextField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboard,
      textAlign: textAlign,
      textCapitalization: keyboard == null ? TextCapitalization.words : TextCapitalization.none,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: TextStyle(fontSize: 17, color: c.text),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: error ? c.errorFill : c.inputFill,
        hintText: hint,
        hintStyle: TextStyle(color: c.muted.withValues(alpha: 0.6)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        prefixIcon: icon == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 14, right: 10), child: Icon(icon, color: c.accent, size: 22)),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffix,
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        enabledBorder: border(error ? c.errorBorder : c.inputBorder, error ? 1.8 : 1),
        focusedBorder: border(error ? c.errorBorder : c.accent, 2),
        border: border(c.inputBorder, 1),
      ),
    );
  }
}

/// Text field with autocomplete (device type, county).
class _SuggestInput extends StatelessWidget {
  const _SuggestInput({
    required this.fieldKey,
    required this.controller,
    required this.focusNode,
    required this.options,
    required this.hint,
    required this.icon,
    required this.error,
    required this.onChanged,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> options;
  final String hint;
  final IconData icon;
  final bool error;
  final ValueChanged<String> onChanged;

  Iterable<String> _filter(TextEditingValue value) {
    final q = value.text.trim().toLowerCase();
    if (q.isEmpty) return options;
    final starts = options.where((o) => o.toLowerCase().startsWith(q));
    final contains = options.where((o) => !o.toLowerCase().startsWith(q) && o.toLowerCase().contains(q));
    return [...starts, ...contains];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, box) => RawAutocomplete<String>(
        textEditingController: controller,
        focusNode: focusNode,
        optionsBuilder: _filter,
        onSelected: onChanged,
        fieldViewBuilder: (context, ctl, node, onSubmit) => _Input(
          fieldKey: fieldKey,
          controller: ctl,
          focusNode: node,
          hint: hint,
          icon: icon,
          trailing: Icons.expand_more,
          error: error,
          onChanged: onChanged,
          onSubmitted: (_) => onSubmit(),
        ),
        optionsViewBuilder: (context, onSelected, opts) => Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Material(
              color: c.card,
              elevation: 8,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14), side: BorderSide(color: c.inputBorder)),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: box.maxWidth,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shrinkWrap: true,
                    itemCount: opts.length,
                    itemBuilder: (context, i) {
                      final o = opts.elementAt(i);
                      return InkWell(
                        onTap: () => onSelected(o),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                          child: Text(o, style: TextStyle(fontSize: 16, color: c.text)),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _YesNoRow extends StatelessWidget {
  const _YesNoRow({required this.label, required this.input});
  final String label;
  final Widget input;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 16, height: 1.3, color: context.colors.text))),
          const SizedBox(width: 12),
          SizedBox(width: 104, child: input),
        ]),
      );
}

class _PredictButton extends StatelessWidget {
  const _PredictButton({required this.loading, required this.slow, required this.onPressed});
  final bool loading, slow;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 58,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          disabledBackgroundColor: c.accent.withValues(alpha: 0.75),
          disabledForegroundColor: c.onAccent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14), side: BorderSide(color: c.buttonBorder, width: 2)),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        child: loading
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: c.onAccent)),
                const SizedBox(width: 12),
                Text(slow ? 'Waking up the server…' : 'Predicting…'),
              ])
            : const Text('Predict'),
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({super.key, required this.price, required this.summary, this.highlight = false});
  final String price, summary;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: highlight ? c.accent : c.cardBorder, width: highlight ? 2 : 1.5),
      ),
      child: Column(children: [
        Text('PREDICTED UPFRONT PRICE',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: c.muted)),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(price,
              style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: highlight ? c.price : c.muted.withValues(alpha: 0.7))),
        ),
        const SizedBox(height: 8),
        Text(summary, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: c.muted)),
      ]),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({super.key, required this.title, required this.messages});
  final String title;
  final List<String> messages;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.errorFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.errorBorder, width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.error_outline, color: c.errorText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: c.errorText)),
          ),
        ]),
        const SizedBox(height: 12),
        for (final m in messages)
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('•  ', style: TextStyle(fontSize: 15.5, color: c.text)),
              Expanded(child: Text(m, style: TextStyle(fontSize: 15.5, height: 1.35, color: c.text))),
            ]),
          ),
      ]),
    );
  }
}
