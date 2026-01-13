
class ClassPackage {
  final String id;
  final String name;
  final String description;
  final String price;
  final String? originalPrice; // For showing discounts
  final int classCount; // Number of classes in this package
  final List<String> features;
  final bool isRecommended;
  final bool isActive;
  final int sortOrder; // For ordering packages
  final String? validFor; // e.g., "1 month", "3 months", "unlimited"

  ClassPackage({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.originalPrice,
    required this.classCount,
    required this.features,
    this.isRecommended = false,
    this.isActive = true,
    this.sortOrder = 0,
    this.validFor,
  });

  factory ClassPackage.fromMap(Map<String, dynamic> map) {
    return ClassPackage(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: map['price'] ?? '₹0',
      originalPrice: map['originalPrice'],
      classCount: map['classCount'] ?? 1,
      features: List<String>.from(map['features'] ?? []),
      isRecommended: map['isRecommended'] ?? false,
      isActive: map['isActive'] ?? true,
      sortOrder: map['sortOrder'] ?? 0,
      validFor: map['validFor'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'originalPrice': originalPrice,
      'classCount': classCount,
      'features': features,
      'isRecommended': isRecommended,
      'isActive': isActive,
      'sortOrder': sortOrder,
      'validFor': validFor,
    };
  }

  // Helper methods
  bool get hasDiscount => originalPrice != null && originalPrice!.isNotEmpty;
  double get discountPercentage {
    if (!hasDiscount) return 0.0;
    final original = double.tryParse(originalPrice!.replaceAll('₹', '').replaceAll(',', '')) ?? 0;
    final current = double.tryParse(price.replaceAll('₹', '').replaceAll(',', '')) ?? 0;
    if (original == 0) return 0.0;
    return ((original - current) / original * 100).roundToDouble();
  }

  String get formattedPrice => price;
  String get formattedOriginalPrice => originalPrice ?? '';
  String get discountText => hasDiscount ? '${discountPercentage.toInt()}% OFF' : '';
}

// Default packages that can be used as templates
class DefaultPackages {
  static List<ClassPackage> getDefaultPackages() {
    return [
      ClassPackage(
        id: 'single',
        name: 'Single Class',
        description: 'One-time class booking',
        price: '₹500',
        classCount: 1,
        features: ['Full class access', 'Basic support'],
        isRecommended: false,
        sortOrder: 1,
      ),
      ClassPackage(
        id: '5-class',
        name: '5-Class Pack',
        description: 'Save 17% with 5-class package',
        price: '₹2,500',
        originalPrice: '₹3,000',
        classCount: 5,
        features: ['5 classes', 'Priority booking', 'Free cancellation'],
        isRecommended: true,
        sortOrder: 2,
        validFor: '2 months',
      ),
      ClassPackage(
        id: '10-class',
        name: '10-Class Pack',
        description: 'Save 25% with 10-class package',
        price: '₹4,500',
        originalPrice: '₹6,000',
        classCount: 10,
        features: ['10 classes', 'Priority booking', 'Free cancellation', 'Bonus class'],
        isRecommended: false,
        sortOrder: 3,
        validFor: '3 months',
      ),
      ClassPackage(
        id: 'monthly',
        name: 'Monthly Unlimited',
        description: 'Unlimited classes for 1 month',
        price: '₹8,000',
        originalPrice: '₹12,000',
        classCount: -1, // -1 for unlimited
        features: ['Unlimited classes', 'All categories', 'Priority booking', 'Personal trainer session'],
        isRecommended: false,
        sortOrder: 4,
        validFor: '1 month',
      ),
    ];
  }
}
