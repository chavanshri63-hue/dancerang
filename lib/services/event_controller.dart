import 'dart:async';

/// Event types for class operations
enum ClassEventType {
  classAdded,
  classUpdated,
  classDeleted,
  classStatusChanged,
  enrollmentAdded,
  enrollmentRemoved,
  attendanceUpdated,
}

/// Event data structure
class ClassEvent {
  final ClassEventType type;
  final String? classId;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  ClassEvent({
    required this.type,
    this.classId,
    this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Event controller for managing class-related events
class EventController {
  static final EventController _instance = EventController._internal();
  factory EventController() => _instance;
  EventController._internal();

  final StreamController<ClassEvent> _eventController = StreamController<ClassEvent>.broadcast();

  /// Stream of class events
  Stream<ClassEvent> get eventStream => _eventController.stream;

  /// Emit a class event
  void emitEvent(ClassEvent event) {
    _eventController.add(event);
  }

  /// Emit class added event
  void emitClassAdded(String classId, Map<String, dynamic>? data) {
    emitEvent(ClassEvent(
      type: ClassEventType.classAdded,
      classId: classId,
      data: data,
    ));
  }

  /// Emit class updated event
  void emitClassUpdated(String classId, Map<String, dynamic>? data) {
    emitEvent(ClassEvent(
      type: ClassEventType.classUpdated,
      classId: classId,
      data: data,
    ));
  }

  /// Emit class deleted event
  void emitClassDeleted(String classId) {
    emitEvent(ClassEvent(
      type: ClassEventType.classDeleted,
      classId: classId,
    ));
  }

  /// Emit class status changed event
  void emitClassStatusChanged(String classId, bool isAvailable) {
    emitEvent(ClassEvent(
      type: ClassEventType.classStatusChanged,
      classId: classId,
      data: {'isAvailable': isAvailable},
    ));
  }

  /// Emit enrollment added event
  void emitEnrollmentAdded(String classId, String userId) {
    emitEvent(ClassEvent(
      type: ClassEventType.enrollmentAdded,
      classId: classId,
      data: {'userId': userId},
    ));
  }

  /// Emit enrollment removed event
  void emitEnrollmentRemoved(String classId, String userId) {
    emitEvent(ClassEvent(
      type: ClassEventType.enrollmentRemoved,
      classId: classId,
      data: {'userId': userId},
    ));
  }

  /// Emit attendance updated event
  void emitAttendanceUpdated(String classId, String userId) {
    emitEvent(ClassEvent(
      type: ClassEventType.attendanceUpdated,
      classId: classId,
      data: {'userId': userId},
    ));
  }

  /// Dispose the event controller
  void dispose() {
    _eventController.close();
  }
}
