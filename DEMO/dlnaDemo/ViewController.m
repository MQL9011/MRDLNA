//
//  ViewController.m
//  dlnaDemo
//
//  Created by MccRee on 2018/5/4.
//  Copyright © 2018年 mccree. All rights reserved.
//

#import "ViewController.h"
#import "DLNASearchVC.h"

@interface ViewController ()

@end

@implementation ViewController

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
