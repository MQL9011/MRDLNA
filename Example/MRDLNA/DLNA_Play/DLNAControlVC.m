//
//  DLNAControlVC.m
//  YSTThirdSDK_Example
//
//  Created by MccRee on 2018/2/11.
//  Copyright © 2018年 MQL9011. All rights reserved.
//

#import "DLNAControlVC.h"
#import <MRDLNA/MRDLNA.h>


//屏幕高度
#define H [UIScreen mainScreen].bounds.size.height
#define W [UIScreen mainScreen].bounds.size.width


@interface DLNAControlVC ()
{
     BOOL _isPlaying;
}

@property(nonatomic,strong) MRDLNA *dlnaManager;

@end

@implementation DLNAControlVC

- (void)viewDidLoad {
    [super viewDidLoad];
   
    self.dlnaManager = [MRDLNA sharedMRDLNAManager];
    [self.dlnaManager startDLNA];

     _isPlaying = YES;
}

#pragma mark -播放控制

/**
 退出
 */
- (IBAction)closeAction:(id)sender {
    [self.dlnaManager endDLNA];
}


/**
 播放/暂停
 */
- (IBAction)playOrPause:(id)sender {
    if (_isPlaying) {
        [self.dlnaManager dlnaPause];
    }else{
        [self.dlnaManager dlnaPlay];
    }
    _isPlaying = !_isPlaying;
}


/**
 进度条
 */
- (IBAction)seekChanged:(UISlider *)sender{
    NSInteger sec = sender.value * 60 * 60;
    NSLog(@"播放进度条======>: %zd",sec);
    [self.dlnaManager seekChanged:sec];
}

/**
 音量
 */
- (IBAction)volumeChange:(UISlider *)sender {
    NSString *vol = [NSString stringWithFormat:@"%.f",sender.value * 100];
    NSLog(@"音量========>: %@",vol);
    [self.dlnaManager volumeChanged:vol];
}


/**
 切集
 */
- (IBAction)playNext:(id)sender {
    NSString *testVideo = @"http://wvideo.spriteapp.cn/video/2016/0328/56f8ec01d9bfe_wpd.mp4";
    [self.dlnaManager playTheURL:testVideo];
}

@end
