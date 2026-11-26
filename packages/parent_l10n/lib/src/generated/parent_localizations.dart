import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'parent_localizations_en.dart';
import 'parent_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of ParentLocalizations
/// returned by `ParentLocalizations.of(context)`.
///
/// Applications need to include `ParentLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/parent_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: ParentLocalizations.localizationsDelegates,
///   supportedLocales: ParentLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the ParentLocalizations.supportedLocales
/// property.
abstract class ParentLocalizations {
  ParentLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static ParentLocalizations of(BuildContext context) {
    return Localizations.of<ParentLocalizations>(context, ParentLocalizations)!;
  }

  static const LocalizationsDelegate<ParentLocalizations> delegate =
      _ParentLocalizationsDelegate();

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
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @enterPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get enterPhoneNumber;

  /// No description provided for @mobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile Number'**
  String get mobileNumber;

  /// No description provided for @securityMessage.
  ///
  /// In en, this message translates to:
  /// **'Securing your personal information is our priority'**
  String get securityMessage;

  /// No description provided for @sendOtp.
  ///
  /// In en, this message translates to:
  /// **'Send OTP'**
  String get sendOtp;

  /// No description provided for @sendingOtp.
  ///
  /// In en, this message translates to:
  /// **'Sending OTP... Please wait...'**
  String get sendingOtp;

  /// No description provided for @otpVerify.
  ///
  /// In en, this message translates to:
  /// **'OTP Verify'**
  String get otpVerify;

  /// No description provided for @otpSentMessage.
  ///
  /// In en, this message translates to:
  /// **'Code has been sent to'**
  String get otpSentMessage;

  /// No description provided for @otp.
  ///
  /// In en, this message translates to:
  /// **'OTP'**
  String get otp;

  /// No description provided for @didNotGetOtp.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t get OTP Code'**
  String get didNotGetOtp;

  /// No description provided for @sec.
  ///
  /// In en, this message translates to:
  /// **'sec'**
  String get sec;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get resendCode;

  /// No description provided for @authenticating.
  ///
  /// In en, this message translates to:
  /// **'Authenticating... Please wait...'**
  String get authenticating;

  /// No description provided for @selectChild.
  ///
  /// In en, this message translates to:
  /// **'Select A Child'**
  String get selectChild;

  /// No description provided for @liveBusTracking.
  ///
  /// In en, this message translates to:
  /// **'Live Bus Tracking'**
  String get liveBusTracking;

  /// No description provided for @realTimeTrackingInfo.
  ///
  /// In en, this message translates to:
  /// **'Advanced real-time vehicle tracking system featuring high-precision accuracy and robust child safety protocols.'**
  String get realTimeTrackingInfo;

  /// No description provided for @trackBus.
  ///
  /// In en, this message translates to:
  /// **'Track Bus'**
  String get trackBus;

  /// No description provided for @safeHands.
  ///
  /// In en, this message translates to:
  /// **'Safe Hands'**
  String get safeHands;

  /// No description provided for @schoolConnect.
  ///
  /// In en, this message translates to:
  /// **'School Connect'**
  String get schoolConnect;

  /// No description provided for @homeWork.
  ///
  /// In en, this message translates to:
  /// **'Home Work'**
  String get homeWork;

  /// No description provided for @messMeals.
  ///
  /// In en, this message translates to:
  /// **'Mess & Meals'**
  String get messMeals;

  /// No description provided for @liveTracking.
  ///
  /// In en, this message translates to:
  /// **'Live Tracking'**
  String get liveTracking;

  /// No description provided for @routeNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Route is not started yet!'**
  String get routeNotStarted;

  /// No description provided for @generatePin.
  ///
  /// In en, this message translates to:
  /// **'Generate PIN'**
  String get generatePin;

  /// No description provided for @safeHandsPin.
  ///
  /// In en, this message translates to:
  /// **'Safe hands pin'**
  String get safeHandsPin;

  /// No description provided for @routeNo.
  ///
  /// In en, this message translates to:
  /// **'Route No'**
  String get routeNo;

