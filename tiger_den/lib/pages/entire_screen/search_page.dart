import 'package:algolia_client_search/algolia_client_search.dart';
import 'package:flutter/material.dart';
import '../../services/search_service.dart';
import '../../base_designs/sitewide/design_main.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

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

  Widget noItemsFound(){
    return SafeArea(
      child: Text("No results found.")
    );
  }
  
  Widget indexListView(String type){
    if (_indexList.isEmpty) {
      return noItemsFound();
    }
    final filteredList = _indexList.where((item) => item['type'] == type).toList();
    if(filteredList.isEmpty){
      return noItemsFound();
    }
    return SafeArea(
      child: ListView.builder(
        itemCount: _indexList.length,
        itemBuilder: (context, index){ 
          SearchResult result = _indexList[index];

          String description = result['description'];
          String shortDes = ' ';
          if(description != null){
            if (description.length > 30) {
              shortDes = '(${description.substring(0, 30)} ...';
            } else {
              shortDes = description;
            }
          }
          String tags = "";
          if(result['tags'] != null){ 
            List<dynamic> tagList = result['tags'];
            tags = tagList.cast<String>().join(', '); 
          } else {
            tags = "None";
          }
          String subtitle = '$shortDes\nTags: $tags';
          return ListTile (
            ///leading: image
            title: Text(result['title'] ?? ""),
            subtitle: Text(subtitle),
            trailing: Text(result['category'] ?? ""),
          );
        }
      )
    );
  }

  Widget searchBar(BuildContext cont) {
    return Container(
      padding: EdgeInsets.all(cont.style.spaceSmall),
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
            Expanded (
              child: indexListView('event')
            ),
            Expanded (
              child: indexListView('club')
            ),
          ],
        )
      )
    );
  }
}