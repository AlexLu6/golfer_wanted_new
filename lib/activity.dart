import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_material_pickers/flutter_material_pickers.dart';
import 'package:editable/editable.dart';
import 'package:emojis/emoji.dart';
import 'package:charcode/charcode.dart';
import 'dataModel.dart';
import 'locale/language.dart';
import 'editable2.dart';

String netPhoto = 'https://wallpaper.dog/large/5514437.jpg';
bool alreadyApply = false;
Widget activityList() {
  Timestamp deadline = Timestamp.fromDate(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));
  return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('GolferActivities').orderBy('teeOff').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        } else {
          return ListView(
              children: snapshot.data!.docs.map((doc) {
            if ((doc.data()! as Map)["teeOff"] == null) {
              return const LinearProgressIndicator();
            } else if (myActivities.contains(doc.id)) {
              return const SizedBox.shrink();
            } else if ((doc.data()! as Map)["uid"] == golferID) {
              if (!myActivities.contains(doc.id))
                myActivities.add(doc.id);
              return const SizedBox.shrink();
            } else if ((doc.data()! as Map)["locale"] != theLocale) {
              return const SizedBox.shrink();
            } else if ((doc.data()! as Map)["teeOff"].compareTo(deadline) < 0) {
              //delete the activity
              FirebaseFirestore.instance.collection('GolferActivities').doc(doc.id).delete();
              return const SizedBox.shrink();
            } else {
              FirebaseFirestore.instance.collection('ApplyAct').where('uid', isEqualTo: golferID).where('aid', isEqualTo: doc.id)
                  .get().then((value) {
                value.docs.forEach((result) {
                  if (result['response'] == 'OK') {
                    myActivities.add(doc.id);
                    storeMyActivities();
                    FirebaseFirestore.instance.collection('ApplyAct').doc(result.id).delete();
                  } else
                    alreadyApply = true;
                });
              });
              ((doc.data()! as Map)['golfers'] as List).forEach((element) {
                if (element['uid'] == golferID && !myActivities.contains(doc.id)) {
                  myActivities.add(doc.id);
                  storeMyActivities();
                }
              });
              return Card(
                  child: ListTile(
                      title: Text((doc.data()! as Map)['course']),
                      subtitle: Text(Language.of(context).teeOff +
                          ((doc.data()! as Map)['teeOff']).toDate().toString().substring(0, 16) + '\n' +
                          Language.of(context).max + (doc.data()! as Map)['max'].toString() + ' ' +
                          Language.of(context).now + ((doc.data()! as Map)['golfers'] as List).length.toString() + " " +
                          Language.of(context).fee + (doc.data()! as Map)['fee'].toString()),
                      leading: Image.network(coursePhoto),
                      trailing: const Icon(Icons.keyboard_arrow_right),
                      onTap: () async {
                        int uid = (doc.data()! as Map)['uid'] as int;
                        Navigator.push(context,ShowActivityPage(doc, golferID, await golferName(uid)!, golferID == uid)).then((value) async {
                          if (value == 1) {
                            if ((doc.data()! as Map)['approve'] == 1) {
                              // send application to owner
                              FirebaseFirestore.instance.collection('ApplyAct').add({
                                'uid': golferID,
                                'aid': doc.id,
                                'response': 'waiting'
                              }).whenComplete(() => showDialog<bool>(
                                      context: context,
                                      builder: (context) {
                                        alreadyApply = true;
                                        return AlertDialog(
                                          title: Text(Language.of(context).hint),
                                          content: Text(Language.of(context).applicationSent),
                                          actions: <Widget>[
                                            TextButton(
                                                child: Text("OK"),
                                                onPressed: () => Navigator.of(context).pop(true)),
                                          ],
                                        );
                                      }));
                            } else {
                              // add my id to golfer list
                              var glist = doc.get('golfers');
                              glist.add({
                                "uid": golferID,
                                "name": userName + ((userSex == gender.Female) ? Language.of(context).femaleNote : ''),
                                "scores": []
                              });
                              FirebaseFirestore.instance.collection('GolferActivities').doc(doc.id).update({'golfers': glist});
                              myActivities.add(doc.id);
                              storeMyActivities();
                            }
                          } else if (value == -1) {
                            if (!(doc.data()! as Map)["uid"] == golferID) {
                              myActivities.remove(doc.id);
                              storeMyActivities();
                            }
                            removeGolferActivity(doc, golferID);
                          }
                        });
                      }));
            }
          }).toList());
        }
      });
}

