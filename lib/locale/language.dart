import 'package:flutter/material.dart';

abstract class Language {
  static Language of(BuildContext context) {
    return Localizations.of<Language>(context, Language)!;
  }

  String get appTitle;
  String get golferInfo;
  String get myActivity;
  String get subGroup;
  String get activities;
  String get golfCourses;
  String get myScores;
  String get groupActivity;
  String get logOut;
  String get purchase;

  String get name;
  String get realName;
  String get mobile;
  String get male;
  String get female;
  String get femaleNote;
  String get register;
  String get modify;
  String get handicap;

  String get region;
  String get manager;
  String get members;
  String get teeOff;
  String get fee;
  String get tableGroup;
  String get rank;
  String get apply;
  String get cancel;
  String get enterScore;
  String get waiting;
  String get create;
  String get max;
  String get now;
  String get store;
  String get total;
  String get net;

  String get createNewActivity;
  String get editActivity;
  String get createNewCourse;
  String get courseName;
  String get createNewGolfGroup;
  String get groupName;
  String get groupActRegion;
  String get groupRemarks;
  String get actRemarks;
  String get select2Courses;
  String get quitGroup;
  String get addManager;
  String get selectManager;
  String get quitManager;
  String get kickMember;
  String get selectKickMember;
  String get selectCourse;
  String get pickDate;
  String get pickTime;
  String get teeOffTime;
  String get applyFirst;
  String get applyWaiting;
  String get applyRejected;
  String get applyGroup;
  String get hint;
  String get reply;
  String get scoreNote;
  String get usage;
  String get helpImage;
  String get applicationSent;
  String get deleteGroup;
  String get includeMyself;
  String get approveNeeded;
  String get host;
  String get leaveMessage;
  String get yourMessage;
}
