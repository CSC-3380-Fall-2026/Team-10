import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:multi_dropdown/multi_dropdown.dart';

import '../../models/event.dart';
import '../../models/organization.dart';
import '../../services/firestore_service.dart';
import '../../services/image_service.dart';
import '../../services/search_service.dart';
import '../../services/tag_service.dart';

/// A form for editing an existing event. It mirrors the event creation form
/// (event_creation_ui.dart), but starts filled in with the event's current
/// info and saves back to the SAME event (same ID, never a copy).
///
/// Only the event's creator, its hosts, or an owner/admin of its club can edit.
class EventEditForm extends StatefulWidget {
  final String eventId;
  final String currentUserId;

  const EventEditForm({
    super.key,
    required this.eventId,
    required this.currentUserId,
  });

  @override
  EventEditFormState createState() => EventEditFormState();
}

/// Stores the state and form data for EventEditForm
class EventEditFormState extends State<EventEditForm> {
  /// The key used to validate this form
  final GlobalKey<FormState> eventFormKey = GlobalKey<FormState>();

  /// The service used for image compression and upload
  ImageService imageService = ImageService();

  /// The service used to communicate with Cloud Firestore
  FirestoreService firestoreService = FirestoreService();

  /// Used to get the list of tags
  TagService tagService = TagService();

  /// The event being edited (as loaded from the database)
  Event? event;

  /// The current user's club memberships
  List<Membership> userMemberships = <Membership>[];

  bool isLoading = true;
  bool isSaving = false;

  TextEditingController titleController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  TextEditingController locationController = TextEditingController();
  TextEditingController capacityController = TextEditingController();
  TextEditingController meetingLinkController = TextEditingController();
  TextEditingController minCapController = TextEditingController();
  MultiSelectController<String> multiSelectController =
      MultiSelectController<String>();

  bool virtualChecked = false;
  bool allDayChecked = false;

  /// "official" (for a club) or "casual"
  String category = "casual";

  DateTime? selectedStartDate;
  DateTime? selectedEndDate;
  TimeOfDay? selectedStartTime;
  TimeOfDay? selectedEndTime;

  /// The ID of the club this event is for (when category is "official")
  String? selectedClubId;

  /// The tags selected for this event
  List<String> selectedTags = <String>[];

  /// A NEW image picked while editing (null = keep the current image)
  XFile? selectedImage;
  ImagePicker picker = ImagePicker();

  void showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// The clubs the current user owns or is an admin of
  List<Membership> get adminMemberships => userMemberships
      .where((Membership m) => m.role == OrgRole.owner || m.role == OrgRole.admin)
      .toList();

  /// Returns whether the current user manages at least one club
  bool isAdmin() => adminMemberships.isNotEmpty;

  /// Only the creator, a host, or an owner/admin of the event's club can edit.
  bool canEdit() {
    final Event? e = event;
    if (e == null) return false;
    if (e.createdBy == widget.currentUserId) return true;
    if (e.hostIds.contains(widget.currentUserId)) return true;
    final String? orgId = e.organizationId;
    return orgId != null && adminMemberships.any((Membership m) => m.orgId == orgId);
  }

