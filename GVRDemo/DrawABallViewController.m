//
//  DrawABallViewController.m
//  GVRDemo
//
//  Created by mac-vincent on 2017/6/22.
//  Copyright © 2017年 Vincent. All rights reserved.
//

#import "DrawABallViewController.h"
#define ES_PI  (3.14159265f)
@interface DrawABallViewController () {
    GLfloat   *_vertexData; // 顶点数据
    GLfloat   *_texCoords;  // 纹理坐标
    GLushort  *_indices;    // 顶点索引
    GLint    _numVetex;   // 顶点数量
    GLuint  _texCoordsBuffer;// 纹理坐标内存标识
    GLuint  _numIndices; // 顶点索引的数量
    GLuint _vertexBuffer;
     
}
@property(nonatomic,strong)GLKBaseEffect *baseEffect;
@end

@implementation DrawABallViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    GLKView *glkView = (GLKView*)self.view;
    glkView.drawableDepthFormat = GLKViewDrawableDepthFormat24;// 设置深度缓冲区格式
    
    glkView.context = [[EAGLContext alloc]initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    [EAGLContext setCurrentContext:glkView.context];
    
    self.baseEffect = [[GLKBaseEffect alloc]init];
    _numIndices = generateSphere(200, 1.0, &(_vertexData), &(_texCoords), &_indices, &_numVetex);
    
    GLKTextureInfo *textureInfo =
    [GLKTextureLoader textureWithCGImage:[UIImage imageNamed:@"earth-diffuse.jpg"].CGImage options:nil error:nil];
    self.baseEffect.texture2d0.target = textureInfo.target;
    self.baseEffect.texture2d0.name = textureInfo.name;
    
    // 设置世界坐标和视角
    float aspect = fabs(self.view.bounds.size.width / self.view.bounds.size.height);
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
    self.baseEffect.transform.projectionMatrix = projectionMatrix;
    
    // 设置模型坐标
    GLKMatrix4 modelViewMatrix = GLKMatrix4MakeTranslation(0.0f, -1.0f, -6.5f);
    self.baseEffect.transform.modelviewMatrix =  modelViewMatrix;
    [self loadVertexData];
}

-(void)glkView:(GLKView *)view drawInRect:(CGRect)rect{
    
    // 清除颜色缓冲区
    glClearColor(1.0, 0, 1.0, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    
    // 绘制之前必须调用这个方法
    [self.baseEffect prepareToDraw];
    static int i =1;
    if (i < _numIndices-2000){
        i = i+1000;
    }else{
        i = _numIndices;
    }
    
    // 以画单独三角形的方式 开始绘制
    glDrawElements(GL_TRIANGLES, i,GL_UNSIGNED_SHORT, NULL);
}

-(void)update{
    self.baseEffect.transform.modelviewMatrix = GLKMatrix4Rotate(self.baseEffect.transform.modelviewMatrix, 0.1, 0, 1, 0);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
 
}

-(void)loadVertexData{
    
    // 加载顶点坐标数据
    glGenBuffers(1, &_vertexBuffer); // 申请内存
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer); // 将命名的缓冲对象绑定到指定的类型上去
    glBufferData(GL_ARRAY_BUFFER, sizeof(GLfloat)*_numVetex*3,_vertexData, GL_STATIC_DRAW);
    glEnableVertexAttribArray(GLKVertexAttribPosition);  // 绑定到位置上
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 3*sizeof(GLfloat), NULL);
    
    // 加载顶点索引数据
    GLuint _indexBuffer;
    glGenBuffers(1, &_indexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, _numIndices*sizeof(GLushort), _indices, GL_STATIC_DRAW);
    
    
    
    // 加载纹理坐标
    glGenBuffers(1, &_texCoordsBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _texCoordsBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(GLfloat)*_numVetex*2, _texCoords, GL_DYNAMIC_DRAW);
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, 2*sizeof(GLfloat), NULL);
    
}
int generateSphere(int numSlices, float radius, float **vertices,
                  float **texCoords, uint16_t **indices, int *numVertices_out) {
    int i;
    int j;
    int numParallels = numSlices / 2;
    int numVertices = (numParallels + 1) * (numSlices + 1);
    int numIndices = numParallels * numSlices * 6;
    float angleStep = (2.0f * ES_PI) / ((float) numSlices);
    if (vertices != NULL)
        *vertices = malloc(sizeof(float) * 3 * numVertices);
    if (texCoords != NULL)
        *texCoords = malloc(sizeof(float) * 2 * numVertices);
    if (indices != NULL)
        *indices = malloc(sizeof(uint16_t) * numIndices);
    for (int i = 0; i < numParallels + 1; i++) {
        for (int j = 0; j < numSlices + 1; j++) {
            int vertex = (i * (numSlices + 1) + j) * 3;
            if (vertices) {
                (*vertices)[vertex + 0] = radius * sinf(angleStep * (float)i) *
                sinf(angleStep * (float)j);
                (*vertices)[vertex + 1] = radius * cosf(angleStep * (float)i);
                (*vertices)[vertex + 2] = radius * sinf(angleStep * (float)i) *
                cosf(angleStep * (float)j);
            }
            if (texCoords) {
                int texIndex = (i * (numSlices + 1) + j) * 2;
                (*texCoords)[texIndex + 0] = (float)j / (float)numSlices;
                (*texCoords)[texIndex + 1] = 1.0f - ((float)i / (float)numParallels);
            }
        }
    }
    if (indices != NULL) {
        uint16_t *indexBuf = (*indices);
        for (i = 0; i < numParallels ; i++) {
            for (j = 0; j < numSlices; j++) {
                *indexBuf++ = i * (numSlices + 1) + j;
                *indexBuf++ = (i + 1) * (numSlices + 1) + j;
                *indexBuf++ = (i + 1) * (numSlices + 1) + (j + 1);
                
                *indexBuf++ = i * (numSlices + 1) + j;
                *indexBuf++ = (i + 1) * (numSlices + 1) + (j + 1);
                *indexBuf++ = i * (numSlices + 1) + (j + 1);
            }
        }
    }
    if (numVertices_out) {
        *numVertices_out = numVertices;
    }
    return numIndices;
}


@end
