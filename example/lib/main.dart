import 'package:flutter/material.dart';
import 'package:flutter_to_mobilepay/flutter_to_mobilepay.dart';
import 'package:uuid/uuid.dart';

void main() async {
  await MobilePay.initialize(
    merchantID: TestMerchantID.denmark,
    country: Country.denmark,
    urlScheme: "flmpexample",
  );
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isInstalled = false;

  @override
  void initState() {
    super.initState();
    _checkIfInstalled();
  }

  void _checkIfInstalled() async {
    final installed = await MobilePay.isInstalled();
    setState(() {
      _isInstalled = installed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter to MobilePay'),
        ),
        body: ListView(
          children: <Widget>[
            ListTile(
              title: const Text("Is MobilePay installed"),
              subtitle: Text(_isInstalled.toString()),
            ),
            ListTile(
              title: const Text("Create (test) payment"),
              subtitle: Builder(
                // The reason this is in a Builder has nothing to do with
                // Flutter to MobilePay, but because otherwise the dialogs
                // could not access something from the context.
                builder: (context) {
                  return OutlineButton(
                    child: Text("New payment"),
                    onPressed: _isInstalled
                        ? () async {
                            Payment payment = Payment(
                              orderID: Uuid().v4(),
                              price: 10,
                            );
                            try {
                              final transaction =
                              await MobilePay.createPayment(payment);
                              // The purchase was successful
                              await showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text("Your purchase was successful"),
                                  content: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text("Transaction id: ${transaction.id}"),
                                      Text("Order id: ${transaction.orderID}"),
                                      Text("Total (not) withdrawn: ${transaction.withdrawnFromCard}"),
                                    ],
                                  ),
                                ),
                              );
                            } on MobilePayError catch (e) {
                              // The MobilePay AppSwitch SDK threw an error
                              switch (e.code) {
                                case 0:
                                case 1:
                                case 4:
                                case 5:
                                case 9:
                                case 10:
                                case 11:
                                case 12:
                                  await showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text("An unknown error has occured"),
                                    ),
                                  );
                                  break;
                                default:
                                  String title;
                                  String message;
                                  switch (e.code) {
                                    case 3:
                                      title = "The MobilePay app is outdated";
                                      message = "Update the MobilePay app to pay using MobilePay";
                                      break;
                                    case 6:
                                    case 8:
                                      title = "The payment timed out";
                                      message = "The purchase took longer than expected. Please try again";
                                      break;
                                    case 7:
                                      title = "You have exceeded you limits";
                                      message = "Open MobilePay 'Beløbsgrænser' to see your status";
                                      break;
                                  }
                                  await showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(title),
                                      content: Text(message),
                                    ),
                                  );
                              }
                            } on CancelledPaymentException catch (_) {
                              // The user cancelled the payment
                              await showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text("You cancelled the payment"),
                                ),
                              );
                            }

                          }
                        : null,
                  );
                }
              ),
            ),
          ],
        ),
      ),
    );
  }
}