  /// Loads the event and the user's memberships, and fills in the form
  Future<void> loadInitialData() async {
    try {
      final Event? loaded = await firestoreService.getEvent(widget.eventId);
      final List<Membership> memberships = await firestoreService
          .streamMyMemberships(widget.currentUserId)
          .first;
      if (!mounted) return;
      setState(() {
        event = loaded;
        userMemberships = memberships;
        if (loaded != null) fillForm(loaded);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      showMessage('Error loading event: $e');
    }
  }

  /// Puts the event's current values into the form fields
  void fillForm(Event e) {
    titleController.text = e.title;
    descriptionController.text = e.description;
    locationController.text = e.location.name;
    capacityController.text = e.capacity?.toString() ?? '';
    virtualChecked = e.location.isVirtual;
    meetingLinkController.text = e.location.meetingUrl ?? '';
    allDayChecked = e.allDay;
    category = e.category == 'official' ? 'official' : 'casual';
    selectedClubId = e.organizationId;
    selectedTags = List<String>.from(e.tags);
    selectedStartDate = DateTime(
        e.startTime.year, e.startTime.month, e.startTime.day);
    selectedEndDate =
        DateTime(e.endTime.year, e.endTime.month, e.endTime.day);
    selectedStartTime = TimeOfDay.fromDateTime(e.startTime);
    selectedEndTime = TimeOfDay.fromDateTime(e.endTime);
  }

  @override
  void initState() {
    super.initState();
    loadInitialData();
  }

  /// Selects an image from the gallery and compresses it
  Future<void> pickImageFromGalleryAndDisplay() async {
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;
      final XFile? compressed = await imageService.compressFile(image);
      if (compressed == null) {
        showMessage('Could not compress that image.');
        return;
      }
      final int size = await compressed.length();
      if (size >= 100000) {
        showMessage('Compressed size: $size bytes. File too large to upload.');
        return;
      }
      setState(() => selectedImage = compressed);
    } catch (e) {
      showMessage('Could not pick image: $e');
    }
  }

  /// Validates the form and saves the changes to the existing event
  Future<void> submitForm() async {
    if (isSaving) return;
    if (!eventFormKey.currentState!.validate()) {
      showMessage('Form validation failed');
      return;
    }
    if (event == null || !canEdit()) {
      showMessage('You do not have permission to edit this event.');
      return;
    }

    setState(() => isSaving = true);
    try {
      String? newImageUrl;
      if (selectedImage != null) {
        newImageUrl = await imageService.uploadImageToImgbb(selectedImage);
        if (newImageUrl == null) {
          showMessage('Image upload failed. Event not saved.');
          return;
        }
      }

      final DateTime startDate = selectedStartDate!;
      final DateTime endDate = selectedEndDate ?? startDate;
      final DateTime startDateTime = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
        allDayChecked ? 0 : (selectedStartTime?.hour ?? 0),
        allDayChecked ? 0 : (selectedStartTime?.minute ?? 0),
      );
      final DateTime endDateTime = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        allDayChecked ? 23 : (selectedEndTime?.hour ?? 23),
        allDayChecked ? 59 : (selectedEndTime?.minute ?? 59),
      );
      if (endDateTime.isBefore(startDateTime)) {
        showMessage('The event can\'t end before it starts.');
        return;
      }

      // Which club the event belongs to (official events only).
      String? orgId;
      String? orgName;
      if (category == 'official' && selectedClubId != null) {
        orgId = selectedClubId;
        final Iterable<Membership> match = userMemberships.where((Membership m) => m.orgId == orgId);
        orgName = match.isNotEmpty
            ? match.first.orgName
            : event!.organizationName; // keep the existing name copy
      }

      // Only the fields the form edits. createdBy, attendeeCount, status and
      // createdAt are left alone, so the event keeps its owner and RSVPs.
      final Map<String, dynamic> changes = <String, dynamic>{
        'title': titleController.text.trim(),
        'description': descriptionController.text.trim(),
        'category': category,
        'organizationId': orgId,
        'organizationName': orgName,
        'startTime': Timestamp.fromDate(startDateTime),
        'endTime': Timestamp.fromDate(endDateTime),
        'allDay': allDayChecked,
        'location': EventLocation(
          name: locationController.text.trim(),
          address: event!.location.address,
          geo: event!.location.geo,
          isVirtual: virtualChecked,
          meetingUrl:
              virtualChecked ? meetingLinkController.text.trim() : null,
        ).toMap(),
        'capacity': int.tryParse(capacityController.text.trim()),
        'tags': selectedTags,
        'imageUrl': ?newImageUrl,
      };

      // Saves to the event's existing document (same ID, no copies). If the
      // title/times/location changed, attendees' calendars get updated too.
      await firestoreService.updateEvent(widget.eventId, changes);
      await updateSearchIndex();

      // Refresh so the page shows what's now saved.
      final Event? saved = await firestoreService.getEvent(widget.eventId);
      if (mounted) {
        setState(() {
          event = saved ?? event;
          selectedImage = null;
        });
      }
      showMessage('Event Updated Successfully!');
    } catch (e) {
      showMessage('Event Not Updated: Error saving event: $e');
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  /// Updates the event's search entry by its ID (overwrites, no duplicates).
  /// If search isn't set up (no Algolia keys in .env), this is skipped.
  Future<void> updateSearchIndex() async {
    try {
      await SearchService().createIndex(
        'event',
        titleController.text.trim(),
        descriptionController.text.trim(),
        widget.eventId,
        selectedTags,
        category,
      );
    } catch (e) {
      debugPrint('Event saved, but the search index was not updated: $e');
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    locationController.dispose();
    capacityController.dispose();
    meetingLinkController.dispose();
    multiSelectController.dispose();
    minCapController.dispose();
    // cleanUp throws if nothing was compressed, so ignore that error
    imageService.cleanUp().catchError((dynamic _) {});
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Form fields (same as the event creation form)
  // ---------------------------------------------------------------------------

  /// Changes the checkbox color based on the current widget state
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

  String? requiredText(String? value) =>
      (value == null || value.trim().isEmpty)
          ? 'You must fill this section out'
          : null;

  Widget buildTitleField() {
    return TextFormField(
      controller: titleController,
      decoration: const InputDecoration(
        labelText: 'Event Title',
        border: UnderlineInputBorder(),
      ),
      validator: requiredText,
    );
  }

  /// Shows the new image if one was picked, otherwise the current one
  Widget displayPicture() {
    if (selectedImage != null) {
      return Image.file(File(selectedImage!.path));
    }
    final String? url = event?.imageUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        errorBuilder: (_, _, _) => const Text('Current image could not load.'),
      );
    }
    return const Text('No image. Tap to add one.');
  }

  Widget buildImageGetter() {
    return GestureDetector(
      onTap: () async => pickImageFromGalleryAndDisplay(),
      child: Container(
        height: 100,
        width: double.infinity,
        alignment: Alignment.center,
        child: displayPicture(),
      ),
    );
  }

  Widget buildDescriptionField() {
    return TextFormField(
      controller: descriptionController,
      decoration: const InputDecoration(
        labelText: 'Event Description',
        border: UnderlineInputBorder(),
      ),
      validator: requiredText,
    );
  }

  Widget buildLocationField() {
    return TextFormField(
      controller: locationController,
      decoration: const InputDecoration(
        labelText: 'Event Location',
        border: OutlineInputBorder(),
      ),
      validator: requiredText,
    );
  }

  Widget buildDatePicker({required bool isStart}) {
    final DateTime? selected = isStart ? selectedStartDate : selectedEndDate;
    return FormField<DateTime>(
      validator: (_) => selected == null ? 'You must fill this out.' : null,
      builder: (FormFieldState<DateTime> state) {
        final String buttonText = selected == null
            ? (isStart ? 'Start Date' : 'End Date')
            : '${selected.month}/${selected.day}/${selected.year}';
        return ElevatedButton(
          onPressed: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: selected ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              state.didChange(picked);
              setState(() {
                if (isStart) {
                  selectedStartDate = picked;
                } else {
                  selectedEndDate = picked;
                }
              });
            }
          },
          child: Text(buttonText),
        );
      },
    );
  }

  Widget buildDateRow() {
    return Row(
      children: <Widget>[
        Expanded(child: buildDatePicker(isStart: true)),
        Expanded(child: buildDatePicker(isStart: false)),
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
                validator: requiredText,
              )
            ),
          ),
          buildAllDayCheckbox(),
        ],
      );

  }

  Widget buildTimePicker({required bool isStart}) {
    final TimeOfDay? selected = isStart ? selectedStartTime : selectedEndTime;
    return FormField<TimeOfDay>(
      validator: (_) => (!allDayChecked && selected == null)
          ? 'You must fill this out.'
          : null,
      builder: (FormFieldState<TimeOfDay> state) {
        final String buttonText = selected == null
            ? (isStart ? 'Start Time' : 'End Time')
            : selected.format(state.context);
        return ElevatedButton(
          onPressed: () async {
            final TimeOfDay? picked = await showTimePicker(
              context: context,
              initialTime: selected ?? TimeOfDay.now(),
            );
            if (picked != null) {
              state.didChange(picked);
              setState(() {
                if (isStart) {
                  selectedStartTime = picked;
                } else {
                  selectedEndTime = picked;
                }
              });
            }
          },
          child: Text(buttonText),
        );
      },
    );
  }

  Widget buildTimeRow() {
    if (allDayChecked) return const SizedBox.shrink();
    return Row(
      children: <Widget>[
        Expanded(child: buildTimePicker(isStart: true)),
        Expanded(child: buildTimePicker(isStart: false)),
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

  /// Official club event vs. casual event (only shown to club owners/admins)
  Widget buildEventTypeDropdown() {
    if (!isAdmin()) return const SizedBox.shrink();
    return DropdownMenu<String>(
      expandedInsets: EdgeInsets.zero,
      initialSelection: category,
      label: const Text('Select Event Type'),
      onSelected: (String? value) {
        if (value != null) setState(() => category = value);
      },
      dropdownMenuEntries: const <DropdownMenuEntry<String>>[
        DropdownMenuEntry<String>(
          value: 'official',
          label: 'Event for Official Organization or Club',
        ),
        DropdownMenuEntry<String>(
          value: 'casual',
          label: 'All Other Events',
        ),
      ],
    );
  }

  /// Which of the user's clubs the event is for (official events only)
  Widget buildClubDropdown() {
    if (category != 'official') return const SizedBox.shrink();
    return FormField<String>(
      validator: (_) =>
          selectedClubId == null ? 'Select the club this event is for' : null,
      builder: (FormFieldState<String> state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DropdownMenu<String>(
            expandedInsets: EdgeInsets.zero,
            initialSelection: selectedClubId,
            label: const Text('Select the Club the Event is for'),
            onSelected: (String? value) {
              if (value != null) {
                state.didChange(value);
                setState(() => selectedClubId = value);
              }
            },
            dropdownMenuEntries: <DropdownMenuEntry<String>>[
              for (final Membership m in adminMemberships)
                DropdownMenuEntry<String>(value: m.orgId, label: m.orgName),
            ],
          ),
          if (state.hasError)
            Text(state.errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ),
    );
  }

  Widget buildTagsDropdown() {
    return MultiDropdown<String>(
      controller: multiSelectController,
      fieldDecoration: FieldDecoration(hintText: 'Select Tags'),
      items: tagService
          .fetchTags()
          .map((String tag) => DropdownItem(
                label: tag,
                value: tag,
                selected: selectedTags.contains(tag),
              ))
          .toList(),
      onSelectionChange: (List<String> selectedItems) {
        setState(() => selectedTags = selectedItems);
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
  Widget buildSaveButton() {
    return ElevatedButton(
      onPressed: isSaving ? null : () async => submitForm(),
      child: Text(isSaving ? 'Saving...' : 'Save Changes'),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (event == null) {
      return const Center(child: Text('Event not found.'));
    }
    if (!canEdit()) {
      return const Center(
        child: Text(
            'Only the event creator, a host, or a club admin can edit this event.'),
      );
    }
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
            buildSaveButton(), //add protections
            
          ],
        ),
      ),
    );
  }
}
