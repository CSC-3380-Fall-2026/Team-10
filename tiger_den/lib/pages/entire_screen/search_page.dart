import 'package:algolia_client_search/algolia_client_search.dart';
import 'package:flutter/material.dart';
import '../../services/search_service.dart';
import '../../base_designs/sitewide/design_main.dart';
import '../../services/image_service.dart';
import '../widgets/filter_widget.dart';


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
  /// List of current filters
  List<String> currentFilters = [];
  /// Controller to track and reuse the current search query
  TextEditingController searchController = TextEditingController();
  
  int clubLimit = 5;
  int eventLimit = 5;
  /// Initializes the page
  int currentPage = 0; 
  bool loadingMore = false;
  @override
  void initState() {
    super.initState();
  }
  /// Disposes text controllers when closing page
  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Widget noItemsFound(){
    return SliverToBoxAdapter(
      child: Text("No results found.")
    );
  }
  
    Future<void> fetchImages(List<SearchResult> results) async {
    for (var result in results) {
      if (result['objectID'] != null) {
        if(result['type'] == 'event'){
          String objectId = result['objectID'];
          if (imageUrls.containsKey(objectId)) continue;
          try {
            String url = await imageService.getEventImageURL(objectId); ///'6C7ZGFjaJs5jMVYvzSoj'
            if (mounted) {
              setState(() {
                imageUrls[objectId] = url;
              });
            }
          } catch (e) {}
        } else if (result['type'] == 'club'){ 
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
  Future<void> loadMore() async {
    if (loadingMore) return; //prevent da spamclick
    setState(() => loadingMore = true);
    String input = searchController.text.trim();
    int nextPage = currentPage + 1;
    final moreResults = await searchService.search(input: input, page: nextPage);
    setState(() {
      loadingMore = false;
      if (moreResults != null && moreResults.isNotEmpty) {
        currentPage = nextPage;
        _indexList.addAll(moreResults);
      }
    });

    if (moreResults != null && moreResults.isNotEmpty) {
      fetchImages(moreResults);
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

    int currentLimit = (type == 'club') ? clubLimit : eventLimit;
    int displayCount = (filteredList.length <= currentLimit) ? filteredList.length : currentLimit;
    return SliverList(
    delegate: SliverChildBuilderDelegate(
        (context, index){ 
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
            imageDisplay = SizedBox(
              child: ClipRRect(
                child: Image.network(
                  imagelink,
                  fit: BoxFit.cover,
                )
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
            child: Material(
              color: context.style.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(context.style.radius),
                side: BorderSide(
                  color: context.style.colorScheme.primary,
                  width: 2,
                ),
              ),
              child: ListTile (
                tileColor: context.style.colorScheme.surface,
                onTap: () {
                  if(type == "event"){
                    print('add link to event viewing widgets hereeeeeeeeeeeeeeee');
                  } else if (type == "club"){
                    print('add link to club viewing widgets hereeeeeeeeeeeeeeee');
                  }
                    },
                leading: imageDisplay,
                title: Text(result['title'] ?? ""),
                subtitle: Text(subtitle),
                trailing: Text(result['category'] ?? ""),
              )
            )
          );
        },
        childCount: displayCount,
      )
    );
  }

  Widget showMoreButton(String type) {
    final filteredList = _indexList.where((item) => item['type'] == type).toList();
    int currentLimit = (type == 'club') ? clubLimit : eventLimit;
    if (filteredList.length <= currentLimit) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverToBoxAdapter(
      child: Center(
        child: TextButton.icon(
          onPressed: () {
            setState(() {
              if (type == 'club') {
                clubLimit += 5; 
              } else {
                eventLimit += 5; 
              }
            });
            if (currentLimit >= filteredList.length) {
              loadMore();
            }
          },
          icon: const Icon(Icons.keyboard_arrow_down),
          label: const Text("Show More"),
        ),
      ),
    );
  }
  Future<void> search() async {
    String input = searchController.text.trim();
    if (input.isEmpty) return;
    final results = await searchService.search(input: input);
    setState(() {
      _indexList = results ?? [];
      clubLimit = 5; 
      eventLimit = 5; 
      currentPage = 0;
    });
    if (results != null) {
      fetchImages(results);
    }
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
        controller: searchController,
        onSubmitted: (value) async {
          search();
        },
        decoration: InputDecoration(
          hintText: "Search...",
          suffixIcon: IconButton(
            icon: const Icon(Icons.filter_alt),
              onPressed: () {
                Scaffold.of(cont).openEndDrawer();
              },
            ),
          ),
      )
    );
  }

  Widget displayTitle(String text, BuildContext cont) {
    return Container(
      padding: EdgeInsets.only(
        left: cont.style.spaceMedium,
        top: cont.style.spaceSmall,
        right: cont.style.spaceMedium,
        bottom: 0,
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

  Widget filterDrawer(){
    return Drawer(
      width: context.style.width * 0.75,
            child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: FilterWidget(
                alreadySelected: currentFilters,
                onFiltersSubmitted: (updatedFilters) {
                  setState(() {
                    currentFilters = updatedFilters;
                  });
                  if (searchController.text.isNotEmpty) {
                    search();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      endDrawer: filterDrawer(),
      body: SafeArea( 
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Builder(
                builder: (BuildContext cont) {
                  return searchBar(cont);
                },
              ),
            ),
            SliverToBoxAdapter(
              child: displayTitle("Clubs and Organizations:", context),
            ),
            indexListView('club'),
            showMoreButton('club'),
            SliverToBoxAdapter(
              child: displayTitle("Events that match:", context),
            ),
            indexListView('event'),
            showMoreButton('event'),
          ],
        ),
      ),
    );
  }
}

//to do: loading wheel thing? (for search definitely, maybe image loading)

//it also searches tags and categories and stuff, might wanna remove
