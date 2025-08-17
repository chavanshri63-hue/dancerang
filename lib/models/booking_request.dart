// lib/models/booking_request.dart
class BookingRequest {
  final String id;
  final String clientName;
  final String phone;
  final String eventType;      // School / Sangeet / Corporate / Other
  final DateTime eventDate;
  final int numDances;

  const BookingRequest({
    required this.id,
    required this.clientName,
    required this.phone,
    required this.eventType,
    required this.eventDate,
    required this.numDances,
  });
}