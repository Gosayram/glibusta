import 'package:flutter/material.dart';

class BookDetailsScreen extends StatelessWidget {
  final int bookId;
  const BookDetailsScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Details'),
      ),
      body: Center(
        child: Text('Book $bookId details - coming soon'),
      ),
    );
  }
}