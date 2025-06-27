import 'package:cloud_firestore/cloud_firestore.dart';
class Task {
  final String id;
  final String title;
  final String assignedTo;
  final String status;
  final double amountSpent;
  Task({
    required this.id,
    required this.title,
    required this.assignedTo,
    required this.status,
    required this.amountSpent,
  });
  factory Task.fromMap(String id, Map<String, dynamic> data) => Task(
    id: id,
    title: data['title'] ?? '',
    assignedTo: data['assignedTo'] ?? '',
    status: data['status'] ?? 'pending',
    amountSpent: (data['amountSpent'] ?? 0).toDouble(),
  );
  Map<String, dynamic> toMap() => {
    'title': title,
    'assignedTo': assignedTo,
    'status': status,
    'amountSpent': amountSpent,
    'createdAt': FieldValue.serverTimestamp(),
  };
}

