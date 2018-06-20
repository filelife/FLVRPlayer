//
//  MyOpenGLView.m
//  GVRDemo
//
//  Created by mac-vincent on 2017/5/17.
//  Copyright © 2017年 Vincent. All rights reserved.
//

#import "MyOpenGLView.h"
#import "sphere.h"
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVUtilities.h>
#import <mach/mach_time.h>
#import <GLKit/GLKit.h>

// Uniform index.
enum
{
    UNIFORM_Y,
    UNIFORM_UV,
    UNIFORM_COLOR_CONVERSION_MATRIX,
    UNIFORM_PROJECTION_MARTRIX,//用户视角
    UNIFORM_MODELVIEW_MARTRIX,//存储球体旋转的位置
    UNIFORM_ROTATE,//视角取景位置
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

// Attribute index.
enum
{
    ATTRIB_VERTEX,
    ATTRIB_TEXCOORD,
    NUM_ATTRIBUTES
};


// kColorConversion601 和 kColorConversion709是两个YUV颜色空间到RGB颜色空间的转换矩阵。
// BT.601, which is the standard for SDTV.
static const GLfloat kColorConversion601[] = {
    1.164,  1.164, 1.164,
    0.0  , -0.392, 2.017,
    1.596, -0.813,   0.0,
};

// BT.709, which is the standard for HDTV.
static const GLfloat kColorConversion709[] = {
    1.164,  1.164, 1.164,
    0.0  , -0.213, 2.112,
    1.793, -0.533,   0.0,
};

// BT.601 full range
const GLfloat kColorConversion601FullRange[] = {
    1.0,    1.0,    1.0,
    0.0,    -0.343, 1.765,
    1.4,    -0.711, 0.0,
};

@interface MyOpenGLView ()
{
    // The pixel dimensions of the CAEAGLLayer.
    GLint _backingWidth;
    GLint _backingHeight;
    
    GLuint _vertexBuffer;
    GLuint _textureBuffer;
    
    EAGLContext *_context;
    CVOpenGLESTextureRef _lumaTexture;//亮度
    CVOpenGLESTextureRef _chromaTexture;//色度
    CVOpenGLESTextureCacheRef _videoTextureCache;
    
    GLuint _frameBufferHandle;
    GLuint _colorBufferHandle;
    
    const GLfloat *_preferredConversion;
    CADisplayLink *displayLink;
    
    UILabel* horizontalLabel;
    float horizontalDegree;
    UILabel* verticalLabel;
    float verticalDegree;
}

@property GLuint program;

- (void)setupBuffers;
- (void)cleanUpTextures;

- (BOOL)loadShaders;
- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type URL:(NSURL *)URL;
- (BOOL)linkProgram:(GLuint)prog;
- (BOOL)validateProgram:(GLuint)prog;

@end


@implementation MyOpenGLView
+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    [self initContext];
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        [self initContext];
    }
    return self;
}

- (BOOL)initContext {
    self.contentScaleFactor = [[UIScreen mainScreen] scale];
    
    CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
    
    eaglLayer.opaque = TRUE;
    eaglLayer.drawableProperties = @{ kEAGLDrawablePropertyRetainedBacking :[NSNumber numberWithBool:NO],
                                      kEAGLDrawablePropertyColorFormat : kEAGLColorFormatRGBA8};
    
    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    
    if (!_context || ![EAGLContext setCurrentContext:_context] || ![self loadShaders]) {
        return NO;
    }
    
    _preferredConversion = kColorConversion709;
    
    [self setupView];
    return YES;
}

#define LY_ROTATE YES


