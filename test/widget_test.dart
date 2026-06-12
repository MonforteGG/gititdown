import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gititdown/core/error/failures.dart';
import 'package:gititdown/domain/entities/user_config.dart';
import 'package:gititdown/domain/repositories/local_storage_repository.dart';
import 'package:gititdown/main.dart';
import 'package:gititdown/presentation/providers/dependency_providers.dart';

class _FakeLocalStorageRepository implements ILocalStorageRepository {
  @override
  Future<Either<Failure, void>> clearAll() async => const Right(null);

  @override
  Future<Either<Failure, UserConfig?>> getUserConfig() async => const Right(null);

  @override
  Future<Either<Failure, bool>> hasValidConfig() {
    return Completer<Either<Failure, bool>>().future;
  }

  @override
  Future<Either<Failure, void>> saveUserConfig(UserConfig config) async =>
      const Right(null);
}

void main() {
  testWidgets('renders startup loading state', (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageRepositoryProvider.overrideWithValue(
            _FakeLocalStorageRepository(),
          ),
        ],
        child: const GitItDownApp(),
      ),
    );

    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
