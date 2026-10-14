// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'UniLect';

  @override
  String get appTagline => 'Your lectures and past exams, in one secure place';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get confirm => 'Confirm';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get close => 'Close';

  @override
  String get search => 'Search';

  @override
  String get filters => 'Filters';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get apply => 'Apply';

  @override
  String get next => 'Next';

  @override
  String get back => 'Back';

  @override
  String get optional => 'Optional';

  @override
  String get all => 'All';

  @override
  String get add => 'Add';

  @override
  String get more => 'More';

  @override
  String get seeAll => 'See all';

  @override
  String get loadMore => 'Load more';

  @override
  String get fieldRequired => 'This field is required';

  @override
  String get emailInvalid => 'Enter a valid email address';

  @override
  String minChars(int count) {
    return 'At least $count characters';
  }

  @override
  String get errorNetwork =>
      'Can\'t reach the server. Check your internet connection.';

  @override
  String get errorTimeout => 'The request took too long. Please try again.';

  @override
  String get errorUnknown => 'Something went wrong. Please try again.';

  @override
  String get errorForbidden => 'You don\'t have permission to do this.';

  @override
  String get errorNotFound =>
      'This item doesn\'t exist or is no longer available.';

  @override
  String get errorValidation => 'Please review the highlighted fields.';

  @override
  String get errorOutOfScope => 'This item is outside your scope.';

  @override
  String get errorRateLimited =>
      'Too many attempts. Wait a moment and try again.';

  @override
  String get language => 'Language';

  @override
  String get arabic => 'العربية';

  @override
  String get english => 'English';

  @override
  String get loginWelcome => 'Welcome back';

  @override
  String get loginSubtitle =>
      'Sign in with the account provided by your administrator';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get signIn => 'Sign in';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get noAccountHint =>
      'Accounts can\'t be self-created. Contact the administrator to get one.';

  @override
  String get invalidCredentials => 'Incorrect email or password';

  @override
  String get accountDisabled =>
      'This account is disabled. Contact the administrator.';

  @override
  String get sessionEndedRevoked =>
      'Your session has ended. Please sign in again.';

  @override
  String get sessionEndedDevice =>
      'This device is no longer linked to your account. Sign in to request a device change.';

  @override
  String get sessionEndedDisabled =>
      'Your account has been disabled by the administrator.';

  @override
  String get forgotTitle => 'Reset password';

  @override
  String get forgotSubtitle =>
      'Enter your email and we\'ll send you a link to set a new password.';

  @override
  String get resetTitle => 'New password';

  @override
  String get resetSubtitle =>
      'Choose a strong password you haven\'t used before.';

  @override
  String get newPassword => 'New password';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get passwordsDontMatch => 'Passwords don\'t match';

  @override
  String get resetPasswordAction => 'Save password';

  @override
  String get passwordResetSuccess =>
      'Password changed. Sign in with your new password.';

  @override
  String stepOf(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get deviceBlockedTitle => 'Your account is linked to another device';

  @override
  String get deviceBlockedBody =>
      'To protect content, a student account can be used on one device only. You can ask to move your account to this device and the administrator will review your request.';

  @override
  String get deviceHowTitle => 'How does a device change work?';

  @override
  String get deviceHowStep1 =>
      'Send the request from this device, with a reason if you like.';

  @override
  String get deviceHowStep2 =>
      'The administrator reviews and approves or rejects it.';

  @override
  String get deviceHowStep3 =>
      'Once approved, the old device is unlinked and you sign in here.';

  @override
  String get reasonLabel => 'Reason for the change';

  @override
  String get reasonHint => 'e.g. my previous phone broke';

  @override
  String get submitRequest => 'Send request';

  @override
  String get requestSubmittedTitle => 'Request sent';

  @override
  String get requestSubmittedBody =>
      'Your request is under review. You\'ll be able to sign in on this device as soon as it is approved.';

  @override
  String get pendingRequestTitle => 'You have a request under review';

  @override
  String pendingRequestBody(String date) {
    return 'You requested a device change on $date. We\'ll let you know once a decision is made.';
  }

  @override
  String get backToLogin => 'Back to sign in';

  @override
  String get navBrowse => 'Browse';

  @override
  String get navSearch => 'Search';

  @override
  String get navFavorites => 'Favorites';

  @override
  String get navNotifications => 'Alerts';

  @override
  String get navProfile => 'Account';

  @override
  String get navDashboard => 'Home';

  @override
  String get navContent => 'Content';

  @override
  String get navUsers => 'Accounts';

  @override
  String get navStructure => 'Structure';

  @override
  String get navDevices => 'Devices';

  @override
  String greeting(String name) {
    return 'Hi, $name';
  }

  @override
  String get chooseUniversity => 'Choose your university to start';

  @override
  String get universities => 'Universities';

  @override
  String get faculties => 'Faculties';

  @override
  String get years => 'Academic years';

  @override
  String get specializations => 'Specializations';

  @override
  String get subjects => 'Subjects';

  @override
  String get doctors => 'Doctors';

  @override
  String get terms => 'Terms';

  @override
  String get examTypes => 'Exam sessions';

  @override
  String get allSpecializations => 'All specializations';

  @override
  String get lectures => 'Lectures';

  @override
  String get exams => 'Past exams';

  @override
  String lectureNumber(int number) {
    return 'Lecture $number';
  }

  @override
  String lecturesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lectures',
      one: '1 lecture',
      zero: 'No lectures',
    );
    return '$_temp0';
  }

  @override
  String get follow => 'Follow';

  @override
  String get following => 'Following';

  @override
  String get followHint =>
      'Get notified when new content is added to this subject';

  @override
  String get followed => 'You\'ll be notified about new content';

  @override
  String get unfollowed => 'Unfollowed';

  @override
  String get chooseDoctor => 'Choose a doctor to see their lectures';

  @override
  String get emptyUniversities => 'No universities available yet';

  @override
  String get emptyFaculties => 'No faculties available in this university';

  @override
  String get emptyYears => 'No academic years for this faculty';

  @override
  String get emptySubjects => 'No subjects in this year';

  @override
  String get emptyDoctors => 'No doctors linked to this subject yet';

  @override
  String get emptyLectures => 'No published lectures yet';

  @override
  String get emptyExams => 'No matching past exams';

  @override
  String get emptyGenericHint => 'Check back later — content is on its way.';

  @override
  String get examYear => 'Year';

  @override
  String get term => 'Term';

  @override
  String get examType => 'Session';

  @override
  String get doctor => 'Doctor';

  @override
  String get anyValue => 'Any';

  @override
  String get contentDetails => 'Content details';

  @override
  String get openFile => 'Open file';

  @override
  String addedOn(String date) {
    return 'Added $date';
  }

  @override
  String get classification => 'Classification';

  @override
  String get university => 'University';

  @override
  String get faculty => 'Faculty';

  @override
  String get year => 'Year';

  @override
  String get subject => 'Subject';

  @override
  String get typeLecture => 'Lecture';

  @override
  String get typeExam => 'Past exam';

  @override
  String get contentType => 'Content type';

  @override
  String get fileInfo => 'File';

  @override
  String get formatPdf => 'PDF';

  @override
  String get formatImage => 'Image';

  @override
  String get addToFavorites => 'Add to favorites';

  @override
  String get removeFromFavorites => 'Remove from favorites';

  @override
  String get addedToFavorites => 'Added to favorites';

  @override
  String get removedFromFavorites => 'Removed from favorites';

  @override
  String get reportContent => 'Report a problem';

  @override
  String get reportTitle => 'What\'s wrong with this content?';

  @override
  String get reasonWrongFile => 'Wrong file';

  @override
  String get reasonDuplicate => 'Duplicate';

  @override
  String get reasonInappropriate => 'Inappropriate';

  @override
  String get reasonOther => 'Other';

  @override
  String get reportNote => 'More details';

  @override
  String get sendReport => 'Send report';

  @override
  String get reportSubmitted =>
      'Thanks — your report reached the administrators';

  @override
  String get unsupportedFormat =>
      'This file format isn\'t supported by the viewer.';

  @override
  String get viewerProtected => 'Protected content · in-app viewing only';

  @override
  String get captureHidden =>
      'Content hidden while the screen is recorded or shared';

  @override
  String pageOf(int current, int total) {
    return '$current / $total';
  }

  @override
  String get loadingFile => 'Loading file securely…';

  @override
  String get protectionNote =>
      'Screenshots may not be blockable on every device. Please respect content rights.';

  @override
  String get searchHint => 'Search lectures, exams or subjects';

  @override
  String get searchPrompt =>
      'Search the lectures and past exams available to you';

  @override
  String get noResults => 'No matching results';

  @override
  String get noResultsHint => 'Try other words or loosen the filters';

  @override
  String resultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
      zero: 'No results',
    );
    return '$_temp0';
  }

  @override
  String get favoritesTitle => 'Favorites';

  @override
  String get emptyFavorites => 'No favorites yet';

  @override
  String get emptyFavoritesHint =>
      'Tap the heart on any lecture to save it here.';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get markAllRead => 'Mark all as read';

  @override
  String get emptyNotifications => 'No notifications';

  @override
  String get emptyNotificationsHint =>
      'Request outcomes and new content will show up here.';

  @override
  String get profileTitle => 'My account';

  @override
  String get fullName => 'Full name';

  @override
  String get phone => 'Phone';

  @override
  String get studentNumber => 'Student number';

  @override
  String get role => 'Role';

  @override
  String get roleStudent => 'Student';

  @override
  String get roleLibrary => 'Library';

  @override
  String get roleAdmin => 'Administrator';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get profileSaved => 'Changes saved';

  @override
  String get protectedFieldsNote =>
      'Email, student number and role are managed by the administrator and can\'t be changed.';

  @override
  String get changePassword => 'Change password';

  @override
  String get currentPassword => 'Current password';

  @override
  String get passwordChanged => 'Password changed';

  @override
  String get logout => 'Sign out';

  @override
  String get logoutConfirm => 'Sign out of this device?';

  @override
  String get scopeLabel => 'Library scope';

  @override
  String get accountSection => 'Account';

  @override
  String get preferencesSection => 'Preferences';

  @override
  String get statusLabel => 'Status';

  @override
  String get statusDraft => 'Draft';

  @override
  String get statusPendingReview => 'Pending review';

  @override
  String get statusPublished => 'Published';

  @override
  String get statusArchived => 'Archived';

  @override
  String get libraryHello => 'Library dashboard';

  @override
  String get contentOverview => 'Content overview';

  @override
  String get quickActions => 'Quick actions';

  @override
  String get uploadLecture => 'Upload lecture';

  @override
  String get uploadExam => 'Upload past exam';

  @override
  String get batchUpload => 'Batch upload';

  @override
  String get recentContent => 'Recently updated';

  @override
  String get manageContent => 'Manage content';

  @override
  String get emptyManaged => 'No content yet';

  @override
  String get emptyManagedHint =>
      'Start by uploading your first lecture or exam file.';

  @override
  String get newLecture => 'New lecture';

  @override
  String get newExam => 'New past exam';

  @override
  String get editContent => 'Edit content';

  @override
  String get title => 'Title';

  @override
  String get description => 'Description';

  @override
  String get file => 'File';

  @override
  String get chooseFile => 'Choose file';

  @override
  String get replaceFile => 'Replace file';

  @override
  String get tapToChooseFile => 'Tap to choose a file';

  @override
  String allowedTypesInfo(String types, int size) {
    return 'Allowed: $types · max $size MB';
  }

  @override
  String selectHint(String field) {
    return 'Select $field';
  }

  @override
  String get lectureOrder => 'Lecture number';

  @override
  String get lectureOrderHint => 'Controls display order';

  @override
  String get saveDraft => 'Save as draft';

  @override
  String get publish => 'Publish';

  @override
  String get submitForReview => 'Submit for review';

  @override
  String get preview => 'Preview';

  @override
  String get previewTitle => 'Preview before publishing';

  @override
  String get previewSubtitle =>
      'Check the classification and file before saving.';

  @override
  String get previewFile => 'Preview file';

  @override
  String uploading(int percent) {
    return 'Uploading… $percent%';
  }

  @override
  String get savedSuccess => 'Saved';

  @override
  String get publishedSuccess => 'Published';

  @override
  String get sentForReview => 'Sent to the administrators for review';

  @override
  String fileTooLarge(int size) {
    return 'File exceeds $size MB';
  }

  @override
  String fileTypeNotAllowed(String ext) {
    return 'File type .$ext is not allowed';
  }

  @override
  String get fileRequired => 'Please choose a file';

  @override
  String get versions => 'Version history';

  @override
  String versionN(int number) {
    return 'Version $number';
  }

  @override
  String get currentVersion => 'Current';

  @override
  String get fileReplaced => 'File replaced';

  @override
  String get archive => 'Archive';

  @override
  String get restoreDraft => 'Move back to draft';

  @override
  String get deleteContentConfirm =>
      'This content will be permanently deleted and hidden from students. Continue?';

  @override
  String get deleted => 'Deleted';

  @override
  String missingForPublish(String fields) {
    return 'Complete the required fields to publish: $fields';
  }

  @override
  String get reviewRequiredNote =>
      'Administrators must review content before students can see it.';

  @override
  String get reviewNote => 'Review note';

  @override
  String get actions => 'Actions';

  @override
  String get statusChanged => 'Status updated';

  @override
  String get batchTitle => 'Batch upload';

  @override
  String get batchSubtitle =>
      'Set a shared classification, then review each file.';

  @override
  String get addFiles => 'Add files';

  @override
  String get commonClassification => 'Shared classification';

  @override
  String filesToUpload(int count) {
    return 'Files ($count)';
  }

  @override
  String get uploadAll => 'Upload all';

  @override
  String batchSummary(int ok, int failed) {
    return '$ok succeeded · $failed failed';
  }

  @override
  String get batchPending => 'Waiting';

  @override
  String get batchSuccess => 'Uploaded';

  @override
  String get batchFailed => 'Failed';

  @override
  String get removeFile => 'Remove';

  @override
  String get publishAfterUpload => 'Publish right after upload';

  @override
  String get retryFailed => 'Retry failed';

  @override
  String get adminHello => 'Admin dashboard';

  @override
  String get needsAction => 'Needs action';

  @override
  String get students => 'Students';

  @override
  String get libraries => 'Libraries';

  @override
  String get admins => 'Admins';

  @override
  String get disabledAccounts => 'Disabled accounts';

  @override
  String get pendingDevices => 'Device change requests';

  @override
  String get pendingReviews => 'Content awaiting review';

  @override
  String get openReports => 'Open reports';

  @override
  String get usersTitle => 'Accounts';

  @override
  String get newUser => 'New account';

  @override
  String get editUser => 'Edit account';

  @override
  String get statusActive => 'Active';

  @override
  String get statusDisabled => 'Disabled';

  @override
  String get disable => 'Disable';

  @override
  String get enable => 'Enable';

  @override
  String disableConfirm(String name) {
    return '$name will be blocked from signing in and their sessions ended. Continue?';
  }

  @override
  String get initialPassword => 'Initial password';

  @override
  String get initialPasswordHint =>
      'Hand it to the user through a secure channel; they must change it at first sign-in';

  @override
  String get scopeUniversities => 'Whole universities';

  @override
  String get scopeFaculties => 'Specific faculties';

  @override
  String get scopeRequired => 'Pick at least one university or faculty';

  @override
  String get userCreated => 'Account created';

  @override
  String get userUpdated => 'Account updated';

  @override
  String get boundDevice => 'Linked device';

  @override
  String get noBoundDevice => 'Not linked yet';

  @override
  String get emptyUsers => 'No matching accounts';

  @override
  String get searchUsers => 'Search by name, email or student number';

  @override
  String createdOn(String date) {
    return 'Created $date';
  }

  @override
  String get structureTitle => 'Academic structure';

  @override
  String get structureSubtitle =>
      'Manage universities, faculties, subjects, categories and their order';

  @override
  String get addItem => 'Add';

  @override
  String get editItem => 'Edit';

  @override
  String get name => 'Name';

  @override
  String get active => 'Active';

  @override
  String get inactive => 'Inactive';

  @override
  String get visibleToStudents => 'Visible to students';

  @override
  String get level => 'Level';

  @override
  String get code => 'Code';

  @override
  String get linkedSubjects => 'Linked subjects';

  @override
  String get linkedSpecializations =>
      'Specializations (leave empty if common to all)';

  @override
  String get reorderHint => 'Drag items to change their display order';

  @override
  String get orderSaved => 'Order saved';

  @override
  String chooseParentFirst(String parent) {
    return 'Choose a $parent to see its items';
  }

  @override
  String get emptyItems => 'No items yet';

  @override
  String get itemSaved => 'Saved';

  @override
  String get allContent => 'All content';

  @override
  String get reviewQueue => 'Review';

  @override
  String get approve => 'Approve';

  @override
  String get reject => 'Reject';

  @override
  String get approved => 'Approved';

  @override
  String get rejected => 'Rejected';

  @override
  String get rejectReasonHint => 'Reason (shown to the library)';

  @override
  String get deviceRequests => 'Device change requests';

  @override
  String get deviceLog => 'Device log';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusApproved => 'Approved';

  @override
  String get statusRejected => 'Rejected';

  @override
  String get sortNewest => 'Newest first';

  @override
  String get sortOldest => 'Oldest first';

  @override
  String get decisionNote => 'Decision note';

  @override
  String get oldDevice => 'Current device';

  @override
  String get newDevice => 'New device';

  @override
  String requestedOn(String date) {
    return 'Requested $date';
  }

  @override
  String decidedBy(String name, String date) {
    return '$name · $date';
  }

  @override
  String get approveDeviceConfirm =>
      'The current device will be unlinked and its sessions ended; the account will be linked to the new device.';

  @override
  String get emptyRequests => 'No requests';

  @override
  String get logBound => 'Device linked';

  @override
  String get logChangeRequested => 'Change requested';

  @override
  String get logApproved => 'Approved & relinked';

  @override
  String get logRejected => 'Request rejected';

  @override
  String get logUnbound => 'Device unlinked';

  @override
  String get emptyLogs => 'No log entries';

  @override
  String get auditLog => 'Audit log';

  @override
  String get auditLogSubtitle => 'Administrative and sensitive operations';

  @override
  String get settingsTitle => 'System settings';

  @override
  String get settingsSubtitle => 'File limits, review, notifications';

  @override
  String get settingsAppliesNote =>
      'New settings apply to subsequent operations only.';

  @override
  String get maxUploadSize => 'Max file size (MB)';

  @override
  String get allowedExtensions => 'Allowed formats';

  @override
  String get requireReview => 'Require review before publishing';

  @override
  String get requireReviewHint =>
      'Library content reaches students only after admin approval';

  @override
  String get settingsSaved => 'Settings saved';

  @override
  String get reportsTitle => 'Reports';

  @override
  String get reportsSubtitle => 'Review student reports about content';

  @override
  String get reportOpen => 'Open';

  @override
  String get reportInReview => 'In progress';

  @override
  String get reportResolved => 'Resolved';

  @override
  String get reportDismissed => 'Dismissed';

  @override
  String get updateStatus => 'Update status';

  @override
  String get addNote => 'Add a note';

  @override
  String get emptyReports => 'No reports';

  @override
  String get emptyAudit => 'No recorded operations';

  @override
  String reportedBy(String name) {
    return 'Reported by $name';
  }

  @override
  String get history => 'History';

  @override
  String get entityContent => 'Content';

  @override
  String get entityDevice => 'Device';

  @override
  String get entitySettings => 'Settings';

  @override
  String get entityReport => 'Report';

  @override
  String get manageSection => 'Management';

  @override
  String get structureKindsSection => 'Structure items';

  @override
  String get passwordRules => 'At least 10 characters, not only digits';

  @override
  String get sendResetLink => 'Send reset link';

  @override
  String get linkSentTitle => 'Check your email';

  @override
  String linkSentBody(String email) {
    return 'If $email is registered, it will receive a link to set a new password, valid for one hour. Open the link on this device.';
  }

  @override
  String get pasteLinkLabel => 'Or paste the link from the email here';

  @override
  String get continueAction => 'Continue';

  @override
  String get invalidResetLink =>
      'This link is not valid. Copy the whole link from the email.';

  @override
  String get resendLink => 'Send the link again';

  @override
  String get mustChangeTitle => 'Set a new password';

  @override
  String get mustChangeBody =>
      'Your account was set up or reset with a temporary password. Choose your own password to continue.';

  @override
  String get category => 'Category';

  @override
  String get lectureCategories => 'Lecture categories';

  @override
  String get doctorTitle => 'Title (e.g. Dr.)';

  @override
  String get number => 'Number';

  @override
  String get librariesSubtitle => 'Content providers and their scope';

  @override
  String get newLibrary => 'New library';

  @override
  String get editLibrary => 'Edit library';

  @override
  String get libraryLabel => 'Library';

  @override
  String get libraryRequired => 'Choose the library';

  @override
  String get contactEmail => 'Contact email';

  @override
  String get contactPhone => 'Contact phone';

  @override
  String staffCount(int count) {
    return '$count accounts';
  }

  @override
  String get emptyLibraries => 'No libraries yet';

  @override
  String get librarySaved => 'Library saved';

  @override
  String get resetDevice => 'Unbind device';

  @override
  String resetDeviceConfirm(String name) {
    return '$name\'s device will be unbound and their sessions ended; the next device they sign in on gets bound.';
  }

  @override
  String get deviceResetDone => 'Device unbound';

  @override
  String get setPassword => 'Set a new password';

  @override
  String get setPasswordHint =>
      'The user\'s sessions end and they must change it at next sign-in';

  @override
  String get passwordSet => 'Password set';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get logCancelled => 'Request cancelled';

  @override
  String get notifyFollowers => 'Notify followers on publish';

  @override
  String get notifyFollowersHint =>
      'Students following a course are notified when new content is published in it';

  @override
  String get auditAccount => 'Accounts';

  @override
  String get auditAuth => 'Sign-in';

  @override
  String get auditCatalog => 'Catalog';

  @override
  String get auditLibrary => 'Libraries';

  @override
  String get auditSecurity => 'Security';

  @override
  String get noFileYet => 'No file uploaded yet';
}
