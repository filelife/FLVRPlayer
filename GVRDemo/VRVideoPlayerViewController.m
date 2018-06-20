//
//  VRVideoPlayerViewController.m
//  GVRDemo
//
//  Created by mac-vincent on 2017/5/15.
//  Copyright © 2017年 Vincent. All rights reserved.
//

#import "VRVideoPlayerViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/ALAssetsLibrary.h>
#import "MyOpenGLView.h"
#import "DrawABallViewController.h"
@interface VRVideoPlayerViewController ()
@property (nonatomic , strong) UILabel  *mLabel;
@property (nonatomic , strong) NSDate *mStartDate;

@property (nonatomic , strong) AVAsset *mAsset;
@property (nonatomic , strong) AVAssetReader *mReader;
@property (nonatomic , strong) AVAssetReaderTrackOutput *mReaderVideoTrackOutput;


// OpenGL ES
@property (nonatomic , strong) MyOpenGLView *mGLView;
@property (nonatomic , strong) CADisplayLink *mDisplayLink;

@end

@implementation VRVideoPlayerViewController
{
    CADisplayLink *displayLink;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationController.navigationBar.hidden = YES;
    
    self.mGLView = [[MyOpenGLView alloc]initWithFrame:self.view.bounds];
    [self.mGLView setupGL];
    [self.view addSubview:self.mGLView];
    
    self.mLabel = [[UILabel alloc] initWithFrame:CGRectMake(100, 100, 100, 100)];
    self.mLabel.textColor = [UIColor redColor];
    [self.view addSubview:self.mLabel];
    
    self.mDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkCallback:)];
    self.mDisplayLink.frameInterval = 2; //FPS=30
    [[self mDisplayLink] addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [[self mDisplayLink] setPaused:YES];
    
    [self loadAsset];
    UIButton * drawBall = [UIButton buttonWithType:UIButtonTypeCustom];
    [drawBall setTitle:@"画个球" forState:UIControlStateNormal];
    [drawBall addTarget:self action:@selector(drawBallAction:) forControlEvents:UIControlEventTouchUpInside];
    CGFloat offsetX = [UIScreen mainScreen].bounds.size.width - 120 - 15;
    drawBall.frame = CGRectMake(offsetX, 15, 120, 30);
    drawBall.layer.masksToBounds = YES;
    drawBall.layer.borderColor = [UIColor lightGrayColor].CGColor;
    drawBall.layer.borderWidth = 1;
    [self.mGLView addSubview:drawBall];
}

- (void)drawBallAction:(id) sender{
    DrawABallViewController * drawVC = [[DrawABallViewController alloc]init];
    [self.navigationController pushViewController:drawVC animated:YES];
}


- (void)loadAsset {
    NSDictionary *inputOptions = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:AVURLAssetPreferPreciseDurationAndTimingKey];
    AVURLAsset *inputAsset = [[AVURLAsset alloc] initWithURL:[[NSBundle mainBundle] URLForResource:@"雪地" withExtension:@"mp4"] options:inputOptions];
    __weak typeof(self) weakSelf = self;
    [inputAsset loadValuesAsynchronouslyForKeys:[NSArray arrayWithObject:@"mTracks"] completionHandler: ^{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSError *error = nil;
            AVKeyValueStatus tracksStatus = [inputAsset statusOfValueForKey:@"mTracks" error:&error];
            if (tracksStatus != AVKeyValueStatusLoaded)
            {
                NSLog(@"error %@", error);
                return;
            }
            weakSelf.mAsset = inputAsset;
            [weakSelf processAsset];
        });
    }];

}



- (AVAssetReader*)createAssetReader
{
    NSError *error = nil;
    AVAssetReader *assetReader = [AVAssetReader assetReaderWithAsset:self.mAsset error:&error];
    
    NSMutableDictionary *outputSettings = [NSMutableDictionary dictionary];
    
    [outputSettings setObject:@(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    
    self.mReaderVideoTrackOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:[[self.mAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] outputSettings:outputSettings];
    self.mReaderVideoTrackOutput.alwaysCopiesSampleData = NO;
    [assetReader addOutput:self.mReaderVideoTrackOutput];
    
    return assetReader;
}

- (void)processAsset
{
    self.mReader = [self createAssetReader];
    
    if ([self.mReader startReading] == NO)
    {
        NSLog(@"Error reading from file at URL: %@", self.mAsset);
        return;
    }
    else {
        self.mStartDate = [NSDate dateWithTimeIntervalSinceNow:0];
        [self.mDisplayLink setPaused:NO];
        NSLog(@"Start reading success.");
    }
}


- (void)displayLinkCallback:(CADisplayLink *)sender
{
    CMSampleBufferRef sampleBuffer = [self.mReaderVideoTrackOutput copyNextSampleBuffer];
    
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (pixelBuffer) {
        self.mLabel.text = [NSString stringWithFormat:@"播放%.f秒", [[NSDate dateWithTimeIntervalSinceNow:0] timeIntervalSinceDate:self.mStartDate]];
        [self.mLabel sizeToFit];
        [self.mGLView displayPixelBuffer:pixelBuffer];
        
        if (pixelBuffer != NULL) {
            CFRelease(pixelBuffer);
        }
    }
    else {
        NSLog(@"播放完成");
        [self.mGLView displayPixelBuffer:pixelBuffer];
//        [self.mDisplayLink setPaused:YES];
    }
}



#pragma mark - Simple Editor

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

@end
