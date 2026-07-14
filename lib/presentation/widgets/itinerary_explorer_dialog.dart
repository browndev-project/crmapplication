import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/itinerary_provider.dart';
import '../../data/models/itinerary_model.dart';

class ItineraryExplorerDialog extends ConsumerStatefulWidget {
  final String itineraryId;
  const ItineraryExplorerDialog({super.key, required this.itineraryId});

  @override
  ConsumerState<ItineraryExplorerDialog> createState() => _ItineraryExplorerDialogState();
}

class _ItineraryExplorerDialogState extends ConsumerState<ItineraryExplorerDialog> {
  final numberFormat = NumberFormat('#,##,###');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(itineraryDetailProvider.notifier).fetchDetails(widget.itineraryId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(itineraryDetailProvider);
    final itinerary = state.itinerary;

    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        body: state.isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.black))
            : state.error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(state.error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 14)),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => ref.read(itineraryDetailProvider.notifier).fetchDetails(widget.itineraryId),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                            child: const Text('Retry'),
                          )
                        ],
                      ),
                    ),
                  )
                : itinerary == null
                    ? const Center(child: Text('Itinerary not found.'))
                    : Stack(
                        children: [
                          CustomScrollView(
                            slivers: [
                              _buildHeroHeader(itinerary),
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildSummaryCards(itinerary),
                                      const SizedBox(height: 32),
                                      _buildSectionTitle('Overview'),
                                      _buildOverview(itinerary),
                                      const SizedBox(height: 32),
                                      if (itinerary.guestList.isNotEmpty) ...[
                                        _buildSectionTitle('Guest List'),
                                        _buildGuestList(itinerary),
                                        const SizedBox(height: 32),
                                      ],
                                      _buildSectionTitle('Experience Timeline'),
                                      _buildTimeline(itinerary),
                                      const SizedBox(height: 32),
                                      _buildSectionTitle('Logistics & Coverage'),
                                      _buildLogistics(itinerary),
                                      const SizedBox(height: 32),
                                      _buildSectionTitle('Destinations'),
                                      _buildDestinations(itinerary),
                                      const SizedBox(height: 32),
                                      _buildSectionTitle('Accommodation'),
                                      _buildAccommodation(itinerary),
                                      const SizedBox(height: 32),
                                      _buildSectionTitle('Cost Breakdown'),
                                      _buildCostBreakdown(itinerary),
                                      const SizedBox(height: 32),
                                      _buildSectionTitle('Transportation'),
                                      _buildTransportation(itinerary),
                                      const SizedBox(height: 32),
                                      _buildSectionTitle('Policies & Terms'),
                                      _buildPolicies(itinerary),
                                      const SizedBox(height: 80),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          _buildCloseButton(),
                        ],
                      ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.5,
          color: Colors.black54,
        ),
      ),
    );
  }

  // 1. Hero Banner
  Widget _buildHeroHeader(ItineraryV2 itinerary) {
    return SliverAppBar(
      expandedHeight: 320,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.black,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (itinerary.heroImage.isNotEmpty)
              Image.network(itinerary.heroImage, fit: BoxFit.cover)
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF111827), Color(0xFF1F2937)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.4), Colors.black.withValues(alpha: 0.85)],
                ),
              ),
            ),
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'PREMIUM EXPERIENCE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    itinerary.subject,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, color: Colors.white70, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        '${itinerary.noOfDays} Days Experience',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 2. Summary Cards
  Widget _buildSummaryCards(ItineraryV2 itinerary) {
    return Row(
      children: [
        Expanded(
          child: _buildWhiteCard(
            'TOTAL VALUE',
            '₹${numberFormat.format(itinerary.totalPrice)}',
            valueColor: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildWhiteCard(
            'PER GUEST',
            '₹${numberFormat.format(itinerary.pricePerAdult)}',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildWhiteCard(
            'GUESTS',
            '${itinerary.adults} Adults${itinerary.kids > 0 ? ' + ${itinerary.kids} Kids' : ''}',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildWhiteCard(
            'ROOMS',
            '${itinerary.rooms}',
          ),
        ),
      ],
    );
  }

  Widget _buildWhiteCard(String label, String value, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))
        ],
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: valueColor ?? Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Overview
  Widget _buildOverview(ItineraryV2 itinerary) {
    String formatDate(String dateStr) {
      if (dateStr.isEmpty) return 'Not set';
      try {
        final d = DateTime.tryParse(dateStr);
        if (d != null) return DateFormat('dd MMM yyyy').format(d);
      } catch (_) {}
      return dateStr;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Client Info
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  itinerary.clientName.isNotEmpty ? itinerary.clientName : 'N/A',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (itinerary.clientCompany.isNotEmpty)
            _infoRow(Icons.business, itinerary.clientCompany),
          if (itinerary.clientEmail.isNotEmpty)
            _infoRow(Icons.email_outlined, itinerary.clientEmail),
          if (itinerary.clientPhoneNo.isNotEmpty)
            _infoRow(Icons.phone_outlined, itinerary.clientPhoneNo),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          // Journey Info
          Row(children: [
            const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
            const SizedBox(width: 6),
            Text('Start: ${formatDate(itinerary.startDate)}', style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
            const SizedBox(width: 16),
            const Icon(Icons.timer_outlined, size: 14, color: Colors.grey),
            const SizedBox(width: 6),
            Text('${itinerary.noOfDays} Days', style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.people_outline, size: 14, color: Colors.grey),
            const SizedBox(width: 6),
            Text('${itinerary.adults} Adults', style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
            if (itinerary.kids > 0) ...[
              const SizedBox(width: 16),
              Text('${itinerary.kids} Kids', style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
            ],
            if (itinerary.rooms > 0) ...[
              const SizedBox(width: 16),
              Text('${itinerary.rooms} Rooms', style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
            ],
          ]),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(
            itinerary.shortDescription.isNotEmpty ? itinerary.shortDescription : 'No overview description provided.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 13, color: Colors.grey),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
        ],
      ),
    );
  }

  Widget _buildGuestList(ItineraryV2 itinerary) {
    final guests = itinerary.guestList;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: guests.map((g) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(child: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w500))),
              Text('${g.age} Yrs, ${g.gender} (${g.type})', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
        )).toList(),
      ),
    );
  }

  // 4. Experience Timeline
  Widget _buildTimeline(ItineraryV2 itinerary) {
    if (itinerary.sections.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('No timeline plans created for this itinerary.', style: TextStyle(color: Colors.grey, fontSize: 13)),
      );
    }

    return Column(
      children: List.generate(itinerary.sections.length, (index) {
        final sec = itinerary.sections[index];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (index < itinerary.sections.length - 1)
                  Container(
                    width: 2,
                    height: 180,
                    color: Colors.black12,
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.01), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sec.name.isNotEmpty ? sec.name : 'Day ${index + 1}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    if (sec.title.isNotEmpty && sec.title != sec.name) ...[
                      const SizedBox(height: 4),
                      Text(
                        sec.title,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (sec.image.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          sec.image,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            height: 120,
                            color: Colors.grey[200],
                            child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      sec.description,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.4),
                    ),
                    if (sec.meals.breakfast || sec.meals.lunch || sec.meals.dinner) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.restaurant, size: 14, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            'Meals: ${[
                                  if (sec.meals.breakfast) 'Breakfast',
                                  if (sec.meals.lunch) 'Lunch',
                                  if (sec.meals.dinner) 'Dinner'
                                ].join(', ')}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF4B5563)),
                          ),
                        ],
                      ),
                    ],
                    if (sec.notes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          'Note: ${sec.notes}',
                          style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF6B7280)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  // 5. Logistics & Coverage
  Widget _buildLogistics(ItineraryV2 itinerary) {
    return Column(
      children: [
        _buildCoverageCard('INCLUSIONS', itinerary.keyInclusions, const Color(0xFF10B981)),
        const SizedBox(height: 16),
        _buildCoverageCard('EXCLUSIONS', itinerary.keyExclusions, const Color(0xFFEF4444)),
      ],
    );
  }

  Widget _buildCoverageCard(String title, List<String> items, Color accentColor) {
    final cleanItems = items.where((item) => item.trim().isNotEmpty).toList();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))
        ],
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                color: accentColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (cleanItems.isEmpty)
                        const Text(
                          'No items specified.',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        )
                      else
                        ...cleanItems.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 5),
                                    child: Icon(Icons.brightness_1, size: 6, color: accentColor),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      item,
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 6. Destinations
  Widget _buildDestinations(ItineraryV2 itinerary) {
    if (itinerary.keyLocations.isEmpty) {
      return const Text('No destinations specified.', style: TextStyle(color: Colors.grey, fontSize: 13));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: itinerary.keyLocations.map((loc) {
        return Chip(
          label: Text(loc, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFE5E7EB)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        );
      }).toList(),
    );
  }

  // 7. Accommodation
  Widget _buildAccommodation(ItineraryV2 itinerary) {
    if (itinerary.stays.isEmpty) {
      return const Text('No stay accommodations required.', style: TextStyle(color: Colors.grey, fontSize: 13));
    }
    return Column(
      children: itinerary.stays.map((stay) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              if (stay.image.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                  child: Image.network(stay.image, width: 80, height: 80, fit: BoxFit.cover),
                )
              else
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.horizontal(left: Radius.circular(12)),
                  ),
                  child: const Icon(Icons.hotel, color: Colors.grey),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stay.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      if (stay.description.isNotEmpty)
                        Text(stay.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text('${stay.noOfNights} Nights stay', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // 8. Cost Breakdown
  Widget _buildCostBreakdown(ItineraryV2 itinerary) {
    final double stayTotal = itinerary.stays.fold(0.0, (sum, stay) => sum + (stay.pricePerNight * stay.noOfNights));
    final double transportTotal = itinerary.transports.fold(0.0, (sum, t) => sum + t.price);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Column(
        children: [
          _buildCostRow('Activities net cost', itinerary.activitiesCost),
          _buildCostRow('Stays total price', stayTotal),
          _buildCostRow('Transports net cost', transportTotal),
          const Divider(height: 24, color: Color(0xFFD1FAE5)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL NET PRICE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF047857))),
              Text('₹${numberFormat.format(itinerary.totalPrice)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF047857))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCostRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF065F46))),
          Text('₹${numberFormat.format(amount)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF065F46))),
        ],
      ),
    );
  }

  // 9. Transportation
  Widget _buildTransportation(ItineraryV2 itinerary) {
    if (itinerary.transports.isEmpty) {
      return const Text('No transportation specified.', style: TextStyle(color: Colors.grey, fontSize: 13));
    }
    return Column(
      children: itinerary.transports.map((t) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.type, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(t.details, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        );
      }).toList(),
    );
  }

  // 10. Policies & Terms
  Widget _buildPolicies(ItineraryV2 itinerary) {
    if (itinerary.termsAndConditions.isEmpty) {
      return const Text('No policies configured.', style: TextStyle(color: Colors.grey, fontSize: 13));
    }
    return Column(
      children: itinerary.termsAndConditions.map((policy) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(policy.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(policy.description, style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563), height: 1.4)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCloseButton() {
    return Positioned(
      top: 40,
      right: 20,
      child: CircleAvatar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        child: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }
}