  /// No description provided for @noDataFound.
  ///
  /// In en, this message translates to:
  /// **'No Data Found!'**
  String get noDataFound;

  /// No description provided for @addEscort.
  ///
  /// In en, this message translates to:
  /// **'Add Escort'**
  String get addEscort;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @relation.
  ///
  /// In en, this message translates to:
  /// **'Relation'**
  String get relation;

  /// No description provided for @mobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get mobile;

  /// No description provided for @uploadPhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload Photo'**
  String get uploadPhoto;

  /// No description provided for @addingEscort.
  ///
  /// In en, this message translates to:
  /// **'Adding Escort... Please wait...'**
  String get addingEscort;

  /// No description provided for @areYouSureYouWantToDelete.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete?'**
  String get areYouSureYouWantToDelete;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @thisPhoneNumberMayNotRegisteredWithUs.
  ///
  /// In en, this message translates to:
  /// **'This Phone Number may not registered with us.'**
  String get thisPhoneNumberMayNotRegisteredWithUs;

  /// No description provided for @pleaseWriteToSupport.
  ///
  /// In en, this message translates to:
  /// **'Please write to support@thoughtniques.com, \nMentioning\n1.⁠ ⁠School Name\n2.⁠ ⁠Student Name\n3.⁠ ⁠Admission Number\n4.⁠ ⁠Parent Contact Number\n\nOur team will contact you and resolve.'**
  String get pleaseWriteToSupport;

  /// No description provided for @sendEmail.
  ///
  /// In en, this message translates to:
  /// **'Send Email'**
  String get sendEmail;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @areYouSureYouWantToLogout.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get areYouSureYouWantToLogout;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @notificationsHistory.
  ///
  /// In en, this message translates to:
  /// **'Notifications History'**
  String get notificationsHistory;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'SUBMIT'**
  String get submit;

  /// No description provided for @requestForEntry.
  ///
  /// In en, this message translates to:
  /// **'Request For Entry'**
  String get requestForEntry;

  /// No description provided for @announcements.
  ///
  /// In en, this message translates to:
  /// **'Announcements'**
  String get announcements;

  /// No description provided for @didNotGetOtpCode.
  ///
  /// In en, this message translates to:
  /// **'Didn’t get OTP Code?'**
  String get didNotGetOtpCode;

  /// No description provided for @events.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get events;

  /// No description provided for @appointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get appointments;

  /// No description provided for @escort.
  ///
  /// In en, this message translates to:
  /// **'ESCORT'**
  String get escort;

  /// No description provided for @academics.
  ///
  /// In en, this message translates to:
  /// **'Academics'**
  String get academics;

  /// No description provided for @enterYourPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get enterYourPhoneNumber;

  /// No description provided for @securingYourPersonalInformationIsOurPriority.
  ///
  /// In en, this message translates to:
  /// **'Securing your personal information is our priority.'**
  String get securingYourPersonalInformationIsOurPriority;

  /// No description provided for @payments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get payments;

  /// No description provided for @mealMenu.
  ///
  /// In en, this message translates to:
  /// **'Meal Menu'**
  String get mealMenu;

  /// No description provided for @todaysMenu.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Menu'**
  String get todaysMenu;

  /// No description provided for @testPage.
  ///
  /// In en, this message translates to:
  /// **'Test Page'**
  String get testPage;

  /// No description provided for @instantMealPurchase.
  ///
  /// In en, this message translates to:
  /// **'Instant Meal Purchase'**
  String get instantMealPurchase;

  /// No description provided for @postComplaint.
  ///
  /// In en, this message translates to:
  /// **'Post Complaint'**
  String get postComplaint;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @selectComplaintType.
  ///
  /// In en, this message translates to:
  /// **'Select Complaint Type'**
  String get selectComplaintType;

  /// No description provided for @complaints.
  ///
  /// In en, this message translates to:
  /// **'Complaints'**
  String get complaints;

  /// No description provided for @responses.
  ///
  /// In en, this message translates to:
  /// **'Responses'**
  String get responses;