Widget myActivityBody() {
  Timestamp deadline = Timestamp.fromDate(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));
  return myActivities.isEmpty ? ListView() :
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('GolferActivities').orderBy('teeOff').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const CircularProgressIndicator();
            } else {
              return ListView(children: snapshot.data!.docs.map((doc) {
                if ((doc.data()! as Map)["teeOff"] == null) {
                  return const LinearProgressIndicator();
                } else if (!myActivities.contains(doc.id)) {
                  return const SizedBox.shrink();
                } else if ((doc.data()! as Map)["teeOff"].compareTo(deadline) < 0) {
                  //delete the activity
                  FirebaseFirestore.instance.collection('GolferActivities').doc(doc.id).delete();
                  myActivities.remove(doc.id);
                  storeMyActivities();
                  return const SizedBox.shrink();
                } else {
                  return Card(
                      child: ListTile(
                          title: Text((doc.data()! as Map)['course']),
                          subtitle: Text(Language.of(context).teeOff +
                              ((doc.data()! as Map)['teeOff']).toDate().toString().substring(0, 16) + '\n' +
                              Language.of(context).max + (doc.data()! as Map)['max'].toString() + ' ' +
                              Language.of(context).now + ((doc.data()! as Map)['golfers'] as List).length .toString() + " " +
                              Language.of(context).fee + (doc.data()! as Map)['fee'].toString()),
                          leading: Image.network(coursePhoto),
                          trailing: Icon(Icons.keyboard_arrow_right),
                          onTap: () async {
                            Navigator.push(context, ShowActivityPage(doc,golferID,
                                        await golferName((doc.data()!as Map)['uid'] as int)!,
                                        (doc.data()! as Map)['uid'] as int == golferID)).then((value) async {
                              if (value == -1) {
                                if ((doc.data()! as Map)["uid"] != golferID) {
                                  myActivities.remove(doc.id);
                                  storeMyActivities();
                                }
                                removeGolferActivity(doc, golferID);
                              } else if (value == 1) {
                                // add my id to golfer list
                                var glist = doc.get('golfers');
                                glist.add({
                                  "uid": golferID,
                                  "name": userName + ((userSex == gender.Female) ? Language.of(context).femaleNote : ''),
                                  "scores": []
                                });
                                FirebaseFirestore.instance.collection('GolferActivities').doc(doc.id).update({'golfers': glist});
                              }
                            });
                          }));
                }
              }).toList());
            }
          });
}

void doAddActivity(BuildContext context) {
  Navigator.push(context, NewActivityPage(golferID));
}

