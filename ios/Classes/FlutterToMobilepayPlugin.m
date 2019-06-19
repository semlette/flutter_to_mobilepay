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
        // TODO: Get merchantId from arguments
        // TODO: Get merchantUrlScheme from arguments
        // TODO: Get country from arguments
        [[MobilePayManager sharedInstance]
         setupWithMerchantId:@"APPDK0000000000"
         merchantUrlScheme:@"flmpexample"
         country:MobilePayCountry_Denmark];
        
        result(nil);
    } else if ([@"isInstalled" isEqualToString:call.method]) {
        // TODO, actually check if the app is installed
        result([NSNumber numberWithBool:1]);
    } else if ([@"createPayment" isEqualToString:call.method]) {
        // TODO: Get order id from arguments
        // TODO: Get price from arguments
        result(nil);
        MobilePayPayment *payment = [[MobilePayPayment alloc]initWithOrderId:@"test order id" productPrice:10];
        [[MobilePayManager sharedInstance]beginMobilePaymentWithPayment:payment error:^(NSError * _Nonnull error) {
            printf("error");
        }];
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
            NSLog(@"MobilePay completed a payment, but there was no listeners");
            return;
        }
        NSDictionary *dict = error.userInfo;
        NSString *errorMessage = [dict valueForKey:NSLocalizedFailureReasonErrorKey];
        NSLog(@"MobilePay purchase failed:  Error code '%li' and message '%@'",(long)error.code,errorMessage);
        
        //TODO: show an appropriate error message to the user. Check MobilePayManager.h for a complete description of the error codes
        
        //An example of using the MobilePayErrorCode enum
        //if (error.code == MobilePayErrorCodeUpdateApp) {
        //    NSLog(@"You must update your MobilePay app");
        //}
    } cancel:^(MobilePayCancelledPayment * _Nullable mobilePayCancelledPayment) {
        NSLog(@"MobilePay purchase with order id '%@' cancelled by user", mobilePayCancelledPayment.orderId);
    }];
    
    return YES;
}

#pragma mark FlutterStreamHandler impl

- (FlutterError*)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)eventSink {
    NSLog(@"new listener");
    events = eventSink;
    return nil;
}

- (FlutterError*)onCancelWithArguments:(id)arguments {
    NSLog(@"canceled listener");
    events = nil;
    return nil;
}

@end
