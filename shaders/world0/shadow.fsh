/***********************************************/
/*       Copyright (C) Noble SSRT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#version 400 compatibility

varying vec2 texCoords;
varying vec4 color;
uniform sampler2D colortex0;

/*DRAWBUFFERS:05*/
void main() {
    gl_FragData[0] = texture2D(colortex0, texCoords) * color;
}