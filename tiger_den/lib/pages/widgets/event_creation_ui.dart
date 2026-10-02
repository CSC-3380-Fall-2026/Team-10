//Sources looked at:https://docs.flutter.dev/cookbook/forms/validation;
// https://medium.com/@kotelnikoff.dev/flutter-forms-basics-and-beyond-40b92e529c0f;
// https://docs.flutter.dev/cookbook/forms/text-input
//https://pub.dev/documentation/image_field/latest/
//https://flutterexplained.com/p/episode-4-image-picker
//https://medium.com/@umuieme/custom-form-field-in-flutter-caf0f816ddd3
//https://medium.com/@mahipalsinhvala5609/build-an-image-picker-in-flutter-a203ffc99623


import 'dart:io';
import 'package:flutter/material.dart';
//import 'package:image_field/image_field.dart';
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
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImageFromGalleryandDisplay() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
    }
  }
  Widget _displayPicture() {
    return _selectedImage == null
        ? Text('No image selected.')
        : Image.file(File(_selectedImage!.path));
  }

  // // Builds the Form widget 
  @override
  Widget build(BuildContext context) {
    return Form(
      key: _eventFormKey,
      child:  Column(
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
          TextFormField( //Tags
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
    );
  }
}

//isVirtual checkbox
//dropdowns:  and meeting url that pops out

//if not all day, then start time and end time pop up
//category drop down that changes betwen 1 and 2 options

//easy add: tags, startTime and Endtime, Max Capacity


//time spent so far is 4h
