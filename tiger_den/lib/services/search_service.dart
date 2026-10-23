import 'package:algolia_client_search/algolia_client_search.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
class SearchService {
  SearchClient? client;
  String? appIdKey = dotenv.env['ALGOLIA_APP_ID']?.trim();
  String? searchKey = dotenv.env['ALGOLIA_SEARCH_ONLY_KEY']?.trim();
  String? writeKey = dotenv.env['ALGOLIA_WRITE_KEY']?.trim();
  SearchService() {
    if (appIdKey == null) {
      print("App ID api key null");
      return;
    }
    if (searchKey == null) {
      print("Search api key null");
      return;
    }
    client = SearchClient(appId: appIdKey!, apiKey: writeKey!);
  } 

  SearchClient? getSearchClient(){
    if(client != null) {
      return client; 
    }
    if (appIdKey == null){
      print("App ID api key null");
      return null;
    }
    if (searchKey == null){
      print("Search api key null");
      return null;
    }
    client = SearchClient(appId: appIdKey!, apiKey: writeKey!);
    return client; 
  }
  
  Future<String> createIndex(String title, String description, String id) async {
    try {
      await client!.saveObject(
        indexName: 'project_SEARCH',
        body: {
          'objectID': id, 
          'title': title,
          'description': description,
        },
      );
      print("Successfully indexed to Algolia via SearchClient!");
  } catch (e) {
    print("Algolia indexing failed: $e");
  }
    return id;
  }


  Future<void> deleteIndex(String indexId) async {
    if(indexId == ""){
      return; 
    }
    try {
      SearchClient cli = getSearchClient()!;
      await cli.deleteObject(
        indexName: 'project_SEARCH',
        objectID: indexId,
      );
      print("Successfully deleted from Algolia!");
    } catch (e) {
      print("Delete failed: $e");
    }
  }
}