class ShowActivityPage extends MaterialPageRoute<int> {
  ShowActivityPage(var activity, int uId, String title, bool editable)
      : super(builder: (BuildContext context) {
          bool alreadyIn = false, scoreReady = false, scoreDone = false, isBackup = false;
          String uName = '';
          int uIdx = 0;

          List buildRows() {
            var rows = [];
            var oneRow = {};
            int idx = 0;

            for (var e in activity.data()!['golfers']) {
              if (idx % 4 == 0) {
                oneRow = Map();
                if (idx >= (activity.data()!['max'] as int))
                  oneRow['row'] = Language.of(context).waiting;
                else
                  oneRow['row'] = (idx >> 2) + 1;
                oneRow['c1'] = e['name'];
                oneRow['c2'] = '';
                oneRow['c3'] = '';
                oneRow['c4'] = '';
              } else if (idx % 4 == 1)
                oneRow['c2'] = e['name'];
              else if (idx % 4 == 2)
                oneRow['c3'] = e['name'];
              else if (idx % 4 == 3) {
                oneRow['c4'] = e['name'];
                rows.add(oneRow);
              }
              idx++;
              if (idx == (activity.data()!['max'] as int)) {
                if (idx % 4 != 0) rows.add(oneRow);
                while (idx % 4 != 0) idx++;
              }
            }
            if ((idx % 4) != 0)
              rows.add(oneRow);
            else if (idx == 0) {
              oneRow['row'] = '1';
              oneRow['c1'] = oneRow['c2'] = oneRow['c3'] = oneRow['c4'] = '';
              rows.add(oneRow);
            }
            return rows;
          }

          List buildScoreRows() {
            var scoreRows = [];
            int idx = 1;
            for (var e in activity.data()!['golfers']) {
              if ((e['scores'] as List).isNotEmpty) {
                List scores = e['scores'] as List;
                String net = e['net'].toString();
                scoreRows.add({
                  'rank': idx,
                  'total': e['total'],
                  'name': e['name'],
                  'net': net.substring(0, min(net.length, 5)),
                  'EG': scores[0],
                  'BD': scores[1],
                  'PAR': scores[2],
                  'BG': scores[3],
                  'DB': scores[4]
                });
                idx++;
              }
            }
            scoreRows.sort((a, b) => a['total'] - b['total']);
            for (idx = 0; idx < scoreRows.length; idx++)
              scoreRows[idx]['rank'] = idx + 1;
            return scoreRows;
          }

          bool teeOffPass = activity.data()!['teeOff'].compareTo(Timestamp.now()) < 0;
          bool teeOffPass2 = activity.data()!['teeOff'].compareTo(Timestamp(Timestamp.now().seconds - 2 * 60 * 60, 0)) < 0;
          void updateScore() {
            var glist = activity.data()!['golfers'];
            glist[uIdx]['scores'] = myScores[0]['scores'];
            glist[uIdx]['total'] = myScores[0]['total'];
            glist[uIdx]['net'] = myScores[0]['total'] - userHandicap;
            FirebaseFirestore.instance
                .collection('GolferActivities')
                .doc(activity.id)
                .update({'golfers': glist}).whenComplete(() => Navigator.of(context).pop(0));
          }

          // prepare parameters
          int eidx = 0;
          for (var e in activity.data()!['golfers']) {
            if (e['uid'] as int == uId) {
              uIdx = eidx;
              alreadyIn = true;
              isBackup = eidx >= (activity.data()!['max'] as int);
              uName = e['name'];
              if (!myActivities.contains(activity.id)) {
                myActivities.add(activity.id);
                storeMyActivities();
              }
            }
            if ((e['scores'] as List).isNotEmpty) {
              scoreReady = true;
              if (e['uid'] as int == uId) scoreDone = true;
            }
            eidx++;
          }
          final _textFieldController = TextEditingController();
          String _remarks = activity.data()!['remarks'];
          Future<String?> chatInputDialog(BuildContext context) async {
            return showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: Text(Language.of(context).leaveMessage),
                    content: TextField(
                      controller: _textFieldController,
                      decoration: InputDecoration(hintText: Language.of(context).yourMessage),
                    ),
                    actions: <Widget>[
                      ElevatedButton(
                        child: const Text("Cancel"),
                        onPressed: () => Navigator.pop(context),
                      ),
                      ElevatedButton(
                        child: const Text('OK'),
                        onPressed: () =>
                            Navigator.pop(context, _textFieldController.text),
                      ),
                    ],
                  );
                });
          }

          Future<int?> grantApplyDialog(String name) {
            return showDialog<int>(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: Text(Language.of(context).reply),
                    content: Text(name + Language.of(context).applyGroup),
                    actions: <Widget>[
                      TextButton(
                          child: Text("OK"),
                          onPressed: () => Navigator.of(context).pop(1)),
                      TextButton(
                          child: Text("Reject"),
                          onPressed: () => Navigator.of(context).pop(-1)),
                      TextButton(
                          child: Text("Skip"),
                          onPressed: () => Navigator.of(context).pop(0))
                    ],
                  );
                });
          }

          bool addMember = false;
          void doAddMember() {
            FirebaseFirestore.instance.collection('ApplyAct').where('aid', isEqualTo: activity.id)
                .where('response', isEqualTo: 'waiting').get().then((value) {
              value.docs.forEach((result) async {
                // grant or refuse the apply of e['uid']
                var e = result.data();
                int uid = e['uid'] as int;
                String uname = await golferName(uid)!;
                int? ans = await grantApplyDialog(uname);
                if (ans! > 0) {
                  FirebaseFirestore.instance.collection('ApplyAct').doc(result.id).update({'response': 'OK'});
                  var glist = activity.get('golfers');
                  glist.add({"uid": uid, "name": uname, "scores": []});
                  FirebaseFirestore.instance.collection('GolferActivities').doc(activity.id).update({'golfers': glist});
                  addMember = true;
                } else if (ans < 0)
                  FirebaseFirestore.instance.collection('ApplyAct').doc(result.id).update({'response': 'No'});
              });
            });
          }

          return Scaffold(
              appBar: AppBar(
                  title: Text(Language.of(context).host + title),
                  elevation: 1.0),
              body: StatefulBuilder(
                  builder: (BuildContext context, StateSetter setState) {
                return Container(
                    decoration: BoxDecoration(image: DecorationImage(image: NetworkImage(netPhoto), fit: BoxFit.cover)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          const SizedBox(height: 10.0),
                          Text(Language.of(context).teeOff + activity.data()!['teeOff'].toDate().toString().substring(0, 16) + ' ' +
                               Language.of(context).fee + activity.data()!['fee'].toString(), style: TextStyle(fontSize: 20)),
                          const SizedBox(height: 10.0),
                          Text(Language.of(context).courseName + activity.data()!['course'] + " " +
                                Language.of(context).max + activity.data()!['max'].toString(), style: TextStyle(fontSize: 20)),
                          const SizedBox(height: 10.0),
                          Visibility(
                              visible: !scoreReady,
                              child: Flexible(child: Editable(
                                borderColor: Colors.black,
                                tdStyle: const TextStyle(fontSize: 14),
                                trHeight: 16,
                                tdAlignment: TextAlign.center,
                                thAlignment: TextAlign.center,
                                columnRatio: 0.2,
                                columns: [
                                  { "title": Language.of(context).tableGroup, 'index': 1, 'key': 'row', 'editable': false, 'widthFactor': 0.15},
                                  const {"title": "A", 'index': 2, 'key': 'c1', 'editable': false},
                                  const {"title": "B", 'index': 3, 'key': 'c2', 'editable': false},
                                  const {"title": "C", 'index': 4, 'key': 'c3', 'editable': false},
                                  const {"title": "D", 'index': 5, 'key': 'c4', 'editable': false}
                                ],
                                rows: buildRows(),
                              ))),
                          const SizedBox(height: 4.0),
                          Visibility(
                              visible: ((activity.data()!['golfers'] as List).length > 4) && alreadyIn && !isBackup && !scoreReady,
                              child: ElevatedButton(
                                  child: Text(Language.of(context).subGroup),
                                  onPressed: () {
                                    Navigator.push(context, SubGroupPage(activity, uId)).then((value) {
                                      if (value ?? false)
                                        Navigator.of(context).pop(0);
                                    });
                                  })),
                          const SizedBox(height: 4.0),
                          Visibility(
                              visible: scoreReady,
                              child: Flexible(child: Editable(
                                borderColor: Colors.black,
                                tdStyle: const TextStyle(fontSize: 14),
                                trHeight: 16,
                                tdAlignment: TextAlign.center,
                                thAlignment: TextAlign.center,
                                columnRatio: 0.1,
                                columns: [
                                  {'title': Language.of(context).rank, 'index': 1, 'key': 'rank', 'editable': false},
                                  {'title': Language.of(context).total, 'index': 2, 'key': 'total', 'editable': false, 'widthFactor': 0.13},
                                  {'title': Language.of(context).name, 'index': 3, 'key': 'name', 'editable': false, 'widthFactor': 0.2},
                                  {'title': Language.of(context).net, 'index': 4, 'key': 'net', 'editable': false, 'widthFactor': 0.15},
                                  {'title': Emoji.byName('dove')!.char, 'index': 5, 'key': 'BD', 'editable': false},
                                  {'title': Emoji.byName('person golfing')!.char, 'index': 6, 'key': 'PAR', 'editable': false},
                                  {'title': Emoji.byName('index pointing up')!.char, 'index': 7, 'key': 'BG', 'editable': false},
                                  {'title': Emoji.byName('victory hand')!.char, 'index': 8, 'key': 'DB', 'editable': false},
                                  {'title': Emoji.byName('eagle')!.char, 'index': 9, 'key': 'EG', 'editable': false},
                                ],
                                rows: buildScoreRows(),
                              ))),
                          Visibility(visible: teeOffPass2 && alreadyIn && !isBackup && !scoreDone,
                              child: Flexible(child: Editable2(
                                borderColor: Colors.black,
                                tdStyle: const TextStyle(fontSize: 14),
                                trHeight: 16,
                                tdAlignment: TextAlign.center,
                                thAlignment: TextAlign.center,
                                columnRatio: 0.12,
                                columns: [
                                  {'title': Language.of(context).total, 'index': 1, 'key': 'total', 'widthFactor': 0.15},
                                  {'title': Emoji.byName('eagle')!.char, 'index': 2, 'key': 'EG'},
                                  {'title': Emoji.byName('dove')!.char, 'index': 3, 'key': 'BD'},
                                  {'title': Emoji.byName('person golfing')!.char, 'index': 4, 'key': 'PAR'},
                                  {'title': Emoji.byName('index pointing up')!.char, 'index': 5, 'key': 'BG'},
                                  {'title': Emoji.byName('victory hand')!.char, 'index': 6, 'key': 'DB'},
                                  {'title': Emoji.byName('face exhaling')!.char, 'index': 7, 'key': 'MM'},
                                ],
                                rows: const [{'total': '', 'BD': '', 'PAR': '', 'BG': '', 'DB': '', 'EG': '', 'MM': ''}],
                                showSaveIcon: true,
                                saveIcon: Icons.save,
                                saveIconColor: Colors.blue,
                                onRowSaved: (row) {
                                  List<int> scores = [
                                    row['EG'] == '' ? 0 : int.parse(row['EG']),
                                    row['BD'] == '' ? 0 : int.parse(row['BD']),
                                    row['PAR'] == '' ? 0 : int.parse(row['PAR']),
                                    row['BG'] == '' ? 0 : int.parse(row['BG']),
                                    row['DB'] == '' ? 0 : int.parse(row['DB']),
                                    row['MM'] == '' ? 0 : int.parse(row['MM'])
                                  ];
                                  int _handicap = scores[3] - scores[1] + (scores[4] - scores[0]) * 2 + scores[5] * 3;
                                  if (row['total'] != '') {
                                    myScores.insert(0, {
                                      'date': DateTime.now().toString().substring(0, 11),
                                      'course': activity.data()!['course'],
                                      'scores': scores,
                                      'total': int.parse(row['total']),
                                      'handicap': _handicap > 0 ? _handicap : 0
                                    });
                                    storeMyScores();
                                    updateScore();
                                    scoreDone = true;
                                  }
                                },
                              ))),
                          Visibility(
                              visible: !teeOffPass2,
                              child: TextFormField(
                                key: Key(_remarks),
                                showCursor: true,
                                initialValue: _remarks,
                                style: TextStyle(color: Colors.black),
                                onTap: () async {
                                  var msg = await chatInputDialog(context);
                                  if (msg != null) {
                                    _remarks = activity.data()['remarks'] + '\n' + userName + ': ' + msg;
                                    FirebaseFirestore.instance.collection('GolferActivities').doc(activity.id).update({'remarks': _remarks})
                                    .then((value) => setState(() {}));
                                    // refresh this TextFormField
                                  }
                                },
                                maxLines: 5,
                                readOnly: true,
                                decoration: InputDecoration(labelText: Language.of(context).actRemarks,border: OutlineInputBorder()),)),
                          Visibility(
                              visible: !teeOffPass && alreadyIn && !alreadyApply,
                              child: ElevatedButton(
                                  child: Text(Language.of(context).cancel),
                                  onPressed: () =>
                                      Navigator.of(context).pop(-1))),
                          Visibility(
                              visible: !teeOffPass && !alreadyIn && !alreadyApply,
                              child: ElevatedButton(
                                  child: Text(Language.of(context).apply),
                                  onPressed: () =>
                                      Navigator.of(context).pop(1))),
                          const SizedBox(height: 4.0)
                        ]));
              }),
              floatingActionButton: Visibility(
                  visible: editable,
                  child: FloatingActionButton(
                    onPressed: () {
                      doAddMember();
                      // modify activity info
                      Navigator.push(context, _EditActivityPage(activity, activity.data()!['course'])).then((value) {
                        if (value ?? false)
                          Navigator.of(context).pop(0);
                        else if (addMember) Navigator.of(context).pop(0);
                      });
                    },
                    child: const Icon(Icons.edit),
                  )),
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.endTop);
        });
}

