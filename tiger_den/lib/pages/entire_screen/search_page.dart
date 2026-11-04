import 'package:algolia_client_search/algolia_client_search.dart';
import 'package:flutter/material.dart';
import '../../services/search_service.dart';
import '../../base_designs/sitewide/design_main.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key})

  @override
  State<SearchPage> createState() => SearchPageState();
}

class SearchPageState extends State<SearchPage> {

  SearchService searchService = SearchService();
  List<SearchResult> _indexList =[];

  @override
  void initState() {
    super.initState();
  }
  Widget indexListView(){
    if (_indexList.isEmpty) {
      return Expanded(
        child: Text("No results found.")
        );
    }
    return Expanded(
      child: ListView.builder(
        itemCount: _indexList.length,
        itemBuilder: (context, index){ 
          final result = _indexList[index];
          return ListTile (
            title: Text(result.toString())
          );
        }
      )
    );
  }

  Widget searchBar() {
    return Container(
      padding: EdgeInsets.all(style.spaceSmall),
      child: TextField( 
        onSubmitted: (value) async {
          if (value.trim().isEmpty) return;
          final results = await searchService.search(input: value);
          setState(() {
            _indexList = results ?? [];
          });
        },
        decoration:InputDecoration(
          hintText: "Search..."
        ),
      )
    );
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      body: SizedBox.expand(
        child: Column (
          children: [
            searchBar(context),
            indexListView()
          ],
        )
      )
    );
  }
}