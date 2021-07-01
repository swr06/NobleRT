/***********************************************/
/*       Copyright (C) Noble SSRT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#version 400 compatibility

#include "/settings.glsl"
#include "/lib/util/distort.glsl"

varying vec2 texCoords;
varying vec4 color;

void main(){
    gl_Position = ftransform();
    gl_Position.xyz = distort(gl_Position.xyz);
    texCoords = gl_MultiTexCoord0.st;
    color = gl_Color;
}