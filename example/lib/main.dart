import 'package:flutter/material.dart';
import 'package:flutter_to_mobilepay/flutter_to_mobilepay.dart';

void main() async {
  await MobilePay.initialize(
    merchantID: TestMerchants.denmark,
    country: Country.denmark,
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
              subtitle: OutlineButton(
                child: Text("New payment"),
                onPressed: _isInstalled
                    ? () async {
                        Payment payment = Payment(
                          orderID: "test order id",
                          price: 10,
                        );
                        final transaction =
                            await MobilePay.createPayment(payment);
                        print(
                            "transaction id: ${transaction.id}, withdrawn: ${transaction.withdrawnFromCard}, signature: ${transaction.signature}");
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
