import 'package:algolia_client_search/algolia_client_search.dart';
import 'package:flutter/material.dart';
import '../../services/search_service.dart';
import '../../base_designs/sitewide/design_main.dart';
import '../../services/image_service.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => SearchPageState();
}

class SearchPageState extends State<SearchPage> {
  /// Service used for search functions
  SearchService searchService = SearchService();
  /// List of results in the Search Index
  List<SearchResult> _indexList = [];
  /// Service used to grab the image url for display
  ImageService imageService = ImageService();
  /// Holds fetched image URLs in a Map to their objectID
  Map<String, String> imageUrls = {};

  @override
  void initState() {
    super.initState();
  }

  Widget noItemsFound(){
    return SafeArea(
      child: Text("No results found.")
    );
  }
  
    Future<void> fetchImages(List<SearchResult> results) async {
    for (var result in results) {
      if (result['objectID'] != null) {
        if(result['type'] == 'event'){
          String objectId = result['objectID'];
          try {
            String url = await imageService.getEventImageURL(objectId);
            if (mounted) {
              setState(() {
                imageUrls[objectId] = url;
              });
            }
          } catch (e) {}
        } else if (result['type'] == 'event'){
          String objectId = result['objectID'];
          try {
            String url = await imageService.getClubImageURL(objectId);
            if (mounted) {
              setState(() {
                imageUrls[objectId] = url;
              });
            }
          } catch (e) {}
        }
      }
    }
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
        itemCount: filteredList.length,
        itemBuilder: (context, index){ 
          SearchResult result = filteredList[index];

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


          String imagelink = imageUrls[result['objectID']] ?? "";

          Image? imageDisplay = null;
          if (imagelink != "") {
            imageDisplay = Image.network(
                imagelink,
              );
            }
          return Padding (
            padding: EdgeInsets.all(context.style.spaceMedium),
            child: ListTile (
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2.0),
                borderRadius: BorderRadius.circular(context.style.radius)
              ),
              leading: imageDisplay,
              title: Text(result['title'] ?? ""),
              subtitle: Text(subtitle),
              trailing: Text(result['category'] ?? ""),
            )
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
          if (results != null) {
            fetchImages(results);
          }
        },
        decoration: InputDecoration(
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

//to do: loading wheel thing?
//add borders
//it also searches tags, might wanna remove