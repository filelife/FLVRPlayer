//
//  MyOpenGLView.h
//  GVRDemo
//
//  Created by mac-vincent on 2017/5/17.
//  Copyright © 2017年 Vincent. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

@interface MyOpenGLView : UIView
@property (nonatomic , assign) BOOL isFullYUVRange;
- (void)setupGL;
- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end
