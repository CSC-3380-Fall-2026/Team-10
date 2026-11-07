import '../../services/tag_service.dart';
import 'package:flutter/material.dart';
import '../../base_designs/sitewide/design_main.dart';
import '../../services/tag_service.dart';

class FilterWidget extends StatefulWidget {
  /// List of already selected filters
  final List<String> alreadySelected;
  const FilterWidget({
    Key? key, 
    required this.alreadySelected}) : super(key: key);
  
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
  @override
  void initState() {
    super.initState(); 
    availableTags = tagService.fetchTags(); 
    selectedFilters = List.from(widget.alreadySelected);
  }
  /// 
  Widget submitFilters(){
    return ElevatedButton(
      onPressed: () {     
        Navigator.pop(context, selectedFilters); ///i so glad this exists lol   
      },
      child: Text('Apply Filters'),
    );
  }
  /// 
  Widget showTitleAndList(String text, Widget widge, BuildContext cont){
    return Column(
      children: [
        displayTitle(text, cont),
        widge
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
      itemCount: availableTags.length,
      itemBuilder: (context, index) {
        String tag = availableTags[index];
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


  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.style.spaceSmall),
      child: Column(
        children: [
          showTitleAndList("Category:", listCategories(), context),
          showTitleAndList("Tags:", listTags(), context)
        ] 
      )
    );
  }
}

///add: 
///everything checked by default
///select/deselect everything



 