import 'package:algolia_client_search/algolia_client_search.dart';
import 'package:flutter/material.dart';
import '../../services/search_service.dart';
import '../../base_designs/sitewide/design_main.dart';
import '../../services/image_service.dart';
import '../widgets/filter_widget.dart';
import '../../models/search_filter.dart';

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
  // /// /The controller for the searchbar
  // final TextEditingController searchController = TextEditingController();

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
          
          Widget? imageDisplay;
          if (imagelink != "") {
            imageDisplay = ClipRRect(
                child: Image.network(
                  imagelink,
                )
              );
            }
          return Padding (
            padding: EdgeInsets.only(
              left: context.style.spaceLarge,
              top: context.style.spaceMedium,
              right: context.style.spaceLarge,
              bottom: context.style.spaceExtraSmall,
            ),
            child: ListTile (
              tileColor: Theme.of(context).colorScheme.surface,
              onTap: () {
                if(type == "event"){
                  print('add link to event viewing widgets hereeeeeeeeeeeeeeee');
                } else if (type == "club"){
                  print('add link to club viewing widgets hereeeeeeeeeeeeeeee');
                }
                  },
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
      padding: EdgeInsets.only(
        left: cont.style.spaceMedium,
        top: cont.style.spaceSmall,
        right: cont.style.spaceMedium,
        bottom: cont.style.spaceExtraSmall,
      ),
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
          hintText: "Search...",
          suffixIcon: IconButton(
            icon: const Icon(Icons.filter_alt),
              onPressed: () {
                ///bring up search filters
              },
            ),
          ),
      )
    );
  }

  Widget searchTitle(String text, BuildContext cont) {
    return Container(
      padding: EdgeInsets.only(
        left: cont.style.spaceMedium,
        top: cont.style.spaceSmall,
        right: cont.style.spaceMedium,
        bottom: cont.style.spaceSmall,
      ), 
      child: Center( 
        child: Text(
          text,
          style: TextStyle(
            fontSize: cont.style.textTheme.titleLarge!.fontSize, //Maybe change in final design
            color: Theme.of(cont).colorScheme.onSurface
          ),
        )
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
            searchTitle("Clubs and Organizations:", context),
            Expanded (
              child: indexListView('club') ///might need to do an intermediate widget for searchpage idle screen
            ),
            searchTitle("Events that match:", context),
            Expanded (
              child: indexListView('event')
            ),
            //backToTop()
          ],
        )
      )
    );
  }
}

//to do: loading wheel thing? (for search definitely, maybe image loading)

//it also searches tags and categories and stuff, might wanna remove
