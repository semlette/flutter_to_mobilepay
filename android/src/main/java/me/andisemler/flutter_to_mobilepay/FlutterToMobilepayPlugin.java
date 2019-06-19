package me.andisemler.flutter_to_mobilepay;

import android.app.Activity;
import android.content.Intent;
import android.util.Log;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.Map;

import dk.danskebank.mobilepay.sdk.ResultCallback;
import dk.danskebank.mobilepay.sdk.model.FailureResult;
import dk.danskebank.mobilepay.sdk.model.Payment;
import dk.danskebank.mobilepay.sdk.model.SuccessResult;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener;

import dk.danskebank.mobilepay.sdk.Country;
import dk.danskebank.mobilepay.sdk.MobilePay;

/**
 * FlutterToMobilepayPlugin
 */
public class FlutterToMobilepayPlugin implements MethodCallHandler, EventChannel.StreamHandler, ActivityResultListener {
    private static final int MOBILEPAY_REQUEST_CODE = 17062000;
    private static final String LOG_TAG = "flutter_to_mobilepay";

    private Activity activity;
    private EventChannel.EventSink events;

    private FlutterToMobilepayPlugin(Activity activity) {
        this.activity = activity;
    }

    /**
     * Plugin registration.
     */
    public static void registerWith(Registrar registrar) {
        final MethodChannel channel = new MethodChannel(registrar.messenger(), "flutter_to_mobilepay");
        final EventChannel eventChannel = new EventChannel(registrar.messenger(), "flutter_to_mobilepay/payments");
        FlutterToMobilepayPlugin plugin = new FlutterToMobilepayPlugin(registrar.activity());
        eventChannel.setStreamHandler(plugin);
        channel.setMethodCallHandler(plugin);
        registrar.addActivityResultListener(plugin);
    }

    @Override
    public void onMethodCall(MethodCall call, Result result) {
        switch (call.method) {
            case "initializeMobilePay":
                // TODO: Hent merchantID fra methodCall argumenter
                MobilePay.getInstance().init("APPDK0000000000", Country.DENMARK);
                result.success(null);
                break;
            case "isInstalled":
                result.success(isInstalled());
                break;
            case "createPayment":
                Payment payment = new Payment();
                Map<String, String> args = (Map<String, String>) call.arguments;
                payment.setOrderId(args.get("order_id"));
                payment.setProductPrice(new BigDecimal(args.get("price")));
                createPayment(payment);
                result.success(null);
                break;
            default:
                result.notImplemented();
        }
    }

    private boolean isInstalled() {
        return MobilePay.getInstance().isMobilePayInstalled(activity.getApplicationContext());
    }

    private void createPayment(Payment payment) {
        if (!isInstalled()) {
            return;
        }
        Intent paymentIntent = MobilePay.getInstance().createPaymentIntent(payment);
        activity.startActivityForResult(paymentIntent, MOBILEPAY_REQUEST_CODE);
    }

    @Override
    public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == MOBILEPAY_REQUEST_CODE) {
            // The request code matches our MobilePay Intent
            MobilePay.getInstance().handleResult(resultCode, data, new ResultCallback() {
                @Override
                public void onSuccess(SuccessResult result) {
                    // The payment succeeded - you can deliver the product.
                    Log.i(LOG_TAG, "success");
                    if (events != null) {
                        Map<String, String> transaction = new HashMap<>();
                        transaction.put("transaction_id", result.getTransactionId());
                        transaction.put("order_id", result.getOrderId());
                        transaction.put("signature", result.getSignature());
                        transaction.put("withdrawn_from_card", result.getAmountWithdrawnFromCard().toString());
                        events.success(transaction);
                    } else {
                        Log.w(LOG_TAG, "MobilePay a completed payment, but there was no listeners");
                    }
                }

                @Override
                public void onFailure(FailureResult result) {
                    // The payment failed - show an appropriate error message to the user. Consult the MobilePay class documentation for possible error codes.
                    Log.e(LOG_TAG, "failure: " + result.getErrorMessage());
                }

                @Override
                public void onCancel() {
                    // The payment was cancelled.
                    Log.w(LOG_TAG, "cancelled");
                }
            });
            return true;
        }
        return false;
    }

    @Override
    public void onListen(Object o, EventChannel.EventSink eventSink) {
        events = eventSink;
    }

    @Override
    public void onCancel(Object o) {
        events = null;
    }
}