  /// No description provided for @pleaseEnterAMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a mobile number'**
  String get pleaseEnterAMobileNumber;

  /// No description provided for @enterAValidMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid mobile number'**
  String get enterAValidMobileNumber;

  /// No description provided for @loggingOut.
  ///
  /// In en, this message translates to:
  /// **'Logging out... Please wait...'**
  String get loggingOut;

  /// No description provided for @pleaseEnterOtp.
  ///
  /// In en, this message translates to:
  /// **'Please enter OTP'**
  String get pleaseEnterOtp;

  /// No description provided for @eta.
  ///
  /// In en, this message translates to:
  /// **'ETA'**
  String get eta;

  /// No description provided for @school.
  ///
  /// In en, this message translates to:
  /// **'School'**
  String get school;

  /// No description provided for @currentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current Location'**
  String get currentLocation;

  /// No description provided for @studentPoint.
  ///
  /// In en, this message translates to:
  /// **'Student Point'**
  String get studentPoint;

  /// No description provided for @yourPoint.
  ///
  /// In en, this message translates to:
  /// **'Your Point'**
  String get yourPoint;

  /// No description provided for @routeCompleted.
  ///
  /// In en, this message translates to:
  /// **'Route is Completed'**
  String get routeCompleted;

  /// No description provided for @pleaseUploadPhoto.
  ///
  /// In en, this message translates to:
  /// **'Please upload photo'**
  String get pleaseUploadPhoto;

  /// No description provided for @fromDate.
  ///
  /// In en, this message translates to:
  /// **'From Date'**
  String get fromDate;

  /// No description provided for @selectFromDate.
  ///
  /// In en, this message translates to:
  /// **'Select From Date'**
  String get selectFromDate;

  /// No description provided for @toDate.
  ///
  /// In en, this message translates to:
  /// **'To Date'**
  String get toDate;

  /// No description provided for @selectToDate.
  ///
  /// In en, this message translates to:
  /// **'Select To Date'**
  String get selectToDate;

  /// No description provided for @thisIsRequired.
  ///
  /// In en, this message translates to:
  /// **'This is required'**
  String get thisIsRequired;

  /// No description provided for @managementConnect.
  ///
  /// In en, this message translates to:
  /// **'Management Connect'**
  String get managementConnect;

  /// No description provided for @parentTeacherMeeting.
  ///
  /// In en, this message translates to:
  /// **'Parent Teacher Meeting'**
  String get parentTeacherMeeting;

  /// No description provided for @testAndExams.
  ///
  /// In en, this message translates to:
  /// **'Test & Exams'**
  String get testAndExams;

  /// No description provided for @observationsAndRecommendations.
  ///
  /// In en, this message translates to:
  /// **'Observations & Recommendes'**
  String get observationsAndRecommendations;

  /// No description provided for @breadButterMasalaDosa.
  ///
  /// In en, this message translates to:
  /// **'Bread Butter / Masala Dosa'**
  String get breadButterMasalaDosa;

  /// No description provided for @beverages.
  ///
  /// In en, this message translates to:
  /// **'Beverages: Milk / Watermelon Juice'**
  String get beverages;

  /// No description provided for @mealDetail.
  ///
  /// In en, this message translates to:
  /// **'Dal, Roti, Bottle Gourd Chickpeas curry, White Rice, Curd, Semiya Kheer with raisins'**
  String get mealDetail;

  /// No description provided for @vegSaladCutlet.
  ///
  /// In en, this message translates to:
  /// **'Veg salad and Veg cutlet'**
  String get vegSaladCutlet;

  /// No description provided for @breakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get breakfast;

  /// No description provided for @lunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get lunch;

  /// No description provided for @snack.
  ///
  /// In en, this message translates to:
  /// **'Snack'**
  String get snack;

  /// No description provided for @marksAndGrades.
  ///
  /// In en, this message translates to:
  /// **'Marks & Grades'**
  String get marksAndGrades;

  /// No description provided for @ptmDiscussions.
  ///
  /// In en, this message translates to:
  /// **'P T M Discussions'**
  String get ptmDiscussions;

