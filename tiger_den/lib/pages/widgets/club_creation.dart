import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:multi_dropdown/multi_dropdown.dart';

import '../../models/app_user.dart';
import '../../models/club_options.dart';
import '../../models/organization.dart';
import '../../services/firestore_service.dart';
import '../../services/image_service.dart';
import '../../services/search_service.dart';
import '../../services/tag_service.dart';

/// A form for creating a new club. It has the same fields as the club editing
/// page (club_Editing.dart), starts empty, and makes the current user the
/// club's owner.
class ClubCreateForm extends StatefulWidget {
  final String currentUserId;
  final FirestoreService? firestoreService;
  final ImageService? imageService;
  final ImagePicker? imagePicker;

  /// Called with the new club's ID after it's created (e.g. to open its page).
  final ValueChanged<String>? onCreated;

  const ClubCreateForm({
    super.key,
    required this.currentUserId,
    this.firestoreService,
    this.imageService,
    this.imagePicker,
    this.onCreated,
  });

  @override
  ClubCreateFormState createState() {
    return ClubCreateFormState();
  }
}

class ClubCreateFormState extends State<ClubCreateForm> {
  final clubFormKey = GlobalKey<FormState>();
  late ImageService imageService;
  late FirestoreService firestoreService;
  late ImagePicker picker;
  TagService tagService = TagService();

  /// The current user's profile; they become the club's owner
  AppUser? owner;
  bool isLoading = true;
  bool isSaving = false;

  /// Set after the club is created, so the form can't create it twice
  String? createdOrgId;
  String? createdOrgName;

  TextEditingController nameController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  TextEditingController contactEmailController = TextEditingController();
  TextEditingController instagramController = TextEditingController();
  TextEditingController discordController = TextEditingController();
  TextEditingController meetingLocationController = TextEditingController();
  MultiSelectController<String> tagsController = MultiSelectController<String>();

  String? selectedCategory;
  List<String> selectedTags = [];
  String? selectedMeetingDay;
  TimeOfDay? selectedMeetingTime;

  bool isPublic = true;
  bool requiresApproval = false;

  XFile? selectedLogo;
  XFile? selectedBanner;

