import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_loop/features/feed/domain/entities/food_listing.dart';
import 'package:food_loop/features/feed/presentation/widgets/food_card.dart';

// Override HttpOverrides to prevent network calls from failing during widget tests
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  setUpAll(() {
    HttpOverrides.global = MyHttpOverrides();
  });

  group('FoodCard Widget Tests', () {
    final baseListing = FoodListing(
      id: 'listing_1',
      sellerId: 'seller_1',
      sellerName: 'John Doe',
      sellerRating: 4.5,
      title: 'Valid Test Title',
      category: FoodCategory.cookedMeal,
      imageUrls: const [],
      price: 5000.0,
      isFree: false,
      allergenTags: const [],
      pickupLocation: const PickupLocation(address: 'Test Address', latitude: 0, longitude: 0),
      pickupWindowStart: DateTime.now(),
      pickupWindowEnd: DateTime.now().add(const Duration(hours: 48)),
      status: ListingStatus.active,
      createdAt: DateTime.now(),
    );

    testWidgets('Renders title correctly', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 350,
              child: FoodCard(
                listing: baseListing,
                distanceKm: 2.5,
                onTap: () {},
              ),
            ),
          ),
        ),
      ));

      expect(find.text('Valid Test Title'), findsOneWidget);
      expect(find.text('2.5 km away'), findsOneWidget);
    });

    testWidgets('Shows "FREE" badge when listing.isFree is true', (WidgetTester tester) async {
      final freeListing = baseListing.copyWith(isFree: true, price: 0);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 350,
              child: FoodCard(
                listing: freeListing,
                distanceKm: 1.0,
                onTap: () {},
              ),
            ),
          ),
        ),
      ));

      expect(find.text('FREE'), findsOneWidget);
      expect(find.text('UGX 0'), findsNothing);
    });

    testWidgets('Shows price when listing.isFree is false', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 350,
              child: FoodCard(
                listing: baseListing,
                distanceKm: 1.0,
                onTap: () {},
              ),
            ),
          ),
        ),
      ));

      expect(find.text('UGX 5000'), findsOneWidget);
      expect(find.text('FREE'), findsNothing);
    });

    testWidgets('Shows expiry countdown for active listings under 24hrs', (WidgetTester tester) async {
      final expiringListing = baseListing.copyWith(
        pickupWindowEnd: DateTime.now().add(const Duration(hours: 12)),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 350,
              child: FoodCard(
                listing: expiringListing,
                distanceKm: 1.0,
                onTap: () {},
              ),
            ),
          ),
        ),
      ));

      expect(find.text('< 1 day left'), findsOneWidget);
    });

    testWidgets('Shows critical expiry countdown for active listings under 2hrs', (WidgetTester tester) async {
      final criticalListing = baseListing.copyWith(
        pickupWindowEnd: DateTime.now().add(const Duration(hours: 1)),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 350,
              child: FoodCard(
                listing: criticalListing,
                distanceKm: 1.0,
                onTap: () {},
              ),
            ),
          ),
        ),
      ));

      expect(find.text('< 2 hrs left'), findsOneWidget);
    });

    testWidgets('Tapping the card calls the onTap callback', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 350,
              child: FoodCard(
                listing: baseListing,
                distanceKm: 1.0,
                onTap: () {
                  tapped = true;
                },
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump(); // Not pumpAndSettle due to shimmer animation

      expect(tapped, isTrue);
    });
  });
}
