//Sources looked at:https://docs.flutter.dev/cookbook/forms/validation;
// https://medium.com/@kotelnikoff.dev/flutter-forms-basics-and-beyond-40b92e529c0f;
// https://docs.flutter.dev/cookbook/forms/text-input
//https://pub.dev/documentation/image_field/latest/
//https://flutterexplained.com/p/episode-4-image-picker
//https://medium.com/@umuieme/custom-form-field-in-flutter-caf0f816ddd3
//https://medium.com/@mahipalsinhvala5609/build-an-image-picker-in-flutter-a203ffc99623
//https://pub.dev/documentation/material_ui/latest/material_ui/Checkbox-class.html
//https://api.flutter.dev/flutter/material/Checkbox-class.html   
//https://www.geeksforgeeks.org/dart/dart-spread-operator/
//https://api.flutter.dev/flutter/widgets/Visibility-class.html
//https://api.flutter.dev/flutter/material/DropdownMenu-class.html
//https://medium.com/@vishaljhaveri4/crafting-dynamic-dropdowns-in-flutter-with-flutter-infinite-dropdown-e12315f8ef90
//https://stackoverflow.com/questions/56752690/how-to-display-list-of-map-into-dropdownmenuitem-in-flutter
//notes: where i think a database thing would go ill do CALL DATABASE HERE so its not more clear, but its nonexhaustive

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';


//Custom Form widget declaration
class EventCreationForm extends StatefulWidget {
  const EventCreationForm({super.key});

  @override
  EventCreationFormState createState() {
    return EventCreationFormState();
  }
}

// Holds form data and makes the form unique and makes form-validation possible
class EventCreationFormState extends State<EventCreationForm> {
  final _eventFormKey = GlobalKey<FormState>();


  bool virtualChecked = false;
  bool allDayChecked = false;
  bool forOrganization = false;

  String? selectedCategory;
  late List<String> orgList;
  String? selectedClub;

  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  Future<void> _pickImageFromGalleryandDisplay() async {
    
    //fetches picture if selected  
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
    }
  }
  //displays picture on the screen
  Widget _displayPicture() {
    return _selectedImage == null
        ? Text('No image selected.')
        : Image.file(File(_selectedImage!.path));
  }
  //Checks if user is an officer or owner of a club
  //insert database check here to see if the user is an officer or owner of a club
  bool isAdmin(){
    //CALL DATABASE HERE and replace return statement
    return true;
  }
  //retrieves the list of clubs a user is the officer or owner of
  //insert database check here to see if the user is an officer or owner of a club
  List<String> retrieveAdminClubs(){
    //CALL DATABASE HERE and replace return statement
    return ['red club', 'green league', 'blue org'];
  }

