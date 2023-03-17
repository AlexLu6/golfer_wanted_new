import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

final String maleGolfer = 'https://images.unsplash.com/photo-1494249120761-ea1225b46c05?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=713&q=80';
final String femaleGolfer = 'https://images.unsplash.com/photo-1622819219010-7721328f050b?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=415&q=80';
final String drawerPhoto = 'https://images.unsplash.com/photo-1622482594949-a2ea0c800edd?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=774&q=80';
final String coursePhoto = 'https://cdn.pixabay.com/photo/2016/11/14/19/20/golf-course-1824369_960_720.jpg';
final double initHandicap = 14.2;

enum gender { Male, Female }
SharedPreferences? prefs;
int golferID = 0;
String userName = '', userPhone = '', expiredDate = '', theLocale ='';
gender userSex = gender.Male;
double userHandicap = initHandicap;
var golferDoc;
bool isExpired = false;

class NameID {
  const NameID(this.name, this.id);
  final String name;
  final int id;
  @override
  String toString() => name;
  int toID() => id;
}

int uuidTime() {
  return DateTime.now().millisecondsSinceEpoch - 1647000000000;
}

var myActivities = [];
void storeMyActivities() {
  prefs!.setString('golfActivities', jsonEncode(myActivities));
}

void loadMyActivities() {
  myActivities = jsonDecode(prefs!.getString('golfActivities') ?? '[]');
}

var myScores = [];
void storeMyScores() {
  while (myScores.length > 30) myScores.removeLast();
  prefs!.setString('golfScores', jsonEncode(myScores));
}

void loadMyScores() {
  myScores = jsonDecode(prefs!.getString('golfScores') ?? '[]');
}

Future<String>? golferName(int uid) {
  var res;
  return FirebaseFirestore.instance.collection('Golfers').where('uid', isEqualTo: uid).get().then((value) {
    value.docs.forEach((result) {
      var items = result.data();
      res = items['name'];
    });
    return res;
  });
}

Future<String>? golferNames(List uids) async {
  String res = '';
  return await FirebaseFirestore.instance.collection('Golfers').where('uid', whereIn: uids).get().then((value) {
    value.docs.forEach((result) {
      var items = result.data();
      res = (res == '') ? items['name'] : res + ', ' + items['name'];
    });
    return res;
  });
}

void removeGolferActivity(var actDoc, int uid) {
  var glist = actDoc.get('golfers');
  
  var subGroups = actDoc.get('subgroups');
  for (int i = 0; i < subGroups.length; i++) {
    for (int j = 0; j < (subGroups[i] as Map).length; j++) {
      if ((subGroups[i] as Map)[j.toString()] == uid) {
        for (; j<(subGroups[i] as Map).length - 1; j++)
          (subGroups[i] as Map)[j.toString()] = (subGroups[i] as Map)[(j+1).toString()];
        (subGroups[i] as Map).remove(j.toString());
      }                                   
    }
  }
  glist.removeWhere((item) => item['uid'] == uid);
  FirebaseFirestore.instance.collection('GolferActivities').doc(actDoc.id).update({
    'golfers': glist,
    'subgroups': subGroups
  });
}

void removeMemberAllActivities(int gid, int uid) {
  FirebaseFirestore.instance.collection('GolferActivities').where('gid', isEqualTo: gid).get().then((value) {
    value.docs.forEach((doc) {
      removeGolferActivity(doc, uid);
    });
  });
}