class NewActivityPage extends MaterialPageRoute<bool> {
  NewActivityPage(int uid)
      : super(builder: (BuildContext context) {
          String _courseName = '', _remarks = '';
          var _selectedCourse;
          DateTime _selectedDate = DateTime.now();
          bool _includeMe = true, _approveNeeded = false;
          int _fee = 2500, _max = 4;
          var activity =
              FirebaseFirestore.instance.collection('GolferActivities');

          return Scaffold(
              appBar: AppBar(
                  title: Text(Language.of(context).createNewActivity),
                  elevation: 1.0),
              body: StatefulBuilder(
                  builder: (BuildContext context, StateSetter setState) {
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const SizedBox(height: 12.0),
                      Flexible(
                          child: TextFormField(
                        initialValue: _courseName,
//                      key: Key(_courseName),
                        showCursor: true,
                        onChanged: (String value) =>
                            setState(() => _courseName = value),
                        //keyboardType: TextInputType.name,
                        decoration: InputDecoration(
                            labelText: Language.of(context).courseName,
                            icon: const Icon(Icons.golf_course),
                            border: const UnderlineInputBorder()),
                      )),
                      const SizedBox(height: 12),
                      Flexible(
                          child: Row(children: <Widget>[
                        ElevatedButton(
                            child: Text(Language.of(context).teeOff),
                            onPressed: () {
                              showMaterialDatePicker(
                                context: context,
                                title: Language.of(context).pickDate,
                                selectedDate: DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate:
                                    DateTime.now().add(Duration(days: 180)),
                                //onChanged: (value) => setState(() => _selectedDate = value),
                              ).then((date) {
                                if (date != null)
                                  showMaterialTimePicker(context: context,  title: Language.of(context).pickTime, selectedTime: TimeOfDay.now())
                                    .then((time) => setState(() => _selectedDate = DateTime(date.year, date.month, date.day, time!.hour, time.minute)));
                              });
                            }),
                        const SizedBox(width: 5),
                        Flexible(child: TextFormField(
                          initialValue: _selectedDate.toString().substring(0, 16),
                          key: Key(_selectedDate.toString().substring(0, 16)),
                          showCursor: true,
                          onChanged: (String? value) => _selectedDate = DateTime.parse(value!),
                          keyboardType: TextInputType.datetime,
                          decoration: InputDecoration(labelText: Language.of(context).teeOffTime, border: OutlineInputBorder()),
                        )),
                        const SizedBox(width: 5)
                      ])),
                      const SizedBox(height: 12),
                      Flexible(child: Row(children: <Widget>[
                        const SizedBox(width: 5),
                        Flexible(child: TextFormField(
                          initialValue: _max.toString(),
                          showCursor: true,
                          onChanged: (String value) => setState(() => _max = int.parse(value)),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText: Language.of(context).max,
                              icon: Icon(Icons.group),
                              border: OutlineInputBorder()),
                        )),
                        const SizedBox(width: 5),
                        Flexible(child: TextFormField(
                          initialValue: _fee.toString(),
                          showCursor: true,
                          onChanged: (String value) => setState(() => _fee = int.parse(value)),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText: Language.of(context).fee,
                              icon: Icon(Icons.money),
                              border: OutlineInputBorder()),
                        )),
                        const SizedBox(width: 5)
                      ])),
                      const SizedBox(height: 12.0),
                      TextFormField(
                        showCursor: true,
                        initialValue: _remarks,
                        onChanged: (String value) => setState(() => _remarks = value),
                        maxLines: 3,
                        scrollPadding: EdgeInsets.only(bottom: 40),
                        decoration: InputDecoration(
                            labelText: Language.of(context).actRemarks,
                            icon: Icon(Icons.edit_note),
                            border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      Flexible(child: Row(children: <Widget>[
                        const SizedBox(width: 5),
                        Checkbox(
                            value: _includeMe,
                            onChanged: (bool? value) => setState(() => _includeMe = value!)),
                        const SizedBox(width: 5),
                        Text(Language.of(context).includeMyself),
                        const SizedBox(width: 8),
                        Checkbox(
                            value: _approveNeeded,
                            onChanged: (bool? value) => setState(() => _approveNeeded = value!)),
                        const SizedBox(width: 5),
                        Text(Language.of(context).approveNeeded)
                      ])),
                      const SizedBox(height: 12.0),
                      ElevatedButton(
                          child: Text(Language.of(context).create,
                          style: const TextStyle(fontSize: 20)),
                          onPressed: () async {
                            if (_courseName != '') {
                              activity.add({
                                'uid': uid,
                                'locale': theLocale,
                                "course": _courseName,
                                "teeOff": Timestamp.fromDate(_selectedDate),
                                "max": _max,
                                "fee": _fee,
                                "remarks": _remarks,
                                'subgroups': [],
                                'approve': _approveNeeded ? 1 : 0,
                                "golfers": _includeMe ? [
                                        {
                                          "uid": uid,
                                          "name": userName + ((userSex == gender.Female) ? Language.of(context).femaleNote : ''), "scores": []
                                        }] : []
                              }).then((value) {
                                if (_includeMe) {
                                  myActivities.add(value.id);
                                  storeMyActivities();
                                }
                                Navigator.of(context).pop(true);
                              });
                            }
                          })
                    ]);
              }));
        });
}