  /// No description provided for @pleaseSelectComplaintType.
  ///
  /// In en, this message translates to:
  /// **'Please select complaint type'**
  String get pleaseSelectComplaintType;

  /// No description provided for @writeYourQuery.
  ///
  /// In en, this message translates to:
  /// **'Write your query'**
  String get writeYourQuery;

  /// No description provided for @pleaseWriteYourQuery.
  ///
  /// In en, this message translates to:
  /// **'Please write your query'**
  String get pleaseWriteYourQuery;

  /// No description provided for @submitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting... Please wait...'**
  String get submitting;

  /// No description provided for @deleting.
  ///
  /// In en, this message translates to:
  /// **'Deleting...'**
  String get deleting;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @students.
  ///
  /// In en, this message translates to:
  /// **'Students'**
  String get students;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @termsAndConditions.
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions'**
  String get termsAndConditions;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'App Version'**
  String get appVersion;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @notificationsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Notifications Disabled'**
  String get notificationsDisabled;

  /// No description provided for @notificationDisabledContent.
  ///
  /// In en, this message translates to:
  /// **'You have disabled notifications.\nTo stay up-to-date, please enable them in your device settings.'**
  String get notificationDisabledContent;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// No description provided for @route.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get route;

  /// No description provided for @callDriver.
  ///
  /// In en, this message translates to:
  /// **'Call Driver'**
  String get callDriver;

  /// No description provided for @switchChild.
  ///
  /// In en, this message translates to:
  /// **'SWITCH'**
  String get switchChild;

  /// No description provided for @myChildren.
  ///
  /// In en, this message translates to:
  /// **'My Children'**
  String get myChildren;

  /// No description provided for @noRouteDetails.
  ///
  /// In en, this message translates to:
  /// **'No route details available'**
  String get noRouteDetails;

  /// No description provided for @transportDetails.
  ///
  /// In en, this message translates to:
  /// **'Transport Details'**
  String get transportDetails;

  /// No description provided for @transportNotOpted.
  ///
  /// In en, this message translates to:
  /// **'Transport not opted'**
  String get transportNotOpted;

  /// No description provided for @mode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get mode;

  /// No description provided for @point.
  ///
  /// In en, this message translates to:
  /// **'Point'**
  String get point;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @children.
  ///
  /// In en, this message translates to:
  /// **'Children'**
  String get children;

  /// No description provided for @myVehicles.
  ///
  /// In en, this message translates to:
  /// **'My Vehicles'**
  String get myVehicles;

  /// No description provided for @generateGatePass.
  ///
  /// In en, this message translates to:
  /// **'Generate Gate Pass'**
  String get generateGatePass;

  /// No description provided for @gatePassType.
  ///
  /// In en, this message translates to:
  /// **'Gate Pass Type'**
  String get gatePassType;

  /// No description provided for @requestGatePass.
  ///
  /// In en, this message translates to:
  /// **'Request Gate Pass'**
  String get requestGatePass;

  /// No description provided for @gatePassRequestedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'GATE PASS REQUESTED\nSUCCESSFULLY'**
  String get gatePassRequestedSuccessfully;

  /// No description provided for @viewRequests.
  ///
  /// In en, this message translates to:
  /// **'View Requests'**
  String get viewRequests;

  /// No description provided for @gatePassRequests.
  ///
  /// In en, this message translates to:
  /// **'Gate Pass Requests'**
  String get gatePassRequests;

  /// No description provided for @gatePassDateInfo.
  ///
  /// In en, this message translates to:
  /// **'Gate pass will be generated for today\'s date: {date}'**
  String gatePassDateInfo(String date);

  /// No description provided for @dateRangeLimited.
  ///
  /// In en, this message translates to:
  /// **'Date range is limited to 10 days.'**
  String get dateRangeLimited;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @dateWithValue.
  ///
  /// In en, this message translates to:
  /// **'Date: {date}'**
  String dateWithValue(String date);

