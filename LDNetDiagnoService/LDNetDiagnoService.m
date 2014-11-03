//
//  LDNetDiagnoService.m
//  LDNetDiagnoServieDemo
//
//  Created by 庞辉 on 14-10-29.
//  Copyright (c) 2014年 庞辉. All rights reserved.
//
#import <UIKit/UIKit.h>
#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import "LDNetDiagnoService.h"
#import "LDNetPing.h"
#import "LDNetTraceRoute.h"

@interface LDNetDiagnoService ()<LDNetPingDelegate, LDNetTraceRouteDelegate> {
    NSString *_appCode; //客户端标记
    NSString *_appName;
    NSString *_appVersion;
    NSString *_UID; //用户ID
    NSString *_deviceID; //客户端机器ID，如果不传入会默认取API提供的机器ID
    NSString *_dormain; //接口域名
    NSString *_carrierName;
    NSString *_ISOCountryCode;
    NSString *_MobileCountryCode;
    NSString *_MobileNetCode;
    
    NSMutableString *_logInfo; //记录网络诊断log日志
    BOOL _isRunning;
    LDNetPing *_netPinger;
    LDNetTraceRoute *_traceRouter;
}

@end

@implementation LDNetDiagnoService
#pragma mark - public method
/**
 * 初始化网络诊断服务
 */
-(id) initWithAppCode:(NSString *)theAppCode
              appName:(NSString *)theAppName
           appVersion:(NSString *)theAppVersion
               userID:(NSString *)theUID
             deviceID:(NSString *)theDeviceID
              dormain:(NSString *)theDormain
          carrierName:(NSString *)theCarrierName
       ISOCountryCode:(NSString *)theISOCountryCode
    MobileCountryCode:(NSString *)theMobileCountryCode
        MobileNetCode:(NSString *)theMobileNetCode
{
    self = [super init];
    if(self){
        _appCode = theAppCode;
        _appName = theAppName;
        _appVersion = theAppVersion;
        _UID = theUID;
        _deviceID = theDeviceID;
        _dormain = theDormain;
        _carrierName = theCarrierName;
        _ISOCountryCode = theISOCountryCode;
        _MobileCountryCode = theMobileCountryCode;
        _MobileNetCode = theMobileNetCode;
        
        _logInfo = [[NSMutableString alloc] initWithCapacity:20];
        _isRunning = NO;
    }
    
    return self;
}

-(void) recordCurrentAppVersion {
    //输出应用版本信息和用户ID
    [self recordStepInfo: [NSString stringWithFormat:@"应用code: %@", _appCode]];
    NSDictionary *dicBundle = [[NSBundle mainBundle] infoDictionary];
    
    if(!_appName || [_appName isEqualToString:@""]){
        _appName = [dicBundle objectForKey:@"CFBundleDisplayName"];
    }
    [self recordStepInfo: [NSString stringWithFormat:@"应用名称: %@", _appName]];
    
    if(!_appVersion || [_appVersion isEqualToString:@""]){
        _appVersion = [dicBundle objectForKey:@"CFBundleShortVersionString"];
    }
    [self recordStepInfo: [NSString stringWithFormat:@"应用版本: %@", _appVersion]];
    [self recordStepInfo:[NSString stringWithFormat:@"用户id: %@", _UID]];
    
    //输出机器信息
    UIDevice* device = [UIDevice currentDevice];
    [self recordStepInfo:[NSString stringWithFormat:@"机器类型: %@", [device systemName]]];
    [self recordStepInfo:[NSString stringWithFormat:@"系统版本: %@", [device systemVersion]]];
    if( !_deviceID || [_deviceID isEqualToString:@""]){
        _deviceID = [self uniqueAppInstanceIdentifier];
    }
    [self recordStepInfo:[NSString stringWithFormat:@"机器ID: %@", _deviceID]];

    
    
    //运营商信息
    if(!_carrierName || [_carrierName isEqualToString:@""]){
        CTTelephonyNetworkInfo *netInfo = [[CTTelephonyNetworkInfo alloc]init];
        CTCarrier *carrier = [netInfo subscriberCellularProvider];
        if (carrier!=NULL) {
            _carrierName = [carrier carrierName];
            _ISOCountryCode = [carrier isoCountryCode];
            _MobileCountryCode = [carrier mobileCountryCode];
            _MobileNetCode = [carrier mobileNetworkCode];
        }else {
            _carrierName = @"";
            _ISOCountryCode = @"";
            _MobileCountryCode = @"";
            _MobileNetCode = @"";
        }
    }
    
    [self recordStepInfo:[NSString stringWithFormat:@"运营商: %@", _carrierName]];
    [self recordStepInfo:[NSString stringWithFormat:@"ISOCountryCode: %@", _ISOCountryCode]];
    [self recordStepInfo:[NSString stringWithFormat:@"MobileCountryCode: %@", _MobileCountryCode]];
    [self recordStepInfo:[NSString stringWithFormat:@"MobileNetworkCode: %@", _MobileNetCode]];
}


