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
    Key? key, 
    required this.alreadySelected,
    required this.onFiltersSubmitted,
    }) : super(key: key);
  
@override
  State<FilterWidget> createState() => FilterWidgetState();
}

class FilterWidgetState extends State<FilterWidget> {
  ///
  late List<String> selectedFilters; 
  /// 
  TagService tagService = TagService();
  /// 
  late List<String> availableTags;
  ///
  ScrollController scrollController = ScrollController();
  /// 
  @override
  void initState() {
    super.initState(); 
    availableTags = tagService.fetchTags(); 
    selectedFilters = List.from(widget.alreadySelected);
  }
  ///Disposes scroll controller when page closes
  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }
  /// 
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
  /// 
  Widget showTitleAndList(String text, Widget widge, BuildContext cont){
    return Column(
      children: [
        displayTitle(text, cont),
        Padding (
          padding: EdgeInsets.all(cont.style.spaceSmall),
          child: widge,
        )
      ]
    );
  }
  /// 
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

  /// 
  Widget listTags(){
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: availableTags.length,
      itemBuilder: (context, index) {
        String tag = availableTags[index];
        if(tag == "official" || tag == 'unofficial'){
          return Container();
        }
        bool isChecked = selectedFilters.contains(tag);
        return CheckboxListTile(
          title: Text(tag),
          value: isChecked,
          onChanged: (bool? value) {
            setState(() {
              if (value == true) {
                selectedFilters.add(tag);
              } else {
                selectedFilters.remove(tag);
              }
            });
          },
        );
      }
    );
  }

  ///
  Widget listCategories() { 
    bool offChecked = selectedFilters.contains("official");
    bool unoChecked = selectedFilters.contains("unofficial");
    return Column(
      children: [
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
            });
          },
        )
      ]
    );
  }

  void scrollToBottom() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    }
  }

  Widget goToBottomButton(){
    return Align(
        alignment: Alignment.bottomRight,
        child: Opacity(
          opacity: 0.75,
          child: FloatingActionButton.extended(
            onPressed: scrollToBottom,
            icon: Icon(Icons.arrow_downward),
            // label: Text("Go to Bottom to Submit!"),
            label: Text("Bottom"),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return /*Scaffold(
      body: */SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              controller: scrollController, 
              padding: EdgeInsets.all(context.style.spaceSmall),
              child: Column(
                children: [
                  showTitleAndList("Category:", listCategories(), context),
                  showTitleAndList("Tags:", listTags(), context),
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