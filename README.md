# VR视频开发分享
##### 为了让大家更好的阅读Demo代码，以下简单介绍相关知识及实现思路。
预览Demo效果图：
![Demo效果图.gif](/pic.gif)

## Step 0.
#### 0.1 渲染VR场景视频的大致思路：
![image](http://upload-images.jianshu.io/upload_images/1049769-5e8b49b5dd0721fc.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
逐帧读取VR视频的逐帧数据，之后通过着色器渲染到球体模型上，获取球体中心的作为视觉取镜点，通过重力感应接受头部移动向量方向，更新手机的映射取镜点。

![image](http://upload-images.jianshu.io/upload_images/1049769-1c8d8124eecef239.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
## Step 1.
#### 1.1 获取模型
#### 首先，需要创建一个球体。在OpenGL中创建模型，需要顶点和纹理坐标，通过3D MAX等工具制作的obj模型在iOS中识别不了，所以需要进行转换为OpenGL使用的顶点数组。

#### 有位大神写了一个模型转换为顶点数组的工具：https://github.com/HBehrens/obj2opengl
#### 产物是一套球体模型的顶点数据+顶点索引；
### 1.2 模型数据描述
#### 为了更好理解顶点数据和定点索引的旨意，我们来分析一个正方形模型的建模数据。

```
GLfloat squareVertexData[] =
{
    0.5, -0.5, 0.0f,    1.0f, 0.0f, //右下
    -0.5, 0.5, 0.0f,    0.0f, 1.0f, //左上
    -0.5, -0.5, 0.0f,   0.0f, 0.0f, //左下
    0.5, 0.5, -0.0f,    1.0f, 1.0f, //右上
};
```
##### 这些点我们本意想要描述的是一个正方形，但是由于手机屏幕坐标系内XY轴比例并不一样，所以最终会产出以下形状：
![image](http://upload-images.jianshu.io/upload_images/1396375-eaefa9be0eec6ad0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

##### 对于初学者还有个容易忽视的技术点,那就是 ==在OpenGL ES只能绘制三角形==,不能绘制多边形,但是在OpenGL中确实可以直接绘制多边形.

```
//顶点索引
GLuint indices[] ={ 
  0, 1, 2,
  1, 3, 0
};
```
![image](http://upload-images.jianshu.io/upload_images/1396375-2da9173beccbc716.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

##### 我们还可以通过以下顶点+索引，绘制一个3D的正方体。
```
//顶点数据，前三个是顶点坐标， 中间三个是顶点颜色，    最后两个是纹理坐标
GLfloat attrArr[] =
{
    -0.5f, 0.5f, 0.0f,       0.0f, 0.0f, 0.5f,       0.0f, 1.0f,//左上
    0.5f, 0.5f, 0.0f,        0.0f, 0.5f, 0.0f,       1.0f, 1.0f,//右上
    -0.5f, -0.5f, 0.0f,      0.5f, 0.0f, 1.0f,       0.0f, 0.0f,//左下
    0.5f, -0.5f, 0.0f,       0.0f, 0.0f, 0.5f,       1.0f, 0.0f,//右下
    -0.5f, 0.5f, 1.0f,       0.0f, 0.0f, 0.5f,       0.0f, 1.0f,//后方左上
    0.5f, 0.5f, 1.0f,        0.0f, 0.5f, 0.0f,       1.0f, 1.0f,//后方右上
    -0.5f, -0.5f, 1.0f,      0.5f, 0.0f, 1.0f,       0.0f, 0.0f,//后方左下
    0.5f, -0.5f, 1.0f,       0.0f, 0.0f, 0.5f,       1.0f, 0.0f,//后方右下
};

```


```
//顶点索引
    GLuint indices[] =
    {
        0, 3, 2,
        0, 1, 3,
        0, 4, 1,
        5, 4, 1,
        1, 5, 3,
        7, 5, 3,
        2, 6, 3,
        6, 7, 3,
        0, 6, 2,
        0, 4, 6,
        4, 5, 7,
        4, 6, 7,
    };

```

## Step 2.
### 2.1渲染基础 - 缓存

#### CPU的运算能力（每秒亿次级别）远高于其对内存的读写能力（每秒百万次级别），为了优化效率，避免产生数据饥饿，在OpenGL ES中，可以让程序从CPU的内存中复制数据到GPU控制的连续RAM缓存中，GPU在取得一个缓存数据之后，便会独占该缓存，从而尽可能有效的读写内存数据，缓存数据包含：几何数据、颜色、灯光效果等等。
#### 缓存的生命周期：
#### 2.1.1.  生成（Generate）：请求OpenGLES为GPU控制的缓存生成一个独一无二的标志符。
#####  对应函数：glGenBuffers()
#### 2.1.2.  绑定（Bind）告诉OpenGLES为接下来的运算使用一个缓存。
#####  对应函数：glBindBuffer()
#### 2.1.3.  启用（Enable）或者禁止（Disable）：告诉OpenGLES再接下来的渲染中，是否使用缓存数据。
#####  对应函数：glEnableVertexAttribArray() 
#### 2.1.4.  设置指针（Set Points）：告诉OpenGLES在缓存中的数据存储的类型和所需要访问的数据的内存指针偏移。
#####  对应函数：geVertexAttribPointer() 
#### 2.1.5.  绘图（Draw）：告诉OpenGLES使用当前绑定并启用的缓存中的数据渲染整个场景或者某个场景的一部分。
#####  对应函数：glDrawArrays()
#### 2.1.6.  删除（Delete）：告诉OpenGLES删除以前生成的缓存并释放相关的资源。
#####  对应函数：glDeleteBuffers()

### 2.2 一个3D场景的几何数据
2.2.1.  坐标系（笛卡尔坐标系）:OpeGLES坐标系没有单位，点{1,0,0}到点{2,0,0}的距离就是沿着X轴的的1单位。
2.2.2.  矢量：矢量是理解现代GPU的关键，因为图形处理器就是大规模矢量处理器。
2.2.3.  点、线、三角形：OpenGLES只渲染顶点、线段和三角形。下图就是一种渲染案例，通过点、线、三角形渲染环形体。


### 2.3 Core Animation层：
#### 由于iOS操作系统不会让应用直接向前帧缓存或者后帧缓存绘图，也不会让应用直接控制前帧缓存和后帧缓存之间的切换。所以iOS使用Core Animation合成器去控制所有绘制层的合成。（例如：StatusBar层+开发者提供的渲染层 = 屏幕最终显示像素）
#### Core Animation合成器使用OpenGLES来尽可能高效地控制GPU、混合层和切换帧缓存，因此Core Animation合成器合成图像形成一个合成结果的过程，都和OpenGLES有关。
![](http://i1.piimg.com/588926/66d08dd4fbce98bf.jpg)

### 2.4 GLKView/GLKViewController:
#### GLKView/GLKViewController都是GLKit框架的一部分。GLKView是UIView的子类，GLKView简化了 通过CoreAnimation对于：创建帧缓存、管理帧缓存、绘制帧缓存的所需要作的工作。于GLKView相关的GLKViewController是视图的委托，并接收当视图需要重绘时的消息。

## Step 3.
#### 理解球体内的取景视角
![image](http://upload-images.jianshu.io/upload_images/1049769-89e678b04bbfd761.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
##### 球坐标系(r,θ,φ)与直角坐标系(x,y,z)的转换关系:
##### x=rsinθcosφ
##### y=rsinθsinφ
##### z=rcosθ
![image](http://upload-images.jianshu.io/upload_images/1049769-7a56a3dcd4507921.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

## Step 4.

### 代码浅析。

##### 1.  GLKBaseEffecty： 隐藏了iOS设备支持的多格OpenGLES版本之间的差异。在应用中使用BaseEffect能够减少代码量,例如简化避免我们去使用OpenGLES2中的Shading Lauguage。
##### EAGL:Embedded Apple GL
##### 2.  EAGLContext： Context上下文是为了多任务在互不干扰情况下，共享图像的硬件设备而存在的， EAGLContext则提供并行工作的函数方法，并控制GPU去执行渲染运算。
##### 3.  EAGLSharegroup： 管理Context中的OpenGL ES对象，Context需要通过EAGLSharegroup对象创建和管理的。
![image](http://my.csdn.net/uploads/201207/22/1342963740_1119.png)

##### 4.  glTexParameter :函数用于制定纹理的应用方式。[[滤波模式](https://wenku.baidu.com/view/398a1ceb27d3240c8547ef8b.html)（第14页）]

```
纹理放大与缩小如下图
/* TextureParameterName */
//提供纹理放大缩小滤波
#define GL_TEXTURE_MAG_FILTER                            0x2800
#define GL_TEXTURE_MIN_FILTER                            0x2801
#define GL_TEXTURE_WRAP_S                                0x2802
#define GL_TEXTURE_WRAP_T                                0x2803
@ glTexParameteri (GLenum target, GLenum pname, GLint param);
//glTexParameterf vs glTexParameteri：不同点在于 integer和 float类型入参。
//In the case where the pname (second) parameter is GL_TEXTURE_WRAP_S where you are passing an enum you should use glTexParameteri but for other possible values such as GL_TEXTURE_MIN_LOD and GL_TEXTURE_MAX_LOD it makes sense to pass a float parameter using glTexParameterf. 
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_REPEAT);
glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
```

##### 5.  纹理空间映射到对象空间上产生了Wrap，关于S方向和T方向上的延伸方案：

```
#define GL_TEXTURE_WRAP_S                                0x2802
#define GL_TEXTURE_WRAP_T                                0x2803
```

##### 6.  纹理在做Mipmap(纹理映射)变化中产生的缩小方案：


### 采样方案：
``` 
点采样方法：最近纹素的纹理值。
线性滤波：最近领域（2x2）纹素加权平均值。
```



## 补充两点：
##### 1.  [Shader语法介绍](http://blog.csdn.net/icetime17/article/details/50436927)
##### 2.  [齐次记法](http://blog.csdn.net/ys5773477/article/details/53001780)
