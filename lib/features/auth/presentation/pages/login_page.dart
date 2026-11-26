import 'package:jewellery_business_manager/core/localization/language_button.dart';
import 'package:jewellery_business_manager/core/localization/copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_copy.dart';
import '../../../../core/widgets/premium_card.dart';
import '../../domain/repositories/auth_repository.dart';
import '../providers/auth_providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidden = true;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(_email.text.trim(), _password.text);
    } on SignInFailure catch (error) {
      if (mounted) {
        setState(
          () => _error = switch (error) {
            SignInFailure.credentials => AppCopy.credentialsError,
            SignInFailure.restricted => AppCopy.ownerError,
            SignInFailure.network => AppCopy.networkError,
            SignInFailure.throttled => AppCopy.throttleError,
            SignInFailure.unavailable => AppCopy.unavailable,
          },
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = AppCopy.unavailable);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(actions: const [LanguageButton()]),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 860;
            return SingleChildScrollView(
              padding: EdgeInsets.all(wide ? 32 : 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - (wide ? 64 : 40)).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: wide ? 920 : 460),
                    child: wide
                        ? Row(
                            children: [
                              const Expanded(child: _BrandPanel()),
                              const SizedBox(width: 20),
                              Expanded(
                                child: _formCard(theme, showBrand: false),
                              ),
                            ],
                          )
                        : _formCard(theme, showBrand: true),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _formCard(ThemeData theme, {required bool showBrand}) => PremiumCard(
    child: AutofillGroup(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showBrand) ...[
              const Align(alignment: Alignment.centerLeft, child: BrandMark()),
              const SizedBox(height: 18),
              Copy(AppCopy.name, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 22),
            ],
            Copy(AppCopy.signIn, style: theme.textTheme.titleLarge),
            const SizedBox(height: 7),
            Copy(AppCopy.loginHint, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 20),
            TextFormField(
              controller: _email,
              enabled: !_busy,
              autofillHints: const [
                AutofillHints.email,
                AutofillHints.username,
              ],
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: context.tr(AppCopy.email)),
              validator: (value) =>
                  RegExp(
                    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                  ).hasMatch(value?.trim() ?? '')
                  ? null
                  : context.tr(AppCopy.emailError),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              enabled: !_busy,
              obscureText: _hidden,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: context.tr(AppCopy.password),
                suffixIcon: IconButton(
                  tooltip: context.tr(
                    _hidden ? AppCopy.showPassword : AppCopy.hidePassword,
                  ),
                  onPressed: () => setState(() => _hidden = !_hidden),
                  icon: Icon(
                    _hidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) => (value ?? '').isEmpty
                  ? context.tr(AppCopy.passwordError)
                  : null,
            ),
            if (_error case final error?) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Copy(AppCopy.signIn),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(36),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: const LinearGradient(
        colors: [Color(0xff31261a), Color(0xff151411)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BrandMark(size: 74),
        const SizedBox(height: 40),
        Copy(
          AppCopy.name,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: const Color(0xfffff5de),
            height: 1.08,
          ),
        ),
        const SizedBox(height: 12),
        Copy(
          AppCopy.workspace,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: const Color(0xffddbf83)),
        ),
      ],
    ),
  );
}
