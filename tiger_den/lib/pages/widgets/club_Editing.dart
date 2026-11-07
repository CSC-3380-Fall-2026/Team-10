import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:multi_dropdown/multi_dropdown.dart';

import '../../models/club_options.dart';
import '../../models/organization.dart';
import '../../services/firestore_service.dart';
import '../../services/image_service.dart';
import '../../services/search_service.dart';
import '../../services/tag_service.dart';

/// A form for editing an existing club. It starts filled in with the club's
/// current info and saves back to the SAME club (same ID, never a copy).
/// Only the club's owner or an admin can edit.
class ClubEditForm extends StatefulWidget {
  final String orgId;
  final String currentUserId;
  final FirestoreService? firestoreService;
  final ImageService? imageService;
  final ImagePicker? imagePicker;

  const ClubEditForm({
    super.key,
    required this.orgId,
    required this.currentUserId,
    this.firestoreService,
    this.imageService,
    this.imagePicker,
  });

  @override
  ClubEditFormState createState() {
    return ClubEditFormState();
  }
}

class ClubEditFormState extends State<ClubEditForm> {
  final clubFormKey = GlobalKey<FormState>();
  late ImageService imageService;
  late FirestoreService firestoreService;
  late ImagePicker picker;
  TagService tagService = TagService();

  Organization? organization;
  bool isLoading = true;
  bool isSaving = false;

  TextEditingController nameController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  TextEditingController contactEmailController = TextEditingController();
  TextEditingController instagramController = TextEditingController();
  TextEditingController discordController = TextEditingController();
  TextEditingController meetingLocationController = TextEditingController();
  MultiSelectController<String> tagsController = MultiSelectController<String>();

  /// The selected category (from ClubOptions.categories)
  String? selectedCategory;

  /// The selected tags (from TagService, plus any the club already had)
  List<String> selectedTags = [];

  /// The selected meeting day (from ClubOptions.meetingDays)
  String? selectedMeetingDay;

  /// The selected meeting time
  TimeOfDay? selectedMeetingTime;

  /// The saved meeting time text, if it couldn't be read as a time
  String? oldMeetingTimeText;

  bool isPublic = true;
  bool requiresApproval = false;

  /// NEW images picked while editing (null = keep the current image)
  XFile? selectedLogo;
  XFile? selectedBanner;

  void showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  bool canEdit() {
    final org = organization;
    if (org == null) return false;
    return org.ownerId == widget.currentUserId ||
        org.adminIds.contains(widget.currentUserId);
  }