  /// No description provided for @selectDateRange.
  ///
  /// In en, this message translates to:
  /// **'Select date range'**
  String get selectDateRange;

  /// No description provided for @recenter.
  ///
  /// In en, this message translates to:
  /// **'Recenter'**
  String get recenter;

  /// No description provided for @transportAttendance.
  ///
  /// In en, this message translates to:
  /// **'Transport Attendance'**
  String get transportAttendance;

  /// No description provided for @addAVehicle.
  ///
  /// In en, this message translates to:
  /// **'Add a vehicle'**
  String get addAVehicle;

  /// No description provided for @vehicleNumber.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Number'**
  String get vehicleNumber;

  /// No description provided for @addVehicle.
  ///
  /// In en, this message translates to:
  /// **'Add Vehicle'**
  String get addVehicle;

  /// No description provided for @savedVehicles.
  ///
  /// In en, this message translates to:
  /// **'Saved Vehicles'**
  String get savedVehicles;

  /// No description provided for @noVehiclesYet.
  ///
  /// In en, this message translates to:
  /// **'No vehicles added yet.'**
  String get noVehiclesYet;

  /// No description provided for @addFirstVehicle.
  ///
  /// In en, this message translates to:
  /// **'Add your first vehicle using the form above.'**
  String get addFirstVehicle;

  /// No description provided for @vehicleRequired.
  ///
  /// In en, this message translates to:
  /// **'Vehicle number is required'**
  String get vehicleRequired;

  /// No description provided for @vehicleInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid vehicle number (e.g., AB12CD3456)'**
  String get vehicleInvalid;

  /// No description provided for @deleteVehicleTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete vehicle?'**
  String get deleteVehicleTitle;

  /// No description provided for @deleteVehicleMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{plate}\"?'**
  String deleteVehicleMessage(String plate);

  /// No description provided for @vehicleAdded.
  ///
  /// In en, this message translates to:
  /// **'Vehicle added successfully!'**
  String get vehicleAdded;

  /// No description provided for @vehicleDeleted.
  ///
  /// In en, this message translates to:
  /// **'Vehicle deleted successfully!'**
  String get vehicleDeleted;

  /// No description provided for @cannotLaunchDialer.
  ///
  /// In en, this message translates to:
  /// **'Cannot launch phone dialer'**
  String get cannotLaunchDialer;

  /// No description provided for @trackingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Live tracking is not available right now.'**
  String get trackingUnavailable;

  /// No description provided for @escortSaved.
  ///
  /// In en, this message translates to:
  /// **'Escort saved successfully!'**
  String get escortSaved;

  /// No description provided for @escortPermanent.
  ///
  /// In en, this message translates to:
  /// **'Permanent'**
  String get escortPermanent;

  /// No description provided for @escortTemporary.
  ///
  /// In en, this message translates to:
  /// **'Temporary'**
  String get escortTemporary;

  /// No description provided for @dateRangeFromTo.
  ///
  /// In en, this message translates to:
  /// **'{from} to {to}'**
  String dateRangeFromTo(String from, String to);

  /// No description provided for @generatePinFirst.
  ///
  /// In en, this message translates to:
  /// **'No PIN generated yet.'**
  String get generatePinFirst;

  /// No description provided for @complaintOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get complaintOpen;

  /// No description provided for @complaintInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get complaintInProgress;

  /// No description provided for @complaintResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get complaintResolved;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @querySubmitted.
  ///
  /// In en, this message translates to:
  /// **'Successfully submitted your query!'**
  String get querySubmitted;

  /// No description provided for @eventDateMissing.
  ///
  /// In en, this message translates to:
  /// **'Date Missing'**
  String get eventDateMissing;

  /// No description provided for @eventDaysToGo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day to go} other{{count} days to go}}'**
  String eventDaysToGo(int count);

  /// No description provided for @eventEnded.
  ///
  /// In en, this message translates to:
  /// **'Event Ended'**
  String get eventEnded;

  /// No description provided for @eventHappeningNow.
  ///
  /// In en, this message translates to:
  /// **'Happening Now'**
  String get eventHappeningNow;