- (void)setupView {
    horizontalLabel = [[UILabel alloc] initWithFrame:CGRectMake(100, 0, 200, 50)];
    [self addSubview:horizontalLabel];
    horizontalLabel.textColor = [UIColor redColor];
    verticalLabel = [[UILabel alloc] initWithFrame:CGRectMake(100, 50, 200, 50)];
    [self addSubview:verticalLabel];
    verticalLabel.textColor = [UIColor redColor];
    
    if (LY_ROTATE) {
        horizontalDegree = 0.0;
        verticalDegree = M_PI_2;
        horizontalLabel.text = [NSString stringWithFormat:@"绕X轴旋转角度为%.2f", GLKMathRadiansToDegrees(horizontalDegree)];
        verticalLabel.text = [NSString stringWithFormat:@"绕Y轴旋转角度为%.2f", GLKMathRadiansToDegrees(verticalDegree)];
    }
    else {
        horizontalDegree = M_PI_2;
        verticalDegree = 0.0;
        horizontalLabel.text = [NSString stringWithFormat:@"偏航角为%.2f", GLKMathRadiansToDegrees(horizontalDegree)];
        verticalLabel.text = [NSString stringWithFormat:@"高度角为%.2f", GLKMathRadiansToDegrees(verticalDegree)];
    }
}

# pragma mark - OpenGL setup

- (void)setupGL {
    [EAGLContext setCurrentContext:_context];
    [self setupBuffers];
    [self loadShaders];
    
    glUseProgram(self.program);
    
    glUniform1i(uniforms[UNIFORM_Y], 0);
    glUniform1i(uniforms[UNIFORM_UV], 1);
    // 视角，要求输入幅度，GLKMathDegreesToRadians帮助我们把角度值转换为幅度。
    glUniform1f(uniforms[UNIFORM_ROTATE], GLKMathDegreesToRadians(180));
    
    glUniformMatrix3fv(uniforms[UNIFORM_COLOR_CONVERSION_MATRIX], 1, GL_FALSE, _preferredConversion);
    // GLKMatrix4MakePerspective 透视投影变换
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(90), CGRectGetWidth(self.bounds) * 1.0 / CGRectGetHeight(self.bounds), 0.01, 10);
    
    GLKMatrix4 modelViewMatrix = GLKMatrix4MakeLookAt(0, 0, 0,
                                                      1, 0, 0,
                                                      0, 1, 0);
    
    glUniformMatrix4fv(uniforms[UNIFORM_PROJECTION_MARTRIX], 1, GL_FALSE, projectionMatrix.m);
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEW_MARTRIX], 1, GL_FALSE, modelViewMatrix.m);
    
    
    if (!_videoTextureCache) {
        CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &_videoTextureCache);
        if (err != noErr) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreate %d", err);
            return;
        }
    }
}


/**
 *  使用极坐标来跟随镜头
 *
 *  @param h 摄像头水平移动角度
 *  @param v 摄像头抬起角度
 */
- (void)changeModelViewWithHorizontal:(float)h Vertical:(float)v {
    horizontalDegree -= h / 100;
    verticalDegree -= v / 100;
    
    horizontalLabel.text = [NSString stringWithFormat:@"偏航角为%.2f", GLKMathRadiansToDegrees(horizontalDegree)];
    verticalLabel.text = [NSString stringWithFormat:@"高度角为%.2f", GLKMathRadiansToDegrees(verticalDegree)];
    
    /*
     GLKMatrix4 GLKMatrix4MakeLookAt(
     float eyeX, float eyeY, float eyeZ,
     float centerX, float centerY, float centerZ,
     float upX, float upY, float upZ)
     */
    GLKMatrix4 modelViewMatrix = GLKMatrix4MakeLookAt(0, 0, 0,
                                                      sin(horizontalDegree) * cos(verticalDegree),
                                                      sin(horizontalDegree) * sin(verticalDegree),
                                                      cos(horizontalDegree),
                                                      0, 1, 0);
    
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEW_MARTRIX], 1, GL_FALSE, modelViewMatrix.m);
}


/**
 *  旋转表示
 *
 *  @param x 绕x轴角度变换
 *  @param y 绕y轴角度变换
 */
