import 'package:cloud_firestore/cloud_firestore.dart';

class PartnerItem {
  final int quantity;
  final String name;
  final double listPrice;
  final double salePrice;
  final String reason;
  final String? promotionName;

  const PartnerItem({
    required this.quantity,
    required this.name,
    required this.listPrice,
    required this.salePrice,
    required this.reason,
    this.promotionName,
  });

  factory PartnerItem.fromMap(Map<String, dynamic> m) => PartnerItem(
        quantity: (m['quantity'] as num?)?.toInt() ?? 1,
        name: m['name']?.toString() ?? 'Producto',
        listPrice: (m['listPrice'] as num?)?.toDouble() ?? 0,
        salePrice: (m['salePrice'] as num?)?.toDouble() ?? 0,
        reason: m['reason']?.toString() ?? '',
        promotionName: m['promotionName']?.toString(),
      );

  double get total => salePrice * quantity;
}

class PartnerTask {
  final String id;
  final int orderId;
  final int partnerId;
  final String partnerName;
  final String customer;
  final String status;
  final int revision;
  final bool paid;
  final bool cancelled;
  final double partnerAmount;
  final String createdAtLocal;
  final DateTime? updatedAt;
  final List<PartnerItem> items;

  const PartnerTask({
    required this.id,
    required this.orderId,
    required this.partnerId,
    required this.partnerName,
    required this.customer,
    required this.status,
    required this.revision,
    required this.paid,
    required this.cancelled,
    required this.partnerAmount,
    required this.createdAtLocal,
    required this.updatedAt,
    required this.items,
  });

  factory PartnerTask.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const <String, dynamic>{};
    return PartnerTask(
      id: doc.id,
      orderId: (m['orderId'] as num?)?.toInt() ?? 0,
      partnerId: (m['partnerNumber'] as num?)?.toInt() ?? 0,
      partnerName: m['partnerName']?.toString() ?? 'Socio',
      customer: m['customer']?.toString() ?? '',
      status: (m['status']?.toString() == 'confirmed' ? 'received' : (m['status']?.toString() ?? 'new')),
      revision: (m['revision'] as num?)?.toInt() ?? 1,
      paid: m['paid'] == true,
      cancelled: m['cancelled'] == true,
      partnerAmount: (m['partnerAmount'] as num?)?.toDouble() ?? 0,
      createdAtLocal: m['createdAtLocal']?.toString() ?? '',
      updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
      items: ((m['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((x) => PartnerItem.fromMap(Map<String, dynamic>.from(x)))
          .toList(),
    );
  }

  int get units => items.fold(0, (sum, x) => sum + x.quantity);

  DateTime? get createdAt => DateTime.tryParse(createdAtLocal);
  int get ageMinutes {
    final d = createdAt;
    if (d == null) return 0;
    return DateTime.now().difference(d).inMinutes.clamp(0, 999999);
  }
  bool get overdueConfirmation => (status == 'new') && ageMinutes >= 5;
  bool get overduePreparation => (status == 'received' || status == 'preparing') && ageMinutes >= 15;
  bool get overdueDelivery => status == 'ready' && ageMinutes >= 5;
  bool get needsAttention => overdueConfirmation || overduePreparation || overdueDelivery;
  bool get isToday {
    if (createdAtLocal.length < 10) return false;
    final now = DateTime.now();
    final day = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return createdAtLocal.substring(0, 10) == day;
  }
}
