import '../../services/tag_service.dart';
import 'package:flutter/material.dart';
import '../../base_designs/sitewide/design_main.dart';
import '../../services/tag_service.dart';

class FilterWidget extends StatefulWidget {
  /// List of already selected filters 
  final List<String> alreadySelected;
  /// Callback 
  final Function(List<String>) onFiltersSubmitted; 

  const FilterWidget({ 
    Key? super.key,
    required List<String> this.alreadySelected,
    required dynamic Function(List<String>) this.onFiltersSubmitted,
    });
  
@override
  State<FilterWidget> createState() => FilterWidgetState();
}

class FilterWidgetState extends State<FilterWidget> {
  /// List of Checked Filters
  late List<String> selectedFilters; 
  /// Service to get tags
  TagService tagService = TagService();
  /// List of all tags
  late List<String> availableTags;
  /// List of Tags with ordered titles
  late Map<String, List<String>> orderedTags;
  /// Controller for scrolling
  ScrollController scrollController = ScrollController();
  /// initiates state, selected filters, list of all tags
  @override
  void initState() {
    super.initState(); 
    availableTags = List.from(tagService.fetchTags()); 
    selectedFilters = List.from(widget.alreadySelected);
    orderedTags = Map.from(tagService.fetchCatTags());
    updateSelectAll();
  }
  ///Disposes scroll controller when page closes
  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }
  /// Submits filters/saves them
  Widget submitFilters(BuildContext cont){
    return Align(
      alignment: AlignmentGeometry.bottomLeft,
      child: Padding(
        padding: EdgeInsets.only(left: cont.style.spaceSmall),
        child: ElevatedButton(
          onPressed: () {     
            widget.onFiltersSubmitted(selectedFilters);
            Navigator.pop(context); 
          },
          child: Text('Apply Filters'),
        )
      )
    );
  }
  /// Shows the title and the appropiate widget
  Widget showTitleAndList(String text, Widget widge, BuildContext cont){
    return Column(
      children: <Widget>[
        displayTitle(text, cont),
        Padding (
          padding: EdgeInsets.all(cont.style.spaceSmall),
          child: widge,
        )
      ]
    );
  }
  /// Displays the large titles
  Widget displayTitle(String text, BuildContext cont) {
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

  ///Displays the smaller titles for the tags
  Widget displayTagTitle(String text, BuildContext cont) {
    return Container(
      padding: EdgeInsets.all(cont.style.spaceExtraSmall), 
      child: Center( 
        child: Text(
          text,
          style: TextStyle(
            fontSize: cont.style.textTheme.titleMedium!.fontSize, //Maybe change in final design
            color: Theme.of(cont).colorScheme.onSurface
          ),
        )
      )
    );
  }//availableTags
  /// Displays the smaller titles for the tags and displays the tags
  Widget listTagNTitle(){
    return Column(
      children: orderedTags.entries.map((MapEntry<String, List<String>> entry) {
        return Column(
          children: <Widget>[
            displayTagTitle(entry.key, context),
            listTags(entry.value), 
          ],
        );
      }).toList(),
    );
  }
  ///Lists all tags passed
  Widget listTags(List<String> avTags){
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: avTags.length,
      itemBuilder: (BuildContext context, int index) {
        String tag = avTags[index];
        if(tag == "official" || tag == 'unofficial'){
          return SizedBox.shrink();
        }
        bool isChecked = selectedFilters.contains(tag);
        return CheckboxListTile(
          visualDensity: VisualDensity.compact,
          title: Text(tag),
          value: isChecked,
          onChanged: (bool? value) {
            setState(() {
              if (value == true) {
                selectedFilters.add(tag);
              } else {
                selectedFilters.remove(tag);
              }
              updateSelectAll();
            });
          },
        );
      }
    );
  }
  ///Whether or not every tag is selected
  bool allSelected = false;
  ///The text displayed to either select or deselect all
  String selectText = "Select All";
  ///Updates the text and checkmark for select all
  void updateSelectAll() {
    bool matchesAll = ((availableTags.every((String tag) => selectedFilters.contains(tag))) && selectedFilters.contains("official") && selectedFilters.contains("unofficial"));
    setState(() {
      allSelected = matchesAll;
      selectText = allSelected ? "Deselect All" : "Select All";
    });
  }
/// Builds select/deselect all check mark
Widget selectAll() {
  return CheckboxListTile(
    title: Text(selectText),
    value: allSelected,
    onChanged: (bool? value) {
      setState(() {
        if (value == true) {
          allSelected = true;
          selectText = "Deselect All";
          for (String tag in availableTags) {
            if (!selectedFilters.contains(tag)) {
              selectedFilters.add(tag);
            }
          }
          if (!selectedFilters.contains("official")) selectedFilters.add("official");
          if (!selectedFilters.contains("unofficial")) selectedFilters.add("unofficial");
        } else {
          allSelected = false;
          selectText = "Select All";
          for (String tag in availableTags) {
            selectedFilters.remove(tag);
          }
          if (selectedFilters.contains("official")) selectedFilters.remove("official");
          if (selectedFilters.contains("unofficial")) selectedFilters.remove("unofficial");
        }
      });
    },
  );
}
  ///Builds the list of categories with check boxes
  Widget listCategories() { 
    bool offChecked = selectedFilters.contains("official");
    bool unoChecked = selectedFilters.contains("unofficial");
    return Column(
      children: <Widget>[
        CheckboxListTile(
          title: Text("official"),
          value: offChecked,
          onChanged: (bool? value) {
            setState(() {
              if (value == true) {
                selectedFilters.add("official");
              } else {
                selectedFilters.remove("official");
              }
              updateSelectAll();
            });
          },
        ),
        CheckboxListTile(
          title: Text("unofficial"),
          value: unoChecked,
          onChanged: (bool? value) {
            setState(() {
              if (value == true) {
                selectedFilters.add("unofficial");
              } else {
                selectedFilters.remove("unofficial");
              }
              updateSelectAll();
            });
          },
        )
      ]
    );
  }
  ///Scroll to bottom mechanism that will smoothly bring the user to the bottom
  void scrollToBottom() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    }
  }
  ///Builds the scroll to bottom button to scroll to the bottom
  Widget goToBottomButton(){
    return Align(
        alignment: Alignment.bottomRight,
        child: Opacity(
          opacity: 0.75,
          child: FloatingActionButton.extended(
            onPressed: scrollToBottom,
            icon: Icon(Icons.arrow_downward),
            label: Text("Submit"),
            backgroundColor: context.style.colorScheme.primaryContainer,
          ),
        ),
      );
  }

  ///Builds the filter widget
  @override
  Widget build(BuildContext context) {
    return /*Scaffold(
      body: */SafeArea(
        child: Stack(
          children: <Widget>[
            SingleChildScrollView(
              controller: scrollController, 
              padding: EdgeInsets.all(context.style.spaceSmall),
              child: Column(
                children: <Widget>[
                  selectAll(),
                  showTitleAndList("Category:", listCategories(), context),
                  showTitleAndList("Tags:", listTagNTitle(), context),
                  submitFilters(context),
                ] 
              )
            ),
            goToBottomButton(),
          ]
        )
      //)
    );
  }
}

///add: 
///Search tags
///go to top/go to bottom
///everything checked by default
///select/deselect everything



          //  Padding(
          //   padding: EdgeInsets.all(context.style.spaceSmall),
          //   child: showTitleAndList("Category:", listCategories(), context),
          // ),
          // Padding(
          //   padding: EdgeInsets.all(context.style.spaceSmall),
          //   child: showTitleAndList("Tags:", listTags(), context),
          // )