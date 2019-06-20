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

  static Stream<Transaction> _paymentStream;

  static Future initialize({
    @required String merchantID,
    @required Country country,

    /// urlScheme is your app's URL scheme. This is defined in `Info.plist` in
    /// `CFBundleURLTypes[x].CFBundleURLSchemes[x]`. If in doubt, see the installation
    /// steps for iOS.
    /// urlScheme is required on iOS and is ignored on Android
    String urlScheme,
  }) {
    if (!_initialized) {
      _initialized = true;
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

      /// country checks if the MobilePay app for the given country is installed.
      /// country is ignored on Android.
      ///
      /// MobilePay on iOS has a different app for each country it is available in.
      /// If this is non-null it will only check for a specific variant.
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
    final args = payment._toMap();
    await _channel.invokeMethod("createPayment", args);

    // Wait for the payment to come through the payment stream
    Completer<Transaction> completer = Completer();
    StreamSubscription<Transaction> subscription;
    subscription = _paymentStream.listen((transaction) {
      if (transaction.orderID == payment.orderID) {
        if (!completer.isCompleted) {
          completer.complete(transaction);
        }
        subscription.cancel();
      }
    }, onError: (error) {
      if (!completer.isCompleted) {
        if (error is PlatformException) {
          switch (error.code) {
            case "CancelledPayment":
              // TODO: On iOS, check if the order ID matches (sent in error.details)
              completer.completeError(CancelledPaymentException());
              break;
            case "MobilePayErrorUnknown":
            case "MobilePayErrorInvalidParameters":
            case "MobilePayErrorMerchantValidationFailed":
            case "MobilePayErrorUpdateApp":
            case "MobilePayErrorMerchantNotValid":
            case "MobilePayErrorHMACNotValid":
            case "MobilePayErrorTimeout":
            case "MobilePayErrorLimitsExceeded":
            case "MobilePayErrorMerchantTimeout":
            case "MobilePayErrorInvalidSignature":
            case "MobilePayErrorSDKIsOutdated":
            case "MobilePayErrorOrderIDAlreadyUsed":
            case "MobilePayErrorPaymentRejectedFraud":
              completer.completeError(MobilePayError._fromPlatformException(error));
              break;
          }
        } else {
          completer.completeError(error);
        }
      }
    });

    // Return the Future<Transaction> and close the stream when it completes
    return completer.future;
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

/// MobilePayUninitializedException is thrown if you called a method on [MobilePay]
/// before [MobilePay.initialize]
class MobilePayUninitializedException implements Exception {
  final String message =
      "Flutter to MobilePay has not been initialized. You must call `MobilePay.initialize()` before using any `MobilePay` methods";

  @override
  String toString() {
    return message;
  }
}

/// CancelledPaymentException is thrown when the user cancels the payment
class CancelledPaymentException implements Exception {
  final String message = "The user cancelled the payment";

  @override
  String toString() {
    return message;
  }
}

/// MobilePayError is thrown when the MobilePay AppSwitch SDK throws an error.
/// The [code] matches the following error messages:
/// | code | message                                                                                          |
/// | ---- | ------------------------------------------------------------------------------------------------ |
/// | 1    | Invalid parameters sent to MobilePay app.                                                        |
/// | 2    | VerifyMerchant request failed - validation af merchant failed.                                   |
/// | 3    | MobilePay app is out of date and must be updated.                                                |
/// | 4    | Merchant is not valid.                                                                           |
/// | 5    | HMAC parameter is not valid.                                                                     |
/// | 6    | MobilePay timeout. The purchase took more than 5 minutes.                                        |
/// | 7    | MobilePay amount limits exceeded. Open MobilePay 'Beløbsgrænser' to see your status.             |
/// | 8    | Timeout set in merchant app exceeded.                                                            |
/// | 9    | Invalid signature. This means that the payment is invalid - it has not been signed by MobilePay. |
/// | 10   | MobilePay SDK version is outdated.                                                               |
/// | 11   | The given OrderId is already used. An OrderId has to be unique.                                  |
/// | 12   | Error related to the MobilePay user.                                                             |
/// | ---- | ------------------------------------------------------------------------------------------------ |
///
/// As per the AppSwitch SDK documentation, error codes 1, 2, 4, 5, 9, 10, 11
/// and 12 are technical errors and should be presented to the user as generic
/// errors without details. The rest (3, 6, 7, 8) should be handled by your
/// app to help the user.
///
/// Reference: https://github.com/MobilePayDev/MobilePay-AppSwitch-SDK/wiki/Error-handling
///
/// If you get a MobilePayError you can compare it's [code] to find out which
/// error it is. All the error codes on available on [MobilePayError]:
/// 0: [unknown]
/// 1: [invalidParameters]
/// 2: [merchantValidationFailed]
/// 3: [updateApp]
/// 4: [merchantNotValid]
/// 5: [hmacNotValid]
/// 6: [timeout]
/// 7: [limitsExceeded]
/// 8: [merchantTimeout]
/// 9: [invalidSignature]
/// 10: [sdkIsOutdated]
/// 11: [orderIDAlreadyUsed]
/// 12: [paymentRejectedFraud]
class MobilePayError implements Exception {
  static const int unknown = 0;
  static const int invalidParameters = 1;
  static const int merchantValidationFailed = 2;
  static const int updateApp = 3;
  static const int merchantNotValid = 4;
  static const int hmacNotValid = 5;
  static const int timeout = 6;
  static const int limitsExceeded = 7;
  static const int merchantTimeout = 8;
  static const int invalidSignature = 9;
  static const int sdkIsOutdated = 10;
  static const int orderIDAlreadyUsed = 11;
  static const int paymentRejectedFraud = 12;

  final int code;
  final String message;

  factory MobilePayError._fromPlatformException(PlatformException e) {
    int code;
    switch (e.code) {
      case "MobilePayErrorUnknown":
        code = 0;
        break;
      case "MobilePayErrorInvalidParameters":
        code = 1;
        break;
      case "MobilePayErrorMerchantValidationFailed":
        code = 2;
        break;
      case "MobilePayErrorUpdateApp":
        code = 3;
        break;
      case "MobilePayErrorMerchantNotValid":
        code = 4;
        break;
      case "MobilePayErrorHMACNotValid":
        code = 5;
        break;
      case "MobilePayErrorTimeout":
        code = 6;
        break;
      case "MobilePayErrorLimitsExceeded":
        code = 7;
        break;
      case "MobilePayErrorMerchantTimeout":
        code = 8;
        break;
      case "MobilePayErrorInvalidSignature":
        code = 9;
        break;
      case "MobilePayErrorSDKIsOutdated":
        code = 10;
        break;
      case "MobilePayErrorOrderIDAlreadyUsed":
        code = 11;
        break;
      case "MobilePayErrorPaymentRejectedFraud":
        code = 12;
        break;
      default:
        code = 0;
    }
    return MobilePayError._internal(
      code,
      e.message,
    );
  }

  MobilePayError._internal(this.code, this.message);

  @override
  String toString() {
    return "MobilePay error: ($code) $message";
  }

  @override
  bool operator ==(other) {
    if (other is MobilePayError) {
      return code == other.code;
    } else {
      return false;
    }
  }

  @override
  int get hashCode {
    return code.hashCode;
  }
}
