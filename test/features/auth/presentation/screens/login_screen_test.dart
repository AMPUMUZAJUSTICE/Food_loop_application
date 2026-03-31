import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_loop/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:food_loop/features/auth/presentation/bloc/auth_event.dart';
import 'package:food_loop/features/auth/presentation/bloc/auth_state.dart';
import 'package:food_loop/features/auth/presentation/screens/login_screen.dart';

class FakeAuthBloc extends Fake implements AuthBloc {
  final _stateController = StreamController<AuthState>.broadcast();
  AuthState _state = AuthInitial();

  @override
  AuthState get state => _state;

  @override
  Stream<AuthState> get stream => _stateController.stream;

  void emitState(AuthState newState) {
    _state = newState;
    _stateController.add(newState);
  }
  
  @override
  void add(AuthEvent event) {}

  @override
  Future<void> close() async {
    await _stateController.close();
  }
}

void main() {
  late FakeAuthBloc mockAuthBloc;

  setUp(() {
    mockAuthBloc = FakeAuthBloc();
  });

  tearDown(() {
    mockAuthBloc.close();
  });

  Widget buildTestWidget() {
    return MaterialApp(
      home: BlocProvider<AuthBloc>.value(
        value: mockAuthBloc,
        child: const LoginScreen(),
      ),
    );
  }

  group('LoginScreen Widget Tests', () {
    testWidgets('Renders email and password fields', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('University Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('Shows error text on empty submit', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      
      final loginButton = find.text('Login');
      await tester.ensureVisible(loginButton);
      await tester.tap(loginButton, warnIfMissed: false);
      await tester.pump();
      
      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('Shows error text for non .ac.ug email', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      
      await tester.enterText(find.byType(TextFormField).first, 'user@gmail.com');
      await tester.enterText(find.byType(TextFormField).last, 'password123');
      
      final loginButton = find.text('Login');
      await tester.ensureVisible(loginButton);
      await tester.tap(loginButton, warnIfMissed: false);
      await tester.pump();
      
      expect(find.text('Must be a valid .ac.ug university email'), findsOneWidget);
    });

    testWidgets('Submit button is disabled while AuthLoading state is active', (WidgetTester tester) async {
      mockAuthBloc.emitState(AuthLoading());
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(); // flush stream
      await tester.pump(const Duration(milliseconds: 600)); // Allows UI slide animation to finish without hanging on CircularProgressIndicator
      
      // Find elevated button
      final elevatedButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(elevatedButton.onPressed, isNull);
      
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Login'), findsNothing);
    });
  });
}