- (void)roatateWithX:(float)x Y:(float)y {
    horizontalDegree -= x / 100;
    verticalDegree += y / 100;
    
    horizontalLabel.text = [NSString stringWithFormat:@"绕X轴旋转角度为%.2f", GLKMathRadiansToDegrees(horizontalDegree)];
    verticalLabel.text = [NSString stringWithFormat:@"绕Y轴旋转角度为%.2f", GLKMathRadiansToDegrees(verticalDegree)];
    //
    GLKMatrix4 modelViewMatrix = GLKMatrix4Identity;
    modelViewMatrix = GLKMatrix4RotateX(modelViewMatrix, horizontalDegree);
    modelViewMatrix = GLKMatrix4RotateY(modelViewMatrix, verticalDegree);
    /*
     void glUniformMatrix4fv(GLint location,  GLsizei count,  GLboolean transpose,  const GLfloat *value);
     location
     指明要更改的uniform变量的位置
     count
     指明要更改的矩阵个数
     transpose
     指明是否要转置矩阵，并将它作为uniform变量的值。必须为GL_FALSE。
     value
     指明一个指向count个元素的指针，用来更新指定的uniform变量。
     */
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEW_MARTRIX], 1, GL_FALSE, modelViewMatrix.m);
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch* touch = [touches anyObject];
    CGPoint point = [touch locationInView:self];
    CGPoint prePoint = [touch previousLocationInView:self];
    if (LY_ROTATE) {
        [self roatateWithX:point.y - prePoint.y Y:point.x - prePoint.x];
    }
    else {
        [self changeModelViewWithHorizontal:point.x - prePoint.x Vertical:point.y - prePoint.y];
    }
}



#pragma mark - Utilities

- (void)setupBuffers
{
    glDisable(GL_DEPTH_TEST);
    
    glEnableVertexAttribArray(ATTRIB_VERTEX);
    glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(GLfloat), 0);
    
    glEnableVertexAttribArray(ATTRIB_TEXCOORD);
    glVertexAttribPointer(ATTRIB_TEXCOORD, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(GLfloat), 0);
    
    glGenFramebuffers(1, &_frameBufferHandle);
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBufferHandle);
    
    glGenRenderbuffers(1, &_colorBufferHandle);
    glBindRenderbuffer(GL_RENDERBUFFER, _colorBufferHandle);
    
    
    // @glGenBuffers (GLsizei n, GLuint* buffers);
    /*
        @n:
        指定要生成的缓存标识数量
        @buffers:
        创建缓存，_vertextBuffer为缓存指针
     */
    glGenBuffers(1, &_vertexBuffer);
    
    // @glBindBuffer (GLenum target, GLuint buffer);
    /*
        @target:
        第一个参数target,是一个常量，用于指定要绑定哪一种类型的缓存。
        GL_ARRAY_BUFFER 表明该类型缓存是用于指定一个顶点属性数组。
        @buffer:
        缓存标识位。
     */
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    
    
    // @glBufferData (GLenum target, GLsizeiptr size, const GLvoid* data, GLenum usage);
    /*
        @target:
        同上
        @size:
        表示要复制进入这段缓存的字节的数量。
        @data:
        要复制的字节的地址。
        @usage:
     
     */
    glBufferData(GL_ARRAY_BUFFER, sizeof(sphereVerts), sphereVerts, GL_STATIC_DRAW);
    
    
    
    glGenBuffers(1, &_textureBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _textureBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(sphereTexCoords), sphereTexCoords, GL_STATIC_DRAW);
    
    
    
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
    
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
    
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _colorBufferHandle);
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
    }
}

- (void)cleanUpTextures
{
    if (_lumaTexture) {
        CFRelease(_lumaTexture);
        _lumaTexture = NULL;
    }
    
    if (_chromaTexture) {
        CFRelease(_chromaTexture);
        _chromaTexture = NULL;
    }
    
    // Periodic texture cache flush every frame
    CVOpenGLESTextureCacheFlush(_videoTextureCache, 0);
}

- (void)dealloc
{
    [self cleanUpTextures];
    
    if(_videoTextureCache) {
        CFRelease(_videoTextureCache);
    }
}

