import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In ar, this message translates to:
  /// **'UniLect'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In ar, this message translates to:
  /// **'محاضراتك وأسئلة دوراتك في مكان واحد آمن'**
  String get appTagline;

  /// No description provided for @retry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get save;

  /// No description provided for @confirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get confirm;

  /// No description provided for @delete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get edit;

  /// No description provided for @close.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get close;

  /// No description provided for @search.
  ///
  /// In ar, this message translates to:
  /// **'بحث'**
  String get search;

  /// No description provided for @filters.
  ///
  /// In ar, this message translates to:
  /// **'التصفية'**
  String get filters;

  /// No description provided for @clearFilters.
  ///
  /// In ar, this message translates to:
  /// **'مسح التصفية'**
  String get clearFilters;

  /// No description provided for @apply.
  ///
  /// In ar, this message translates to:
  /// **'تطبيق'**
  String get apply;

  /// No description provided for @next.
  ///
  /// In ar, this message translates to:
  /// **'التالي'**
  String get next;

  /// No description provided for @back.
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get back;

  /// No description provided for @optional.
  ///
  /// In ar, this message translates to:
  /// **'اختياري'**
  String get optional;

  /// No description provided for @all.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get all;

  /// No description provided for @add.
  ///
  /// In ar, this message translates to:
  /// **'إضافة'**
  String get add;

  /// No description provided for @more.
  ///
  /// In ar, this message translates to:
  /// **'المزيد'**
  String get more;

  /// No description provided for @seeAll.
  ///
  /// In ar, this message translates to:
  /// **'عرض الكل'**
  String get seeAll;

  /// No description provided for @loadMore.
  ///
  /// In ar, this message translates to:
  /// **'تحميل المزيد'**
  String get loadMore;

  /// No description provided for @fieldRequired.
  ///
  /// In ar, this message translates to:
  /// **'هذا الحقل مطلوب'**
  String get fieldRequired;

  /// No description provided for @emailInvalid.
  ///
  /// In ar, this message translates to:
  /// **'أدخل بريداً إلكترونياً صحيحاً'**
  String get emailInvalid;

  /// No description provided for @minChars.
  ///
  /// In ar, this message translates to:
  /// **'{count} أحرف على الأقل'**
  String minChars(int count);

  /// No description provided for @errorNetwork.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الاتصال بالخادم. تحقق من اتصالك بالإنترنت.'**
  String get errorNetwork;

  /// No description provided for @errorTimeout.
  ///
  /// In ar, this message translates to:
  /// **'استغرق الطلب وقتاً طويلاً. حاول مجدداً.'**
  String get errorTimeout;

  /// No description provided for @errorUnknown.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ غير متوقع. حاول مجدداً.'**
  String get errorUnknown;

  /// No description provided for @errorForbidden.
  ///
  /// In ar, this message translates to:
  /// **'ليست لديك صلاحية لتنفيذ هذه العملية.'**
  String get errorForbidden;

  /// No description provided for @errorNotFound.
  ///
  /// In ar, this message translates to:
  /// **'العنصر غير موجود أو لم يعد متاحاً.'**
  String get errorNotFound;

  /// No description provided for @errorValidation.
  ///
  /// In ar, this message translates to:
  /// **'يرجى مراجعة الحقول المحددة.'**
  String get errorValidation;

  /// No description provided for @errorOutOfScope.
  ///
  /// In ar, this message translates to:
  /// **'هذا العنصر خارج نطاق صلاحياتك.'**
  String get errorOutOfScope;

  /// No description provided for @errorRateLimited.
  ///
  /// In ar, this message translates to:
  /// **'محاولات كثيرة. انتظر قليلاً ثم أعد المحاولة.'**
  String get errorRateLimited;

  /// No description provided for @language.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get language;

  /// No description provided for @arabic.
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get arabic;

  /// No description provided for @english.
  ///
  /// In ar, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @loginWelcome.
  ///
  /// In ar, this message translates to:
  /// **'مرحباً بعودتك'**
  String get loginWelcome;

  /// No description provided for @loginSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'سجّل الدخول بالحساب الذي زوّدتك به الإدارة'**
  String get loginSubtitle;

  /// No description provided for @email.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني'**
  String get email;

  /// No description provided for @password.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور'**
  String get password;

  /// No description provided for @signIn.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get signIn;

  /// No description provided for @forgotPassword.
  ///
  /// In ar, this message translates to:
  /// **'نسيت كلمة المرور؟'**
  String get forgotPassword;

  /// No description provided for @showPassword.
  ///
  /// In ar, this message translates to:
  /// **'إظهار كلمة المرور'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء كلمة المرور'**
  String get hidePassword;

  /// No description provided for @noAccountHint.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن إنشاء حساب ذاتياً. تواصل مع إدارة النظام للحصول على حساب.'**
  String get noAccountHint;

  /// No description provided for @invalidCredentials.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني أو كلمة المرور غير صحيحة'**
  String get invalidCredentials;

  /// No description provided for @accountDisabled.
  ///
  /// In ar, this message translates to:
  /// **'هذا الحساب معطّل. تواصل مع إدارة النظام.'**
  String get accountDisabled;

  /// No description provided for @sessionEndedRevoked.
  ///
  /// In ar, this message translates to:
  /// **'انتهت جلستك. يرجى تسجيل الدخول مجدداً.'**
  String get sessionEndedRevoked;

  /// No description provided for @sessionEndedDevice.
  ///
  /// In ar, this message translates to:
  /// **'لم يعد هذا الجهاز مرتبطاً بحسابك. سجّل الدخول لتقديم طلب تغيير جهاز.'**
  String get sessionEndedDevice;

  /// No description provided for @sessionEndedDisabled.
  ///
  /// In ar, this message translates to:
  /// **'تم تعطيل حسابك من قبل الإدارة.'**
  String get sessionEndedDisabled;

  /// No description provided for @forgotTitle.
  ///
  /// In ar, this message translates to:
  /// **'استعادة كلمة المرور'**
  String get forgotTitle;

  /// No description provided for @forgotSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أدخل بريدك الإلكتروني وسنرسل لك رابطاً لتعيين كلمة مرور جديدة.'**
  String get forgotSubtitle;

  /// No description provided for @resetTitle.
  ///
  /// In ar, this message translates to:
  /// **'كلمة مرور جديدة'**
  String get resetTitle;

  /// No description provided for @resetSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر كلمة مرور قوية لم تستخدمها من قبل.'**
  String get resetSubtitle;

  /// No description provided for @newPassword.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور الجديدة'**
  String get newPassword;

  /// No description provided for @confirmPassword.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد كلمة المرور'**
  String get confirmPassword;

  /// No description provided for @passwordsDontMatch.
  ///
  /// In ar, this message translates to:
  /// **'كلمتا المرور غير متطابقتين'**
  String get passwordsDontMatch;

  /// No description provided for @resetPasswordAction.
  ///
  /// In ar, this message translates to:
  /// **'حفظ كلمة المرور'**
  String get resetPasswordAction;

  /// No description provided for @passwordResetSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم تغيير كلمة المرور. سجّل الدخول بكلمة المرور الجديدة.'**
  String get passwordResetSuccess;

  /// No description provided for @stepOf.
  ///
  /// In ar, this message translates to:
  /// **'الخطوة {current} من {total}'**
  String stepOf(int current, int total);

  /// No description provided for @deviceBlockedTitle.
  ///
  /// In ar, this message translates to:
  /// **'حسابك مرتبط بجهاز آخر'**
  String get deviceBlockedTitle;

  /// No description provided for @deviceBlockedBody.
  ///
  /// In ar, this message translates to:
  /// **'لحماية المحتوى، يُسمح باستخدام حساب الطالب على جهاز واحد فقط. يمكنك طلب نقل حسابك إلى هذا الجهاز وستراجع الإدارة طلبك.'**
  String get deviceBlockedBody;

  /// No description provided for @deviceHowTitle.
  ///
  /// In ar, this message translates to:
  /// **'كيف يعمل طلب تغيير الجهاز؟'**
  String get deviceHowTitle;

  /// No description provided for @deviceHowStep1.
  ///
  /// In ar, this message translates to:
  /// **'أرسل الطلب من هذا الجهاز مع ذكر السبب إن أردت.'**
  String get deviceHowStep1;

  /// No description provided for @deviceHowStep2.
  ///
  /// In ar, this message translates to:
  /// **'يراجع مدير النظام الطلب ويقبله أو يرفضه.'**
  String get deviceHowStep2;

  /// No description provided for @deviceHowStep3.
  ///
  /// In ar, this message translates to:
  /// **'عند القبول يُلغى ارتباط الجهاز القديم وتسجّل الدخول من هذا الجهاز.'**
  String get deviceHowStep3;

  /// No description provided for @reasonLabel.
  ///
  /// In ar, this message translates to:
  /// **'سبب التغيير'**
  String get reasonLabel;

  /// No description provided for @reasonHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: تعطّل جهازي السابق'**
  String get reasonHint;

  /// No description provided for @submitRequest.
  ///
  /// In ar, this message translates to:
  /// **'إرسال الطلب'**
  String get submitRequest;

  /// No description provided for @requestSubmittedTitle.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال طلبك'**
  String get requestSubmittedTitle;

  /// No description provided for @requestSubmittedBody.
  ///
  /// In ar, this message translates to:
  /// **'طلبك الآن قيد المراجعة. ستتمكن من تسجيل الدخول على هذا الجهاز فور الموافقة عليه.'**
  String get requestSubmittedBody;

  /// No description provided for @pendingRequestTitle.
  ///
  /// In ar, this message translates to:
  /// **'لديك طلب قيد المراجعة'**
  String get pendingRequestTitle;

  /// No description provided for @pendingRequestBody.
  ///
  /// In ar, this message translates to:
  /// **'أرسلت طلب تغيير جهاز بتاريخ {date}. سنُعلمك فور اتخاذ القرار.'**
  String pendingRequestBody(String date);

  /// No description provided for @backToLogin.
  ///
  /// In ar, this message translates to:
  /// **'العودة لتسجيل الدخول'**
  String get backToLogin;

  /// No description provided for @navBrowse.
  ///
  /// In ar, this message translates to:
  /// **'تصفّح'**
  String get navBrowse;

  /// No description provided for @navSearch.
  ///
  /// In ar, this message translates to:
  /// **'بحث'**
  String get navSearch;

  /// No description provided for @navFavorites.
  ///
  /// In ar, this message translates to:
  /// **'المفضلة'**
  String get navFavorites;

  /// No description provided for @navNotifications.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات'**
  String get navNotifications;

  /// No description provided for @navProfile.
  ///
  /// In ar, this message translates to:
  /// **'حسابي'**
  String get navProfile;

  /// No description provided for @navDashboard.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get navDashboard;

  /// No description provided for @navContent.
  ///
  /// In ar, this message translates to:
  /// **'المحتوى'**
  String get navContent;

  /// No description provided for @navUsers.
  ///
  /// In ar, this message translates to:
  /// **'الحسابات'**
  String get navUsers;

  /// No description provided for @navStructure.
  ///
  /// In ar, this message translates to:
  /// **'الهيكل'**
  String get navStructure;

  /// No description provided for @navDevices.
  ///
  /// In ar, this message translates to:
  /// **'الأجهزة'**
  String get navDevices;

  /// No description provided for @greeting.
  ///
  /// In ar, this message translates to:
  /// **'أهلاً، {name}'**
  String greeting(String name);

  /// No description provided for @chooseUniversity.
  ///
  /// In ar, this message translates to:
  /// **'اختر جامعتك للبدء'**
  String get chooseUniversity;

  /// No description provided for @universities.
  ///
  /// In ar, this message translates to:
  /// **'الجامعات'**
  String get universities;

  /// No description provided for @faculties.
  ///
  /// In ar, this message translates to:
  /// **'الكليات'**
  String get faculties;

  /// No description provided for @years.
  ///
  /// In ar, this message translates to:
  /// **'السنوات الدراسية'**
  String get years;

  /// No description provided for @specializations.
  ///
  /// In ar, this message translates to:
  /// **'الاختصاصات'**
  String get specializations;

  /// No description provided for @subjects.
  ///
  /// In ar, this message translates to:
  /// **'المواد'**
  String get subjects;

  /// No description provided for @doctors.
  ///
  /// In ar, this message translates to:
  /// **'الدكاترة'**
  String get doctors;

  /// No description provided for @terms.
  ///
  /// In ar, this message translates to:
  /// **'الفصول الدراسية'**
  String get terms;

  /// No description provided for @examTypes.
  ///
  /// In ar, this message translates to:
  /// **'أنواع الدورات'**
  String get examTypes;

  /// No description provided for @allSpecializations.
  ///
  /// In ar, this message translates to:
  /// **'كل الاختصاصات'**
  String get allSpecializations;

  /// No description provided for @lectures.
  ///
  /// In ar, this message translates to:
  /// **'المحاضرات'**
  String get lectures;

  /// No description provided for @exams.
  ///
  /// In ar, this message translates to:
  /// **'أسئلة الدورات'**
  String get exams;

  /// No description provided for @lectureNumber.
  ///
  /// In ar, this message translates to:
  /// **'المحاضرة {number}'**
  String lectureNumber(int number);

  /// No description provided for @lecturesCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا محاضرات} =1{محاضرة واحدة} =2{محاضرتان} few{{count} محاضرات} many{{count} محاضرة} other{{count} محاضرة}}'**
  String lecturesCount(int count);

  /// No description provided for @follow.
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get follow;

  /// No description provided for @following.
  ///
  /// In ar, this message translates to:
  /// **'متابَعة'**
  String get following;

  /// No description provided for @followHint.
  ///
  /// In ar, this message translates to:
  /// **'ستصلك إشعارات عند إضافة محتوى جديد لهذه المادة'**
  String get followHint;

  /// No description provided for @followed.
  ///
  /// In ar, this message translates to:
  /// **'ستصلك إشعارات بالمحتوى الجديد'**
  String get followed;

  /// No description provided for @unfollowed.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء المتابعة'**
  String get unfollowed;

  /// No description provided for @chooseDoctor.
  ///
  /// In ar, this message translates to:
  /// **'اختر الدكتور لعرض محاضراته'**
  String get chooseDoctor;

  /// No description provided for @emptyUniversities.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد جامعات متاحة حالياً'**
  String get emptyUniversities;

  /// No description provided for @emptyFaculties.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد كليات متاحة في هذه الجامعة'**
  String get emptyFaculties;

  /// No description provided for @emptyYears.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد سنوات دراسية لهذه الكلية'**
  String get emptyYears;

  /// No description provided for @emptySubjects.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مواد في هذه السنة'**
  String get emptySubjects;

  /// No description provided for @emptyDoctors.
  ///
  /// In ar, this message translates to:
  /// **'لم يُربط أي دكتور بهذه المادة بعد'**
  String get emptyDoctors;

  /// No description provided for @emptyLectures.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد محاضرات منشورة بعد'**
  String get emptyLectures;

  /// No description provided for @emptyExams.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد أسئلة دورات مطابقة'**
  String get emptyExams;

  /// No description provided for @emptyGenericHint.
  ///
  /// In ar, this message translates to:
  /// **'عُد لاحقاً، سيُضاف المحتوى قريباً.'**
  String get emptyGenericHint;

  /// No description provided for @examYear.
  ///
  /// In ar, this message translates to:
  /// **'العام'**
  String get examYear;

  /// No description provided for @term.
  ///
  /// In ar, this message translates to:
  /// **'الفصل'**
  String get term;

  /// No description provided for @examType.
  ///
  /// In ar, this message translates to:
  /// **'نوع الدورة'**
  String get examType;

  /// No description provided for @doctor.
  ///
  /// In ar, this message translates to:
  /// **'الدكتور'**
  String get doctor;

  /// No description provided for @anyValue.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get anyValue;

  /// No description provided for @contentDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل المحتوى'**
  String get contentDetails;

  /// No description provided for @openFile.
  ///
  /// In ar, this message translates to:
  /// **'فتح الملف'**
  String get openFile;

  /// No description provided for @addedOn.
  ///
  /// In ar, this message translates to:
  /// **'أُضيف في {date}'**
  String addedOn(String date);

  /// No description provided for @classification.
  ///
  /// In ar, this message translates to:
  /// **'التصنيف'**
  String get classification;

  /// No description provided for @university.
  ///
  /// In ar, this message translates to:
  /// **'الجامعة'**
  String get university;

  /// No description provided for @faculty.
  ///
  /// In ar, this message translates to:
  /// **'الكلية'**
  String get faculty;

  /// No description provided for @year.
  ///
  /// In ar, this message translates to:
  /// **'السنة'**
  String get year;

  /// No description provided for @subject.
  ///
  /// In ar, this message translates to:
  /// **'المادة'**
  String get subject;

  /// No description provided for @typeLecture.
  ///
  /// In ar, this message translates to:
  /// **'محاضرة'**
  String get typeLecture;

  /// No description provided for @typeExam.
  ///
  /// In ar, this message translates to:
  /// **'أسئلة دورة'**
  String get typeExam;

  /// No description provided for @contentType.
  ///
  /// In ar, this message translates to:
  /// **'نوع المحتوى'**
  String get contentType;

  /// No description provided for @fileInfo.
  ///
  /// In ar, this message translates to:
  /// **'الملف'**
  String get fileInfo;

  /// No description provided for @formatPdf.
  ///
  /// In ar, this message translates to:
  /// **'PDF'**
  String get formatPdf;

  /// No description provided for @formatImage.
  ///
  /// In ar, this message translates to:
  /// **'صورة'**
  String get formatImage;

  /// No description provided for @addToFavorites.
  ///
  /// In ar, this message translates to:
  /// **'إضافة إلى المفضلة'**
  String get addToFavorites;

  /// No description provided for @removeFromFavorites.
  ///
  /// In ar, this message translates to:
  /// **'إزالة من المفضلة'**
  String get removeFromFavorites;

  /// No description provided for @addedToFavorites.
  ///
  /// In ar, this message translates to:
  /// **'أُضيف إلى المفضلة'**
  String get addedToFavorites;

  /// No description provided for @removedFromFavorites.
  ///
  /// In ar, this message translates to:
  /// **'أُزيل من المفضلة'**
  String get removedFromFavorites;

  /// No description provided for @reportContent.
  ///
  /// In ar, this message translates to:
  /// **'الإبلاغ عن مشكلة'**
  String get reportContent;

  /// No description provided for @reportTitle.
  ///
  /// In ar, this message translates to:
  /// **'ما المشكلة في هذا المحتوى؟'**
  String get reportTitle;

  /// No description provided for @reasonWrongFile.
  ///
  /// In ar, this message translates to:
  /// **'ملف خاطئ'**
  String get reasonWrongFile;

  /// No description provided for @reasonDuplicate.
  ///
  /// In ar, this message translates to:
  /// **'محتوى مكرر'**
  String get reasonDuplicate;

  /// No description provided for @reasonInappropriate.
  ///
  /// In ar, this message translates to:
  /// **'محتوى غير مناسب'**
  String get reasonInappropriate;

  /// No description provided for @reasonOther.
  ///
  /// In ar, this message translates to:
  /// **'سبب آخر'**
  String get reasonOther;

  /// No description provided for @reportNote.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل إضافية'**
  String get reportNote;

  /// No description provided for @sendReport.
  ///
  /// In ar, this message translates to:
  /// **'إرسال البلاغ'**
  String get sendReport;

  /// No description provided for @reportSubmitted.
  ///
  /// In ar, this message translates to:
  /// **'شكراً لك، وصل بلاغك إلى الإدارة'**
  String get reportSubmitted;

  /// No description provided for @unsupportedFormat.
  ///
  /// In ar, this message translates to:
  /// **'صيغة هذا الملف غير مدعومة في العارض.'**
  String get unsupportedFormat;

  /// No description provided for @viewerProtected.
  ///
  /// In ar, this message translates to:
  /// **'محتوى محمي · للعرض داخل التطبيق فقط'**
  String get viewerProtected;

  /// No description provided for @captureHidden.
  ///
  /// In ar, this message translates to:
  /// **'أُخفي المحتوى أثناء تسجيل الشاشة أو مشاركتها'**
  String get captureHidden;

  /// No description provided for @pageOf.
  ///
  /// In ar, this message translates to:
  /// **'{current} / {total}'**
  String pageOf(int current, int total);

  /// No description provided for @loadingFile.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تحميل الملف بأمان…'**
  String get loadingFile;

  /// No description provided for @protectionNote.
  ///
  /// In ar, this message translates to:
  /// **'قد لا يمنع التطبيق لقطات الشاشة على جميع الأجهزة. يُرجى احترام حقوق المحتوى.'**
  String get protectionNote;

  /// No description provided for @searchHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن محاضرة أو دورة أو مادة'**
  String get searchHint;

  /// No description provided for @searchPrompt.
  ///
  /// In ar, this message translates to:
  /// **'ابحث في المحاضرات وأسئلة الدورات المتاحة لك'**
  String get searchPrompt;

  /// No description provided for @noResults.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد نتائج مطابقة'**
  String get noResults;

  /// No description provided for @noResultsHint.
  ///
  /// In ar, this message translates to:
  /// **'جرّب كلمات أخرى أو خفّف التصفية'**
  String get noResultsHint;

  /// No description provided for @resultsCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا نتائج} =1{نتيجة واحدة} =2{نتيجتان} few{{count} نتائج} many{{count} نتيجة} other{{count} نتيجة}}'**
  String resultsCount(int count);

  /// No description provided for @favoritesTitle.
  ///
  /// In ar, this message translates to:
  /// **'المفضلة'**
  String get favoritesTitle;

  /// No description provided for @emptyFavorites.
  ///
  /// In ar, this message translates to:
  /// **'لا عناصر في المفضلة'**
  String get emptyFavorites;

  /// No description provided for @emptyFavoritesHint.
  ///
  /// In ar, this message translates to:
  /// **'اضغط على رمز القلب في أي محاضرة لحفظها هنا.'**
  String get emptyFavoritesHint;

  /// No description provided for @notificationsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات'**
  String get notificationsTitle;

  /// No description provided for @markAllRead.
  ///
  /// In ar, this message translates to:
  /// **'تحديد الكل كمقروء'**
  String get markAllRead;

  /// No description provided for @emptyNotifications.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد إشعارات'**
  String get emptyNotifications;

  /// No description provided for @emptyNotificationsHint.
  ///
  /// In ar, this message translates to:
  /// **'ستظهر هنا نتائج طلباتك والمحتوى الجديد.'**
  String get emptyNotificationsHint;

  /// No description provided for @profileTitle.
  ///
  /// In ar, this message translates to:
  /// **'حسابي'**
  String get profileTitle;

  /// No description provided for @fullName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم الكامل'**
  String get fullName;

  /// No description provided for @phone.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف'**
  String get phone;

  /// No description provided for @studentNumber.
  ///
  /// In ar, this message translates to:
  /// **'الرقم الجامعي'**
  String get studentNumber;

  /// No description provided for @role.
  ///
  /// In ar, this message translates to:
  /// **'الدور'**
  String get role;

  /// No description provided for @roleStudent.
  ///
  /// In ar, this message translates to:
  /// **'طالب'**
  String get roleStudent;

  /// No description provided for @roleLibrary.
  ///
  /// In ar, this message translates to:
  /// **'مكتبة'**
  String get roleLibrary;

  /// No description provided for @roleAdmin.
  ///
  /// In ar, this message translates to:
  /// **'مدير النظام'**
  String get roleAdmin;

  /// No description provided for @editProfile.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الملف الشخصي'**
  String get editProfile;

  /// No description provided for @saveChanges.
  ///
  /// In ar, this message translates to:
  /// **'حفظ التغييرات'**
  String get saveChanges;

  /// No description provided for @profileSaved.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ التغييرات'**
  String get profileSaved;

  /// No description provided for @protectedFieldsNote.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني والرقم الجامعي والدور تديرها الإدارة ولا يمكن تعديلها.'**
  String get protectedFieldsNote;

  /// No description provided for @changePassword.
  ///
  /// In ar, this message translates to:
  /// **'تغيير كلمة المرور'**
  String get changePassword;

  /// No description provided for @currentPassword.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور الحالية'**
  String get currentPassword;

  /// No description provided for @passwordChanged.
  ///
  /// In ar, this message translates to:
  /// **'تم تغيير كلمة المرور'**
  String get passwordChanged;

  /// No description provided for @logout.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get logout;

  /// No description provided for @logoutConfirm.
  ///
  /// In ar, this message translates to:
  /// **'هل تريد تسجيل الخروج من هذا الجهاز؟'**
  String get logoutConfirm;

  /// No description provided for @scopeLabel.
  ///
  /// In ar, this message translates to:
  /// **'نطاق المكتبة'**
  String get scopeLabel;

  /// No description provided for @accountSection.
  ///
  /// In ar, this message translates to:
  /// **'الحساب'**
  String get accountSection;

  /// No description provided for @preferencesSection.
  ///
  /// In ar, this message translates to:
  /// **'التفضيلات'**
  String get preferencesSection;

  /// No description provided for @statusLabel.
  ///
  /// In ar, this message translates to:
  /// **'الحالة'**
  String get statusLabel;

  /// No description provided for @statusDraft.
  ///
  /// In ar, this message translates to:
  /// **'مسودة'**
  String get statusDraft;

  /// No description provided for @statusPendingReview.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار المراجعة'**
  String get statusPendingReview;

  /// No description provided for @statusPublished.
  ///
  /// In ar, this message translates to:
  /// **'منشور'**
  String get statusPublished;

  /// No description provided for @statusArchived.
  ///
  /// In ar, this message translates to:
  /// **'مؤرشف'**
  String get statusArchived;

  /// No description provided for @libraryHello.
  ///
  /// In ar, this message translates to:
  /// **'لوحة المكتبة'**
  String get libraryHello;

  /// No description provided for @contentOverview.
  ///
  /// In ar, this message translates to:
  /// **'نظرة على المحتوى'**
  String get contentOverview;

  /// No description provided for @quickActions.
  ///
  /// In ar, this message translates to:
  /// **'إجراءات سريعة'**
  String get quickActions;

  /// No description provided for @uploadLecture.
  ///
  /// In ar, this message translates to:
  /// **'رفع محاضرة'**
  String get uploadLecture;

  /// No description provided for @uploadExam.
  ///
  /// In ar, this message translates to:
  /// **'رفع أسئلة دورة'**
  String get uploadExam;

  /// No description provided for @batchUpload.
  ///
  /// In ar, this message translates to:
  /// **'رفع عدة ملفات'**
  String get batchUpload;

  /// No description provided for @recentContent.
  ///
  /// In ar, this message translates to:
  /// **'آخر التحديثات'**
  String get recentContent;

  /// No description provided for @manageContent.
  ///
  /// In ar, this message translates to:
  /// **'إدارة المحتوى'**
  String get manageContent;

  /// No description provided for @emptyManaged.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد محتوى بعد'**
  String get emptyManaged;

  /// No description provided for @emptyManagedHint.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ برفع أول محاضرة أو ملف دورة.'**
  String get emptyManagedHint;

  /// No description provided for @newLecture.
  ///
  /// In ar, this message translates to:
  /// **'محاضرة جديدة'**
  String get newLecture;

  /// No description provided for @newExam.
  ///
  /// In ar, this message translates to:
  /// **'أسئلة دورة جديدة'**
  String get newExam;

  /// No description provided for @editContent.
  ///
  /// In ar, this message translates to:
  /// **'تعديل المحتوى'**
  String get editContent;

  /// No description provided for @title.
  ///
  /// In ar, this message translates to:
  /// **'العنوان'**
  String get title;

  /// No description provided for @description.
  ///
  /// In ar, this message translates to:
  /// **'الوصف'**
  String get description;

  /// No description provided for @file.
  ///
  /// In ar, this message translates to:
  /// **'الملف'**
  String get file;

  /// No description provided for @chooseFile.
  ///
  /// In ar, this message translates to:
  /// **'اختيار ملف'**
  String get chooseFile;

  /// No description provided for @replaceFile.
  ///
  /// In ar, this message translates to:
  /// **'استبدال الملف'**
  String get replaceFile;

  /// No description provided for @tapToChooseFile.
  ///
  /// In ar, this message translates to:
  /// **'اضغط لاختيار ملف'**
  String get tapToChooseFile;

  /// No description provided for @allowedTypesInfo.
  ///
  /// In ar, this message translates to:
  /// **'الصيغ المسموحة: {types} · الحد الأقصى {size} ميغابايت'**
  String allowedTypesInfo(String types, int size);

  /// No description provided for @selectHint.
  ///
  /// In ar, this message translates to:
  /// **'اختر {field}'**
  String selectHint(String field);

  /// No description provided for @lectureOrder.
  ///
  /// In ar, this message translates to:
  /// **'رقم المحاضرة'**
  String get lectureOrder;

  /// No description provided for @lectureOrderHint.
  ///
  /// In ar, this message translates to:
  /// **'يحدد ترتيب الظهور'**
  String get lectureOrderHint;

  /// No description provided for @saveDraft.
  ///
  /// In ar, this message translates to:
  /// **'حفظ كمسودة'**
  String get saveDraft;

  /// No description provided for @publish.
  ///
  /// In ar, this message translates to:
  /// **'نشر'**
  String get publish;

  /// No description provided for @submitForReview.
  ///
  /// In ar, this message translates to:
  /// **'إرسال للمراجعة'**
  String get submitForReview;

  /// No description provided for @preview.
  ///
  /// In ar, this message translates to:
  /// **'معاينة'**
  String get preview;

  /// No description provided for @previewTitle.
  ///
  /// In ar, this message translates to:
  /// **'معاينة قبل النشر'**
  String get previewTitle;

  /// No description provided for @previewSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'تأكد من التصنيف والملف قبل الحفظ النهائي.'**
  String get previewSubtitle;

  /// No description provided for @previewFile.
  ///
  /// In ar, this message translates to:
  /// **'معاينة الملف'**
  String get previewFile;

  /// No description provided for @uploading.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ الرفع… {percent}%'**
  String uploading(int percent);

  /// No description provided for @savedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم الحفظ بنجاح'**
  String get savedSuccess;

  /// No description provided for @publishedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم النشر بنجاح'**
  String get publishedSuccess;

  /// No description provided for @sentForReview.
  ///
  /// In ar, this message translates to:
  /// **'أُرسل المحتوى لمراجعة الإدارة'**
  String get sentForReview;

  /// No description provided for @fileTooLarge.
  ///
  /// In ar, this message translates to:
  /// **'حجم الملف يتجاوز {size} ميغابايت'**
  String fileTooLarge(int size);

  /// No description provided for @fileTypeNotAllowed.
  ///
  /// In ar, this message translates to:
  /// **'صيغة الملف .{ext} غير مسموحة'**
  String fileTypeNotAllowed(String ext);

  /// No description provided for @fileRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى اختيار ملف'**
  String get fileRequired;

  /// No description provided for @versions.
  ///
  /// In ar, this message translates to:
  /// **'سجل النسخ'**
  String get versions;

  /// No description provided for @versionN.
  ///
  /// In ar, this message translates to:
  /// **'النسخة {number}'**
  String versionN(int number);

  /// No description provided for @currentVersion.
  ///
  /// In ar, this message translates to:
  /// **'الحالية'**
  String get currentVersion;

  /// No description provided for @fileReplaced.
  ///
  /// In ar, this message translates to:
  /// **'تم استبدال الملف'**
  String get fileReplaced;

  /// No description provided for @archive.
  ///
  /// In ar, this message translates to:
  /// **'أرشفة'**
  String get archive;

  /// No description provided for @restoreDraft.
  ///
  /// In ar, this message translates to:
  /// **'إرجاع إلى مسودة'**
  String get restoreDraft;

  /// No description provided for @deleteContentConfirm.
  ///
  /// In ar, this message translates to:
  /// **'سيُحذف المحتوى نهائياً ولن يعود ظاهراً للطلاب. هل تريد المتابعة؟'**
  String get deleteContentConfirm;

  /// No description provided for @deleted.
  ///
  /// In ar, this message translates to:
  /// **'تم الحذف'**
  String get deleted;

  /// No description provided for @missingForPublish.
  ///
  /// In ar, this message translates to:
  /// **'أكمل الحقول الإلزامية للنشر: {fields}'**
  String missingForPublish(String fields);

  /// No description provided for @reviewRequiredNote.
  ///
  /// In ar, this message translates to:
  /// **'تتطلب الإدارة مراجعة المحتوى قبل ظهوره للطلاب.'**
  String get reviewRequiredNote;

  /// No description provided for @reviewNote.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة المراجعة'**
  String get reviewNote;

  /// No description provided for @actions.
  ///
  /// In ar, this message translates to:
  /// **'إجراءات'**
  String get actions;

  /// No description provided for @statusChanged.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديث الحالة'**
  String get statusChanged;

  /// No description provided for @batchTitle.
  ///
  /// In ar, this message translates to:
  /// **'رفع عدة ملفات'**
  String get batchTitle;

  /// No description provided for @batchSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'حدّد تصنيفاً مشتركاً ثم راجع بيانات كل ملف.'**
  String get batchSubtitle;

  /// No description provided for @addFiles.
  ///
  /// In ar, this message translates to:
  /// **'إضافة ملفات'**
  String get addFiles;

  /// No description provided for @commonClassification.
  ///
  /// In ar, this message translates to:
  /// **'التصنيف المشترك'**
  String get commonClassification;

  /// No description provided for @filesToUpload.
  ///
  /// In ar, this message translates to:
  /// **'الملفات ({count})'**
  String filesToUpload(int count);

  /// No description provided for @uploadAll.
  ///
  /// In ar, this message translates to:
  /// **'رفع الكل'**
  String get uploadAll;

  /// No description provided for @batchSummary.
  ///
  /// In ar, this message translates to:
  /// **'نجح {ok} · فشل {failed}'**
  String batchSummary(int ok, int failed);

  /// No description provided for @batchPending.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار الرفع'**
  String get batchPending;

  /// No description provided for @batchSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم الرفع'**
  String get batchSuccess;

  /// No description provided for @batchFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل'**
  String get batchFailed;

  /// No description provided for @removeFile.
  ///
  /// In ar, this message translates to:
  /// **'إزالة'**
  String get removeFile;

  /// No description provided for @publishAfterUpload.
  ///
  /// In ar, this message translates to:
  /// **'نشر مباشرة بعد الرفع'**
  String get publishAfterUpload;

  /// No description provided for @retryFailed.
  ///
  /// In ar, this message translates to:
  /// **'إعادة محاولة الفاشلة'**
  String get retryFailed;

  /// No description provided for @adminHello.
  ///
  /// In ar, this message translates to:
  /// **'لوحة الإدارة'**
  String get adminHello;

  /// No description provided for @needsAction.
  ///
  /// In ar, this message translates to:
  /// **'بحاجة إلى إجراء'**
  String get needsAction;

  /// No description provided for @students.
  ///
  /// In ar, this message translates to:
  /// **'الطلاب'**
  String get students;

  /// No description provided for @libraries.
  ///
  /// In ar, this message translates to:
  /// **'المكتبات'**
  String get libraries;

  /// No description provided for @admins.
  ///
  /// In ar, this message translates to:
  /// **'المدراء'**
  String get admins;

  /// No description provided for @disabledAccounts.
  ///
  /// In ar, this message translates to:
  /// **'حسابات معطّلة'**
  String get disabledAccounts;

  /// No description provided for @pendingDevices.
  ///
  /// In ar, this message translates to:
  /// **'طلبات تغيير جهاز'**
  String get pendingDevices;

  /// No description provided for @pendingReviews.
  ///
  /// In ar, this message translates to:
  /// **'محتوى بانتظار المراجعة'**
  String get pendingReviews;

  /// No description provided for @openReports.
  ///
  /// In ar, this message translates to:
  /// **'بلاغات مفتوحة'**
  String get openReports;

  /// No description provided for @usersTitle.
  ///
  /// In ar, this message translates to:
  /// **'الحسابات'**
  String get usersTitle;

  /// No description provided for @newUser.
  ///
  /// In ar, this message translates to:
  /// **'حساب جديد'**
  String get newUser;

  /// No description provided for @editUser.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الحساب'**
  String get editUser;

  /// No description provided for @statusActive.
  ///
  /// In ar, this message translates to:
  /// **'مفعّل'**
  String get statusActive;

  /// No description provided for @statusDisabled.
  ///
  /// In ar, this message translates to:
  /// **'معطّل'**
  String get statusDisabled;

  /// No description provided for @disable.
  ///
  /// In ar, this message translates to:
  /// **'تعطيل'**
  String get disable;

  /// No description provided for @enable.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل'**
  String get enable;

  /// No description provided for @disableConfirm.
  ///
  /// In ar, this message translates to:
  /// **'سيُمنع {name} من الدخول وتُنهى جلساته الحالية. متابعة؟'**
  String disableConfirm(String name);

  /// No description provided for @initialPassword.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور الأولية'**
  String get initialPassword;

  /// No description provided for @initialPasswordHint.
  ///
  /// In ar, this message translates to:
  /// **'يُسلّمها المدير للمستخدم بطريقة آمنة، ويُطلب منه تغييرها عند أول دخول'**
  String get initialPasswordHint;

  /// No description provided for @scopeUniversities.
  ///
  /// In ar, this message translates to:
  /// **'جامعات كاملة'**
  String get scopeUniversities;

  /// No description provided for @scopeFaculties.
  ///
  /// In ar, this message translates to:
  /// **'كليات محددة'**
  String get scopeFaculties;

  /// No description provided for @scopeRequired.
  ///
  /// In ar, this message translates to:
  /// **'حدّد جامعة أو كلية واحدة على الأقل'**
  String get scopeRequired;

  /// No description provided for @userCreated.
  ///
  /// In ar, this message translates to:
  /// **'تم إنشاء الحساب'**
  String get userCreated;

  /// No description provided for @userUpdated.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديث الحساب'**
  String get userUpdated;

  /// No description provided for @boundDevice.
  ///
  /// In ar, this message translates to:
  /// **'الجهاز المرتبط'**
  String get boundDevice;

  /// No description provided for @noBoundDevice.
  ///
  /// In ar, this message translates to:
  /// **'لم يُربط بعد'**
  String get noBoundDevice;

  /// No description provided for @emptyUsers.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد حسابات مطابقة'**
  String get emptyUsers;

  /// No description provided for @searchUsers.
  ///
  /// In ar, this message translates to:
  /// **'ابحث بالاسم أو البريد أو الرقم الجامعي'**
  String get searchUsers;

  /// No description provided for @createdOn.
  ///
  /// In ar, this message translates to:
  /// **'أُنشئ في {date}'**
  String createdOn(String date);

  /// No description provided for @structureTitle.
  ///
  /// In ar, this message translates to:
  /// **'الهيكل الجامعي'**
  String get structureTitle;

  /// No description provided for @structureSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أدر الجامعات والكليات والمواد والتصنيفات وترتيب ظهورها'**
  String get structureSubtitle;

  /// No description provided for @addItem.
  ///
  /// In ar, this message translates to:
  /// **'إضافة'**
  String get addItem;

  /// No description provided for @editItem.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get editItem;

  /// No description provided for @name.
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get name;

  /// No description provided for @active.
  ///
  /// In ar, this message translates to:
  /// **'مفعّل'**
  String get active;

  /// No description provided for @inactive.
  ///
  /// In ar, this message translates to:
  /// **'معطّل'**
  String get inactive;

  /// No description provided for @visibleToStudents.
  ///
  /// In ar, this message translates to:
  /// **'ظاهر للطلاب'**
  String get visibleToStudents;

  /// No description provided for @level.
  ///
  /// In ar, this message translates to:
  /// **'المستوى'**
  String get level;

  /// No description provided for @code.
  ///
  /// In ar, this message translates to:
  /// **'الرمز'**
  String get code;

  /// No description provided for @linkedSubjects.
  ///
  /// In ar, this message translates to:
  /// **'المواد المرتبطة'**
  String get linkedSubjects;

  /// No description provided for @linkedSpecializations.
  ///
  /// In ar, this message translates to:
  /// **'الاختصاصات (اتركها فارغة إن كانت المادة مشتركة)'**
  String get linkedSpecializations;

  /// No description provided for @reorderHint.
  ///
  /// In ar, this message translates to:
  /// **'اسحب العناصر لتغيير ترتيب ظهورها'**
  String get reorderHint;

  /// No description provided for @orderSaved.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ الترتيب'**
  String get orderSaved;

  /// No description provided for @chooseParentFirst.
  ///
  /// In ar, this message translates to:
  /// **'اختر {parent} لعرض العناصر'**
  String chooseParentFirst(String parent);

  /// No description provided for @emptyItems.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد عناصر بعد'**
  String get emptyItems;

  /// No description provided for @itemSaved.
  ///
  /// In ar, this message translates to:
  /// **'تم الحفظ'**
  String get itemSaved;

  /// No description provided for @allContent.
  ///
  /// In ar, this message translates to:
  /// **'كل المحتوى'**
  String get allContent;

  /// No description provided for @reviewQueue.
  ///
  /// In ar, this message translates to:
  /// **'المراجعة'**
  String get reviewQueue;

  /// No description provided for @approve.
  ///
  /// In ar, this message translates to:
  /// **'اعتماد'**
  String get approve;

  /// No description provided for @reject.
  ///
  /// In ar, this message translates to:
  /// **'رفض'**
  String get reject;

  /// No description provided for @approved.
  ///
  /// In ar, this message translates to:
  /// **'تم الاعتماد'**
  String get approved;

  /// No description provided for @rejected.
  ///
  /// In ar, this message translates to:
  /// **'تم الرفض'**
  String get rejected;

  /// No description provided for @rejectReasonHint.
  ///
  /// In ar, this message translates to:
  /// **'سبب الرفض (يظهر للمكتبة)'**
  String get rejectReasonHint;

  /// No description provided for @deviceRequests.
  ///
  /// In ar, this message translates to:
  /// **'طلبات تغيير الجهاز'**
  String get deviceRequests;

  /// No description provided for @deviceLog.
  ///
  /// In ar, this message translates to:
  /// **'سجل الأجهزة'**
  String get deviceLog;

  /// No description provided for @statusPending.
  ///
  /// In ar, this message translates to:
  /// **'قيد المراجعة'**
  String get statusPending;

  /// No description provided for @statusApproved.
  ///
  /// In ar, this message translates to:
  /// **'مقبول'**
  String get statusApproved;

  /// No description provided for @statusRejected.
  ///
  /// In ar, this message translates to:
  /// **'مرفوض'**
  String get statusRejected;

  /// No description provided for @sortNewest.
  ///
  /// In ar, this message translates to:
  /// **'الأحدث أولاً'**
  String get sortNewest;

  /// No description provided for @sortOldest.
  ///
  /// In ar, this message translates to:
  /// **'الأقدم أولاً'**
  String get sortOldest;

  /// No description provided for @decisionNote.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة القرار'**
  String get decisionNote;

  /// No description provided for @oldDevice.
  ///
  /// In ar, this message translates to:
  /// **'الجهاز الحالي'**
  String get oldDevice;

  /// No description provided for @newDevice.
  ///
  /// In ar, this message translates to:
  /// **'الجهاز الجديد'**
  String get newDevice;

  /// No description provided for @requestedOn.
  ///
  /// In ar, this message translates to:
  /// **'طُلب في {date}'**
  String requestedOn(String date);

  /// No description provided for @decidedBy.
  ///
  /// In ar, this message translates to:
  /// **'{name} · {date}'**
  String decidedBy(String name, String date);

  /// No description provided for @approveDeviceConfirm.
  ///
  /// In ar, this message translates to:
  /// **'سيُلغى ارتباط الجهاز الحالي وتُنهى جلساته، ويُربط الحساب بالجهاز الجديد.'**
  String get approveDeviceConfirm;

  /// No description provided for @emptyRequests.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات'**
  String get emptyRequests;

  /// No description provided for @logBound.
  ///
  /// In ar, this message translates to:
  /// **'ربط جهاز'**
  String get logBound;

  /// No description provided for @logChangeRequested.
  ///
  /// In ar, this message translates to:
  /// **'طلب تغيير'**
  String get logChangeRequested;

  /// No description provided for @logApproved.
  ///
  /// In ar, this message translates to:
  /// **'موافقة وربط جديد'**
  String get logApproved;

  /// No description provided for @logRejected.
  ///
  /// In ar, this message translates to:
  /// **'رفض الطلب'**
  String get logRejected;

  /// No description provided for @logUnbound.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء ارتباط'**
  String get logUnbound;

  /// No description provided for @emptyLogs.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد سجلات'**
  String get emptyLogs;

  /// No description provided for @auditLog.
  ///
  /// In ar, this message translates to:
  /// **'سجل العمليات'**
  String get auditLog;

  /// No description provided for @auditLogSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'العمليات الإدارية والحساسة'**
  String get auditLogSubtitle;

  /// No description provided for @settingsTitle.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات النظام'**
  String get settingsTitle;

  /// No description provided for @settingsSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'حدود الملفات، المراجعة، الإشعارات'**
  String get settingsSubtitle;

  /// No description provided for @settingsAppliesNote.
  ///
  /// In ar, this message translates to:
  /// **'تُطبّق الإعدادات الجديدة على العمليات اللاحقة فقط.'**
  String get settingsAppliesNote;

  /// No description provided for @maxUploadSize.
  ///
  /// In ar, this message translates to:
  /// **'الحد الأقصى لحجم الملف (ميغابايت)'**
  String get maxUploadSize;

  /// No description provided for @allowedExtensions.
  ///
  /// In ar, this message translates to:
  /// **'الصيغ المسموحة'**
  String get allowedExtensions;

  /// No description provided for @requireReview.
  ///
  /// In ar, this message translates to:
  /// **'اشتراط مراجعة المحتوى قبل النشر'**
  String get requireReview;

  /// No description provided for @requireReviewHint.
  ///
  /// In ar, this message translates to:
  /// **'يظهر محتوى المكتبات للطلاب بعد اعتماد المدير فقط'**
  String get requireReviewHint;

  /// No description provided for @settingsSaved.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ الإعدادات'**
  String get settingsSaved;

  /// No description provided for @reportsTitle.
  ///
  /// In ar, this message translates to:
  /// **'البلاغات'**
  String get reportsTitle;

  /// No description provided for @reportsSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'مراجعة بلاغات الطلاب عن المحتوى'**
  String get reportsSubtitle;

  /// No description provided for @reportOpen.
  ///
  /// In ar, this message translates to:
  /// **'مفتوح'**
  String get reportOpen;

  /// No description provided for @reportInReview.
  ///
  /// In ar, this message translates to:
  /// **'قيد المعالجة'**
  String get reportInReview;

  /// No description provided for @reportResolved.
  ///
  /// In ar, this message translates to:
  /// **'تمت المعالجة'**
  String get reportResolved;

  /// No description provided for @reportDismissed.
  ///
  /// In ar, this message translates to:
  /// **'مرفوض'**
  String get reportDismissed;

  /// No description provided for @updateStatus.
  ///
  /// In ar, this message translates to:
  /// **'تحديث الحالة'**
  String get updateStatus;

  /// No description provided for @addNote.
  ///
  /// In ar, this message translates to:
  /// **'إضافة ملاحظة'**
  String get addNote;

  /// No description provided for @emptyReports.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد بلاغات'**
  String get emptyReports;

  /// No description provided for @emptyAudit.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد عمليات مسجلة'**
  String get emptyAudit;

  /// No description provided for @reportedBy.
  ///
  /// In ar, this message translates to:
  /// **'أبلغ عنه {name}'**
  String reportedBy(String name);

  /// No description provided for @history.
  ///
  /// In ar, this message translates to:
  /// **'السجل'**
  String get history;

  /// No description provided for @entityContent.
  ///
  /// In ar, this message translates to:
  /// **'محتوى'**
  String get entityContent;

  /// No description provided for @entityDevice.
  ///
  /// In ar, this message translates to:
  /// **'جهاز'**
  String get entityDevice;

  /// No description provided for @entitySettings.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات'**
  String get entitySettings;

  /// No description provided for @entityReport.
  ///
  /// In ar, this message translates to:
  /// **'بلاغ'**
  String get entityReport;

  /// No description provided for @manageSection.
  ///
  /// In ar, this message translates to:
  /// **'الإدارة'**
  String get manageSection;

  /// No description provided for @structureKindsSection.
  ///
  /// In ar, this message translates to:
  /// **'عناصر الهيكل'**
  String get structureKindsSection;

  /// No description provided for @passwordRules.
  ///
  /// In ar, this message translates to:
  /// **'10 أحرف على الأقل، ولا تتكوّن من أرقام فقط'**
  String get passwordRules;

  /// No description provided for @sendResetLink.
  ///
  /// In ar, this message translates to:
  /// **'إرسال رابط الاستعادة'**
  String get sendResetLink;

  /// No description provided for @linkSentTitle.
  ///
  /// In ar, this message translates to:
  /// **'تحقّق من بريدك'**
  String get linkSentTitle;

  /// No description provided for @linkSentBody.
  ///
  /// In ar, this message translates to:
  /// **'إذا كان {email} مسجّلاً فسيصله رابط لتعيين كلمة مرور جديدة صالح لمدة ساعة. افتح الرابط على هذا الجهاز.'**
  String linkSentBody(String email);

  /// No description provided for @pasteLinkLabel.
  ///
  /// In ar, this message translates to:
  /// **'أو الصق الرابط من البريد هنا'**
  String get pasteLinkLabel;

  /// No description provided for @continueAction.
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get continueAction;

  /// No description provided for @invalidResetLink.
  ///
  /// In ar, this message translates to:
  /// **'الرابط غير صالح. انسخ الرابط كاملاً من البريد.'**
  String get invalidResetLink;

  /// No description provided for @resendLink.
  ///
  /// In ar, this message translates to:
  /// **'إعادة إرسال الرابط'**
  String get resendLink;

  /// No description provided for @mustChangeTitle.
  ///
  /// In ar, this message translates to:
  /// **'عيّن كلمة مرور جديدة'**
  String get mustChangeTitle;

  /// No description provided for @mustChangeBody.
  ///
  /// In ar, this message translates to:
  /// **'أُنشئ حسابك أو أُعيد تعيينه بكلمة مرور مؤقتة. اختر كلمة مرور خاصة بك للمتابعة.'**
  String get mustChangeBody;

  /// No description provided for @category.
  ///
  /// In ar, this message translates to:
  /// **'التصنيف'**
  String get category;

  /// No description provided for @lectureCategories.
  ///
  /// In ar, this message translates to:
  /// **'تصنيفات المحاضرات'**
  String get lectureCategories;

  /// No description provided for @doctorTitle.
  ///
  /// In ar, this message translates to:
  /// **'اللقب (مثل د.)'**
  String get doctorTitle;

  /// No description provided for @number.
  ///
  /// In ar, this message translates to:
  /// **'الرقم'**
  String get number;

  /// No description provided for @librariesSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'الجهات المزوّدة للمحتوى ونطاق كل منها'**
  String get librariesSubtitle;

  /// No description provided for @newLibrary.
  ///
  /// In ar, this message translates to:
  /// **'مكتبة جديدة'**
  String get newLibrary;

  /// No description provided for @editLibrary.
  ///
  /// In ar, this message translates to:
  /// **'تعديل المكتبة'**
  String get editLibrary;

  /// No description provided for @libraryLabel.
  ///
  /// In ar, this message translates to:
  /// **'المكتبة'**
  String get libraryLabel;

  /// No description provided for @libraryRequired.
  ///
  /// In ar, this message translates to:
  /// **'اختر المكتبة'**
  String get libraryRequired;

  /// No description provided for @contactEmail.
  ///
  /// In ar, this message translates to:
  /// **'بريد التواصل'**
  String get contactEmail;

  /// No description provided for @contactPhone.
  ///
  /// In ar, this message translates to:
  /// **'هاتف التواصل'**
  String get contactPhone;

  /// No description provided for @staffCount.
  ///
  /// In ar, this message translates to:
  /// **'{count} حساب'**
  String staffCount(int count);

  /// No description provided for @emptyLibraries.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مكتبات بعد'**
  String get emptyLibraries;

  /// No description provided for @librarySaved.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ المكتبة'**
  String get librarySaved;

  /// No description provided for @resetDevice.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء ربط الجهاز'**
  String get resetDevice;

  /// No description provided for @resetDeviceConfirm.
  ///
  /// In ar, this message translates to:
  /// **'سيُلغى ربط جهاز {name} وتنتهي جلساته، ويُربط أول جهاز يسجّل الدخول منه بعد ذلك.'**
  String resetDeviceConfirm(String name);

  /// No description provided for @deviceResetDone.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء ربط الجهاز'**
  String get deviceResetDone;

  /// No description provided for @setPassword.
  ///
  /// In ar, this message translates to:
  /// **'تعيين كلمة مرور جديدة'**
  String get setPassword;

  /// No description provided for @setPasswordHint.
  ///
  /// In ar, this message translates to:
  /// **'تنتهي جلسات المستخدم ويُطلب منه تغييرها عند الدخول'**
  String get setPasswordHint;

  /// No description provided for @passwordSet.
  ///
  /// In ar, this message translates to:
  /// **'تم تعيين كلمة المرور'**
  String get passwordSet;

  /// No description provided for @statusCancelled.
  ///
  /// In ar, this message translates to:
  /// **'ملغى'**
  String get statusCancelled;

  /// No description provided for @logCancelled.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الطلب'**
  String get logCancelled;

  /// No description provided for @notifyFollowers.
  ///
  /// In ar, this message translates to:
  /// **'إشعار المتابعين عند النشر'**
  String get notifyFollowers;

  /// No description provided for @notifyFollowersHint.
  ///
  /// In ar, this message translates to:
  /// **'يصل إشعار لمتابعي المقرر عند نشر محتوى جديد فيه'**
  String get notifyFollowersHint;

  /// No description provided for @auditAccount.
  ///
  /// In ar, this message translates to:
  /// **'الحسابات'**
  String get auditAccount;

  /// No description provided for @auditAuth.
  ///
  /// In ar, this message translates to:
  /// **'الدخول'**
  String get auditAuth;

  /// No description provided for @auditCatalog.
  ///
  /// In ar, this message translates to:
  /// **'الهيكل الأكاديمي'**
  String get auditCatalog;

  /// No description provided for @auditLibrary.
  ///
  /// In ar, this message translates to:
  /// **'المكتبات'**
  String get auditLibrary;

  /// No description provided for @auditSecurity.
  ///
  /// In ar, this message translates to:
  /// **'الأمان'**
  String get auditSecurity;

  /// No description provided for @noFileYet.
  ///
  /// In ar, this message translates to:
  /// **'لم يُرفع ملف بعد'**
  String get noFileYet;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
