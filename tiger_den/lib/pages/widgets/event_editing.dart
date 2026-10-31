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
  final eventFormKey = GlobalKey<FormState>();

  /// The service used for image compression and upload
  ImageService imageService = ImageService();

  /// The service used to communicate with Cloud Firestore
  FirestoreService firestoreService = FirestoreService();

  /// Used to get the list of tags
  TagService tagService = TagService();

  /// The event being edited (as loaded from the database)
  Event? event;

  /// The current user's club memberships
  List<Membership> userMemberships = [];

  bool isLoading = true;
  bool isSaving = false;

  TextEditingController titleController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  TextEditingController addressController = TextEditingController();
  TextEditingController capacityController = TextEditingController();
  TextEditingController meetingLinkController = TextEditingController();
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
  List<String> selectedTags = [];

  /// A NEW image picked while editing (null = keep the current image)
  XFile? selectedImage;
  ImagePicker picker = ImagePicker();

  void showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// The clubs the current user owns or is an admin of
  List<Membership> get adminMemberships => userMemberships
      .where((m) => m.role == OrgRole.owner || m.role == OrgRole.admin)
      .toList();

  /// Returns whether the current user manages at least one club
  bool isAdmin() => adminMemberships.isNotEmpty;

  /// Only the creator, a host, or an owner/admin of the event's club can edit.
  bool canEdit() {
    final e = event;
    if (e == null) return false;
    if (e.createdBy == widget.currentUserId) return true;
    if (e.hostIds.contains(widget.currentUserId)) return true;
    final orgId = e.organizationId;
    return orgId != null && adminMemberships.any((m) => m.orgId == orgId);
  }

  /// Loads the event and the user's memberships, and fills in the form
  Future<void> loadInitialData() async {
    try {
      final loaded = await firestoreService.getEvent(widget.eventId);
      final memberships = await firestoreService
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
    addressController.text = e.location.name;
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
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;
      final compressed = await imageService.compressFile(image);
      if (compressed == null) {
        showMessage('Could not compress that image.');
        return;
      }
      final size = await compressed.length();
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

      final startDate = selectedStartDate!;
      final endDate = selectedEndDate ?? startDate;
      final startDateTime = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
        allDayChecked ? 0 : (selectedStartTime?.hour ?? 0),
        allDayChecked ? 0 : (selectedStartTime?.minute ?? 0),
      );
      final endDateTime = DateTime(
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
        final match = userMemberships.where((m) => m.orgId == orgId);
        orgName = match.isNotEmpty
            ? match.first.orgName
            : event!.organizationName; // keep the existing name copy
      }

      // Only the fields the form edits. createdBy, attendeeCount, status and
      // createdAt are left alone, so the event keeps its owner and RSVPs.
      final changes = <String, dynamic>{
        'title': titleController.text.trim(),
        'description': descriptionController.text.trim(),
        'category': category,
        'organizationId': orgId,
        'organizationName': orgName,
        'startTime': Timestamp.fromDate(startDateTime),
        'endTime': Timestamp.fromDate(endDateTime),
        'allDay': allDayChecked,
        'location': EventLocation(
          name: addressController.text.trim(),
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
      final saved = await firestoreService.getEvent(widget.eventId);
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
    addressController.dispose();
    capacityController.dispose();
    meetingLinkController.dispose();
    multiSelectController.dispose();
    // cleanUp throws if nothing was compressed, so ignore that error
    imageService.cleanUp().catchError((_) {});
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Form fields (same as the event creation form)
  // ---------------------------------------------------------------------------

  /// Changes the checkbox color based on the current widget state
  Color checkBoxGetColor(Set<WidgetState> states) {
    const interactiveStates = <WidgetState>{
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
    final url = event?.imageUrl;
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

  Widget buildAddressField() {
    return TextFormField(
      controller: addressController,
      decoration: const InputDecoration(
        labelText: 'Event Address',
        border: OutlineInputBorder(),
      ),
      validator: requiredText,
    );
  }

  Widget buildDatePicker({required bool isStart}) {
    final selected = isStart ? selectedStartDate : selectedEndDate;
    return FormField<DateTime>(
      validator: (_) => selected == null ? 'You must fill this out.' : null,
      builder: (state) {
        final buttonText = selected == null
            ? (isStart ? 'Start Date' : 'End Date')
            : '${selected.month}/${selected.day}/${selected.year}';
        return ElevatedButton(
          onPressed: () async {
            final picked = await showDatePicker(
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
      children: [
        Expanded(child: buildDatePicker(isStart: true)),
        Expanded(child: buildDatePicker(isStart: false)),
      ],
    );
  }

  Widget buildAllDayCheckbox() {
    return Row(
      children: [
        Checkbox(
          checkColor: Colors.white,
          fillColor: WidgetStateProperty.resolveWith(checkBoxGetColor),
          value: allDayChecked,
          onChanged: (bool? value) =>
              setState(() => allDayChecked = value ?? false),
        ),
        const Text('All-day event'),
      ],
    );
  }

  Widget buildTimePicker({required bool isStart}) {
    final selected = isStart ? selectedStartTime : selectedEndTime;
    return FormField<TimeOfDay>(
      validator: (_) => (!allDayChecked && selected == null)
          ? 'You must fill this out.'
          : null,
      builder: (state) {
        final buttonText = selected == null
            ? (isStart ? 'Start Time' : 'End Time')
            : selected.format(state.context);
        return ElevatedButton(
          onPressed: () async {
            final picked = await showTimePicker(
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
      children: [
        Expanded(child: buildTimePicker(isStart: true)),
        Expanded(child: buildTimePicker(isStart: false)),
      ],
    );
  }

  Widget buildCapacityField() {
    return TextFormField(
      controller: capacityController,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Max Capacity',
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'You must fill this section out';
        }
        if (int.tryParse(value) == null) {
          return 'Please enter a valid number';
        }
        return null;
      },
    );
  }

  Widget buildVirtualRow() {
    return Row(
      children: [
        Checkbox(
          checkColor: Colors.white,
          fillColor: WidgetStateProperty.resolveWith(checkBoxGetColor),
          value: virtualChecked,
          onChanged: (bool? value) =>
              setState(() => virtualChecked = value ?? false),
        ),
        const Text('Virtual'),
        const SizedBox(width: 8),
        if (virtualChecked)
          Expanded(
            child: TextFormField(
              controller: meetingLinkController,
              decoration: const InputDecoration(
                labelText: 'Meeting Link',
                border: OutlineInputBorder(),
              ),
              validator: requiredText,
            ),
          ),
      ],
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
      dropdownMenuEntries: const [
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
      builder: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            dropdownMenuEntries: [
              for (final m in adminMemberships)
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
          .map((tag) => DropdownItem(
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
            buildTitleField(),
            buildImageGetter(),
            buildDescriptionField(),
            buildAddressField(),
            buildDateRow(),
            buildAllDayCheckbox(),
            buildTimeRow(),
            buildCapacityField(),
            buildVirtualRow(),
            buildEventTypeDropdown(),
            buildClubDropdown(),
            buildTagsDropdown(),
            buildSaveButton(),
          ],
        ),
      ),
    );
  }
}