  /// No description provided for @eventDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration:'**
  String get eventDuration;

  /// No description provided for @eventDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Day} other{{count} Days}}'**
  String eventDays(int count);

  /// No description provided for @eventPaymentsHistory.
  ///
  /// In en, this message translates to:
  /// **'Event Payments History'**
  String get eventPaymentsHistory;

  /// No description provided for @noPaymentRecords.
  ///
  /// In en, this message translates to:
  /// **'No Payment Records Found!'**
  String get noPaymentRecords;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @paymentDetails.
  ///
  /// In en, this message translates to:
  /// **'Payment Details'**
  String get paymentDetails;

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal:'**
  String get subtotal;

  /// No description provided for @convenienceFee.
  ///
  /// In en, this message translates to:
  /// **'Convenience Fee:'**
  String get convenienceFee;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total:'**
  String get total;

  /// No description provided for @bookingDetails.
  ///
  /// In en, this message translates to:
  /// **'Booking Details'**
  String get bookingDetails;

  /// No description provided for @attendDate.
  ///
  /// In en, this message translates to:
  /// **'Attend Date:'**
  String get attendDate;

  /// No description provided for @attendees.
  ///
  /// In en, this message translates to:
  /// **'Attendees:'**
  String get attendees;

  /// No description provided for @attendeesValue.
  ///
  /// In en, this message translates to:
  /// **'{booked} Booked / {attended} Attended'**
  String attendeesValue(String booked, String attended);

  /// No description provided for @totalPrice.
  ///
  /// In en, this message translates to:
  /// **'Total Price:'**
  String get totalPrice;

  /// No description provided for @information.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get information;

  /// No description provided for @questionsAndAnswers.
  ///
  /// In en, this message translates to:
  /// **'Q&A'**
  String get questionsAndAnswers;

  /// No description provided for @tryAgainMessage.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong... Please try again!'**
  String get tryAgainMessage;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @studentDetails.
  ///
  /// In en, this message translates to:
  /// **'Student Details'**
  String get studentDetails;

  /// No description provided for @admissionNumber.
  ///
  /// In en, this message translates to:
  /// **'Admission Number'**
  String get admissionNumber;

  /// No description provided for @classLabel.
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get classLabel;

  /// No description provided for @mess.
  ///
  /// In en, this message translates to:
  /// **'Mess'**
  String get mess;

  /// No description provided for @subscribedAnnual.
  ///
  /// In en, this message translates to:
  /// **'Subscribed (Annual)'**
  String get subscribedAnnual;

  /// No description provided for @nonSubscriber.
  ///
  /// In en, this message translates to:
  /// **'Non-Subscriber'**
  String get nonSubscriber;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @buyMealVouchers.
  ///
  /// In en, this message translates to:
  /// **'Buy Meal Vouchers'**
  String get buyMealVouchers;

  /// No description provided for @vouchersHistory.
  ///
  /// In en, this message translates to:
  /// **'Vouchers History'**
  String get vouchersHistory;

  /// No description provided for @purchaseRules.
  ///
  /// In en, this message translates to:
  /// **'Purchase Rules for Meal Vouchers'**
  String get purchaseRules;

  /// No description provided for @noRules.
  ///
  /// In en, this message translates to:
  /// **'No rules available at the moment.'**
  String get noRules;

  /// No description provided for @selectMealVouchers.
  ///
  /// In en, this message translates to:
  /// **'Select Meal Vouchers'**
  String get selectMealVouchers;

  /// No description provided for @onlyOneVoucherOfType.
  ///
  /// In en, this message translates to:
  /// **'Only one voucher of type {types} can be selected.'**
  String onlyOneVoucherOfType(String types);

  /// No description provided for @vouchersSelected.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 voucher selected} other{{count} vouchers selected}}'**
  String vouchersSelected(int count);

  /// No description provided for @totalWithAmount.
  ///
  /// In en, this message translates to:
  /// **'Total: {amount}'**
  String totalWithAmount(String amount);

