#version 400 compatibility
#include "/programs/extensions.glsl"

/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

varying vec2 texCoords;

#include "/settings.glsl"
#include "/programs/common.glsl"
#include "/lib/fragment/svgf.glsl"

void main() {
    vec3 globalIllumination = texture(colortex5, texCoords).rgb;
    if(!isSky(texCoords)) {
        #if GI == 1
            #if GI_FILTER == 1
                vec3 viewPos = getViewPos(texCoords);
                vec3 normal = normalize(decodeNormal(texture(colortex1, texCoords).xy));
                
                globalIllumination = SVGF(colortex5, viewPos, normal, texCoords);
            #endif
        #endif
    }
    /*DRAWBUFFERS:5*/
    gl_FragData[0] = vec4(globalIllumination, 1.0);
}
