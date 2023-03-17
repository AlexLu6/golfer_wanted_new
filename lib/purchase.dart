import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inapp_purchase/flutter_inapp_purchase.dart';
import 'package:flutter/foundation.dart'
  show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'dataModel.dart';

late StreamSubscription _purchaseUpdatedSubscription;
late StreamSubscription _purchaseErrorSubscription;
late StreamSubscription _conectionSubscription;
String? platformVersion = 'Unknown';
bool isConnected = false;
// Platform messages are asynchronous, so we initialize in an async method.
Future<void> initPlatformState() async {
//  String? platformVersion;
  // Platform messages may fail, so we use a try/catch PlatformException.
/*  try {
    platformVersion = await FlutterInappPurchase.instance.platformVersion;
  } on PlatformException {
    platformVersion = 'Failed to get platform version.';
  }
  print('platformVersion: $platformVersion');*/
  // prepare
  var result = await FlutterInappPurchase.instance.initialize();
  print('result: $result');

  // refresh items for android
  try {
    String msg = await FlutterInappPurchase.instance.consumeAll();
    print('consumeAllItems: $msg');
  } catch (err) {
    print('consumeAllItems error: $err');
  }

  _conectionSubscription =
      FlutterInappPurchase.connectionUpdated.listen((connected) {
        isConnected = connected.connected!;
        print('connected: $connected');
  });

  _purchaseUpdatedSubscription =
      FlutterInappPurchase.purchaseUpdated.listen((productItem) {
        int idx = productItem!.productId == 'golfer_consume_1_month' ? 0 :
                  productItem.productId == 'golfer_consume_1_season' ? 1 :
                  productItem.productId == 'golfer_consume_1_year' ? 2 : 3;
        if (idx == 3)
          idx = productItem.productId == 'golfer_1_month_fee' ? 0 :
                productItem.productId == 'golfer_1_season_fee' ? 1 : 2;
 
          DateTime expireDate = DateTime.now().add(Duration(days: idx == 0 ? 30 : idx == 1 ? 91 : 365));
          Timestamp expire = Timestamp.fromDate(expireDate);
          if (isExpired) {
            validateReceipt(productItem);
            FirebaseFirestore.instance.collection('Golfers').doc(golferDoc).update({
                "expired": expire
            });
            isExpired = false;
            expiredDate = expireDate.toString();
            prefs!.setString('expired', expiredDate);     
            FlutterInappPurchase.instance.finishTransaction(productItem, isConsumable: true);
          }
  });

  _purchaseErrorSubscription =
      FlutterInappPurchase.purchaseError.listen((purchaseError) {
    print('purchase-error: $purchaseError');
  });
}

Future<void> closePlatformState() async {
  _purchaseUpdatedSubscription.cancel();
  _purchaseErrorSubscription.cancel();
  _conectionSubscription.cancel();
  await FlutterInappPurchase.instance.finalize();
}

void validateReceipt(PurchasedItem purchased) async {
  var receiptBody = {
    'receipt-data': purchased.transactionReceipt!,
    'password': 'MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQgezW3JgrQgyWVwfrUFs9pNylWNsQSrT+3h/+BLrCoitOgCgYIKoZIzj0DAQehRANCAAQiTdJ9Nk3TFJi5EE37IbPF1QfdIma+uXfQK0M8hs3XdbPNmPwjM/x2yAFWComxE6LudI9nLIJ7XQGb/Pfk9csr'
  };
  bool isTest = true;
  var result;
  String accessToken ='MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA8XqtSItuF5oOW5cJcbEcdwqEOlF3RAE5g0W3CkTRKT4doGwAeg0Cpk9zWGuFfF837LmJ1aVf02oYO1CuTKRPvUzVxKTXgDNbl/V3Pi85jfo4PMtEU/B/KBtfHae9RMHSroaGZiieXEPjeldd2S8nIBQeuWa+Ml8J4f6spzgunQd94H39cxU3AUJUBnc6OE0+orRLerwzBzW2ngTmztD/uo/Gr3BBKvqcmMy/ueVdBUj40vtKG5sA8iXwbv15ax9B07JXjSjjtm60Z5ASMGhh1AsyrvsI7oXV/UbqwEib/2D7Df5dJKFO6walxZnA/H0mYeZPmpi6VakJnVuZhxWuqwIDAQAB';
  if (defaultTargetPlatform == TargetPlatform.android)
    result = await FlutterInappPurchase.instance.validateReceiptAndroid(
      packageName: 'com.niahome.golferclub', 
      productId: purchased.productId!, 
      productToken: purchased.purchaseToken!, 
      accessToken: accessToken).then((value) => 
        result = FlutterInappPurchase.instance.consumePurchaseAndroid(purchased.purchaseToken!));
  else 
    result = await FlutterInappPurchase.instance.validateReceiptIos(receiptBody: receiptBody, isTest: isTest);
  print(result);
}

Widget purchaseBody() {

  final List<String> _productLists = defaultTargetPlatform == TargetPlatform.android ||  kIsWeb // FlutterInappPurchase.Platform.isAndroid
      ? [
          'golfer_1_month_fee',
          'golfer_1_season_fee',
          'golfer_1_year_fee'
        ]
       : [
          'golfer_consume_1_month', 
          'golfer_consume_1_season'
          'golfer_consume_1_year'
        ];

  List<IAPItem> _items = [];
  //List<PurchasedItem> _purchases = [];
  return FutureBuilder(
    future: FlutterInappPurchase.instance.getProducts(_productLists),
    builder: (context, snapshot) {
      if (!snapshot.hasData)
        return const CircularProgressIndicator();
      else {
        _items = snapshot.data! as List<IAPItem>;
        return ListView.builder(
          itemCount: _items.length,
          itemBuilder: (BuildContext context2, int i) {
            return Card(child: ListTile(
              title: Text('${_items[i].title!.substring(0, 11)} :   ${_items[i].price} ${_items[i].currency}'),
              subtitle: Text('${_items[i].productId}'),
              trailing: Icon(Icons.payment),
              onTap: () async {
                if (isExpired)
                  await FlutterInappPurchase.instance.requestPurchase(_items[i].productId!);
              },
            ));
          }
        );
        
      }
    });
}
