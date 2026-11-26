// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(notificationRepository)
final notificationRepositoryProvider = NotificationRepositoryProvider._();

final class NotificationRepositoryProvider
    extends
        $FunctionalProvider<
          NotificationRepository,
          NotificationRepository,
          NotificationRepository
        >
    with $Provider<NotificationRepository> {
  NotificationRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationRepositoryHash();

  @$internal
  @override
  $ProviderElement<NotificationRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NotificationRepository create(Ref ref) {
    return notificationRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationRepository>(value),
    );
  }
}

String _$notificationRepositoryHash() =>
    r'1f1b85c0ead77cda7e21ebb1f93cbc2f5fe7a9f5';

@ProviderFor(browserPush)
final browserPushProvider = BrowserPushProvider._();

final class BrowserPushProvider
    extends $FunctionalProvider<BrowserPush, BrowserPush, BrowserPush>
    with $Provider<BrowserPush> {
  BrowserPushProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'browserPushProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$browserPushHash();

  @$internal
  @override
  $ProviderElement<BrowserPush> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BrowserPush create(Ref ref) {
    return browserPush(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BrowserPush value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BrowserPush>(value),
    );
  }
}

String _$browserPushHash() => r'4b1049f178f770fa2f5110d37f60eb869cf6a319';

@ProviderFor(notices)
final noticesProvider = NoticesFamily._();

final class NoticesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Notice>>,
          List<Notice>,
          Stream<List<Notice>>
        >
    with $FutureModifier<List<Notice>>, $StreamProvider<List<Notice>> {
  NoticesProvider._({
    required NoticesFamily super.from,
    required NoticeFolder super.argument,
  }) : super(
         retry: null,
         name: r'noticesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$noticesHash();

  @override
  String toString() {
    return r'noticesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Notice>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Notice>> create(Ref ref) {
    final argument = this.argument as NoticeFolder;
    return notices(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is NoticesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$noticesHash() => r'fe3ed600b67e9e0e661347359dfada88235b3186';

final class NoticesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Notice>>, NoticeFolder> {
  NoticesFamily._()
    : super(
        retry: null,
        name: r'noticesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  NoticesProvider call(NoticeFolder folder) =>
      NoticesProvider._(argument: folder, from: this);

  @override
  String toString() => r'noticesProvider';
}

@ProviderFor(unreadNotices)
final unreadNoticesProvider = UnreadNoticesProvider._();

final class UnreadNoticesProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  UnreadNoticesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'unreadNoticesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$unreadNoticesHash();

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    return unreadNotices(ref);
  }
}

String _$unreadNoticesHash() => r'cba6163597df57faca3e52810993de57a78ca7b4';

@ProviderFor(reminderRules)
final reminderRulesProvider = ReminderRulesProvider._();

final class ReminderRulesProvider
    extends
        $FunctionalProvider<
          AsyncValue<ReminderRules>,
          ReminderRules,
          Stream<ReminderRules>
        >
    with $FutureModifier<ReminderRules>, $StreamProvider<ReminderRules> {
  ReminderRulesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reminderRulesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reminderRulesHash();

  @$internal
  @override
  $StreamProviderElement<ReminderRules> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<ReminderRules> create(Ref ref) {
    return reminderRules(ref);
  }
}

String _$reminderRulesHash() => r'48f222d4d884559bbaefda60a20efbbcf87b4bdb';
