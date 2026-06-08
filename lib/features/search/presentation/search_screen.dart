import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'search_controller.dart';
import '../../../shared/models/book.dart';

class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(searchControllerProvider);
    final controller = ref.read(searchControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Поиск'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SearchBar(
              hintText: 'Поиск книг...',
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  controller.search(value);
                }
              },
            ),
          ),
          if (state.isLoading)
            const LinearProgressIndicator(),
          if (state.error != null)
            Center(child: Text('Ошибка: ${state.error}')),
          _buildResults(context, state),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context, SearchState state) {
    if (state.books.isEmpty && !state.isLoading) {
      return const Expanded(
        child: Center(child: Text('Начните поиск')),
      );
    }

    return Expanded(
      child: ListView.builder(
        itemCount: state.books.length,
        itemBuilder: (context, index) {
          final book = state.books[index];
          return BookListItem(book: book);
        },
      ),
    );
  }
}

class BookListItem extends StatelessWidget {
  final Book book;

  const BookListItem({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(book.title),
      subtitle: book.description != null ? Text(book.description!) : null,
      onTap: () {
        // Navigate to book details
      },
    );
  }
}