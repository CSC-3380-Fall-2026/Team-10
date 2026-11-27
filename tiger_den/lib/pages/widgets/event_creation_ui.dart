import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:multi_dropdown/multi_dropdown.dart';
import '../../models/app_user.dart';
import '../../models/event.dart';
import '../../models/organization.dart';
import '../../services/firestore_service.dart';
import '../../services/image_service.dart';
import '../../services/search_service.dart';
import '../../services/tag_service.dart';

///A form for creating an event
class EventCreationForm extends StatefulWidget {
  final String currentUserId;
  const EventCreationForm({
    super.key,
    required this.currentUserId,
  });

  @override
  EventCreationFormState createState() {
    return EventCreationFormState();
  }
}

///Stores the state and form data for EventCreationForm
class EventCreationFormState extends State<EventCreationForm> {
  ///The key used to validate this form
  final GlobalKey<FormState> eventFormKey = GlobalKey<FormState>();
  ///The service used for image compression and modification
  ImageService imageService = ImageService();
  ///The service used to communicate with Cloud Firestore
  FirestoreService firestoreService = FirestoreService();
  ///The service used to upload the event to the search function
  SearchService searchService = SearchService();
  ///Service used to fetch tags
  TagService tagService = TagService();
  ///The currently signed-in user's profile
  AppUser? currentUser;

  ///The controller for the event title field
  TextEditingController titleController = TextEditingController();
  ///The controller for the event description field
  TextEditingController descriptionController = TextEditingController();
  ///The controller for the event location field
  TextEditingController locationController = TextEditingController();
  ///The controller for the event capacity field
  TextEditingController capacityController = TextEditingController();
  ///The controller for the event minCapacity field
  TextEditingController minCapController = TextEditingController();
  ///The controller for the virtual meeting link field
  TextEditingController meetingLinkController = TextEditingController();
  ///The controller for the event tags dropdown
  MultiSelectController<String> multiSelectController = MultiSelectController<String>();
  
  ///Whether the event is virtual
  bool virtualChecked = false;
  ///Whether the event lasts all day
  bool allDayChecked = false; 
  ///Whether the event is associated with an official club/organization or a casual, unrecognized one
  String category = "casual";
  ///Id for search index of event uploaded
  String searchIndexId = "";
  ///Prevents spam clicking
  bool submitClicked = false;

  ///The selected starting date for the event
  DateTime? selectedStartDate;
  ///The selected ending date for the event
  DateTime? selectedEndDate;
  ///The selected starting time for the event
  TimeOfDay? selectedStartTime;
  ///The selected ending time for the event
  TimeOfDay? selectedEndTime;

  ///The selected organization name
  String? selectedClub;
  ///The selected event category
  String? selectedCategory;
  ///The organizations managed by the current user
  List<String> orgList = <String>[]; 
  ///The current user's organization memberships
  List<Membership> userMemberships = <Membership>[];
  ///The tags selected for this event
  List<String> selectedTags = <String>[];
  
