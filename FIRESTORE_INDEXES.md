# Firestore Indexes Documentation

This document lists all required Firestore composite indexes for the DanceRang application.

## Current Indexes (Deployed)

### Attendance Collection
1. **classId + userId** (ASC, ASC)
   - Used for: Checking if student is enrolled in a class
   - Query: `attendance.where('classId', isEqualTo: classId).where('userId', isEqualTo: userId)`

2. **workshopId + userId** (ASC, ASC)
   - Used for: Checking if student is enrolled in a workshop
   - Query: `attendance.where('workshopId', isEqualTo: workshopId).where('userId', isEqualTo: userId)`

3. **classId + markedAt** (ASC, DESC)
   - Used for: Live attendance dashboard for classes
   - Query: `attendance.where('classId', isEqualTo: classId).orderBy('markedAt', descending: true)`

4. **userId + markedAt** (ASC, DESC)
   - Used for: User's attendance history
   - Query: `attendance.where('userId', isEqualTo: userId).orderBy('markedAt', descending: true)`

### Enrollments Collection
5. **userId + status + itemType** (ASC, ASC, ASC)
   - Used for: Getting user's enrollments by type (class/workshop)
   - Query: `enrollments.where('userId', isEqualTo: userId).where('status', isEqualTo: 'enrolled').where('itemType', isEqualTo: 'class')`

6. **userId + itemId + status** (ASC, ASC, ASC)
   - Used for: Checking specific enrollment
   - Query: `enrollments.where('userId', isEqualTo: userId).where('itemId', isEqualTo: itemId).where('status', isEqualTo: 'enrolled')`

### Classes Collection
7. **isAvailable + dateTime** (ASC, DESC)
   - Used for: Getting available classes sorted by date
   - Query: `classes.where('isAvailable', isEqualTo: true).orderBy('dateTime', descending: true)`

8. **isAvailable + instructorId** (ASC, ASC)
   - Used for: Getting classes by instructor
   - Query: `classes.where('isAvailable', isEqualTo: true).where('instructorId', isEqualTo: instructorId)`

### Workshops Collection
9. **isAvailable + date** (ASC, ASC)
   - Used for: Getting available workshops sorted by date
   - Query: `workshops.where('isAvailable', isEqualTo: true).orderBy('date', ascending: true)`

### Payments Collection
10. **status + created_at** (ASC, ASC)
    - Used for: Revenue calculations by month
    - Query: `payments.where('status', isEqualTo: 'success').where('created_at', isGreaterThanOrEqualTo: startOfMonth)`

## Future Index Requirements

When adding new features, consider these potential index needs:

### User Management
- `users` collection: `role + isActive` (for admin queries)
- `users` collection: `createdAt` (for user analytics)

### Class Management
- `classes` collection: `category + isAvailable` (for filtering by dance style)
- `classes` collection: `level + isAvailable` (for filtering by difficulty)

### Workshop Management
- `workshops` collection: `instructor + isAvailable` (for instructor's workshops)
- `workshops` collection: `category + isAvailable` (for filtering by type)

### Attendance Analytics
- `attendance` collection: `markedAt + status` (for attendance reports)
- `attendance` collection: `classId + status` (for class attendance stats)

### Notifications
- `notifications` collection: `userId + read` (for user notifications)
- `notifications` collection: `createdAt` (for notification history)

## How to Add New Indexes

1. **Edit `firestore.indexes.json`**:
   ```json
   {
     "collectionGroup": "collection_name",
     "queryScope": "COLLECTION",
     "fields": [
       {
         "fieldPath": "field1",
         "order": "ASCENDING"
       },
       {
         "fieldPath": "field2", 
         "order": "DESCENDING"
       }
     ]
   }
   ```

2. **Deploy indexes**:
   ```bash
   firebase deploy --only firestore:indexes
   ```

3. **Test the query** to ensure it works without index errors

## Index Optimization Tips

- **Single field indexes** are created automatically by Firestore
- **Composite indexes** are only needed for queries with multiple `where` clauses or `where` + `orderBy`
- **Array fields** require special consideration for indexing
- **Subcollection queries** need indexes on the parent collection

## Monitoring Index Usage

- Check Firebase Console → Firestore → Indexes tab
- Monitor query performance in Firebase Console → Performance
- Use `firebase firestore:indexes` to see all indexes
- Check for "index not found" errors in logs

## Common Index Patterns

### Filter + Sort
```dart
// Requires: field1 + field2 index
.where('field1', isEqualTo: value)
.orderBy('field2', descending: true)
```

### Multiple Filters
```dart
// Requires: field1 + field2 + field3 index
.where('field1', isEqualTo: value1)
.where('field2', isEqualTo: value2)
.where('field3', isEqualTo: value3)
```

### Range + Sort
```dart
// Requires: field1 + field2 index
.where('field1', isGreaterThan: value)
.orderBy('field2', descending: true)
```

## Troubleshooting

### "Index not found" Error
1. Check if the exact query pattern has an index
2. Add the required index to `firestore.indexes.json`
3. Deploy with `firebase deploy --only firestore:indexes`
4. Wait for index to build (can take several minutes)

### "Index not necessary" Error
- This means Firestore can handle the query with single-field indexes
- Remove the unnecessary composite index from the configuration

### Performance Issues
- Check if queries are using the most efficient indexes
- Consider denormalizing data to reduce complex queries
- Use pagination for large result sets
