import 'package:algolia_client_search/algolia_client_search.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

typedef SearchResult = Map<String, dynamic>;
class SearchService {
  SearchClient? client;
  ///Enviornmental variable used to enable search index write and search; the Algolia ID for our project
  String? appIdKey = dotenv.env['ALGOLIA_APP_ID']?.trim();
  ///Enviornmental variable used to enable search index search
  String? searchKey = dotenv.env['ALGOLIA_SEARCH_ONLY_KEY']?.trim();
  ///Enviornmental variable used to enable search index writeIf we have time, hide this later for security reasons
  String? writeKey = dotenv.env['ALGOLIA_WRITE_KEY']?.trim();
  ///Initializes the client needed for algolia function
  SearchService() {
    getSearchClient("write");
  } 
///Gets the client needed for algolia functions
  SearchClient? getSearchClient(String clientType){
    if (appIdKey == null){
      print("App ID api key null");
      return null;
    }
    if (clientType =="write") {
      if (writeKey == null){
        print("Write api key null");
        return null;
      }
      client = SearchClient(appId: appIdKey!, apiKey: writeKey!);
    } else {
      if (clientType =="search" && searchKey == null){
        print("Search api key null");
        return null;
        }
        client = SearchClient(appId: appIdKey!, apiKey: searchKey!);}
    return client; 
  }
  ///Creates and index for searching. Neccessary for every time an event or club is added. type refers to event vs club, category is official vs unofficial 
  Future<String> createIndex(String type, String title, String description, String id, List<String>tags, String category) async {
    try {
      getSearchClient("write");
      SaveObjectResponse response = await client!.saveObject(
        indexName: 'project_SEARCH',
        body: {
          'type': type,
          'objectID': id, 
          'title': title,
          'description': description,
          'tags': tags,
          'category': category,
        },
      );
      await client!.waitTask(indexName: 'project_SEARCH', taskID: response.taskID);
      print("Successfully indexed to Algolia via SearchClient!");
  } catch (e) {
    print("Algolia indexing failed: $e");
    return "";
  }
    return id;
  }
///Deletes database object for searching
  Future<void> deleteIndex(String indexId) async {
    if(indexId == ""){
      return; 
    }
    try {
      getSearchClient("write");
      await client!.deleteObject(
        indexName: 'project_SEARCH',
        objectID: indexId,
      );
      print("Successfully deleted from Algolia!");
    } catch (e) {
      print("Delete failed: $e");
    }
  }

  ///Takes user input, searches Algolia, and returns items ranked in relation to it. Has some page logic included. 
  Future<List<SearchResult>>? search({
    required String input,
    String? type,
    String? category,
    List<String>? selectedTags,
    int page = 0,
  }) async {
    try {
      if (searchKey == null) {
        print("SearchKey null.");
        return [];
      }
      if (appIdKey == null) {
        print("appIdKey null.");
        return [];
      }
      getSearchClient("search");
      List<String> conditions = [];
      if (type != null && type.trim().isNotEmpty) {
        conditions.add("type:'${type.trim()}'");
      }
      if (category != null && category.trim().isNotEmpty) {
        conditions.add("category:'${category.trim()}'");
      }

      if (selectedTags != null && selectedTags.isNotEmpty) {
        for (var tag in selectedTags) {
          if (tag.trim().isNotEmpty) {
            conditions.add("tags:'${tag.trim()}'");
          }
        }
      }
      List<List<String>>? filters;
      if (conditions.isNotEmpty) {
        filters = [conditions];
      }
      final searchParams = SearchMethodParams(
        requests: [
          SearchForHits(
            indexName: 'project_SEARCH',
            query: input,
            facetFilters: filters,
            page: 0,  
            hitsPerPage: 20,
            typoTolerance: true,
            minWordSizefor1Typo: 4, //Seems to be the recommended size to start for 1 typo
            minWordSizefor2Typos: 7, //Seems to be the recommended size to start for 2 typos
          ),
        ],
      );
      SearchResponses searchResponse = await client!.search(searchMethodParams: searchParams);
      var result = searchResponse.results.first;
      if (result.isNotEmpty) {
        var hits = result['hits'];
        List<SearchResult> cleanedResults = [];
        if (hits != null) {
          for (var hit in hits) {
            // SearchResult data = Map<String, dynamic>.from(hit);
            cleanedResults.add(hit); 
          }
        }
        return cleanedResults;
      }
    } catch (e) {
      print("Search Failed: $e");
      return [];
    }
    return [];
  }
}
