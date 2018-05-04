//
//  MRViewController.m
//  MRDLNA
//
//  Created by MQL9011 on 05/04/2018.
//  Copyright (c) 2018 MQL9011. All rights reserved.
//

#import "MRViewController.h"
#import "DLNASearchVC.h"


@interface MRViewController ()

@end

@implementation MRViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
	[self sendTestRequest];
}

- (IBAction)gotoDlna:(id)sender {
    DLNASearchVC *dlna = [[DLNASearchVC alloc]init];
    [self.navigationController pushViewController:dlna animated:YES];
    
}

/**
 DLNA功能只有在用户允许了网络权限后才能使用
 */
-(void)sendTestRequest{
    NSURL *url = [NSURL URLWithString:@"https://www.baidu.com"];
    NSMutableURLRequest *requst = [[NSMutableURLRequest alloc]initWithURL:url];
    requst.HTTPMethod = @"GET";
    requst.timeoutInterval = 5;
    
    [NSURLConnection sendAsynchronousRequest:requst queue:[[NSOperationQueue alloc]init] completionHandler:^(NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable connectionError) {
        if (!connectionError.description) {
            NSLog(@"网络正常");
        }else{
            NSLog(@"=========>网络异常");
        }
    }];
}



@end
