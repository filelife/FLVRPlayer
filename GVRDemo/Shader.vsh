//
//  Shader.fsh
//  GVRDemo
//
//  Created by mac-vincent on 2017/5/17.
//  Copyright © 2017年 Vincent. All rights reserved.
//
// Vertex Shader
// @顶点着色器
//attattribute为输入数据，未声明为attribute的变量即为输出变量，即将传递给FSH。
varying vec2 texCoordVarying;
//外部程序可通过 glBindAttribLocation将一个attribute 名与一个index绑定起来。
attribute vec4 position;// vertex position in object coordinates;
attribute vec2 texCoord;// texture coordinate from app
//uniform 是全局变量
uniform float preferredRotation;// 首选旋转
//mat4 是一个4*4的视口矩阵
uniform mat4 projectionMatrix;//用户视角
uniform mat4 modelViewMatrix; //存储球体旋转的位置

void main()
{
    mat4 rotationMatrix = mat4( cos(preferredRotation), -sin(preferredRotation), 0.0, 0.0,
                               sin(preferredRotation),  cos(preferredRotation), 0.0, 0.0,
                               0.0,					    0.0, 1.0, 0.0,
                               0.0,					    0.0, 0.0, 1.0);
    // 坐标最后渲染的位置是通过： 用户视角矩阵 、 球体旋转位置矩阵 、旋转角度矩阵  用户视角举证共同确定的。
    gl_Position = projectionMatrix * modelViewMatrix * rotationMatrix * position;// * modelViewMatrix * projectionMatrix;
    texCoordVarying = texCoord;
}

