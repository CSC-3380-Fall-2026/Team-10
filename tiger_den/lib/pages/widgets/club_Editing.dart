import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/organization.dart';
import '../../services/firestore_service.dart';
import '../../services/image_service.dart';
 
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
 
  Organization? organization;
  bool isLoading = true;
  bool isSaving = false;
 
  TextEditingController nameController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  TextEditingController categoryController = TextEditingController();
  TextEditingController tagsController = TextEditingController();
  TextEditingController contactEmailController = TextEditingController();
  TextEditingController instagramController = TextEditingController();
  TextEditingController discordController = TextEditingController();
  TextEditingController meetingDayController = TextEditingController();
  TextEditingController meetingTimeController = TextEditingController();
  TextEditingController meetingLocationController = TextEditingController();
 
  bool isPublic = true;
  bool requiresApproval = false;
 
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
        if (org != null) {
          nameController.text = org.name;
          descriptionController.text = org.description;
          categoryController.text = org.category;
          tagsController.text = org.tags.join(', ');
          contactEmailController.text = org.contactEmail ?? '';
          instagramController.text = org.socialLinks['instagram'] ?? '';
          discordController.text = org.socialLinks['discord'] ?? '';
          meetingDayController.text = org.meetingInfo['day'] ?? '';
          meetingTimeController.text = org.meetingInfo['time'] ?? '';
          meetingLocationController.text = org.meetingInfo['location'] ?? '';
          isPublic = org.isPublic;
          requiresApproval = org.requiresApproval;
        }
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
 
  @override
  void initState() {
    super.initState();
    imageService = widget.imageService ?? ImageService();
    firestoreService = widget.firestoreService ?? FirestoreService();
    picker = widget.imagePicker ?? ImagePicker();
    loadInitialData();
  }
 
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
 
  List<String> parseTags(String text) {
    return text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }
 
  Map<String, String> nonBlank(Map<String, TextEditingController> fields) {
    final result = <String, String>{};
    fields.forEach((key, controller) {
      final value = controller.text.trim();
      if (value.isNotEmpty) result[key] = value;
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
      final changes = <String, dynamic>{
        'name': nameController.text.trim(),
        'description': descriptionController.text.trim(),
        'category': categoryController.text.trim(),
        'tags': parseTags(tagsController.text),
        'contactEmail': email.isEmpty ? null : email,
        'socialLinks': nonBlank({
          'instagram': instagramController,
          'discord': discordController,
        }),
        'meetingInfo': nonBlank({
          'day': meetingDayController,
          'time': meetingTimeController,
          'location': meetingLocationController,
        }),
        'isPublic': isPublic,
        'requiresApproval': requiresApproval,
        if (newLogoUrl != null) 'logoUrl': newLogoUrl,
        if (newBannerUrl != null) 'bannerUrl': newBannerUrl,
      };
      await firestoreService.updateOrganization(widget.orgId, changes);
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
 
  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    categoryController.dispose();
    tagsController.dispose();
    contactEmailController.dispose();
    instagramController.dispose();
    discordController.dispose();
    meetingDayController.dispose();
    meetingTimeController.dispose();
    meetingLocationController.dispose();
    //cleanUp throws if nothing was compressed, so ignore that error
    imageService.cleanUp().catchError((_) {});
    super.dispose();
  }
 
  Widget buildNameField() {
    return TextFormField(
      controller: nameController,
      decoration: InputDecoration(
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
      decoration: InputDecoration(
        labelText: 'Club Description',
        border: UnderlineInputBorder(),
      ),
    );
  }
 
  Widget buildCategoryField() {
    return TextFormField(
      controller: categoryController,
      decoration: InputDecoration(
        labelText: 'Category',
        border: UnderlineInputBorder(),
      ),
    );
  }
 
  Widget buildTagsField() {
    return TextFormField(
      controller: tagsController,
      decoration: InputDecoration(
        labelText: 'Tags (separate with commas)',
        border: UnderlineInputBorder(),
      ),
    );
  }
 
  Widget buildContactEmailField() {
    return TextFormField(
      controller: contactEmailController,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
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
          decoration: InputDecoration(labelText: 'Instagram Link'),
        ),
        TextFormField(
          controller: discordController,
          decoration: InputDecoration(labelText: 'Discord Link'),
        ),
      ],
    );
  }
 
  Widget buildMeetingInfoFields() {
    return Column(
      children: [
        TextFormField(
          controller: meetingDayController,
          decoration: InputDecoration(labelText: 'Meeting Day'),
        ),
        TextFormField(
          controller: meetingTimeController,
          decoration: InputDecoration(labelText: 'Meeting Time'),
        ),
        TextFormField(
          controller: meetingLocationController,
          decoration: InputDecoration(labelText: 'Meeting Location'),
        ),
      ],
    );
  }
 
  Widget buildImageRow({required String label, required String? currentUrl, required XFile? selected, required bool isLogo,}) {
    String status;
    if (selected != null) {
      status = 'New image selected (saved when you press Save)';
    } else if (currentUrl != null && currentUrl.isNotEmpty) {
      status = 'Current: $currentUrl';
    } else {
      status = 'No image';
    }
    return Row(
      children: [
        ElevatedButton(
          onPressed: () async {
            await pickImage(isLogo: isLogo);
          },
          child: Text(label),
        ),
        Expanded(child: Text(status)),
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
            buildImageRow(
              label: 'Add Logo',
              currentUrl: organization!.logoUrl,
              selected: selectedLogo,
              isLogo: true,
            ),
            buildImageRow(
              label: 'Add Banner',
              currentUrl: organization!.bannerUrl,
              selected: selectedBanner,
              isLogo: false,
            ),
            buildNameField(),
            buildDescriptionField(),
            buildCategoryField(),
            buildTagsField(),
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