  ///The image selected for the event
  XFile? selectedImage;
  ///The image URL from the selected image
  String? selectedImageUrl;
  ///The image picker used to select an event image
  ImagePicker picker = ImagePicker();
  ///Selects an image from the device gallery, compresses it, renames it, and displays it
  Future<void> pickImageFromGalleryAndDisplay() async {
    XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) {return;}
    XFile? compressedImage = await imageService.compressFile(image);
    int fileLength = -1;
    if (compressedImage != null) {fileLength = await compressedImage!.length();
      if (fileLength < 100000) {
        setState(() {
          selectedImage = compressedImage;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Compressed size: $fileLength bytes. File too large to upload.'),
              duration: Duration(seconds: 2),
              ),
          );
        }
      }
    }
  }

  ///Displays the selected picture on the screen
  Widget displayPicture() {
    return selectedImage == null
        ? Text('No image selected.')
        : Image.file(File(selectedImage!.path));
  }

  ///Returns whether the current user is an officer or owner of an organization
  bool isAdmin(){
    for (final Membership m in userMemberships) {
      if (m.role == OrgRole.owner || m.role == OrgRole.admin) {
        return true;
      }
    }
    return false;
  }

  ///Retrieves the list of organizations the current user manages
  List<String> retrieveAdminClubs(){
    List<String> adminClubs = <String>[];
    for (final Membership m in userMemberships) {
      if (m.role == OrgRole.owner || m.role == OrgRole.admin) {
        adminClubs.add(m.orgName);
      }
    }
    return adminClubs;
  }

  ///Changes the checkbox color based on the current widget state
  Color checkBoxGetColor(Set<WidgetState> states) {
    Set<WidgetState> interactiveStates = <WidgetState>{
      WidgetState.pressed,
      WidgetState.hovered,
      WidgetState.focused,
    };
    if (states.any(interactiveStates.contains)) {
      return Colors.blue;
    }
    return Colors.red;
  }

  ///Loads the initial user profile and organization memberships from the database
  Future<void> loadInitialData() async {
    try {
      final AppUser? user = await firestoreService.getUser(widget.currentUserId);
      final List<Membership> membershipsSnap = await firestoreService.streamMyMemberships(widget.currentUserId).first;
      if (mounted) {
        setState(() {
          currentUser = user;
          userMemberships = membershipsSnap;
          orgList = retrieveAdminClubs();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading initial data: $e')),
        );
      }
    }
  }

  ///Initializes and fetches starting data
  @override
  void initState() {
    super.initState();
    loadInitialData();
  }

  ///Validates the input fields and uploads the new event to Firestore
  Future<void> submitForm() async {
    if (!eventFormKey.currentState!.validate()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Form validation failed')),
        );
      }
      return;
    }
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User profile not loaded yet. Please wait.')),
        );
      }
      return;
    }

    try {
      final DateTime startDate = selectedStartDate ?? DateTime.now();
      final DateTime endDate = selectedEndDate ?? startDate;
      
      final TimeOfDay? startTime = selectedStartTime;
      final DateTime startDateTime = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
        allDayChecked ? 0 : (startTime != null ? startTime.hour : 0),
        allDayChecked ? 0 : (startTime != null ? startTime.minute : 0),
      );

      final TimeOfDay? endTime = selectedEndTime;
      final DateTime endDateTime = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        allDayChecked ? 23 : (endTime != null ? endTime.hour : 23),
        allDayChecked ? 59 : (endTime != null ? endTime.minute : 59),
      );

      String? targetOrgId;
      if (category == "official" && selectedClub != null) {
          Membership match = userMemberships.first; 
          for (final Membership m in userMemberships) {
            if (m.orgName == selectedClub) {
              match = m;
              break;
            }
          }
          targetOrgId = match.orgId;
        }
      final Event newEvent = Event(
        id: '', 
        organizationId: targetOrgId,
        createdBy: currentUser!.id,
        title: titleController.text.trim(),
        description: descriptionController.text.trim(),
        category: category,
        startTime: startDateTime,
        endTime: endDateTime,
        allDay: allDayChecked,
        location: EventLocation(
          name: locationController.text.trim(),
          isVirtual: virtualChecked,
          meetingUrl: virtualChecked ? meetingLinkController.text.trim() : null,
        ),
        capacity: int.tryParse(capacityController.text.trim()),
        minCapacity: int.tryParse(minCapController.text.trim()),
        tags: selectedTags,
        imageUrl: selectedImageUrl,
        visibility: EventVisibility.public,
        status: EventStatus.scheduled,
      );
      
      String fireUploadID = await firestoreService.createEvent(newEvent);
      String indexId = await searchService.createIndex(
      "event", 
      titleController.text.trim(),
      descriptionController.text.trim(), 
      fireUploadID, 
      selectedTags, 
      category); 
      searchIndexId = indexId;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event Created Successfully!')),
        );
      } 
    } catch (e) { 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Event Not Created: Error creating event: $e')),
        );
      }
      searchService.deleteIndex(searchIndexId);
    }
  }

  ///Disposes text and dropdown controllers when finished
  ///implemented when exiting page
  @override
  void dispose() { 
    titleController.dispose();
    descriptionController.dispose();
    locationController.dispose();
    capacityController.dispose();
    minCapController.dispose();
    meetingLinkController.dispose();
    multiSelectController.dispose();
    imageService.cleanUp();
    super.dispose();
  }

  ///Builds the text field for the event title
  Widget buildTitleField() {
    return TextFormField(
      controller: titleController,
      decoration: InputDecoration(
        labelText: 'Event Title',
        border: UnderlineInputBorder(),
      ),
      validator: (String? value) {
        if (value == null || value.isEmpty) {
          return 'You must fill this section out';
        }
        return null;
      },
    );
  }

  ///Builds the image selection field
  Widget buildImageGetter() {
    return GestureDetector(
      onTap: () async { await pickImageFromGalleryAndDisplay(); },
      child: Container(
        height: 100,
        width: double.infinity,
        alignment: Alignment.center,
        child: displayPicture(),
      ),
    );
  }

  ///Builds the text field for the event description
  Widget buildDescriptionField() {
    return TextFormField(
      controller: descriptionController,
      decoration: InputDecoration(
        labelText: 'Event Description',
        border: UnderlineInputBorder(),  
      ),
      validator: (String? value) {
        if (value == null || value.isEmpty) {
          return 'You must fill this section out';
        }
        return null;
      },
    );
  }

  ///Builds the text field for the event location
  Widget buildLocationField() {
    return TextFormField(
      controller: locationController,
      keyboardType: TextInputType.streetAddress,
      decoration: InputDecoration(
        labelText: 'Event Location',
        border: OutlineInputBorder(),
      ),
      validator: (String? value) {
        if ((value == null || value.isEmpty) && !virtualChecked) {
          return 'You must fill this section out';
        }
        return null;
      },
    );
  }

  ///Builds the start date picker field
  Widget buildStartDatePicker() {
    return FormField<DateTime>(
      validator: (DateTime? value) {
        if (selectedStartDate == null) {
          return 'You must fill the start date out.';
        }
        return null;
      },
      builder: (FormFieldState<DateTime> state) {
        String buttonText;
        if (selectedStartDate == null) {
          buttonText = 'Start Date';
        } else {
          buttonText = "${selectedStartDate!.month}/${selectedStartDate!.day}/${selectedStartDate!.year}";
        }
        return ElevatedButton(
          onPressed: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: selectedStartDate ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              state.didChange(picked);
              setState(() {
                selectedStartDate = picked;
              });
            }
          },
          child: Text(buttonText),
        );
      },
    );
  }

  ///Builds the end date picker field
  Widget buildEndDatePicker() {
    return FormField<DateTime>(
      validator: (DateTime? value) {
        if (selectedEndDate == null) {
          return 'You must fill the end date out.';
        }
        return null;
      },
      builder: (FormFieldState<DateTime> state) {
        String buttonText;
        if (selectedEndDate == null) {
          buttonText = 'End Date';
        } else {
          buttonText = "${selectedEndDate!.month}/${selectedEndDate!.day}/${selectedEndDate!.year}";
        }
        return ElevatedButton(
          onPressed: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: selectedEndDate ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              state.didChange(picked);
              setState(() {
                selectedEndDate = picked;
              });
            }
          },
          child: Text(buttonText),
        );
      },
    );
  }


  ///Builds the row containing both min and max capacity 
  Widget buildCapacityRow() {
    return Row(
      children: <Widget>[
        Expanded(
          /// true is min
          child: buildCapacityField(true),
        ),
        Expanded(
          child: buildCapacityField(false),
        ),
      ],
    );
  }

  ///Builds the row containing both start and end date pickers
  Widget buildDateRow() {
    return Row(
      children: <Widget>[
        Expanded(
          child: buildStartDatePicker(),
        ),
        Expanded(
          child: buildEndDatePicker(),
        ),
      ],
    );
  }

  ///Builds the checkbox specifying whether the event is an all-day event
  Widget buildAllDayCheckbox() {
    return Expanded (
      child: Row(
        children: <Widget>[
          Expanded(
            child: Checkbox(
              checkColor: Colors.white,
              fillColor: WidgetStateProperty.resolveWith(checkBoxGetColor),
              value: allDayChecked,
              onChanged: (bool? value) {
                setState(() {
                  allDayChecked = value!;
                });
              },
            ),
          ),
          Expanded(
            child: Text(
              "All Day?",
              // style: context.,
            )
          ),
        ]
      )
    );
  }

  ///Builds the start time picker field
  Widget buildStartTimePicker() {
    return FormField<TimeOfDay>(
      validator: (TimeOfDay? value) {
        if (!allDayChecked && selectedStartTime == null) {
          return 'You must fill the start time out.';
        }
        return null;
      },
      builder: (FormFieldState<TimeOfDay> state) {
        String buttonText;
        if (selectedStartTime == null) {
          buttonText = 'Start Time';
        } else {
          buttonText = selectedStartTime!.format(state.context);
        }

        return ElevatedButton(
          onPressed: () async {
            final TimeOfDay? picked = await showTimePicker(
              context: context,
              initialTime: selectedStartTime ?? TimeOfDay.now(),
            );
            if (picked != null) {
              state.didChange(picked);
              setState(() {
                selectedStartTime = picked;
              });
            }
          },
          child: Text(buttonText),
        );
      },
    );
  }

  ///Builds the end time picker field
  Widget buildEndTimePicker() {
    return FormField<TimeOfDay>(
      validator: (TimeOfDay? value) {
        if (!allDayChecked && selectedEndTime == null) {
          return 'You must fill the end time out.';
        }
        return null;
      },
      builder: (FormFieldState<TimeOfDay> state) {
        String buttonText;
        if (selectedEndTime == null) {
          buttonText = 'End Time';
        } else {
          buttonText = selectedEndTime!.format(state.context);
        }
        return ElevatedButton(
          onPressed: () async {
            final TimeOfDay? picked = await showTimePicker(
              context: context,
              initialTime: selectedEndTime ?? TimeOfDay.now(),
            );
            if (picked != null) {
              state.didChange(picked);
              setState(() {
                selectedEndTime = picked;
              });
            }
          },
          child: Text(buttonText),
        );
      },
    );
  }

  ///Builds the row containing the start and end time pickers when not an all-day event
  Widget buildTimeRow() {
    if (allDayChecked) {
      return SizedBox.shrink();
    }
    return Row(
      children: <Widget>[
        Expanded(
          child: buildStartTimePicker(),
        ),
        Expanded(
          child: buildEndTimePicker(),
        ),
      ],
    );
  }

  ///Builds the text field for maximum attendee capacity
  Widget buildCapacityField(bool isMin) {
    TextEditingController control = capacityController;
    String label = 'Maxiumum Attendance';
    if(isMin){
      control = minCapController;
      label = 'Minimum Attendance';
    }
    return TextFormField(
      controller: control,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
      validator: (String? value) {
        if (value == null || value.isEmpty) {
          return null;
        }
        if (int.tryParse(value.trim()) == null) {
          return 'Please enter a valid number';
        }
        return null;
      },
    );
  }

  Widget buildVirtualCheckbox(){
    return Expanded(
      child: Row(
        children: <Widget>[
          Expanded(
            child: Checkbox(
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
          Expanded(
            child: Text(
              "Virtual?",
              // style: context.,
            )
          ),
        ]
      )
    );
  }

  ///Builds the virtual event checkbox, the conditional meeting link input field, and the all day checkbox
  Widget buildCheckboxRow() {
    return Row(
        children: <Widget>[
          buildVirtualCheckbox(),
          Expanded(
            child: Visibility(
              visible: virtualChecked,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: TextFormField(
                controller: meetingLinkController,
                decoration: InputDecoration(
                  labelText: 'Link - Meeting',
                  border: OutlineInputBorder(),
                ),
                validator: (String? value) {
                  if ((value == null || value.isEmpty)) {
                    return 'You must fill this section out';
                  }
                  return null;
                },
              )
            ),
          ),
          buildAllDayCheckbox(),
        ],
      );

  }

  ///Builds the dropdown to toggle between official organization events and other events
  Widget buildEventTypeDropdown() {
    if (!isAdmin()) {
      return SizedBox.shrink();
    }
    return DropdownMenu<String>(
      expandedInsets: EdgeInsets.zero,
      initialSelection: selectedCategory,
      label: const Text('Select Event Type'),
      onSelected: (String? value) {
        if (value != null){
          setState(() {
            selectedCategory = value;
            if(value == 'official'){
              category = "official";
            } else {
              category = "casual";
            }
          });
        }
      },
      dropdownMenuEntries: <DropdownMenuEntry<String>>[
        DropdownMenuEntry<String>(
          value: 'official',
          label: 'Event for Official Organization or Club',
        ),
        DropdownMenuEntry<String>(
          value: 'casual',
          label: 'All Other Events',
        ),
      ]
    );
  }

  ///Builds the dropdown allowing selection among the organizations the user manages
  Widget buildClubDropdown() {
    if (category == "casual") {
      return SizedBox.shrink();
    }
    return DropdownMenu<String>(
      expandedInsets: EdgeInsets.zero,
      initialSelection: selectedClub,
      label: const Text('Select the Club the Event is for'),
      onSelected: (String? value) {
        if (value != null){
          setState(() {
            selectedClub = value;
          });
        }
      }, 
      dropdownMenuEntries: orgList.map((String value) {
        return DropdownMenuEntry<String>(
          value: value.toString(),
          label: value.toString(),
        );
      }).toList(),
    );
  }

  ///Builds the multi-select dropdown for tags
  Widget buildTagsDropdown() {
    return MultiDropdown<String>(
      controller: multiSelectController,
      fieldDecoration: FieldDecoration(
        hintText: 'Select Tags',
      ),
      items: tagService.fetchTags().map((String item) => DropdownItem(
        label: item, 
        value: item,)).toList(),
      onSelectionChange: (List<String> selectedItems) {
        setState(() {
          selectedTags = selectedItems;
        });
      },
    );
  }

  ///Builds the form 
  @override
  Widget build(BuildContext context) {
    return Form(
      key: eventFormKey,
      child: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            buildImageGetter(),
            buildTitleField(),
            buildDescriptionField(),
            buildLocationField(),
            buildCheckboxRow(), //oo i see an issue
            buildDateRow(),
            buildTimeRow(),
            buildCapacityRow(),
            buildEventTypeDropdown(),
            buildClubDropdown(),
            buildTagsDropdown(),
            ElevatedButton(
              onPressed: () async {
                if(!submitClicked){
                  Set<FormFieldState<Object?>> validations = eventFormKey.currentState!.validateGranularly();
                    if (validations != null && validations.isNotEmpty) {
                      String err = validations.first.errorText ?? 'Form validation failed for unknown reason.';
                      if(mounted){
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Form Validation Failed: $err')),
                        );
                      }
                      return;
                    }
                  try {
                    ///put loading thing here?
                    submitClicked = true;
                    if(mounted){
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Uploading...')),
                      );
                    }
                    if (selectedImage != null) {
                      debugPrint("Awaiting Image Upload");
                      selectedImageUrl = await imageService.uploadImageToImgbb(selectedImage!);
                      debugPrint("Image Uploaded");
                      if (selectedImageUrl == null) {
                        if(mounted){
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('ImageURL is null.')),
                          );
                        }
                      }
                    }
                    debugPrint("Awaiting Upload");
                    await submitForm();
                    submitClicked = false;
                    if(mounted){
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Event Uploaded Successfully.')),
                      );
                    }        
                    debugPrint("Event Tried Uploading");
                  } catch (e) {
                    submitClicked = false;
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to Upload Form: $e')),
                      );
                    }
                  }
                } else {
                  if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Still uploading form. Image Uploading Can Take  a Long Time.')),
                      );
                    }
                }
              },
              child: Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}


///Things to add: way to go back maybe?? like cancel? idk
