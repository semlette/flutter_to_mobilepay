import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class TestMerchants {
  static final String denmark = "APPDK0000000000";
  static final String finland = "APPFI0000000000";
  static final String norway = "APPNO0000000000";
}

enum Country {
  denmark,
  finland,
  norway,
}

class MobilePay {
  static bool _initialized = false;
  static const MethodChannel _channel =
      const MethodChannel("flutter_to_mobilepay");
  static const EventChannel _eventChannel =
      const EventChannel("flutter_to_mobilepay/payments");

  // _orderIDs is a list of order id's submitted to `createPayment()`. This is
  // used to catch duplicate order id's. This is only initialized and used in
  // debug mode.
  static List<String> _orderIDs;

  static Stream<Transaction> _paymentStream;

  static Future initialize({
    @required String merchantID,
    @required Country country,
    // urlScheme is required on iOS
    // TODO: Better explanation
    String urlScheme,
  }) {
    if (!_initialized) {
      _initialized = true;
      if (_isInDebugMode) {
        _orderIDs = [];
      }
      _paymentStream =
          _eventChannel.receiveBroadcastStream().map<Transaction>((data) {
        assert(data is Map);

        final transaction = Transaction._internal(
          data["transaction_id"],
          double.parse(data["withdrawn_from_card"]),
          data["signature"],
          data["order_id"],
        );
        return transaction;
      });
    }

    assert(merchantID != null);
    assert(country != null);
    // TODO: Send arguments
    return _channel.invokeMethod("initializeMobilePay");
  }

  static Future<bool> isInstalled(
      {
      /**
       * country checks if the MobilePay app for the given country is installed.
       * country is ignored on Android.
       * 
       * MobilePay on iOS has a different app for each country it is available in.
       * If this is non-null it will only check for a specific variant.
       */
      Country country}) async {
    _throwIfUninitialized();
    try {
      Future<bool> future;
      if (Platform.isIOS) {
        future = _channel.invokeMethod("isInstalled");
      } else {
        // TODO: Check for specific country variant
        future = _channel.invokeMethod("isInstalled");
      }
      final installed = await future;
      assert(installed is bool);
      return installed;
    } on PlatformException catch (e) {
      FlutterError.reportError(FlutterErrorDetails(exception: e));
      return false;
    }
  }

  static Future<Transaction> createPayment(Payment payment) async {
    _throwIfUninitialized();
    if (_isInDebugMode) {
      if (_orderIDs.contains(payment.orderID)) {
        throw Exception(
            "You have created multiple payments using the same order ID. Flutter to MobilePay requires each order ID to be unique");
      }
      _orderIDs.add(payment.orderID);
    }
    final args = payment._toMap();
    await _channel.invokeMethod("createPayment", args);
    // TODO: Explore implementing custom "firstWhere" method. Might help
    // with the 'unique order ID' situation
    final transaction = await _paymentStream.firstWhere((transaction) {
      return transaction.orderID == payment.orderID;
    });

    return transaction;
  }

  static void _throwIfUninitialized() {
    if (!_initialized) {
      throw MobilePayUninitializedException();
    }
  }
}

class Payment {
  final double price;
  final String orderID;

  Payment({
    @required this.price,
    @required this.orderID,
  });

  Map<String, dynamic> _toMap() {
    return {
      "price": price.toString(),
      "order_id": orderID,
    };
  }
}

class Transaction {
  final String id;
  final double withdrawnFromCard;
  final String signature;
  final String orderID;

  Transaction._internal(
      this.id, this.withdrawnFromCard, this.signature, this.orderID);
}

bool get _isInDebugMode {
  bool inDebugMode = false;
  assert(inDebugMode = true);
  return inDebugMode;
}

class MobilePayUninitializedException implements Exception {
  final String reason =
      "Flutter to MobilePay has not been initialized. You must call `MobilePay.initialize()` before using any `MobilePay` methods";
}