class _EditActivityPage extends MaterialPageRoute<bool> {
  _EditActivityPage(var actDoc, String _courseName)
      : super(builder: (BuildContext context) {
          String _remarks = (actDoc.data()! as Map)['remarks'];
          int _fee = (actDoc.data()! as Map)['fee'],
              _max = (actDoc.data()! as Map)['max'];
          DateTime _selectedDate = (actDoc.data()! as Map)['teeOff'].toDate();
          bool _approveNeeded =
              (actDoc.data()! as Map)['approve'] == 1 ? true : false;
          List<NameID> golfers = [];
          var _selectedGolfer;
          var blist = [];

          ((actDoc.data()! as Map)['golfers'] as List).forEach((element) {
            blist.add(element['uid']);
          });
          if (blist.length > 0)
            FirebaseFirestore.instance.collection('Golfers').get().then((value) {
              value.docs.forEach((result) {
                var items = result.data();
                if (blist.contains(items['uid'] as int))
                  golfers.add(NameID(items['name'] + '(' + items['phone'] + ')', items['uid'] as int));
              });
            });

          return Scaffold(
              appBar: AppBar(
                  title: Text(Language.of(context).editActivity),
                  elevation: 1.0),
              body: StatefulBuilder(
                  builder: (BuildContext context, StateSetter setState) {
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      const SizedBox(height: 12),
                      Text(_courseName, style: TextStyle(fontSize: 20)),
                      const SizedBox(height: 12),
                      Flexible(
                          child: Row(children: <Widget>[
                        ElevatedButton(
                            child: Text(Language.of(context).teeOff),
                            onPressed: () {
                              showMaterialDatePicker(
                                context: context,
                                title: Language.of(context).pickDate,
                                selectedDate: DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(Duration(days: 180)),
                              ).then((date) {
                                if (date != null)
                                  showMaterialTimePicker(
                                    context: context,
                                    title: Language.of(context).pickTime,
                                    selectedTime: TimeOfDay.now()).then((time) => setState(() => 
                                        _selectedDate = DateTime(date.year, date.month, date.day, time!.hour, time.minute)));
                              });
                            }),
                        const SizedBox(width: 5),
                        Flexible(child: TextFormField(
                          initialValue: _selectedDate.toString().substring(0, 16),
                          key: Key(_selectedDate.toString().substring(0, 16)),
                          showCursor: true,
                          onChanged: (String? value) => _selectedDate = DateTime.parse(value!),
                          keyboardType: TextInputType.datetime,
                          decoration: InputDecoration(labelText: Language.of(context).teeOffTime, border: OutlineInputBorder()),
                        )),
                        const SizedBox(width: 5)
                      ])),
                      const SizedBox(height: 12),
                      Flexible(child: Row(children: <Widget>[
                        const SizedBox(width: 5),
                        Flexible(child: TextFormField(
                          initialValue: _max.toString(),
                          showCursor: true,
                          onChanged: (String value) => _max = int.parse(value),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: Language.of(context).max, icon: Icon(Icons.group), border: OutlineInputBorder()),
                        )),
                        const SizedBox(width: 5),
                        Flexible(child: TextFormField(
                          initialValue: _fee.toString(),
                          showCursor: true,
                          onChanged: (String value) => _fee = int.parse(value),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: Language.of(context).fee, icon: Icon(Icons.money), border: OutlineInputBorder()),
                        )),
                        const SizedBox(width: 5)
                      ])),
                      const SizedBox(height: 12),
                      TextFormField(
                        showCursor: true,
                        initialValue: _remarks,
                        onChanged: (String value) => _remarks = value,
                        maxLines: 3,
                        scrollPadding: EdgeInsets.only(bottom: 40),
                        decoration: InputDecoration(labelText: Language.of(context).actRemarks, icon: Icon(Icons.edit_note), border: OutlineInputBorder()),
                      ),
                      Flexible(child: Row(children: <Widget>[
                        const SizedBox(width: 5),
                        Checkbox(
                            value: _approveNeeded,
                            onChanged: (bool? value) => setState(() => _approveNeeded = value!)
                        ),
                        const SizedBox(width: 5),
                        Text(Language.of(context).approveNeeded)
                      ])),
                      const SizedBox(height: 12),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: <Widget>[
                            ElevatedButton(
                                child: Text(Language.of(context).modify,
                                    style: TextStyle(fontSize: 18)),
                                onPressed: () async {
                                  FirebaseFirestore.instance.collection('GolferActivities').doc(actDoc.id)
                                    .update({
                                      "teeOff": Timestamp.fromDate(_selectedDate),
                                      "max": _max,
                                      "fee": _fee,
                                      "remarks": _remarks,
                                      "approve": _approveNeeded ? 1 : 0,
                                    }).then((value) {
                                      Navigator.of(context).pop(true);
                                    });
                                }),
                            Visibility(
                                visible: blist.length > 0,
                                child: ElevatedButton(
                                    child: Text(Language.of(context).kickMember, style: TextStyle(fontSize: 18)),
                                    onPressed: () {
                                      showMaterialScrollPicker<NameID>(
                                        context: context,
                                        title: Language.of(context).selectKickMember,
                                        items: golfers,
                                        showDivider: false,
                                        selectedItem: golfers[0],
                                        onChanged: (value) => setState(() => _selectedGolfer = value),
                                      ).then((value) {
                                        if (_selectedGolfer != null)
                                          removeGolferActivity(actDoc, _selectedGolfer.toID());
                                        Navigator.of(context).pop(true);
                                      });
                                    }))
                          ])
                    ]);
              }));
        });
}