/**
 * 开始诊断网络
 */
-(void) startNetDiagnosis{
    if(!_dormain || [_dormain isEqualToString:@""]) return;
    
    _isRunning = YES;
    [_logInfo setString:@""];
    [self recordStepInfo:@"开始诊断..."];
    [self recordCurrentAppVersion];
    
    //诊断ping信息, 同步过程
    [self recordStepInfo:[NSString stringWithFormat:@"\n\n诊断域名 %@...", _dormain]];
    [self recordStepInfo:@"\n开始ping..."];
    _netPinger = [[LDNetPing alloc] init];
    _netPinger.delegate = self;
    [_netPinger runWithHostName: _dormain];
    
    
    //开始诊断traceRoute
    [self recordStepInfo:@"\n开始traceroute..."];
    _traceRouter = [[LDNetTraceRoute alloc] initWithMaxTTL:TRACEROUTE_MAX_TTL timeout:TRACEROUTE_TIMEOUT maxAttempts:TRACEROUTE_ATTEMPTS port:TRACEROUTE_PORT];
    _traceRouter.delegate = self;
    if(_traceRouter) {
        [NSThread detachNewThreadSelector:@selector(doTraceRoute:) toTarget:_traceRouter withObject:_dormain];
    }
}

/**
 * 停止诊断网络
 */
-(void) stopNetDialogsis {
    if(_isRunning){
        if(_netPinger != nil){
            [_netPinger  stopPing];
            _netPinger = nil;
        }
        
        if(_traceRouter != nil) {
            [_traceRouter stopTrace];
            _traceRouter = nil;
        }
        
        _isRunning = NO;
    }
}


/**
 * 打印整体loginInfo；
 */
-(void)printLogInfo {
    NSLog(@"\n%@\n", _logInfo);
}





#pragma mark netPingDelegate
-(void)appendPingLog:(NSString *)pingLog {
    [self recordStepInfo:pingLog];
}

-(void) netPingDidEnd {
    //net
}

#pragma mark - traceRouteDelegate
-(void) appendRouteLog:(NSString *)routeLog {
    [self recordStepInfo:routeLog];
}

-(void) traceRouteDidEnd {
    _isRunning = NO;
    [self recordStepInfo:@"\n网络诊断结束\n"];
    if(self.delegate && [self.delegate respondsToSelector:@selector(netDiagnosisDidEnd:)]){
        [self.delegate netDiagnosisDidEnd:_logInfo];
    }
}


#pragma mark - common method
/**
 * 如果调用者实现了stepInfo接口，输出信息
 */
-(void) recordStepInfo:(NSString *)stepInfo{
    if(stepInfo == nil) stepInfo = @"";
    [_logInfo appendString:stepInfo];
    [_logInfo appendString:@"\n"];

    if(self.delegate && [self.delegate respondsToSelector:@selector(netDiagnosisStepInfo:)]){
        [self.delegate netDiagnosisStepInfo:[NSString stringWithFormat:@"%@\n", stepInfo]];
    }
}


/**
 * 获取deviceID
 */
- (NSString*)uniqueAppInstanceIdentifier
{
    NSString *app_uuid = @"";
    CFUUIDRef uuidRef = CFUUIDCreate(kCFAllocatorDefault);
    CFStringRef uuidString = CFUUIDCreateString(kCFAllocatorDefault, uuidRef);
    app_uuid = [NSString stringWithString:(__bridge NSString*)uuidString];
    CFRelease(uuidString);
    CFRelease(uuidRef);
    return app_uuid;
}







@end