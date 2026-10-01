import 'package:cloud_firestore/cloud_firestore.dart';
import 'model_utils.dart';

/// Roles a person can have inside an organization.
enum OrgRole { owner, admin, member }

/// Whether someone is a full member or still waiting for approval.
enum MemberStatus { active, pending }

/// A club / organization. Publicly visible, but owned by a user.
/// Stored at: organizations/{id}
class Organization {
  final String id;
  final String name;
  final String description;
  final String category;
  final List<String> tags;
  final String? logoUrl;
  final String? bannerUrl;
  final String? contactEmail;

  /// e.g. {'instagram': 'https://...', 'discord': 'https://...'}
  final Map<String, String> socialLinks;

  /// e.g. {'day': 'Tuesday', 'time': '6:00 PM', 'location': 'Room 204'}
  final Map<String, String> meetingInfo;

  final String ownerId;
  final List<String> adminIds;
  final int memberCount;
  final bool isPublic;
  final bool requiresApproval;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Organization({
    required this.id,
    required this.name,
    required this.ownerId,
    this.description = '',
    this.category = '',
    this.tags = const [],
    this.logoUrl,
    this.bannerUrl,
    this.contactEmail,
    this.socialLinks = const {},
    this.meetingInfo = const {},
    this.adminIds = const [],
    this.memberCount = 0,
    this.isPublic = true,
    this.requiresApproval = false,
    this.createdAt,
    this.updatedAt,
  });

  factory Organization.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Organization(
      id: doc.id,
      name: d['name'] ?? '',
      description: d['description'] ?? '',
      category: d['category'] ?? '',
      tags: stringList(d['tags']),
      logoUrl: d['logoUrl'],
      bannerUrl: d['bannerUrl'],
      contactEmail: d['contactEmail'],
      socialLinks: stringMap(d['socialLinks']),
      meetingInfo: stringMap(d['meetingInfo']),
      ownerId: d['ownerId'] ?? '',
      adminIds: stringList(d['adminIds']),
      memberCount: d['memberCount'] ?? 0,
      isPublic: d['isPublic'] ?? true,
      requiresApproval: d['requiresApproval'] ?? false,
      createdAt: dateFrom(d['createdAt']),
      updatedAt: dateFrom(d['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'category': category,
        'tags': tags,
        'logoUrl': logoUrl,
        'bannerUrl': bannerUrl,
        'contactEmail': contactEmail,
        'socialLinks': socialLinks,
        'meetingInfo': meetingInfo,
        'ownerId': ownerId,
        'adminIds': adminIds,
        'memberCount': memberCount,
        'isPublic': isPublic,
        'requiresApproval': requiresApproval,
      };
}

/// One person inside a club.
/// Stored at: organizations/{orgId}/members/{userId}
class OrgMember {
  final String userId;
  final OrgRole role;
  final String displayName;
  final MemberStatus status;
  final DateTime? joinedAt;

  OrgMember({
    required this.userId,
    required this.displayName,
    this.role = OrgRole.member,
    this.status = MemberStatus.active,
    this.joinedAt,
  });

  factory OrgMember.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return OrgMember(
      userId: doc.id,
      displayName: d['displayName'] ?? '',
      role: enumFrom(OrgRole.values, d['role'], OrgRole.member),
      status: enumFrom(MemberStatus.values, d['status'], MemberStatus.active),
      joinedAt: dateFrom(d['joinedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'role': role.name,
        'status': status.name,
      };
}

/// The user's side of a membership (the "My Clubs" list).
/// Stored at: users/{userId}/memberships/{orgId}
class Membership {
  final String orgId;
  final String orgName;
  final OrgRole role;

  /// 'pending' while waiting for a club admin to approve the join request.
  final MemberStatus status;
  final DateTime? joinedAt;

  Membership({
    required this.orgId,
    required this.orgName,
    this.role = OrgRole.member,
    this.status = MemberStatus.active,
    this.joinedAt,
  });

  factory Membership.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Membership(
      orgId: doc.id,
      orgName: d['orgName'] ?? '',
      role: enumFrom(OrgRole.values, d['role'], OrgRole.member),
      status: enumFrom(MemberStatus.values, d['status'], MemberStatus.active),
      joinedAt: dateFrom(d['joinedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'orgName': orgName,
        'role': role.name,
        'status': status.name,
      };
}
