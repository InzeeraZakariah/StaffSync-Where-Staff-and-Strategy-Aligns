class ApiConstants {
  static const String baseUrl = 'http://localhost:8000/api/v1';
  static const String wsBaseUrl = 'ws://localhost:8000/api/v1';

  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String me = '/auth/me';
  static const String updateProfile = '/auth/me';
  static const String uploadAvatar = '/auth/me/avatar';
  static const String updateSettings = '/auth/me/settings';
  static const String changePassword = '/auth/me/change-password';

  // Staffs
  static const String staff = '/staff/';
  static String staffById(int id) => '/staff/$id/';

  // Groups
  static const String groups = '/groups';
  static String groupMessages(int id) => '/groups/$id/messages';
  static String groupMembers(int id) => '/groups/$id/members';
  static String groupWs(int id, String token) =>
      '$wsBaseUrl/groups/$id/ws?token=$token';

  // Availability
  static const String availability = '/availability';
  static const String myAvailability = '/availability/me';
  static const String checkAvailability = '/availability/check';
  static const String bulkCheckAvailability = '/availability/check/bulk';

  // Meetings
  static const String meetings = '/meetings';
  static String meetingById(int id) => '/meetings/$id';
  static String meetingSummary(int id) => '/meetings/$id/summary';
  static String meetingBotProfile(int id) => '/meetings/$id/bot-profile';
  static String shareMeeting(int id) => '/meetings/$id/share';
  static String shareMeetingToStaff(int id) => '/meetings/$id/share/staff';
  static String rsvpMeeting(int id) => '/meetings/$id/rsvp';

  // Reminders
  static const String reminders = '/reminders';
  static const String urgentNotify = '/reminders/urgent';
  static String markReminderRead(int id) => '/reminders/$id/read';

  // Resources
  static const String resourceUpload = '/resources/upload';
  static const String resourceLink = '/resources/link';
  static const String resources = '/resources';
  static const String notes = '/resources/notes';
  static const String resourcesSharedWithMe = '/resources/shared-with-me/';
  static String resourceById(int id) => '/resources/$id';
  static String resourceDownload(int id) => '/resources/$id/download/file';
  static String resourceShareToStaff(int id) => '/resources/$id/share/staff';
  static String resourceShareToGroups(int id) => '/resources/$id/share/groups';
  static String resourceShares(int id) => '/resources/$id/shares';
  static String revokeShare(int shareId) => '/resources/shares/$shareId';
  static String noteById(int id) => '/resources/notes/$id';
  static String noteHistory(int id) => '/resources/notes/$id/history';
  static String groupShareMessage(int groupId) =>
      '/groups/$groupId/share-message/';
  // ADD to ApiConstants class:
  static String shareReminderToGroup(int id) => '/reminders/$id/share/group';
  static String shareMeetingToGroup(int id) =>
      '/meetings/$id/share'; // already exists

  // Games
  static const String games = '/games';
  static const String dailyChallenge = '/games/daily';
  static const String leaderboard = '/games/leaderboard/all';
  static String startGame(int id) => '/games/$id/start';
  static String submitAnswer(int sessionId) =>
      '/games/sessions/$sessionId/submit';
  static const String mySessions = '/games/sessions/me';
}
