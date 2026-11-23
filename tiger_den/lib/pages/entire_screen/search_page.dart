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
  /// Controller to scroll back to the top
  ScrollController scrollController = ScrollController();
  /// Bool for if events are still loading 
  bool eventLoading = false;
  /// Bool for if clubs are still loading 
  bool clubLoading = false;
  /// int for the limit of how many clubs are displayed 
  int clubLimit = 5;
  /// int for the limit of how many events are displayed 
  int eventLimit = 5;
  /// passed to the search service when needed to search for more events/clubs
  int currentPage = 0; 
  /// Bool for if search service is still loading more events/clubs
  bool loadingMore = false;
  /// Initializes the page
  @override
  void initState() {
    super.initState();
  }
  /// Disposes controllers when closing page
  @override
  void dispose() {
    searchController.dispose();
    scrollController.dispose();
    imageService.cleanUp();
    super.dispose();
  }
  /// Builds display for if no items are found after searching
  Widget noItemsFound(){
    return SliverToBoxAdapter(
      child: Padding(
        padding:EdgeInsetsGeometry.all(context.style.spaceMedium),
        child: Center( child: Text("No results found."))
      )
    );
  }
  /// Fetches the image for a certain event or club
  Future<void> fetchImages(List<SearchResult> results) async {
    for (var result in results) {
      if (result['objectID'] != null) {
        if(result['type'] == 'event'){
          String objectId = result['objectID'];
          if (imageUrls.containsKey(objectId)) continue;
          try {
            String url = await imageService.getEventImageURL(objectId); ///'6C7ZGFjaJs5jMVYvzSoj' <testing
            if (mounted) {
              setState(() {
                imageUrls[objectId] = url;
              });
            }
          } catch (e) {}
        } else { 
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
  /// Loads more clubs/events 
  Future<void> loadMore(String type) async {
    if (loadingMore) return; //prevent da spamclick
    setState(() {
      loadingMore = true;
      if (type == 'club'){
        clubLoading = true;
      } else {
        eventLoading = true;
      }
      });
    String input = searchController.text.trim();
    int nextPage = currentPage + 1;
    List<Map<String, dynamic>>? moreResults = await searchService.search(input: input, page: nextPage);
    setState(() {
      loadingMore = false;
      if (type == 'club'){
        clubLoading = false;
      } else {
        eventLoading = false;
      }
      if (moreResults != null && moreResults.isNotEmpty) {
        currentPage = nextPage;
        _indexList.addAll(moreResults);
      }
    });

    if (moreResults != null && moreResults.isNotEmpty) {
      fetchImages(moreResults);
    }
  }
  /// Lists event or clubs that come up after being searched
  Widget indexListView(String type){
    bool isLoading = (type == 'club') ? clubLoading : eventLoading;
    if (isLoading) {
      return SliverToBoxAdapter(child: SizedBox.shrink());
    }
    if (_indexList.isEmpty) {
      return noItemsFound();
    }
    List<Map<String, dynamic>>? filteredList = _indexList.where((Map<String, dynamic> item) => item['type'] == type).toList(); 
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
  ///Builds show more button, extends club/event limit and loads more
  Widget showMoreButton(String type) {
    List<Map<String, dynamic>>? filteredList = _indexList.where((Map<String, dynamic> item) => item['type'] == type).toList();
    int currentLimit = (type == 'club') ? clubLimit : eventLimit;
    if (filteredList.length <= currentLimit) {
      return SliverToBoxAdapter(child: SizedBox.shrink());
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
            currentLimit = (type == 'club') ? clubLimit : eventLimit;
            if (currentLimit >= filteredList.length) {
              loadMore(type);
            }
          },
          icon: const Icon(Icons.keyboard_arrow_down),
          label: const Text("Show More"),
        ),
      ),
    );
  }
  ///Searches according to provided text and filters
  Future<void> search() async {
    String input = searchController.text.trim();
    if (input.isEmpty) return;
    setState(() {
      clubLoading = true;
      eventLoading = true;
    });
    List<String> cat = [];
    List<String> tag = List.from(currentFilters);
    if (currentFilters.contains("official")){
      cat.add("official");
      tag.remove("official");
    } 
    if (currentFilters.contains("unofficial")) {
      cat.add("unofficial");
      tag.remove("unofficial");
    }

    List<Map<String, dynamic>>? results = await searchService.search(input: input, category: cat, selectedTags: tag);
    setState(() {
      _indexList = results ?? [];
      clubLimit = 5; 
      eventLimit = 5; 
      currentPage = 0;
      clubLoading = false;
      eventLoading = false;
    });
    if (results != null) {
      fetchImages(results);
    }
  }
  ///Builds search bar
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
  ///Builds Titles
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
  ///Builds the drawer for the filter widget
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
  /// Helper function used to scroll to the top of the page
  void scrollToTop() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.minScrollExtent,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    }
  }
  ///Builds button for scrolling back to the top
  Widget goToTopButton(){
    return SliverToBoxAdapter(
      child: ElevatedButton.icon(
        onPressed: scrollToTop,
        icon: Icon(Icons.arrow_upward),
        label: Text("Go Back to Top")
      )
    );
  }
  /// builds the loading widgets
  Widget loadingWid(bool isLoading){
    if (!loadingMore && isLoading) {
      return Center(child: CircularProgressIndicator());
    } else {
      return SizedBox.shrink();
    }
  }


  ///Builds the search page
  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.purple,
        backgroundColor: Colors.grey,
        title: const Text('Search'),
        actions: const [SizedBox.shrink()],
      ),
      endDrawer: filterDrawer(),
      body: Padding( 
        padding: EdgeInsetsGeometry.symmetric(vertical: context.style.pageMargin), 
        child: CustomScrollView(
          controller: scrollController,
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
            SliverToBoxAdapter(
              child: loadingWid(clubLoading)
              ),
            indexListView('club'),
            showMoreButton('club'),
            SliverToBoxAdapter(
              child: displayTitle("Events that match:", context),
            ),
            SliverToBoxAdapter(
              child: loadingWid(eventLoading)
            ),
            indexListView('event'),
            showMoreButton('event'),
            goToTopButton(),
          ],
        ),
      ),
    );
  }
}

//to do: loading wheel thing? (for search definitely, maybe image loading)

//it also searches tags and categories and stuff, might wanna remove