  /// No description provided for @pricePerDay.
  ///
  /// In en, this message translates to:
  /// **'{price}/day'**
  String pricePerDay(String price);

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @selectVouchersToContinue.
  ///
  /// In en, this message translates to:
  /// **'Select vouchers to continue'**
  String get selectVouchersToContinue;

  /// No description provided for @selectVoucherDates.
  ///
  /// In en, this message translates to:
  /// **'Select {name} Dates'**
  String selectVoucherDates(String name);

  /// No description provided for @bookableRange.
  ///
  /// In en, this message translates to:
  /// **'Bookable: {range}'**
  String bookableRange(String range);

  /// No description provided for @purchaseTimings.
  ///
  /// In en, this message translates to:
  /// **'Purchase Timings'**
  String get purchaseTimings;

  /// No description provided for @todayClosedAt.
  ///
  /// In en, this message translates to:
  /// **'Today\'s voucher purchases closed at {time}.'**
  String todayClosedAt(String time);

  /// No description provided for @todayBuyUntil.
  ///
  /// In en, this message translates to:
  /// **'Today\'s voucher can be bought until {time}.'**
  String todayBuyUntil(String time);

  /// No description provided for @todayHadToBuy.
  ///
  /// In en, this message translates to:
  /// **'Today\'s voucher had to be purchased by {time} yesterday.'**
  String todayHadToBuy(String time);

  /// No description provided for @tomorrowClosedAt.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow\'s voucher purchases closed at {time} today.'**
  String tomorrowClosedAt(String time);

  /// No description provided for @tomorrowBuyUntil.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow\'s voucher can be bought until {time} today.'**
  String tomorrowBuyUntil(String time);

  /// No description provided for @quickSelectDays.
  ///
  /// In en, this message translates to:
  /// **'Quick select working days ({count} available)'**
  String quickSelectDays(int count);

  /// No description provided for @daysCount.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String daysCount(int count);

