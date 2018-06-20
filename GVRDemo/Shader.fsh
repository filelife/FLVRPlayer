//
//  Shader.fsh
//  GVRDemo
//
//  Created by mac-vincent on 2017/5/17.
//  Copyright © 2017年 Vincent. All rights reserved.
//
// Fragment Shader


//varying –用于顶点shader和片断shader间传递的插值数据，在顶点shader中可写，在片断shader中只读。
varying highp vec2 texCoordVarying;//由顶点着色器传入，lowp表示低精度
//precision mediump float设置float的精度为mediump，还可设置为lowp和highp，主要是出于性能考虑。
precision mediump float;
// simpler是一种特殊的uniform，用于呈现纹理，可用于vertex shader和fragment shader。
//Luma 采样器
uniform sampler2D SamplerY;
//Chroma 采样器
uniform sampler2D SamplerUV;
//3x3矩阵
uniform mat3 colorConversionMatrix;

void main()
{
	mediump vec3 yuv;
	lowp vec3 rgb;
	
	// Subtract constants to map the video range start at 0
    yuv.x = (texture2D(SamplerY, texCoordVarying).r);// - (16.0/255.0));
    yuv.yz = (texture2D(SamplerUV, texCoordVarying).ra - vec2(0.5, 0.5));
	
	rgb = colorConversionMatrix * yuv;
    // 采样器从纹理对象中返回纹理颜色值
	gl_FragColor = vec4(rgb,1);
//    gl_FragColor = vec4(1, 0, 0, 1);
}
