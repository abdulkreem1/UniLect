// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'UniLect';

  @override
  String get appTagline => 'محاضراتك وأسئلة دوراتك في مكان واحد آمن';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get cancel => 'إلغاء';

  @override
  String get save => 'حفظ';

  @override
  String get confirm => 'تأكيد';

  @override
  String get delete => 'حذف';

  @override
  String get edit => 'تعديل';

  @override
  String get close => 'إغلاق';

  @override
  String get search => 'بحث';

  @override
  String get filters => 'التصفية';

  @override
  String get clearFilters => 'مسح التصفية';

  @override
  String get apply => 'تطبيق';

  @override
  String get next => 'التالي';

  @override
  String get back => 'رجوع';

  @override
  String get optional => 'اختياري';

  @override
  String get all => 'الكل';

  @override
  String get add => 'إضافة';

  @override
  String get more => 'المزيد';

  @override
  String get seeAll => 'عرض الكل';

  @override
  String get loadMore => 'تحميل المزيد';

  @override
  String get fieldRequired => 'هذا الحقل مطلوب';

  @override
  String get emailInvalid => 'أدخل بريداً إلكترونياً صحيحاً';

  @override
  String minChars(int count) {
    return '$count أحرف على الأقل';
  }

  @override
  String get errorNetwork => 'تعذّر الاتصال بالخادم. تحقق من اتصالك بالإنترنت.';

  @override
  String get errorTimeout => 'استغرق الطلب وقتاً طويلاً. حاول مجدداً.';

  @override
  String get errorUnknown => 'حدث خطأ غير متوقع. حاول مجدداً.';

  @override
  String get errorForbidden => 'ليست لديك صلاحية لتنفيذ هذه العملية.';

  @override
  String get errorNotFound => 'العنصر غير موجود أو لم يعد متاحاً.';

  @override
  String get errorValidation => 'يرجى مراجعة الحقول المحددة.';

  @override
  String get errorOutOfScope => 'هذا العنصر خارج نطاق صلاحياتك.';

  @override
  String get errorRateLimited => 'محاولات كثيرة. انتظر قليلاً ثم أعد المحاولة.';

  @override
  String get language => 'اللغة';

  @override
  String get arabic => 'العربية';

  @override
  String get english => 'English';

  @override
  String get loginWelcome => 'مرحباً بعودتك';

  @override
  String get loginSubtitle => 'سجّل الدخول بالحساب الذي زوّدتك به الإدارة';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get showPassword => 'إظهار كلمة المرور';

  @override
  String get hidePassword => 'إخفاء كلمة المرور';

  @override
  String get noAccountHint =>
      'لا يمكن إنشاء حساب ذاتياً. تواصل مع إدارة النظام للحصول على حساب.';

  @override
  String get invalidCredentials => 'البريد الإلكتروني أو كلمة المرور غير صحيحة';

  @override
  String get accountDisabled => 'هذا الحساب معطّل. تواصل مع إدارة النظام.';

  @override
  String get sessionEndedRevoked => 'انتهت جلستك. يرجى تسجيل الدخول مجدداً.';

  @override
  String get sessionEndedDevice =>
      'لم يعد هذا الجهاز مرتبطاً بحسابك. سجّل الدخول لتقديم طلب تغيير جهاز.';

  @override
  String get sessionEndedDisabled => 'تم تعطيل حسابك من قبل الإدارة.';

  @override
  String get forgotTitle => 'استعادة كلمة المرور';

  @override
  String get forgotSubtitle =>
      'أدخل بريدك الإلكتروني وسنرسل لك رابطاً لتعيين كلمة مرور جديدة.';

  @override
  String get resetTitle => 'كلمة مرور جديدة';

  @override
  String get resetSubtitle => 'اختر كلمة مرور قوية لم تستخدمها من قبل.';

  @override
  String get newPassword => 'كلمة المرور الجديدة';

  @override
  String get confirmPassword => 'تأكيد كلمة المرور';

  @override
  String get passwordsDontMatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get resetPasswordAction => 'حفظ كلمة المرور';

  @override
  String get passwordResetSuccess =>
      'تم تغيير كلمة المرور. سجّل الدخول بكلمة المرور الجديدة.';

  @override
  String stepOf(int current, int total) {
    return 'الخطوة $current من $total';
  }

  @override
  String get deviceBlockedTitle => 'حسابك مرتبط بجهاز آخر';

  @override
  String get deviceBlockedBody =>
      'لحماية المحتوى، يُسمح باستخدام حساب الطالب على جهاز واحد فقط. يمكنك طلب نقل حسابك إلى هذا الجهاز وستراجع الإدارة طلبك.';

  @override
  String get deviceHowTitle => 'كيف يعمل طلب تغيير الجهاز؟';

  @override
  String get deviceHowStep1 => 'أرسل الطلب من هذا الجهاز مع ذكر السبب إن أردت.';

  @override
  String get deviceHowStep2 => 'يراجع مدير النظام الطلب ويقبله أو يرفضه.';

  @override
  String get deviceHowStep3 =>
      'عند القبول يُلغى ارتباط الجهاز القديم وتسجّل الدخول من هذا الجهاز.';

  @override
  String get reasonLabel => 'سبب التغيير';

  @override
  String get reasonHint => 'مثال: تعطّل جهازي السابق';

  @override
  String get submitRequest => 'إرسال الطلب';

  @override
  String get requestSubmittedTitle => 'تم إرسال طلبك';

  @override
  String get requestSubmittedBody =>
      'طلبك الآن قيد المراجعة. ستتمكن من تسجيل الدخول على هذا الجهاز فور الموافقة عليه.';

  @override
  String get pendingRequestTitle => 'لديك طلب قيد المراجعة';

  @override
  String pendingRequestBody(String date) {
    return 'أرسلت طلب تغيير جهاز بتاريخ $date. سنُعلمك فور اتخاذ القرار.';
  }

  @override
  String get backToLogin => 'العودة لتسجيل الدخول';

  @override
  String get navBrowse => 'تصفّح';

  @override
  String get navSearch => 'بحث';

  @override
  String get navFavorites => 'المفضلة';

  @override
  String get navNotifications => 'الإشعارات';

  @override
  String get navProfile => 'حسابي';

  @override
  String get navDashboard => 'الرئيسية';

  @override
  String get navContent => 'المحتوى';

  @override
  String get navUsers => 'الحسابات';

  @override
  String get navStructure => 'الهيكل';

  @override
  String get navDevices => 'الأجهزة';

  @override
  String greeting(String name) {
    return 'أهلاً، $name';
  }

  @override
  String get chooseUniversity => 'اختر جامعتك للبدء';

  @override
  String get universities => 'الجامعات';

  @override
  String get faculties => 'الكليات';

  @override
  String get years => 'السنوات الدراسية';

  @override
  String get specializations => 'الاختصاصات';

  @override
  String get subjects => 'المواد';

  @override
  String get doctors => 'الدكاترة';

  @override
  String get terms => 'الفصول الدراسية';

  @override
  String get examTypes => 'أنواع الدورات';

  @override
  String get allSpecializations => 'كل الاختصاصات';

  @override
  String get lectures => 'المحاضرات';

  @override
  String get exams => 'أسئلة الدورات';

  @override
  String lectureNumber(int number) {
    return 'المحاضرة $number';
  }

  @override
  String lecturesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count محاضرة',
      many: '$count محاضرة',
      few: '$count محاضرات',
      two: 'محاضرتان',
      one: 'محاضرة واحدة',
      zero: 'لا محاضرات',
    );
    return '$_temp0';
  }

  @override
  String get follow => 'متابعة';

  @override
  String get following => 'متابَعة';

  @override
  String get followHint => 'ستصلك إشعارات عند إضافة محتوى جديد لهذه المادة';

  @override
  String get followed => 'ستصلك إشعارات بالمحتوى الجديد';

  @override
  String get unfollowed => 'تم إلغاء المتابعة';

  @override
  String get chooseDoctor => 'اختر الدكتور لعرض محاضراته';

  @override
  String get emptyUniversities => 'لا توجد جامعات متاحة حالياً';

  @override
  String get emptyFaculties => 'لا توجد كليات متاحة في هذه الجامعة';

  @override
  String get emptyYears => 'لا توجد سنوات دراسية لهذه الكلية';

  @override
  String get emptySubjects => 'لا توجد مواد في هذه السنة';

  @override
  String get emptyDoctors => 'لم يُربط أي دكتور بهذه المادة بعد';

  @override
  String get emptyLectures => 'لا توجد محاضرات منشورة بعد';

  @override
  String get emptyExams => 'لا توجد أسئلة دورات مطابقة';

  @override
  String get emptyGenericHint => 'عُد لاحقاً، سيُضاف المحتوى قريباً.';

  @override
  String get examYear => 'العام';

  @override
  String get term => 'الفصل';

  @override
  String get examType => 'نوع الدورة';

  @override
  String get doctor => 'الدكتور';

  @override
  String get anyValue => 'الكل';

  @override
  String get contentDetails => 'تفاصيل المحتوى';

  @override
  String get openFile => 'فتح الملف';

  @override
  String addedOn(String date) {
    return 'أُضيف في $date';
  }

  @override
  String get classification => 'التصنيف';

  @override
  String get university => 'الجامعة';

  @override
  String get faculty => 'الكلية';

  @override
  String get year => 'السنة';

  @override
  String get subject => 'المادة';

  @override
  String get typeLecture => 'محاضرة';

  @override
  String get typeExam => 'أسئلة دورة';

  @override
  String get contentType => 'نوع المحتوى';

  @override
  String get fileInfo => 'الملف';

  @override
  String get formatPdf => 'PDF';

  @override
  String get formatImage => 'صورة';

  @override
  String get addToFavorites => 'إضافة إلى المفضلة';

  @override
  String get removeFromFavorites => 'إزالة من المفضلة';

  @override
  String get addedToFavorites => 'أُضيف إلى المفضلة';

  @override
  String get removedFromFavorites => 'أُزيل من المفضلة';

  @override
  String get reportContent => 'الإبلاغ عن مشكلة';

  @override
  String get reportTitle => 'ما المشكلة في هذا المحتوى؟';

  @override
  String get reasonWrongFile => 'ملف خاطئ';

  @override
  String get reasonDuplicate => 'محتوى مكرر';

  @override
  String get reasonInappropriate => 'محتوى غير مناسب';

  @override
  String get reasonOther => 'سبب آخر';

  @override
  String get reportNote => 'تفاصيل إضافية';

  @override
  String get sendReport => 'إرسال البلاغ';

  @override
  String get reportSubmitted => 'شكراً لك، وصل بلاغك إلى الإدارة';

  @override
  String get unsupportedFormat => 'صيغة هذا الملف غير مدعومة في العارض.';

  @override
  String get viewerProtected => 'محتوى محمي · للعرض داخل التطبيق فقط';

  @override
  String get captureHidden => 'أُخفي المحتوى أثناء تسجيل الشاشة أو مشاركتها';

  @override
  String pageOf(int current, int total) {
    return '$current / $total';
  }

  @override
  String get loadingFile => 'جارٍ تحميل الملف بأمان…';

  @override
  String get protectionNote =>
      'قد لا يمنع التطبيق لقطات الشاشة على جميع الأجهزة. يُرجى احترام حقوق المحتوى.';

  @override
  String get searchHint => 'ابحث عن محاضرة أو دورة أو مادة';

  @override
  String get searchPrompt => 'ابحث في المحاضرات وأسئلة الدورات المتاحة لك';

  @override
  String get noResults => 'لا توجد نتائج مطابقة';

  @override
  String get noResultsHint => 'جرّب كلمات أخرى أو خفّف التصفية';

  @override
  String resultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نتيجة',
      many: '$count نتيجة',
      few: '$count نتائج',
      two: 'نتيجتان',
      one: 'نتيجة واحدة',
      zero: 'لا نتائج',
    );
    return '$_temp0';
  }

  @override
  String get favoritesTitle => 'المفضلة';

  @override
  String get emptyFavorites => 'لا عناصر في المفضلة';

  @override
  String get emptyFavoritesHint =>
      'اضغط على رمز القلب في أي محاضرة لحفظها هنا.';

  @override
  String get notificationsTitle => 'الإشعارات';

  @override
  String get markAllRead => 'تحديد الكل كمقروء';

  @override
  String get emptyNotifications => 'لا توجد إشعارات';

  @override
  String get emptyNotificationsHint =>
      'ستظهر هنا نتائج طلباتك والمحتوى الجديد.';

  @override
  String get profileTitle => 'حسابي';

  @override
  String get fullName => 'الاسم الكامل';

  @override
  String get phone => 'رقم الهاتف';

  @override
  String get studentNumber => 'الرقم الجامعي';

  @override
  String get role => 'الدور';

  @override
  String get roleStudent => 'طالب';

  @override
  String get roleLibrary => 'مكتبة';

  @override
  String get roleAdmin => 'مدير النظام';

  @override
  String get editProfile => 'تعديل الملف الشخصي';

  @override
  String get saveChanges => 'حفظ التغييرات';

  @override
  String get profileSaved => 'تم حفظ التغييرات';

  @override
  String get protectedFieldsNote =>
      'البريد الإلكتروني والرقم الجامعي والدور تديرها الإدارة ولا يمكن تعديلها.';

  @override
  String get changePassword => 'تغيير كلمة المرور';

  @override
  String get currentPassword => 'كلمة المرور الحالية';

  @override
  String get passwordChanged => 'تم تغيير كلمة المرور';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get logoutConfirm => 'هل تريد تسجيل الخروج من هذا الجهاز؟';

  @override
  String get scopeLabel => 'نطاق المكتبة';

  @override
  String get accountSection => 'الحساب';

  @override
  String get preferencesSection => 'التفضيلات';

  @override
  String get statusLabel => 'الحالة';

  @override
  String get statusDraft => 'مسودة';

  @override
  String get statusPendingReview => 'بانتظار المراجعة';

  @override
  String get statusPublished => 'منشور';

  @override
  String get statusArchived => 'مؤرشف';

  @override
  String get libraryHello => 'لوحة المكتبة';

  @override
  String get contentOverview => 'نظرة على المحتوى';

  @override
  String get quickActions => 'إجراءات سريعة';

  @override
  String get uploadLecture => 'رفع محاضرة';

  @override
  String get uploadExam => 'رفع أسئلة دورة';

  @override
  String get batchUpload => 'رفع عدة ملفات';

  @override
  String get recentContent => 'آخر التحديثات';

  @override
  String get manageContent => 'إدارة المحتوى';

  @override
  String get emptyManaged => 'لا يوجد محتوى بعد';

  @override
  String get emptyManagedHint => 'ابدأ برفع أول محاضرة أو ملف دورة.';

  @override
  String get newLecture => 'محاضرة جديدة';

  @override
  String get newExam => 'أسئلة دورة جديدة';

  @override
  String get editContent => 'تعديل المحتوى';

  @override
  String get title => 'العنوان';

  @override
  String get description => 'الوصف';

  @override
  String get file => 'الملف';

  @override
  String get chooseFile => 'اختيار ملف';

  @override
  String get replaceFile => 'استبدال الملف';

  @override
  String get tapToChooseFile => 'اضغط لاختيار ملف';

  @override
  String allowedTypesInfo(String types, int size) {
    return 'الصيغ المسموحة: $types · الحد الأقصى $size ميغابايت';
  }

  @override
  String selectHint(String field) {
    return 'اختر $field';
  }

  @override
  String get lectureOrder => 'رقم المحاضرة';

  @override
  String get lectureOrderHint => 'يحدد ترتيب الظهور';

  @override
  String get saveDraft => 'حفظ كمسودة';

  @override
  String get publish => 'نشر';

  @override
  String get submitForReview => 'إرسال للمراجعة';

  @override
  String get preview => 'معاينة';

  @override
  String get previewTitle => 'معاينة قبل النشر';

  @override
  String get previewSubtitle => 'تأكد من التصنيف والملف قبل الحفظ النهائي.';

  @override
  String get previewFile => 'معاينة الملف';

  @override
  String uploading(int percent) {
    return 'جارٍ الرفع… $percent%';
  }

  @override
  String get savedSuccess => 'تم الحفظ بنجاح';

  @override
  String get publishedSuccess => 'تم النشر بنجاح';

  @override
  String get sentForReview => 'أُرسل المحتوى لمراجعة الإدارة';

  @override
  String fileTooLarge(int size) {
    return 'حجم الملف يتجاوز $size ميغابايت';
  }

  @override
  String fileTypeNotAllowed(String ext) {
    return 'صيغة الملف .$ext غير مسموحة';
  }

  @override
  String get fileRequired => 'يرجى اختيار ملف';

  @override
  String get versions => 'سجل النسخ';

  @override
  String versionN(int number) {
    return 'النسخة $number';
  }

  @override
  String get currentVersion => 'الحالية';

  @override
  String get fileReplaced => 'تم استبدال الملف';

  @override
  String get archive => 'أرشفة';

  @override
  String get restoreDraft => 'إرجاع إلى مسودة';

  @override
  String get deleteContentConfirm =>
      'سيُحذف المحتوى نهائياً ولن يعود ظاهراً للطلاب. هل تريد المتابعة؟';

  @override
  String get deleted => 'تم الحذف';

  @override
  String missingForPublish(String fields) {
    return 'أكمل الحقول الإلزامية للنشر: $fields';
  }

  @override
  String get reviewRequiredNote =>
      'تتطلب الإدارة مراجعة المحتوى قبل ظهوره للطلاب.';

  @override
  String get reviewNote => 'ملاحظة المراجعة';

  @override
  String get actions => 'إجراءات';

  @override
  String get statusChanged => 'تم تحديث الحالة';

  @override
  String get batchTitle => 'رفع عدة ملفات';

  @override
  String get batchSubtitle => 'حدّد تصنيفاً مشتركاً ثم راجع بيانات كل ملف.';

  @override
  String get addFiles => 'إضافة ملفات';

  @override
  String get commonClassification => 'التصنيف المشترك';

  @override
  String filesToUpload(int count) {
    return 'الملفات ($count)';
  }

  @override
  String get uploadAll => 'رفع الكل';

  @override
  String batchSummary(int ok, int failed) {
    return 'نجح $ok · فشل $failed';
  }

  @override
  String get batchPending => 'بانتظار الرفع';

  @override
  String get batchSuccess => 'تم الرفع';

  @override
  String get batchFailed => 'فشل';

  @override
  String get removeFile => 'إزالة';

  @override
  String get publishAfterUpload => 'نشر مباشرة بعد الرفع';

  @override
  String get retryFailed => 'إعادة محاولة الفاشلة';

  @override
  String get adminHello => 'لوحة الإدارة';

  @override
  String get needsAction => 'بحاجة إلى إجراء';

  @override
  String get students => 'الطلاب';

  @override
  String get libraries => 'المكتبات';

  @override
  String get admins => 'المدراء';

  @override
  String get disabledAccounts => 'حسابات معطّلة';

  @override
  String get pendingDevices => 'طلبات تغيير جهاز';

  @override
  String get pendingReviews => 'محتوى بانتظار المراجعة';

  @override
  String get openReports => 'بلاغات مفتوحة';

  @override
  String get usersTitle => 'الحسابات';

  @override
  String get newUser => 'حساب جديد';

  @override
  String get editUser => 'تعديل الحساب';

  @override
  String get statusActive => 'مفعّل';

  @override
  String get statusDisabled => 'معطّل';

  @override
  String get disable => 'تعطيل';

  @override
  String get enable => 'تفعيل';

  @override
  String disableConfirm(String name) {
    return 'سيُمنع $name من الدخول وتُنهى جلساته الحالية. متابعة؟';
  }

  @override
  String get initialPassword => 'كلمة المرور الأولية';

  @override
  String get initialPasswordHint =>
      'يُسلّمها المدير للمستخدم بطريقة آمنة، ويُطلب منه تغييرها عند أول دخول';

  @override
  String get scopeUniversities => 'جامعات كاملة';

  @override
  String get scopeFaculties => 'كليات محددة';

  @override
  String get scopeRequired => 'حدّد جامعة أو كلية واحدة على الأقل';

  @override
  String get userCreated => 'تم إنشاء الحساب';

  @override
  String get userUpdated => 'تم تحديث الحساب';

  @override
  String get boundDevice => 'الجهاز المرتبط';

  @override
  String get noBoundDevice => 'لم يُربط بعد';

  @override
  String get emptyUsers => 'لا توجد حسابات مطابقة';

  @override
  String get searchUsers => 'ابحث بالاسم أو البريد أو الرقم الجامعي';

  @override
  String createdOn(String date) {
    return 'أُنشئ في $date';
  }

  @override
  String get structureTitle => 'الهيكل الجامعي';

  @override
  String get structureSubtitle =>
      'أدر الجامعات والكليات والمواد والتصنيفات وترتيب ظهورها';

  @override
  String get addItem => 'إضافة';

  @override
  String get editItem => 'تعديل';

  @override
  String get name => 'الاسم';

  @override
  String get active => 'مفعّل';

  @override
  String get inactive => 'معطّل';

  @override
  String get visibleToStudents => 'ظاهر للطلاب';

  @override
  String get level => 'المستوى';

  @override
  String get code => 'الرمز';

  @override
  String get linkedSubjects => 'المواد المرتبطة';

  @override
  String get linkedSpecializations =>
      'الاختصاصات (اتركها فارغة إن كانت المادة مشتركة)';

  @override
  String get reorderHint => 'اسحب العناصر لتغيير ترتيب ظهورها';

  @override
  String get orderSaved => 'تم حفظ الترتيب';

  @override
  String chooseParentFirst(String parent) {
    return 'اختر $parent لعرض العناصر';
  }

  @override
  String get emptyItems => 'لا توجد عناصر بعد';

  @override
  String get itemSaved => 'تم الحفظ';

  @override
  String get allContent => 'كل المحتوى';

  @override
  String get reviewQueue => 'المراجعة';

  @override
  String get approve => 'اعتماد';

  @override
  String get reject => 'رفض';

  @override
  String get approved => 'تم الاعتماد';

  @override
  String get rejected => 'تم الرفض';

  @override
  String get rejectReasonHint => 'سبب الرفض (يظهر للمكتبة)';

  @override
  String get deviceRequests => 'طلبات تغيير الجهاز';

  @override
  String get deviceLog => 'سجل الأجهزة';

  @override
  String get statusPending => 'قيد المراجعة';

  @override
  String get statusApproved => 'مقبول';

  @override
  String get statusRejected => 'مرفوض';

  @override
  String get sortNewest => 'الأحدث أولاً';

  @override
  String get sortOldest => 'الأقدم أولاً';

  @override
  String get decisionNote => 'ملاحظة القرار';

  @override
  String get oldDevice => 'الجهاز الحالي';

  @override
  String get newDevice => 'الجهاز الجديد';

  @override
  String requestedOn(String date) {
    return 'طُلب في $date';
  }

  @override
  String decidedBy(String name, String date) {
    return '$name · $date';
  }

  @override
  String get approveDeviceConfirm =>
      'سيُلغى ارتباط الجهاز الحالي وتُنهى جلساته، ويُربط الحساب بالجهاز الجديد.';

  @override
  String get emptyRequests => 'لا توجد طلبات';

  @override
  String get logBound => 'ربط جهاز';

  @override
  String get logChangeRequested => 'طلب تغيير';

  @override
  String get logApproved => 'موافقة وربط جديد';

  @override
  String get logRejected => 'رفض الطلب';

  @override
  String get logUnbound => 'إلغاء ارتباط';

  @override
  String get emptyLogs => 'لا توجد سجلات';

  @override
  String get auditLog => 'سجل العمليات';

  @override
  String get auditLogSubtitle => 'العمليات الإدارية والحساسة';

  @override
  String get settingsTitle => 'إعدادات النظام';

  @override
  String get settingsSubtitle => 'حدود الملفات، المراجعة، الإشعارات';

  @override
  String get settingsAppliesNote =>
      'تُطبّق الإعدادات الجديدة على العمليات اللاحقة فقط.';

  @override
  String get maxUploadSize => 'الحد الأقصى لحجم الملف (ميغابايت)';

  @override
  String get allowedExtensions => 'الصيغ المسموحة';

  @override
  String get requireReview => 'اشتراط مراجعة المحتوى قبل النشر';

  @override
  String get requireReviewHint =>
      'يظهر محتوى المكتبات للطلاب بعد اعتماد المدير فقط';

  @override
  String get settingsSaved => 'تم حفظ الإعدادات';

  @override
  String get reportsTitle => 'البلاغات';

  @override
  String get reportsSubtitle => 'مراجعة بلاغات الطلاب عن المحتوى';

  @override
  String get reportOpen => 'مفتوح';

  @override
  String get reportInReview => 'قيد المعالجة';

  @override
  String get reportResolved => 'تمت المعالجة';

  @override
  String get reportDismissed => 'مرفوض';

  @override
  String get updateStatus => 'تحديث الحالة';

  @override
  String get addNote => 'إضافة ملاحظة';

  @override
  String get emptyReports => 'لا توجد بلاغات';

  @override
  String get emptyAudit => 'لا توجد عمليات مسجلة';

  @override
  String reportedBy(String name) {
    return 'أبلغ عنه $name';
  }

  @override
  String get history => 'السجل';

  @override
  String get entityContent => 'محتوى';

  @override
  String get entityDevice => 'جهاز';

  @override
  String get entitySettings => 'إعدادات';

  @override
  String get entityReport => 'بلاغ';

  @override
  String get manageSection => 'الإدارة';

  @override
  String get structureKindsSection => 'عناصر الهيكل';

  @override
  String get passwordRules => '10 أحرف على الأقل، ولا تتكوّن من أرقام فقط';

  @override
  String get sendResetLink => 'إرسال رابط الاستعادة';

  @override
  String get linkSentTitle => 'تحقّق من بريدك';

  @override
  String linkSentBody(String email) {
    return 'إذا كان $email مسجّلاً فسيصله رابط لتعيين كلمة مرور جديدة صالح لمدة ساعة. افتح الرابط على هذا الجهاز.';
  }

  @override
  String get pasteLinkLabel => 'أو الصق الرابط من البريد هنا';

  @override
  String get continueAction => 'متابعة';

  @override
  String get invalidResetLink =>
      'الرابط غير صالح. انسخ الرابط كاملاً من البريد.';

  @override
  String get resendLink => 'إعادة إرسال الرابط';

  @override
  String get mustChangeTitle => 'عيّن كلمة مرور جديدة';

  @override
  String get mustChangeBody =>
      'أُنشئ حسابك أو أُعيد تعيينه بكلمة مرور مؤقتة. اختر كلمة مرور خاصة بك للمتابعة.';

  @override
  String get category => 'التصنيف';

  @override
  String get lectureCategories => 'تصنيفات المحاضرات';

  @override
  String get doctorTitle => 'اللقب (مثل د.)';

  @override
  String get number => 'الرقم';

  @override
  String get librariesSubtitle => 'الجهات المزوّدة للمحتوى ونطاق كل منها';

  @override
  String get newLibrary => 'مكتبة جديدة';

  @override
  String get editLibrary => 'تعديل المكتبة';

  @override
  String get libraryLabel => 'المكتبة';

  @override
  String get libraryRequired => 'اختر المكتبة';

  @override
  String get contactEmail => 'بريد التواصل';

  @override
  String get contactPhone => 'هاتف التواصل';

  @override
  String staffCount(int count) {
    return '$count حساب';
  }

  @override
  String get emptyLibraries => 'لا توجد مكتبات بعد';

  @override
  String get librarySaved => 'تم حفظ المكتبة';

  @override
  String get resetDevice => 'إلغاء ربط الجهاز';

  @override
  String resetDeviceConfirm(String name) {
    return 'سيُلغى ربط جهاز $name وتنتهي جلساته، ويُربط أول جهاز يسجّل الدخول منه بعد ذلك.';
  }

  @override
  String get deviceResetDone => 'تم إلغاء ربط الجهاز';

  @override
  String get setPassword => 'تعيين كلمة مرور جديدة';

  @override
  String get setPasswordHint =>
      'تنتهي جلسات المستخدم ويُطلب منه تغييرها عند الدخول';

  @override
  String get passwordSet => 'تم تعيين كلمة المرور';

  @override
  String get statusCancelled => 'ملغى';

  @override
  String get logCancelled => 'إلغاء الطلب';

  @override
  String get notifyFollowers => 'إشعار المتابعين عند النشر';

  @override
  String get notifyFollowersHint =>
      'يصل إشعار لمتابعي المقرر عند نشر محتوى جديد فيه';

  @override
  String get auditAccount => 'الحسابات';

  @override
  String get auditAuth => 'الدخول';

  @override
  String get auditCatalog => 'الهيكل الأكاديمي';

  @override
  String get auditLibrary => 'المكتبات';

  @override
  String get auditSecurity => 'الأمان';

  @override
  String get noFileYet => 'لم يُرفع ملف بعد';
}