  /// No description provided for @allAvailable.
  ///
  /// In en, this message translates to:
  /// **'All available'**
  String get allAvailable;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @onlyWorkingDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Only 1 working day available.} other{Only {count} working days available.}}'**
  String onlyWorkingDays(int count);

  /// No description provided for @legendSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get legendSelected;

  /// No description provided for @legendHoliday.
  ///
  /// In en, this message translates to:
  /// **'Holiday'**
  String get legendHoliday;

  /// No description provided for @legendPurchased.
  ///
  /// In en, this message translates to:
  /// **'Purchased'**
  String get legendPurchased;

  /// No description provided for @legendWeekend.
  ///
  /// In en, this message translates to:
  /// **'Weekend'**
  String get legendWeekend;

  /// No description provided for @noBookableDates.
  ///
  /// In en, this message translates to:
  /// **'No bookable dates available'**
  String get noBookableDates;

  /// No description provided for @noBookableDatesMessage.
  ///
  /// In en, this message translates to:
  /// **'All dates in the range are either holidays, weekends, or already purchased.'**
  String get noBookableDatesMessage;

  /// No description provided for @daysSelected.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day selected} other{{count} days selected}}'**
  String daysSelected(int count);

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @orderSummary.
  ///
  /// In en, this message translates to:
  /// **'Order Summary'**
  String get orderSummary;

  /// No description provided for @subTotal.
  ///
  /// In en, this message translates to:
  /// **'Sub Total'**
  String get subTotal;

  /// No description provided for @totalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total Amount'**
  String get totalAmount;

  /// No description provided for @voucherDetailsHeading.
  ///
  /// In en, this message translates to:
  /// **'Vouchers Details'**
  String get voucherDetailsHeading;

  /// No description provided for @proceedToPay.
  ///
  /// In en, this message translates to:
  /// **'Proceed to Pay'**
  String get proceedToPay;

  /// No description provided for @completePayment.
  ///
  /// In en, this message translates to:
  /// **'Complete Your Payment'**
  String get completePayment;

  /// No description provided for @redirectingToGateway.
  ///
  /// In en, this message translates to:
  /// **'Redirecting to secure payment gateway...'**
  String get redirectingToGateway;

  /// No description provided for @dontCloseApp.
  ///
  /// In en, this message translates to:
  /// **'Please don\'t close the app or press back.'**
  String get dontCloseApp;

  /// No description provided for @paymentSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Payment Successful!'**
  String get paymentSuccessful;

  /// No description provided for @orderPlaced.
  ///
  /// In en, this message translates to:
  /// **'Order placed successfully.'**
  String get orderPlaced;

  /// No description provided for @orderIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Order ID: {id}'**
  String orderIdLabel(String id);

  /// No description provided for @copyOrderId.
  ///
  /// In en, this message translates to:
  /// **'Copy Order ID'**
  String get copyOrderId;

  /// No description provided for @orderIdCopied.
  ///
  /// In en, this message translates to:
  /// **'Order ID copied'**
  String get orderIdCopied;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @paymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment Failed'**
  String get paymentFailed;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get goBack;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @paymentCancelled.
  ///
  /// In en, this message translates to:
  /// **'The payment was cancelled. Please try again if you wish to proceed.'**
  String get paymentCancelled;

  /// No description provided for @paymentCouldNotBeProcessed.
  ///
  /// In en, this message translates to:
  /// **'Your payment could not be processed. (Reason: {reason})'**
  String paymentCouldNotBeProcessed(String reason);

  /// No description provided for @paymentUnknownError.
  ///
  /// In en, this message translates to:
  /// **'An unknown error occurred. Please try again.'**
  String get paymentUnknownError;

  /// No description provided for @paymentCouldNotStart.
  ///
  /// In en, this message translates to:
  /// **'Could not initiate the payment session.'**
  String get paymentCouldNotStart;

  /// No description provided for @voucherPurchaseHistory.
  ///
  /// In en, this message translates to:
  /// **'Voucher Purchase History'**
  String get voucherPurchaseHistory;

  /// No description provided for @paymentModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment Mode'**
  String get paymentModeLabel;

  /// No description provided for @purchasedVouchers.
  ///
  /// In en, this message translates to:
  /// **'Purchased Vouchers'**
  String get purchasedVouchers;

  /// No description provided for @detailsUpper.
  ///
  /// In en, this message translates to:
  /// **'DETAILS'**
  String get detailsUpper;

  /// No description provided for @noItemDetails.
  ///
  /// In en, this message translates to:
  /// **'No item details available.'**
  String get noItemDetails;

  /// No description provided for @daysAtPrice.
  ///
  /// In en, this message translates to:
  /// **'{days} days @ {price}'**
  String daysAtPrice(int days, String price);

  /// No description provided for @noHistoryFound.
  ///
  /// In en, this message translates to:
  /// **'No History Found'**
  String get noHistoryFound;

  /// No description provided for @historyWillAppear.
  ///
  /// In en, this message translates to:
  /// **'Your purchased meal vouchers will appear here.'**
  String get historyWillAppear;

  /// No description provided for @voucherDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Voucher Details'**
  String get voucherDetailsTitle;

  /// No description provided for @voucherUsed.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get voucherUsed;

  /// No description provided for @voucherExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get voucherExpired;

  /// No description provided for @voucherUnused.
  ///
  /// In en, this message translates to:
  /// **'Unused'**
  String get voucherUnused;

  /// No description provided for @effectiveDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Effective Date'**
  String get effectiveDateLabel;

  /// No description provided for @expiryDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Expiry Date'**
  String get expiryDateLabel;
}

class _ParentLocalizationsDelegate
    extends LocalizationsDelegate<ParentLocalizations> {
  const _ParentLocalizationsDelegate();

  @override
  Future<ParentLocalizations> load(Locale locale) {
    return SynchronousFuture<ParentLocalizations>(
      lookupParentLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_ParentLocalizationsDelegate old) => false;
}

ParentLocalizations lookupParentLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return ParentLocalizationsEn();
    case 'es':
      return ParentLocalizationsEs();
  }

  throw FlutterError(
    'ParentLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
