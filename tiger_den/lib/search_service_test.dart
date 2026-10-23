import 'package:flutter/material.dart';
import 'services/search_service.dart';

class SearchTestButton extends StatelessWidget {
  const SearchTestButton({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Algolia Test'),
        ),
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              try {
                SearchService searchService = SearchService();
                String result = await searchService.createIndex(
                  "Test1", 
                  "my name is bob", 
                  "1234"
                );

                print("Algolia Success Result: $result");

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Successfully indexed to Algolia!')),
                  );
                }
              } catch (e) {
                print("Algolia Error: $e");
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Press to Test Algolia Indexing'),
          ),
        ),
      ),
    );
  }
}