  void showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Loads the current user's profile (needed to make them the owner)
  Future<void> loadInitialData() async {
    try {
      final user = await firestoreService.getUser(widget.currentUserId);
      if (!mounted) return;
      setState(() {
        owner = user;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      showMessage('Error loading your profile: $e');
    }
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

  /// Validates the form and creates the club in Firestore
  Future<void> submitForm() async {
    if (isSaving || createdOrgId != null) return; // never create twice
    if (!clubFormKey.currentState!.validate()) {
      showMessage('Form validation failed');
      return;
    }
    final creator = owner;
    if (creator == null) {
      showMessage('Your profile isn\'t loaded, so the club can\'t be created.');
      return;
    }

    setState(() {
      isSaving = true;
    });
    try {
      String? logoUrl;
      String? bannerUrl;
      if (selectedLogo != null) {
        logoUrl = await imageService.uploadImageToImgbb(selectedLogo);
        if (logoUrl == null) {
          showMessage('Logo upload failed. Club not created.');
          return;
        }
      }
      if (selectedBanner != null) {
        bannerUrl = await imageService.uploadImageToImgbb(selectedBanner);
        if (bannerUrl == null) {
          showMessage('Banner upload failed. Club not created.');
          return;
        }
      }

      final email = contactEmailController.text.trim();
      final newClub = Organization(
        id: '', // Firestore picks the ID
        name: nameController.text.trim(),
        ownerId: creator.id,
        description: descriptionController.text.trim(),
        category: selectedCategory ?? '',
        tags: selectedTags,
        logoUrl: logoUrl,
        bannerUrl: bannerUrl,
        contactEmail: email.isEmpty ? null : email,
        socialLinks: nonBlank({
          'instagram': instagramController.text,
          'discord': discordController.text,
        }),
        meetingInfo: nonBlank({
          'day': selectedMeetingDay,
          'time': selectedMeetingTime == null
              ? null
              : ClubOptions.formatTime(selectedMeetingTime!),
          'location': meetingLocationController.text,
        }),
        isPublic: isPublic,
        requiresApproval: requiresApproval,
      );

      // Creates the club AND makes the creator its owner (in the club's
      // members list and in their "My Clubs" list), all in one step.
      final newId = await firestoreService.createOrganization(newClub, creator);
      await addToSearchIndex(newId, newClub);

      if (mounted) {
        setState(() {
          createdOrgId = newId;
          createdOrgName = newClub.name;
        });
      }
      showMessage('Club Created Successfully!');
      widget.onCreated?.call(newId);
    } catch (e) {
      showMessage('Club Not Created: Error saving club: $e');
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  /// Adds the new club to search. If search isn't set up (e.g. no Algolia
  /// keys in .env), the club is still created and this is skipped.
  Future<void> addToSearchIndex(String orgId, Organization club) async {
    try {
      await SearchService().createIndex(
        'club',
        club.name,
        club.description,
        orgId,
        club.tags,
        'official',
      );
    } catch (e) {
      debugPrint('Club created, but it was not added to search: $e');
    }
  }

  /// Empties the form so another club can be created
  void resetForm() {
    setState(() {
      createdOrgId = null;
      createdOrgName = null;
      nameController.clear();
      descriptionController.clear();
      contactEmailController.clear();
      instagramController.clear();
      discordController.clear();
      meetingLocationController.clear();
      // A fresh controller, since the old tag dropdown is no longer on screen
      tagsController.dispose();
      tagsController = MultiSelectController<String>();
      selectedCategory = null;
      selectedTags = [];
      selectedMeetingDay = null;
      selectedMeetingTime = null;
      isPublic = true;
      requiresApproval = false;
      selectedLogo = null;
      selectedBanner = null;
    });
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
  // Form fields (same as the club editing page)
  // ---------------------------------------------------------------------------

  /// A tap-to-pick image box that shows a preview (like the event pages)
  Widget buildImagePicker({
    required String label,
    required XFile? selected,
    required bool isLogo,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label (optional, tap to choose)'),
        GestureDetector(
          onTap: () async => pickImage(isLogo: isLogo),
          child: Container(
            height: 100,
            width: double.infinity,
            alignment: Alignment.center,
            child: selected == null
                ? Text('No $label. Tap to add one.')
                : Image.file(File(selected.path), fit: BoxFit.contain),
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
              for (final c in ClubOptions.categories)
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
    return MultiDropdown<String>(
      controller: tagsController,
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
            for (final d in ClubOptions.meetingDays)
              DropdownMenuEntry<String>(value: d, label: d),
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
                  setState(() => selectedMeetingTime = picked);
                }
              },
              child: Text(selectedMeetingTime == null
                  ? 'Meeting Time'
                  : ClubOptions.formatTime(selectedMeetingTime!)),
            ),
            if (selectedMeetingTime != null)
              TextButton(
                onPressed: () => setState(() => selectedMeetingTime = null),
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

  Widget buildCreateButton() {
    return ElevatedButton(
      onPressed: isSaving ? null : () async { await submitForm(); },
      child: Text(isSaving ? 'Creating...' : 'Create Club'),
    );
  }

  /// Shown after the club is created, instead of the form
  Widget buildCreatedView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('"$createdOrgName" was created!'),
          const SizedBox(height: 4),
          const Text('You are its owner.'),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: resetForm,
            child: const Text('Create another club'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (owner == null) {
      return const Center(
          child: Text('Your profile could not be loaded, so you can\'t '
              'create a club yet.'));
    }
    if (createdOrgId != null) {
      return buildCreatedView();
    }
    return Form(
      key: clubFormKey,
      child: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            buildImagePicker(
              label: 'Logo',
              selected: selectedLogo,
              isLogo: true,
            ),
            buildImagePicker(
              label: 'Banner',
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
            buildCreateButton(),
          ],
        ),
      ),
    );
  }
}
