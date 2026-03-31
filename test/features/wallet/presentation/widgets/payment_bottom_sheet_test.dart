import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_loop/features/wallet/presentation/widgets/payment_bottom_sheet.dart';
import 'package:food_loop/features/feed/domain/entities/food_listing.dart';

// HttpOverrides to bypass bad certs and cache fetches for cached_network_image
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

// --- FAKES FOR FIRESTORE (just enough for this widget test) ---
class FakeFirestore extends Fake implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    if (collectionPath == 'users') {
      return FakeCollection();
    }
    throw UnimplementedError();
  }
}

class FakeCollection extends Fake implements CollectionReference<Map<String, dynamic>> {
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return FakeDocumentReference();
  }
}

class FakeDocumentReference extends Fake implements DocumentReference<Map<String, dynamic>> {
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    return FakeDocumentSnapshot();
  }
}

class FakeDocumentSnapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  bool get exists => true;

  @override
  Map<String, dynamic>? data() {
    return {
      'uid': 'buyer_1',
      'email': 'buyer@must.ac.ug',
      'fullName': 'Test Buyer',
      'phoneNumber': '+256700000000',
      'profileImageUrl': '',
      'studentId': '',
      'role': 'buyer',
      'walletBalance': 500.0, // Hardcode 500.0 to test insufficient balance!
      'createdAt': Timestamp.now(),
      'notificationPrefs': {},
    };
  }
}

void main() {
  setUpAll(() {
    HttpOverrides.global = MyHttpOverrides();
  });

  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.window.physicalSizeTestValue = const Size(1080, 2400);
    binding.window.devicePixelRatioTestValue = 1.0;
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.window.clearPhysicalSizeTestValue();
    binding.window.clearDevicePixelRatioTestValue();
  });

  final baseListing = FoodListing(
    id: 'listing_1',
    sellerId: 'seller_1',
    sellerName: 'John Doe',
    sellerRating: 4.5,
    title: 'Valid Test Title',
    category: FoodCategory.cookedMeal,
    imageUrls: const [],
    price: 10000.0, // Price is 10k, wallet is 500 -> triggers insufficient balance logic
    isFree: false,
    allergenTags: const [],
    pickupLocation: const PickupLocation(address: 'Test Address', latitude: 0, longitude: 0),
    pickupWindowStart: DateTime.now(),
    pickupWindowEnd: DateTime.now().add(const Duration(hours: 48)),
    status: ListingStatus.active,
    createdAt: DateTime.now(),
  );

  group('PaymentBottomSheet Widget Tests', () {
    testWidgets('Renders correct breakdown (item price + fee = total)', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PaymentBottomSheet(
            listing: baseListing, // 10000UGX price
            buyerId: 'buyer_1',
            firestore: FakeFirestore(),
          ),
        ),
      ));

      await tester.pumpAndSettle();

      expect(find.text('UGX 10000'), findsWidgets); // Price shown twice (in list and table)
      expect(find.text('UGX 500'), findsNWidgets(2)); // Fee 5% (500) and Mock Wallet Balance (500)
      expect(find.text('UGX 10500'), findsWidgets); // Total (10500)
    });

    testWidgets('"Use Wallet Balance" option is disabled when balance < total', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PaymentBottomSheet(
            listing: baseListing,
            buyerId: 'buyer_1',
            firestore: FakeFirestore(),
          ),
        ),
      ));

      await tester.pumpAndSettle();

      // Ensure the "Insufficient" text renders, proving the logic caught the < balance
      expect(find.textContaining('⚠ Insufficient'), findsOneWidget);
    });

    testWidgets('Confirm button shows correct total amount', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PaymentBottomSheet(
            listing: baseListing,
            buyerId: 'buyer_1',
            firestore: FakeFirestore(),
          ),
        ),
      ));

      await tester.pumpAndSettle();

      // Use text finder within ElevatedButton
      final buttonFinder = find.widgetWithText(ElevatedButton, 'Pay UGX 10500');
      expect(buttonFinder, findsOneWidget);
    });
  });
}