#pragma mark - OpenGLES drawing

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    CVReturn err;
    if (pixelBuffer != NULL) {
        int frameWidth = (int)CVPixelBufferGetWidth(pixelBuffer);
        int frameHeight = (int)CVPixelBufferGetHeight(pixelBuffer);
        
        
        if (!_videoTextureCache) {
            NSLog(@"No video texture cache");
            return;
        }
        // 设置上下文
        if ([EAGLContext currentContext] != _context) {
            [EAGLContext setCurrentContext:_context]; // 非常重要的一行代码
        }
        [self cleanUpTextures];
        // 获取pixelBuffer的颜色空间格式，决定使用的颜色转换矩阵，用于下一步的YUV到RGB颜色空间的转换；
        CFTypeRef colorAttachments = CVBufferGetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, NULL);
        
        if (colorAttachments == kCVImageBufferYCbCrMatrix_ITU_R_601_4) {
            if (self.isFullYUVRange) {
                _preferredConversion = kColorConversion601FullRange;
            }
            else {
                _preferredConversion = kColorConversion601;
            }
        }
        else {
            _preferredConversion = kColorConversion709;
        }
        // @void glActiveTexture(GLenum texUnit);
        // 建设纹理单位,texUnit是一个符号常量，其形式为GL_TEXTUREi，其中i的范围是从0到k-1，k是纹理单位的最大数量.
        glActiveTexture(GL_TEXTURE0);
        
        // From apple: A cache used to create and manage OpenGL ES texture objects.
        //从buffer中读取数据并创建亮度纹理。
        err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                           _videoTextureCache,
                                                           pixelBuffer,
                                                           NULL,
                                                           GL_TEXTURE_2D,
                                                           GL_LUMINANCE,
                                                           frameWidth,
                                                           frameHeight,
                                                           GL_LUMINANCE,
                                                           GL_UNSIGNED_BYTE,
                                                           0,
                                                           &_lumaTexture);
        if (err) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
        }
        
        // 允许建立一个绑定到目标纹理的有名称的纹理。
        glBindTexture(CVOpenGLESTextureGetTarget(_lumaTexture), CVOpenGLESTextureGetName(_lumaTexture));
        
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        glActiveTexture(GL_TEXTURE1);
        
        //取数据并创建彩色纹理
        err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                           _videoTextureCache,
                                                           pixelBuffer,
                                                           NULL,
                                                           GL_TEXTURE_2D,
                                                           GL_LUMINANCE_ALPHA,
                                                           frameWidth / 2,
                                                           frameHeight / 2,
                                                           GL_LUMINANCE_ALPHA,
                                                           GL_UNSIGNED_BYTE,
                                                           1,
                                                           &_chromaTexture);
        if (err) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
        }
        // 绑定色彩纹理
        glBindTexture(CVOpenGLESTextureGetTarget(_chromaTexture), CVOpenGLESTextureGetName(_chromaTexture));
        
        // 滤波模式制定
        // @void glTexParameteri(GLenum target,GLenum  pname,GLint param)
        // GL_TEXTURE_2D: 操作2D纹理.
        // 纹理过滤：GL_TEXTURE_MIN_FILTER(缩小过滤);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        // 纹理过滤：GL_TEXTURE_MAG_FILTER(放大过滤)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        
        // 纹理WRAP: 将纹理坐标限制在0.0,1.0的范围之内.如果超出了会如何呢.不会错误,只是会边缘拉伸填充.
        // GL_TEXTURE_WRAP_S: S方向上的贴图模式.
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
        // GL_TEXTURE_WRAP_T: T方向上的贴图模式.
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
        
        glBindFramebuffer(GL_RENDERBUFFER, _frameBufferHandle);
        
        glViewport(0,0,_backingWidth,_backingHeight);
    }
    
    glClearColor(0.1f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glUseProgram(self.program);
    glUniformMatrix3fv(uniforms[UNIFORM_COLOR_CONVERSION_MATRIX], 1, GL_FALSE, _preferredConversion);
    
    
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    
    
    // @glVertexAttribPointer (GLuint indx, GLint size, GLenum type, GLboolean normalized, GLsizei stride, const GLvoid* ptr)
    /*
        indx:
        指示当前绑定的缓存包含每个顶点的位置信息
     
     */
    
    glVertexAttribPointer(ATTRIB_VERTEX, 3, GL_FLOAT, GL_FALSE, 0, NULL);
    glEnableVertexAttribArray(ATTRIB_VERTEX);
    
    glBindBuffer(GL_ARRAY_BUFFER, _textureBuffer);
    glVertexAttribPointer(ATTRIB_TEXCOORD, 2, GL_FLOAT, GL_FALSE, 0, NULL);
    glEnableVertexAttribArray(ATTRIB_TEXCOORD);
    
    glDrawArrays(GL_TRIANGLES, 0, sphereNumVerts);
    
    glBindRenderbuffer(GL_RENDERBUFFER, _colorBufferHandle);
    
    if ([EAGLContext currentContext] == _context) {
        [_context presentRenderbuffer:GL_RENDERBUFFER];
    }
    
}