//Changes the color of the checkbox when checked so users can know when a box is checked
//might be removed when form defaults come out
  Color checkBoxGetColor(Set<WidgetState> states) {
      const Set<WidgetState> interactiveStates = <WidgetState>{
        WidgetState.pressed,
        WidgetState.hovered,
        WidgetState.focused,
      };
      if (states.any(interactiveStates.contains)) {
        return Colors.blue;
      }
      return Colors.red;
    }
    //initialize list data so it can be loaded into the club list widget
    @override
      void initState() {
        super.initState();
        orgList = retrieveAdminClubs();
      }



  // // Builds the Form widget 
  @override
  Widget build(BuildContext context) {
    return Form(
      key: _eventFormKey,
      child: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            
            TextFormField( //Event Title
              decoration: const InputDecoration(
                labelText: 'Event Title',
                border: UnderlineInputBorder(),
                ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'You must fill this section out';
                }
                return null;
              },
            ), 

            GestureDetector( //ImageGetter
              onTap: () async {await _pickImageFromGalleryandDisplay();}, //display prolly not gonna work but test
              child: Container(
                  height: 100,
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: _displayPicture(),
                  ),
            ),
            
            TextFormField( //Event Description
              decoration: const InputDecoration(
                labelText: 'Event Description',
                border: UnderlineInputBorder(),
                ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'You must fill this section out';
                }
                return null;
              },
            ), 

            TextFormField( //Address
              decoration: const InputDecoration(
                labelText: 'Event Address',
                border: OutlineInputBorder(),
                ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'You must fill this section out';
                }
                return null;
              },
            ), 
            Row(
              children: [
                Expanded(
                  child: TextFormField( //Start Date
                    decoration: const InputDecoration(
                      labelText: 'Start Date',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'You must fill this section out';
                      }
                      return null;
                    },
                  ),
                ),

                Expanded(
                  child: TextFormField( //End Date
                    decoration: const InputDecoration(
                      labelText: 'End Date',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'You must fill this section out';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),

            Checkbox( //all day check box
              checkColor: Colors.white,
              fillColor: WidgetStateProperty.resolveWith(checkBoxGetColor),
              value: allDayChecked,
              onChanged: (bool? value) {
                setState(() {
                allDayChecked = value!;
                });
              },
            ),
            
            //Start and endtimes, only appear if all Day is NOT checked
            if (!allDayChecked)
              Row( 
                children: [
                  Expanded(
                    child: TextFormField( //Start Time
                      decoration: const InputDecoration(
                        labelText: 'Start Time',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'You must fill this section out';
                        }
                        return null;
                      },
                    ),
                  ),
                  Expanded(
                    child: TextFormField( //End Time
                      decoration: const InputDecoration(
                        labelText: 'End Time',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'You must fill this section out';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),

            TextFormField( //Capacity
              decoration: const InputDecoration(
                labelText: 'Max Capacity',
                border: OutlineInputBorder(),
                ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'You must fill this section out';
                }
                return null;
              },
            ), 

            Row( //Is it Virtual checkbox there by default, Meeting link black only appear when box is checked
              children: [
                Expanded(
                  child: Checkbox( // is it virtual check box
                    checkColor: Colors.white,
                    fillColor: WidgetStateProperty.resolveWith(checkBoxGetColor),
                    value: virtualChecked,
                    onChanged: (bool? value) {
                      setState(() {
                      virtualChecked = value!;
                      });
                    },
                  ),
                ),
                
                if (virtualChecked)
                  Expanded(
                    child: TextFormField( //Start Time
                      decoration: const InputDecoration(
                        labelText: 'Meeting Link',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if ((value == null || value.isEmpty)) {
                          return 'You must fill this section out';
                        }
                        return null;
                      },
                    ),
                  ),
              ],
            ),
            //this only shows if the user is an owner or officer of a club
            //this is a dropdown that allows the user to select whether this event is for a club or nonofficial
            //If the club is official, forOrganization is set to true, causing another dropdown to pop up that has their clubs
            if (isAdmin())
              DropdownMenu<String>(
                expandedInsets: EdgeInsets.zero, //DropdownMenu breaks without this, cause it is in SingleChildScrollView
                initialSelection: selectedCategory,
                label: const Text('Select Event Type'),
                onSelected: (String? value) {
                  if (value != null){
                    setState(() {
                     selectedCategory = value;
                     if(value == 'official'){
                      forOrganization = true;
                     } else {
                      forOrganization = false;
                     }
                    });
                  }
                },
                dropdownMenuEntries: const [
                  DropdownMenuEntry<String>(
                    value: 'official',
                    label: 'Event for Official Organization or Club',
                  ),
                  DropdownMenuEntry<String>(
                    value: 'casual',
                    label: 'All Other Events',
                  ),
                ]
              ),

            //is visible if the event is for an official organization
            //selects what would 
            if (forOrganization) 
              DropdownMenu<String>(
                expandedInsets: EdgeInsets.zero,
                initialSelection: selectedClub,
                label: const Text('Select the Club the Event is for'),
                onSelected: (String? value) {
                  if (value != null){
                    setState(() {
                      selectedClub = value;});
                    }
                  }, 
                dropdownMenuEntries: orgList.map((value) {
                  return DropdownMenuEntry<String>(
                    value: value.toString(),
                    label: value.toString(),
                  );
                }).toList(),
              ),

            TextFormField( //Tags (when function is added, would need to separate by commas)
              decoration: const InputDecoration(
                labelText: 'Tags',
                border: OutlineInputBorder(),
                ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'You must fill this section out';
                }
                return null;
              },
            ), 
            ElevatedButton(
              onPressed: () {
                if (_eventFormKey.currentState!.validate()) {
                  ///CALL DATABASE HERE
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('yay i work, now get rid of me')),
                  );
                }
              },
              child: const Text('Submit'),
            ),
        
          ],
        ),
      ),
    );
  }
}