import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:emojis/emoji.dart';
import 'package:flutter/foundation.dart'
  show defaultTargetPlatform, kIsWeb;
import 'dart:math';
import 'locale/language.dart';
import 'locale/app_localizations_delegate.dart';
import 'firebase_options.dart';
import 'dataModel.dart';
import 'activity.dart';
import 'purchase.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await setupFlutterNotifications();
}
/// Create a [AndroidNotificationChannel] for heads up notifications
late AndroidNotificationChannel channel;

bool isFlutterLocalNotificationsInitialized = false;

Future<void> setupFlutterNotifications() async {
  if (isFlutterLocalNotificationsInitialized) {
    return;
  }
  channel = const AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    description:
        'This channel is used for important notifications.', // description
    importance: Importance.high,
  );

  flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  /// Create an Android Notification Channel.
  ///
  /// We use this channel in the `AndroidManifest.xml` file to override the
  /// default FCM channel to enable heads up notifications.
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  /// Update the iOS foreground notification presentation options to allow
  /// heads up notifications.
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );
  isFlutterLocalNotificationsInitialized = true;
}

/// Initialize the [FlutterLocalNotificationsPlugin] package.
late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  prefs = await SharedPreferences.getInstance();
  if (!kIsWeb) {
    await setupFlutterNotifications();
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: [
        const AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      supportedLocales: [
        const Locale('en'),
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ],
      onGenerateTitle: (context) => Language.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      title: 'Golfer Wanted',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {

  MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _currentPageIndex = 0;
  bool isRegistered = false, isUpdate = false;

  void _openPage(int index) {
    setState(() {
      _currentPageIndex = index;
    });
  }
  @override
  void initState() {
    // initPlatformState();
    golferID = prefs!.getInt('golferID') ?? 0;
    userHandicap = prefs!.getDouble('handicap') ?? initHandicap;
    expiredDate = prefs!.getString('expired')?? '';
    loadMyActivities();
    loadMyScores();
    FirebaseFirestore.instance.collection('Golfers').where('uid', isEqualTo: golferID).get().then((value) {
      value.docs.forEach((result) {
        golferDoc = result.id;
        var items = result.data();
        userName = items['name'];
        userPhone = items['phone'];
        theLocale = items['locale'];
        userSex = items['sex'] == 1 ? gender.Male : gender.Female;
        if (expiredDate == '') {
          expiredDate = items['expired'].toDate().toString();
          prefs!.setString('expired', expiredDate);
        }
        // isExpired = items['expired'].compareTo(Timestamp.now()) < 0;
        setState(() => isRegistered = true);
        _currentPageIndex = isExpired ? 5 : myActivities.isNotEmpty ? 2 : 1;
      });
    });
    super.initState();
  }
  @override
  void dispose() async{
    super.dispose();
    closePlatformState();
  }
  @override
  Widget build(BuildContext context) {
    List<String> appTitle = [
      Language.of(context).golferInfo,
      Language.of(context).activities, //"Activity List",
      Language.of(context).myActivity, // "My Activities",
      Language.of(context).myScores, //"My Scores",
      Language.of(context).usage,  // "Program Usage"
      Language.of(context).purchase
    ];

/*     if (expiredDate.length > 0)
      isExpired = Timestamp.fromDate(DateTime.parse(expiredDate.substring(0, 16))).compareTo(Timestamp.now()) < 0;
 */
    return Scaffold(
      appBar: AppBar(
        title: Text(appTitle[_currentPageIndex]),
      ),
      body: Center(
        child: _currentPageIndex == 0 ? registerBody()
              : _currentPageIndex == 1 ? activityList()
              : _currentPageIndex == 2 ? myActivityBody()
              : _currentPageIndex == 3  ? myScoreBody()  
              : _currentPageIndex == 4  ? usageBody() : purchaseBody()
      ),
      drawer: isRegistered ? golfDrawer() : null,

      floatingActionButton: (_currentPageIndex == 1)
          ? FloatingActionButton(
              onPressed: () => doAddActivity(context),
              child: Icon(Icons.add),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Drawer golfDrawer() {
    return Drawer(
      child: ListView(
        children: <Widget>[
          UserAccountsDrawerHeader(
            accountName: Text(userName),
            accountEmail: Text(userPhone),
            currentAccountPicture: GestureDetector(
                onTap: () {
                  setState(() => isUpdate = true);
                  _currentPageIndex = isExpired ? 5 : 0;
                  Navigator.of(context).pop();
                },
                child: CircleAvatar(backgroundImage: NetworkImage(userSex == gender.Male ? maleGolfer : femaleGolfer))),
            decoration: BoxDecoration(image: DecorationImage(fit: BoxFit.fill, image: NetworkImage(drawerPhoto))),
            onDetailsPressed: () {
              setState(() => isUpdate = true);
              _currentPageIndex = isExpired ? 5 : 0;
              Navigator.of(context).pop();
            },
          ),
          ListTile(
              title: Text(Language.of(context).activities),
              leading: Icon(Icons.sports_golf),
              onTap: () {
                setState(() => _currentPageIndex = isExpired ? 5 : 1);
                Navigator.of(context).pop();
              }),
          ListTile(
              title: Text(Language.of(context).myActivity),
              leading: Icon(Icons.sports_score),
              onTap: () {
                setState(() => _currentPageIndex = isExpired ? 5 : 2);
                Navigator.of(context).pop();
              }),
          ListTile(
              title: Text(Language.of(context).myScores),
              leading: Icon(Icons.format_list_numbered),
              onTap: () {
                setState(() => _currentPageIndex = 3);
                Navigator.of(context).pop();
              }),
          ListTile(
              title: Text(Language.of(context).logOut),
              leading: Icon(Icons.exit_to_app),
              onTap: () {
                setState(() {
                  isRegistered = isUpdate = false;
                  userName = '';
                  userPhone = '';
                  golferID = 0;
                  userHandicap= initHandicap;
                  myActivities.clear();
                  myScores.clear();
                  _currentPageIndex = isExpired ? 5 : 0;
                });
                Navigator.of(context).pop();
              }),
          ListTile(
              title: Text(Language.of(context).usage),
              leading: Icon(Icons.help),
              onTap: () {
                setState(() => _currentPageIndex = 4);
                Navigator.of(context).pop();
              })
        ],
      ),
    );
  }

  Widget usageBody() {
    return FutureBuilder(
      future: FirebaseStorage.instance.ref().child(Language.of(context).helpImage).getDownloadURL(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const CircularProgressIndicator();
        else
          return Column(children: [Expanded(flex: 2, child: InteractiveViewer(
            //panEnabled: false,
            minScale: 0.8,
            maxScale: 2.5,
            child: Image.network(snapshot.data!.toString())
          ))]);
      }
    );
  }

  ListView registerBody() {
    final logo = Hero(
      tag: 'golfer',
      child: CircleAvatar(backgroundImage: NetworkImage(userSex == gender.Male ? maleGolfer : femaleGolfer), radius: 130),
    );

    Locale myLocale = Localizations.localeOf(context);
    final golferName = TextFormField(
      initialValue: userName,
//      key: Key(userName),
      showCursor: true,
      onChanged: (String value) => setState(() => userName = value.trim()),
      keyboardType: TextInputType.name,
      style: const TextStyle(fontSize: 24),
      decoration: InputDecoration(labelText: Language.of(context).name, hintText: Language.of(context).realName, icon: Icon(Icons.person), border: UnderlineInputBorder()),
    );

    final golferPhone = TextFormField(
      initialValue: userPhone,
//      key: Key(_phone),
      onChanged: (String value) => setState(() => userPhone = value.trim()),
      keyboardType: TextInputType.phone,
      style: const TextStyle(fontSize: 24),
      decoration: InputDecoration(labelText: Language.of(context).mobile, icon: Icon(Icons.phone), border: UnderlineInputBorder()),
    );
    final golferSex = Row(children: <Widget>[
      Flexible(
          child: RadioListTile<gender>(
              title: Text(Language.of(context).male),
              value: gender.Male,
              groupValue: userSex,
              onChanged: (gender? value) => setState(() => userSex = value!))),
      Flexible(
          child: RadioListTile<gender>(
              title: Text(Language.of(context).female),
              value: gender.Female,
              groupValue: userSex,
              onChanged: (gender? value) => setState(() => userSex = value!))),
    ], mainAxisAlignment: MainAxisAlignment.center);
    final loginButton = Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0),
      child: ElevatedButton(
            child: Text(
              isUpdate ? Language.of(context).modify : Language.of(context).register,
              style: TextStyle(color: Colors.white, fontSize: 20.0),
            ),
            onPressed: () {
              int uID = 0;
              if (userName != '' && userPhone != '') {
                FirebaseFirestore.instance.collection('Golfers').where('name', isEqualTo: userName).where('phone', isEqualTo: userPhone)
                  .get().then((value) {
                  value.docs.forEach((result) {
                    var items = result.data();
                    golferDoc = result.id;
                    uID = items['uid'];
                    theLocale = items['locale'];
                    expiredDate = items['expired'].toDate().toString();
                    userSex = items['sex'] == 1 ? gender.Male : gender.Female;
                    prefs!.setString('expired', expiredDate);
                    golferID = uID;
                    print(userName + '(' + userPhone + ') already registered! ($golferID)');
                    myActivities.clear();
                    storeMyActivities();
                    myScores.clear();
                    storeMyScores();
                    // isExpired = items['expired'].compareTo(Timestamp.now()) < 0;
                  });
                }).whenComplete(() {
                    if (uID == 0) {
                      if (isUpdate) {
                        FirebaseFirestore.instance.collection('Golfers').doc(golferDoc).update({
                          "name": userName,
                          "phone": userPhone,
                          "sex": userSex == gender.Male ? 1 : 2,
                        });
                        isUpdate = false;
                      } else {
                        golferID = uuidTime();
                        DateTime expireDate = DateTime.now().add(Duration(days: 90));
                        Timestamp expire = Timestamp.fromDate(expireDate);
                        theLocale = myLocale.toString();
                        FirebaseFirestore.instance.collection('Golfers').add({
                          "name": userName,
                          "phone": userPhone,
                          "sex": userSex == gender.Male ? 1 : 2,
                          "uid": golferID,
                          "expired": expire,
                          "locale": theLocale
                        }).whenComplete(() {
                          expiredDate = expire.toDate().toString();
                          prefs!.setString('expired', expiredDate);
                        });
                      }
                    }
                    _currentPageIndex = isExpired ? 5 : 1;
                    setState(() => isRegistered = true);
                    prefs!.setInt('golferID', golferID);
                  });
                }
            }
        )
    );
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(left: 24.0, right: 24.0),
      children: <Widget>[
        const SizedBox(height: 8.0),
        logo,
        const SizedBox(height: 12.0),
        golferName,
        const SizedBox(height: 8.0),
        golferPhone,
        const SizedBox(height: 8.0),
        golferSex,
        const SizedBox(height: 8.0),
        Visibility(
          visible:isRegistered,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: <Widget>[
            Text(Language.of(context).handicap + ": " + userHandicap.toString().substring(0, min(userHandicap.toString().length, 5)), style: TextStyle(fontWeight: FontWeight.bold)),
            // Text('Expired: ' + expiredDate.substring(0, min(10, expiredDate.length)))
          ])
        ),
        const SizedBox(height: 10.0),
        loginButton,
        const SizedBox(height: 10.0)
      ],
    );
  }

  ListView myScoreBody() {
    int cnt = myScores.length > 10 ? 10 : myScores.length;
    userHandicap = 0;
    List parRows = [
      Emoji.byName('eagle')!.char, 
      Emoji.byName('dove')!.char, 
      Emoji.byName('person golfing')!.char, 
      Emoji.byName('index pointing up')!.char,
      Emoji.byName('victory hand')!.char,
      Emoji.byName('face exhaling')!.char
    ];
    return ListView.builder(
      itemCount: myScores.length,
      padding: const EdgeInsets.all(16.0),
      itemBuilder: (BuildContext context, int i) {
        if (i < cnt) userHandicap += myScores[i]['handicap'];
        if ((i + 1) == cnt) {
          userHandicap = (userHandicap / cnt) * 0.9;
          prefs!.setDouble('handicap', userHandicap);
        }
        return ListTile(
          leading: CircleAvatar(child: Text(myScores[i]['total'].toString(), style: const TextStyle(fontWeight: FontWeight.bold))), 
          title: Text(myScores[i]['date'] + ' ' + myScores[i]['course'], style: const TextStyle(fontWeight: FontWeight.bold)), 
          subtitle: Text(parRows.toString() + '\n' + myScores[i]['scores'].toString())
        );
      },
    );
  }
}