  Future<void> loadInitialData() async {
    try {
      final org = await firestoreService.getOrganization(widget.orgId);
      if (!mounted) return;
      setState(() {
        organization = org;
        if (org != null) fillForm(org);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      showMessage('Error loading club: $e');
    }
  }

  /// Puts the club's current values into the form fields
  void fillForm(Organization org) {
    nameController.text = org.name;
    descriptionController.text = org.description;
    selectedCategory = org.category.isEmpty ? null : org.category;
    selectedTags = List<String>.from(org.tags);
    contactEmailController.text = org.contactEmail ?? '';
    instagramController.text = org.socialLinks['instagram'] ?? '';
    discordController.text = org.socialLinks['discord'] ?? '';
    final day = org.meetingInfo['day'];
    selectedMeetingDay = (day == null || day.isEmpty) ? null : day;
    final time = org.meetingInfo['time'];
    selectedMeetingTime = ClubOptions.parseTime(time);
    oldMeetingTimeText =
        (selectedMeetingTime == null && time != null && time.isNotEmpty)
            ? time
            : null;
    meetingLocationController.text = org.meetingInfo['location'] ?? '';
    isPublic = org.isPublic;
    requiresApproval = org.requiresApproval;
  }

  @override
  void initState() {
    super.initState();
    imageService = widget.imageService ?? ImageService();
    firestoreService = widget.firestoreService ?? FirestoreService();
    picker = widget.imagePicker ?? ImagePicker();
    loadInitialData();
  }

  /// Picks an image from the gallery and compresses it with ImageService
  Future<void> pickImage({required bool isLogo}) async {
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
      setState(() {
        if (isLogo) {
          selectedLogo = compressed;
        } else {
          selectedBanner = compressed;
        }
      });
    } catch (e) {
      showMessage('Could not pick image: $e');
    }
  }

  Map<String, String> nonBlank(Map<String, String?> fields) {
    final result = <String, String>{};
    fields.forEach((key, value) {
      final text = value?.trim() ?? '';
      if (text.isNotEmpty) result[key] = text;
    });
    return result;
  }

  Future<void> submitForm() async {
    if (isSaving) return;
    if (!clubFormKey.currentState!.validate()) {
      showMessage('Form validation failed');
      return;
    }
    if (organization == null || !canEdit()) {
      showMessage('You do not have permission to edit this club.');
      return;
    }

    setState(() {
      isSaving = true;
    });
    try {
      String? newLogoUrl;
      String? newBannerUrl;
      if (selectedLogo != null) {
        newLogoUrl = await imageService.uploadImageToImgbb(selectedLogo);
        if (newLogoUrl == null) {
          showMessage('Logo upload failed. Club not saved.');
          return;
        }
      }
      if (selectedBanner != null) {
        newBannerUrl = await imageService.uploadImageToImgbb(selectedBanner);
        if (newBannerUrl == null) {
          showMessage('Banner upload failed. Club not saved.');
          return;
        }
      }

      final email = contactEmailController.text.trim();
      final meetingTime = selectedMeetingTime != null
          ? ClubOptions.formatTime(selectedMeetingTime!)
          : oldMeetingTimeText;
      final changes = <String, dynamic>{
        'name': nameController.text.trim(),
        'description': descriptionController.text.trim(),
        'category': selectedCategory ?? '',
        'tags': selectedTags,
        'contactEmail': email.isEmpty ? null : email,
        'socialLinks': nonBlank({
          'instagram': instagramController.text,
          'discord': discordController.text,
        }),
        'meetingInfo': nonBlank({
          'day': selectedMeetingDay,
          'time': meetingTime,
          'location': meetingLocationController.text,
        }),
        'isPublic': isPublic,
        'requiresApproval': requiresApproval,
        'logoUrl': ?newLogoUrl,
        'bannerUrl': ?newBannerUrl,
      };
      // Saves to the club's existing document (same ID, no copies). If the
      // name changed, its events and members' club lists get the new name too.
      await firestoreService.updateOrganization(widget.orgId, changes);
      await updateSearchIndex(changes);

      // Refresh so the page shows what's now saved (e.g. the new logo).
      final saved = await firestoreService.getOrganization(widget.orgId);
      if (mounted) {
        setState(() {
          organization = saved ?? organization;
          selectedLogo = null;
          selectedBanner = null;
        });
      }
      showMessage('Club Updated Successfully!');
    } catch (e) {
      showMessage('Club Not Updated: Error saving club: $e');
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  /// Updates the club's search entry so search shows the new name,
  /// description and tags. Uses the club's ID, so it overwrites the old
  /// entry instead of adding a second one. If search isn't set up (e.g. no
  /// Algolia keys in .env), the club is still saved and this is skipped.
  Future<void> updateSearchIndex(Map<String, dynamic> changes) async {
    try {
      await SearchService().createIndex(
        'club',
        changes['name'] as String,
        changes['description'] as String,
        widget.orgId,
        List<String>.from(changes['tags'] as List),
        'official',
      );
    } catch (e) {
      debugPrint('Club saved, but the search index was not updated: $e');
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    contactEmailController.dispose();
    instagramController.dispose();
    discordController.dispose();
    meetingLocationController.dispose();
    tagsController.dispose();
    //cleanUp throws if nothing was compressed, so ignore that error
    imageService.cleanUp().catchError((_) {});
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Form fields
  // ---------------------------------------------------------------------------

  /// A tap-to-pick image box: shows the new image if one was picked,
  /// otherwise the club's current image (like the event pages).
  Widget buildImagePicker({
    required String label,
    required String? currentUrl,
    required XFile? selected,
    required bool isLogo,
  }) {
    Widget preview;
    if (selected != null) {
      preview = Image.file(File(selected.path), fit: BoxFit.contain);
    } else if (currentUrl != null && currentUrl.isNotEmpty) {
      preview = Image.network(
        currentUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Text('Current $label could not load.'),
      );
    } else {
      preview = Text('No $label. Tap to add one.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label (tap to change)'),
        GestureDetector(
          onTap: () async => pickImage(isLogo: isLogo),
          child: Container(
            height: 100,
            width: double.infinity,
            alignment: Alignment.center,
            child: preview,
          ),
        ),
      ],
    );
  }

  Widget buildNameField() {
    return TextFormField(
      controller: nameController,
      decoration: const InputDecoration(
        labelText: 'Club Name',
        border: UnderlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'This section must be filled out.';
        }
        return null;
      },
    );
  }

  Widget buildDescriptionField() {
    return TextFormField(
      controller: descriptionController,
      decoration: const InputDecoration(
        labelText: 'Club Description',
        border: UnderlineInputBorder(),
      ),
    );
  }

  /// Category dropdown (required)
  Widget buildCategoryDropdown() {
    final options =
        ClubOptions.withCurrent(ClubOptions.categories, selectedCategory);
    return FormField<String>(
      validator: (_) =>
          selectedCategory == null ? 'Select a category for this club' : null,
      builder: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownMenu<String>(
            expandedInsets: EdgeInsets.zero,
            initialSelection: selectedCategory,
            label: const Text('Category'),
            onSelected: (String? value) {
              if (value != null) {
                state.didChange(value);
                setState(() => selectedCategory = value);
              }
            },
            dropdownMenuEntries: [
              for (final c in options)
                DropdownMenuEntry<String>(value: c, label: c),
            ],
          ),
          if (state.hasError)
            Text(state.errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ),
    );
  }

  /// Tags multi-select, using the same TagService list as events
  Widget buildTagsDropdown() {
    final options = ClubOptions.withAll(tagService.fetchTags(), selectedTags);
    return MultiDropdown<String>(
      controller: tagsController,
      fieldDecoration: FieldDecoration(hintText: 'Select Tags'),
      items: options
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

  Widget buildContactEmailField() {
    return TextFormField(
      controller: contactEmailController,
      keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(
        labelText: 'Contact Email',
        border: UnderlineInputBorder(),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) return null; //optional
        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
          return 'Please enter a valid email address';
        }
        return null;
      },
    );
  }

  Widget buildSocialLinksFields() {
    return Column(
      children: [
        TextFormField(
          controller: instagramController,
          decoration: const InputDecoration(labelText: 'Instagram Link'),
        ),
        TextFormField(
          controller: discordController,
          decoration: const InputDecoration(labelText: 'Discord Link'),
        ),
      ],
    );
  }

  /// Meeting day dropdown, meeting time picker, and meeting location
  Widget buildMeetingInfoFields() {
    final days =
        ClubOptions.withCurrent(ClubOptions.meetingDays, selectedMeetingDay);
    final timeText = selectedMeetingTime != null
        ? ClubOptions.formatTime(selectedMeetingTime!)
        : (oldMeetingTimeText ?? 'Meeting Time');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownMenu<String>(
          expandedInsets: EdgeInsets.zero,
          initialSelection: selectedMeetingDay,
          label: const Text('Meeting Day'),
          onSelected: (String? value) =>
              setState(() => selectedMeetingDay = value),
          dropdownMenuEntries: [
            for (final d in days) DropdownMenuEntry<String>(value: d, label: d),
          ],
        ),
        Row(
          children: [
            ElevatedButton(
              onPressed: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: selectedMeetingTime ??
                      const TimeOfDay(hour: 18, minute: 0),
                );
                if (picked != null) {
                  setState(() {
                    selectedMeetingTime = picked;
                    oldMeetingTimeText = null;
                  });
                }
              },
              child: Text(timeText),
            ),
            if (selectedMeetingTime != null || oldMeetingTimeText != null)
              TextButton(
                onPressed: () => setState(() {
                  selectedMeetingTime = null;
                  oldMeetingTimeText = null;
                }),
                child: const Text('Clear time'),
              ),
          ],
        ),
        TextFormField(
          controller: meetingLocationController,
          decoration: const InputDecoration(labelText: 'Meeting Location'),
        ),
      ],
    );
  }

  Widget buildIsPublicRow() {
    return Row(
      children: [
        Checkbox(
          value: isPublic,
          onChanged: (bool? value) {
            setState(() {
              isPublic = value ?? true;
            });
          },
        ),
        const Text('Public club (anyone can find it)'),
      ],
    );
  }

  Widget buildRequiresApprovalRow() {
    return Row(
      children: [
        Checkbox(
          value: requiresApproval,
          onChanged: (bool? value) {
            setState(() {
              requiresApproval = value ?? false;
            });
          },
        ),
        const Text('Joining requires approval'),
      ],
    );
  }

  Widget buildSaveButton() {
    return ElevatedButton(
      onPressed: isSaving ? null : () async { await submitForm(); },
      child: Text(isSaving ? 'Saving...' : 'Save'),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (organization == null) {
      return const Center(child: Text('Club not found.'));
    }
    if (!canEdit()) {
      return const Center(
          child: Text('Only the club owner or an admin can edit this club.'));
    }
    return Form(
      key: clubFormKey,
      child: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            buildImagePicker(
              label: 'Logo',
              currentUrl: organization!.logoUrl,
              selected: selectedLogo,
              isLogo: true,
            ),
            buildImagePicker(
              label: 'Banner',
              currentUrl: organization!.bannerUrl,
              selected: selectedBanner,
              isLogo: false,
            ),
            buildNameField(),
            buildDescriptionField(),
            buildCategoryDropdown(),
            buildTagsDropdown(),
            buildContactEmailField(),
            buildSocialLinksFields(),
            buildMeetingInfoFields(),
            buildIsPublicRow(),
            buildRequiresApprovalRow(),
            buildSaveButton(),
          ],
        ),
      ),
    );
  }
}