class SubGroupPage extends MaterialPageRoute<bool> {
  SubGroupPage(var activity, int uId)
      : super(builder: (BuildContext context) {
          var subGroups = activity.data()!['subgroups'] as List;
          int max = (activity.data()!['max'] + 3) >> 2;
          List<List<int>> subIntGroups = [];

          void storeAndLeave() {
            var newGroups = [];
            for (int i = 0; i < subIntGroups.length; i++) {
              Map subMap = Map();
              for (int j = 0; j < subIntGroups[i].length; j++)
                subMap[j.toString()] = subIntGroups[i][j];
              newGroups.add(subMap);
            }
            subGroups = newGroups;
            FirebaseFirestore.instance.collection('GolferActivities').doc(activity.id)
                .update({'subgroups': newGroups})
                .whenComplete(() => Navigator.of(context).pop(true));
          }

          int alreadyIn = -1;
          for (int i = 0; i < subGroups.length; i++) {
            subIntGroups.add([]);
            for (int j = 0; j < (subGroups[i] as Map).length; j++) {
              subIntGroups[i].add((subGroups[i] as Map)[j.toString()]);
              if (subIntGroups[i][j] == uId) alreadyIn = i;
            }
          }
          if (subIntGroups.isEmpty ||
              (subIntGroups[subIntGroups.length - 1].isNotEmpty &&
                  subIntGroups.length < max &&
                  alreadyIn < 0)) subIntGroups.add([]);

          return Scaffold(
              appBar: AppBar(
                  title: Text(Language.of(context).subGroup), elevation: 1.0),
              body: ListView.builder(
                  itemCount: subIntGroups.length,
                  padding: const EdgeInsets.all(10.0),
                  itemBuilder: (BuildContext context, int i) {
                    bool isfull = subIntGroups[i].length == 4;
                    return ListTile(
                      leading: CircleAvatar(child: Text(String.fromCharCodes([$A + i]))),
                      title: subIntGroups[i].length == 0 ? Text(Language.of(context).name) : FutureBuilder(
                              future: golferNames(subIntGroups[i]),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData)
                                  return const LinearProgressIndicator();
                                else
                                  return Text(snapshot.data!.toString(), style: TextStyle(fontWeight: FontWeight.bold));
                              }),
                      trailing: (alreadyIn == i) ? Icon(Icons.person_remove_rounded, color: Colors.red,)
                            : (!isfull && alreadyIn < 0) ? Icon(Icons.add_box_outlined, color: Colors.blue,)
                            : Icon(Icons.stop, color: Colors.grey),
                      onTap: () {
                        if (alreadyIn == i) {
                          subIntGroups[i].remove(uId);
                          if (subIntGroups[i].length == 0)
                            subIntGroups.removeAt(i);
                          storeAndLeave();
                        } else if (!isfull && alreadyIn < 0) {
                          subIntGroups[i].add(uId);
                          storeAndLeave();
                        }
                      },
                    );
                  }));
        });
}
