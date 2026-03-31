import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class FoodSafetyScreen extends StatelessWidget {
  const FoodSafetyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 150.0,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Food Safety Guidelines',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryGreen, AppColors.darkGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(right: 24.0, bottom: 20.0),
                    child: Icon(
                      Icons.eco,
                      size: 80,
                      color: Colors.white24,
                    ),
                  ),
                ),
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          SliverToBoxAdapter(
            child: _buildDisclaimerBanner(),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SafetySection(
                  icon: '🌡️',
                  title: 'Safe Temperature Zones',
                  body: '',
                  bullets: [
                    'Hot food: keep above 60°C until pickup',
                    'Cold food: store below 4°C',
                    'The danger zone: 4°C–60°C — bacteria multiply rapidly',
                    'Do not leave cooked food at room temperature for more than 2 hours',
                  ],
                ),
                const SizedBox(height: 24),
                const SafetySection(
                  icon: '📦',
                  title: 'Packaging Standards',
                  body: '',
                  bullets: [
                    'Always use sealed, clean containers',
                    'Label the container with the food name and time cooked/packed',
                    'Use separate containers for raw and cooked items',
                    'Avoid reusing single-use takeaway boxes',
                  ],
                ),
                const SizedBox(height: 24),
                const SafetySection(
                  icon: '⚠️',
                  title: 'Allergen Disclosure (MANDATORY)',
                  body: '',
                  bullets: [
                    'You MUST declare: nuts, gluten, dairy, eggs, shellfish, soy',
                    'Always tag allergens in your listing before publishing',
                    'When in doubt, label it',
                  ],
                ),
                const SizedBox(height: 24),
                const SafetySection(
                  icon: '🚫',
                  title: 'When NOT to Share Food',
                  body: '',
                  bullets: [
                    'Food cooked more than 6 hours ago (unless refrigerated)',
                    'Food with visible mold, unusual smell, or discoloration',
                    'If you are feeling unwell or have any contagious illness',
                  ],
                ),
                const SizedBox(height: 24),
                const SafetySection(
                  icon: '🤝',
                  title: 'Handover Best Practices',
                  body: '',
                  bullets: [
                    'Always hand over food in its sealed container',
                    'Wash hands before handling food meant for others',
                    'Confirm pickup in-app — never share food without a confirmed order',
                  ],
                ),
                const SizedBox(height: 24),
                const SafetySection(
                  icon: '🆘',
                  title: 'If Something Goes Wrong',
                  body: '',
                  bullets: [
                    'Report unsafe food immediately via the "Report a Problem" button in Settings',
                    'Contact: Campus Health & Safety contact',
                  ],
                ),
                const SizedBox(height: 48), // Bottom padding
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimerBanner() {
    return Container(
      width: double.infinity,
      color: Colors.amber.shade100,
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.amber, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Platform Disclaimer',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Food Loop facilitates peer-to-peer sharing. Buyers accept responsibility for verifying food safety upon pickup.',
                  style: TextStyle(
                    color: Colors.amber.shade900,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SafetySection extends StatelessWidget {
  final String icon;
  final String title;
  final String body;
  final List<String> bullets;

  const SafetySection({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.bullets,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Emoticon Icon
        Text(
          icon,
          style: const TextStyle(fontSize: 32),
        ),
        const SizedBox(width: 16),
        // Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              if (body.isNotEmpty) ...[
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textGrey,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (bullets.isNotEmpty)
                ...bullets.map((bullet) => Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '• ',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              bullet,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textGrey,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
            ],
          ),
        ),
      ],
    );
  }
}
