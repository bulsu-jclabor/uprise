// lib/utils/constants.dart
class FirebaseConstants {
  static const String usersCollection = 'users';
  static const String eventsCollection = 'events';
  static const String organizationsCollection = 'organizations';
  static const String announcementsCollection = 'announcements';
  static const String certificatesCollection = 'certificates';
  static const String merchandiseCollection = 'merchandise';
  static const String ordersCollection = 'orders';
  static const String attendanceCollection = 'attendance';
  
  // User roles
  static const String roleAdmin = 'admin';
  static const String roleOrgOfficer = 'org_officer';
  static const String roleOrgAdviser = 'org_adviser';
  static const String roleCictStudent = 'cict_student';
  static const String roleGuest = 'guest';
  
  // Event access levels
  static const String eventAccessPublic = 'public';
  static const String eventAccessCictOnly = 'cict_only';
  static const String eventAccessMembersOnly = 'members_only';
  
  // Event status
  static const String eventStatusPending = 'pending';
  static const String eventStatusApproved = 'approved';
  static const String eventStatusRejected = 'rejected';
  static const String eventStatusCompleted = 'completed';
}

class AppStrings {
  static const String appName = 'UPRISE';
  static const String tagline = 'Rise with UPRISE';
}