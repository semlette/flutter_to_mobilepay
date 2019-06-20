# flutter_to_mobilepay

Flutter to MobilePay provides easy integration with [MobilePay](https://developer.mobilepay.dk/). It uses the [MobilePay AppSwitch SDK](https://developer.mobilepay.dk/faq/appswitch) to switch to the MobilePay app, perform the payment and then return the transaction information back to
Flutter.

Flutter to MobilePay works on both Android\* and iOS.

\* see caveats further down

## Usage

```dart
import "package:flutter_to_mobilepay/flutter_to_mobilepay.dart";
import "package:uuid/uuid.dart";

void main() async {
    await MobilePay.initialize(
        merchantID: TestMerchantID.denmark,
        country: Country.denmark,
        urlScheme: "myapp", // iOS only, see installation
    );
    runApp(MobilePayButton());
}

class MobilePayButton extends StatelessWidget {
    @override
    Widget build(BuildContext context) {
        return RaisedButton(
            child: const Text("Pay with MobilePay"),
            onPressed: () async {

                Payment payment = Payment(
                    orderID: Uuid().v4(),
                    price: 100, // double
                );
                Transaction transaction = await MobilePay.createPayment(payment);
                print("transaction id: ${transaction.id}");
                print("order id: ${transaction.orderID}");
                print("total withdrawn: ${transaction.withdrawnFromCard}");

            }
        );
    }
}
```

## Installing

Add the package as a dependency to your project

`pubspec.yaml`

```yaml
dependencies:
    # ...
    flutter_to_mobilepay: ^1.0.0
```

Android should be ready to go, however iOS requires a bit more work.

### iOS

Opening other apps on iOS requires registering their URL schemes (and your own). Add your app's URL scheme to your `Info.plist` if you haven't already.

`ios/Info.plist`

```xml
<!-- ... -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string> -- your bundle id -- </string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>
                -- your url scheme --
<!--
This must match the one provided to `MobilePay.initialize(urlScheme: "")`

Documentation: https://developer.apple.com/documentation/uikit/inter-process_communication/allowing_apps_and_websites_to_link_to_your_content/defining_a_custom_url_scheme_for_your_app
-->
            </string>
        </array>
    </dict>
</array>
```

If you wish to check if the MobilePay app is installed, you have to add the following URL schemes (or exclude the ones you don't need) to your `Info.plist`.

`ios/Info.plist`

```xml
<!-- ... -->
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>mobilepay</string> <!-- denmark -->
    <string>mobilepayfi</string> <!-- finland -->
    <string>mobilepayno</string> <!-- norway -->
</array>
```

## Caveats

-   The MobilePay AppSwitch SDK does not target the latest Android SDK version. It uses deprecated APIs on newer versions and is not compatible with Android P at all.

## Alternatives

-   [flutter_mobilepay_payment](https://pub.dev/packages/flutter_mobilepay_payment)

## Contributing

### Implementation

On the native side of things, Flutter to MobilePay is written in Objective C and Java. It does most things by calling the platform with maps as arguments, containing the needed data. However the payments are implemented using an EventChannel stream. This is because the payment callback is sent to the Android activity and iOS app delegate, not the function creating the payment.
When the payment callback is received, it transforms it into a map and sends it to Flutter through the EventChannel.
`createPayment()` awaits the payment and returns it to the user.