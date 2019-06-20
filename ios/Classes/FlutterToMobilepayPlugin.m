#import "FlutterToMobilepayPlugin.h"
#import "MobilePayManager.h"

@interface FlutterToMobilepayPlugin () <FlutterStreamHandler> {
    FlutterEventSink events;
}
@end

@implementation FlutterToMobilepayPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    // Create plugin instance
    FlutterToMobilepayPlugin* instance = [[FlutterToMobilepayPlugin alloc] init];
    
    // Create method channel
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"flutter_to_mobilepay"
                                     binaryMessenger:[registrar messenger]];
    
    // Create event channel
    FlutterEventChannel* paymentChannel = [FlutterEventChannel
                                         eventChannelWithName:@"flutter_to_mobilepay/payments"
                                         binaryMessenger:[registrar messenger]];
    
    // Register channels and application delegate callback
    [registrar addMethodCallDelegate:instance channel:channel];
    [registrar addApplicationDelegate:instance];
    [paymentChannel setStreamHandler:instance];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"initializeMobilePay" isEqualToString:call.method]) {
        // Set up MobilePay
        NSDictionary *args = call.arguments;
        [[MobilePayManager sharedInstance]
         setupWithMerchantId:args[@"merchant_id"]
         merchantUrlScheme:args[@"url_scheme"]
         country:[self getMobilePayCountryFromString:args[@"country"]]];
        
        result(nil);
    } else if ([@"isInstalled" isEqualToString:call.method]) {
        // TODO, actually check if the app is installed
        result([NSNumber numberWithBool:1]);
    } else if ([@"createPayment" isEqualToString:call.method]) {
        NSDictionary *args = call.arguments;
        MobilePayPayment *payment = [[MobilePayPayment alloc]
                                     initWithOrderId:args[@"order_id"]
                                     productPrice:[args[@"price"] floatValue]];
        [[MobilePayManager sharedInstance]beginMobilePaymentWithPayment:payment error:^(NSError * _Nonnull error) {
            result([FlutterError errorWithCode:[NSString stringWithFormat:@"%ld", (long)error.code] message:error.localizedDescription details:error.localizedFailureReason]);
        }];
        result(nil);
    } else {
        result(FlutterMethodNotImplemented);
    }
}

-(BOOL)application:(UIApplication*)application
           openURL:(NSURL*)url
           options:(NSDictionary<UIApplicationOpenURLOptionsKey, id>*)options {
    
    [[MobilePayManager sharedInstance]handleMobilePayPaymentWithUrl:url success:^(MobilePaySuccessfulPayment * _Nullable mobilePaySuccessfulPayment) {
        if (!self->events) {
            NSLog(@"MobilePay completed a payment, but there was no listeners");
            return;
        }
        NSDictionary *transaction = @{
                                    @"order_id": mobilePaySuccessfulPayment.orderId,
                                    @"transaction_id": mobilePaySuccessfulPayment.transactionId,
                                    @"withdrawn_from_card": [NSString stringWithFormat:@"%f",mobilePaySuccessfulPayment.amountWithdrawnFromCard],
                                    @"signature": mobilePaySuccessfulPayment.signature,
                                    };
        self->events(transaction);
    } error:^(NSError * _Nonnull error) {
        if (!self->events) {
            NSLog(@"MobilePay returned payment with error, but there was no listeners");
            return;
        }

        NSDictionary *dict = error.userInfo;
        NSString *errorMessage = [dict valueForKey:NSLocalizedFailureReasonErrorKey];
        self->events([self flutterErrorFromMobilePayError:(long)error.code message: errorMessage]);
    } cancel:^(MobilePayCancelledPayment * _Nullable mobilePayCancelledPayment) {
        if (!self->events) {
            NSLog(@"MobilePay returned a cancelled payment, but there was no listeners");
            return;
        }
        self->events([FlutterError errorWithCode:@"CancelledPayment" message:@"The user cancelled the payment" details: [mobilePayCancelledPayment orderId]]);
    }];
    
    return YES;
}

- (FlutterError*)flutterErrorFromMobilePayError:(long)code message:(NSString*)message {
    NSString *formattedCode;
    switch (code) {
            case 0:
            formattedCode = @"MobilePayErrorUnknown";
            break;
            case 1:
            formattedCode = @"MobilePayErrorInvalidParameters";
            break;
            case 2:
            formattedCode = @"MobilePayErrorMerchantValidationFailed";
            break;
            case 3:
            formattedCode = @"MobilePayErrorUpdateApp";
            break;
            case 4:
            formattedCode = @"MobilePayErrorMerchantNotValid";
            break;
            case 5:
            formattedCode = @"MobilePayErrorHMACNotValid";
            break;
            case 6:
            formattedCode = @"MobilePayErrorTimeout";
            break;
            case 7:
            formattedCode = @"MobilePayErrorLimitsExceeded";
            break;
            case 8:
            formattedCode = @"MobilePayErrorMerchantTimeout";
            break;
            case 9:
            formattedCode = @"MobilePayErrorInvalidSignature";
            break;
            case 10:
            formattedCode = @"MobilePayErrorSDKIsOutdated"; // hah, as if
            break;
            case 11:
            formattedCode = @"MobilePayErrorOrderIDAlreadyUsed";
            break;
            case 12:
            formattedCode = @"MobilePayErrorPaymentRejectedFraud";
            break;
    }
    return [FlutterError errorWithCode:formattedCode message:message details: nil];
}

- (MobilePayCountry)getMobilePayCountryFromString:(NSString*)string {
    if ([@"denmark" isEqualToString:string]) {
        return MobilePayCountry_Denmark;
    } else if ([@"finland" isEqualToString:string]) {
        return MobilePayCountry_Finland;
    }
    return MobilePayCountry_Norway;
}

#pragma mark FlutterStreamHandler impl

- (FlutterError*)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)eventSink {
    events = eventSink;
    return nil;
}

- (FlutterError*)onCancelWithArguments:(id)arguments {
    events = nil;
    return nil;
}

@end