#pragma mark -  OpenGL ES 2 shader compilation

- (BOOL)loadShaders
{
    GLuint vertShader, fragShader;
    NSURL *vertShaderURL, *fragShaderURL;
    
    //创建一个渲染程序
    self.program = glCreateProgram();
    
    // 创建顶点着色器
    vertShaderURL = [[NSBundle mainBundle] URLForResource:@"Shader" withExtension:@"vsh"];
    if (![self compileShader:&vertShader type:GL_VERTEX_SHADER URL:vertShaderURL]) {
        NSLog(@"Failed to compile vertex shader");
        return NO;
    }
    
    // 创建片段着色器
    fragShaderURL = [[NSBundle mainBundle] URLForResource:@"Shader" withExtension:@"fsh"];
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER URL:fragShaderURL]) {
        NSLog(@"Failed to compile fragment shader");
        return NO;
    }
    //@将着色器添加到程序中
    //  添加定点着色器
    glAttachShader(self.program, vertShader);
    
    //  添加片段着色器
    glAttachShader(self.program, fragShader);
    
    //从着色器代码中获取属性信息
    //从着色器源程序中的顶点着色器中获取位置属性
    glBindAttribLocation(self.program, ATTRIB_VERTEX, "position");
    //从着色器源程序中的顶点着色器中获取文理坐标属性
    glBindAttribLocation(self.program, ATTRIB_TEXCOORD, "texCoord");
    
    // Link the program.
    if (![self linkProgram:self.program]) {
        NSLog(@"Failed to link program: %d", self.program);
        
        if (vertShader) {
            glDeleteShader(vertShader);
            vertShader = 0;
        }
        if (fragShader) {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (self.program) {
            glDeleteProgram(self.program);
            self.program = 0;
        }
        
        return NO;
    }
    
    // Get uniform locations.
    uniforms[UNIFORM_Y] = glGetUniformLocation(self.program, "SamplerY");
    uniforms[UNIFORM_UV] = glGetUniformLocation(self.program, "SamplerUV");
    uniforms[UNIFORM_ROTATE] = glGetUniformLocation(self.program, "preferredRotation");
    uniforms[UNIFORM_COLOR_CONVERSION_MATRIX] = glGetUniformLocation(self.program, "colorConversionMatrix");
    uniforms[UNIFORM_PROJECTION_MARTRIX] = glGetUniformLocation(self.program, "projectionMatrix");
    uniforms[UNIFORM_MODELVIEW_MARTRIX] = glGetUniformLocation(self.program, "modelViewMatrix");
    
    // Release vertex and fragment shaders.
    if (vertShader) {
        glDetachShader(self.program, vertShader);
        glDeleteShader(vertShader);
    }
    if (fragShader) {
        glDetachShader(self.program, fragShader);
        glDeleteShader(fragShader);
    }
    
    return YES;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type URL:(NSURL *)URL
{
    NSError *error;
    NSString *sourceString = [[NSString alloc] initWithContentsOfURL:URL encoding:NSUTF8StringEncoding error:&error];
    if (sourceString == nil) {
        NSLog(@"Failed to load vertex shader: %@", [error localizedDescription]);
        return NO;
    }
    
    GLint status;
    const GLchar *source;
    source = (GLchar *)[sourceString UTF8String];
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(*shader);
        return NO;
    }
    
    return YES;
}

- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    glLinkProgram(prog);
    
#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

- (BOOL)validateProgram:(GLuint)prog
{
    GLint logLength, status;
    
    glValidateProgram(prog);
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

@end
