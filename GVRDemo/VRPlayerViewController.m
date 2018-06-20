//
//  VRPlayerViewController.m
//  GVRDemo
//
//  Created by mac-vincent on 2017/5/12.
//  Copyright © 2017年 Vincent. All rights reserved.
//

#import "VRPlayerViewController.h"
#import <GCSVideoView.h>
#import <objc/runtime.h>
@interface VRPlayerViewController ()<GCSVideoViewDelegate>
@property (nonatomic, strong)GCSVideoView * vrPlayerView;
@property (nonatomic, assign)BOOL isPaused;

@end

@implementation VRPlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _vrPlayerView = [[GCSVideoView alloc]initWithFrame:self.view.bounds];
    _vrPlayerView.delegate = self;
    _vrPlayerView.enableCardboardButton = YES;
    [self.view addSubview:_vrPlayerView];
    
}


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
    if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        //调用隐藏方法
        [self prefersStatusBarHidden];
        [self performSelector:@selector(setNeedsStatusBarAppearanceUpdate)];
    }
    
    
    
    NSURL *pathUrl = [[NSBundle mainBundle]URLForResource:self.playFileUrl withExtension:@"mp4" subdirectory:nil];
    if(pathUrl) {
        [_vrPlayerView loadFromUrl:pathUrl];
    }
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

//实现隐藏方法
- (BOOL)prefersStatusBarHidden{
    
    return YES;
}

#pragma mark ----GCSVideoViewDelegate----
//GCSVideoView的点击事件

- (void)setIsPaused:(BOOL)isPaused {
    _isPaused = isPaused;
}

-(void)widgetViewDidTap:(GCSWidgetView *)widgetView{
    if(_isPaused) {
        [_vrPlayerView resume];
    }else{
        [_vrPlayerView pause];
    }
    _isPaused = !_isPaused;
}

//视频播放到某个位置时触发事件

-(void)videoView:(GCSVideoView *)videoView didUpdatePosition:(NSTimeInterval)position{
    if(position == videoView.duration) {
        [_vrPlayerView seekTo:0];
        [_vrPlayerView resume];
    }
}

//视频播放失败
-(void)widgetView:(GCSWidgetView *)widgetView didFailToLoadContent:(id)content withErrorMessage:(NSString*)errorMessage{
    
    NSLog(@"播放错误");
    
}

@end
