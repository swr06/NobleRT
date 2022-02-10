/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* DRAWBUFFERS:04 */

layout (location = 0) out vec4 color;
layout (location = 1) out vec3 bloomBuffer;

#include "/include/utility/blur.glsl"
#include "/include/post/bloom.glsl"

#if DOF == 1
    // https://en.wikipedia.org/wiki/Circle_of_confusion#Determining_a_circle_of_confusion_diameter_from_the_object_field
    float getCoC(float fragDepth, float cursorDepth) {
        return fragDepth < 0.56 ? 0.0 : abs((FOCAL / APERTURE) * ((FOCAL * (cursorDepth - fragDepth)) / (fragDepth * (cursorDepth - FOCAL)))) * 0.5;
    }

    void depthOfField(inout vec3 color, vec2 coords, sampler2D tex, int quality, float radius, float coc) {
        vec3 dof   = vec3(0.0);
        vec2 noise = uniformAnimatedNoise(vec2(randF(), randF()));

        vec2 caOffset;

        #if CHROMATIC_ABERRATION == 1
            float distFromCenter = pow2(distance(coords, vec2(0.5)));
                  caOffset       = vec2(ABERRATION_STRENGTH * distFromCenter) * coc / pow2(quality);
        #endif

        for(int i = 0; i < quality; i++) {
            for(int j = 0; j < quality; j++) {
                vec2 offset = ((vec2(i, j) + noise) - quality * 0.5) / quality;
            
                if(length(offset) < 0.5) {
                    vec2 sampleCoords = coords + (offset * radius * coc * pixelSize);

                    #if CHROMATIC_ABERRATION == 1
                        dof += vec3(
                            texture(tex, sampleCoords + caOffset).r,
                            texture(tex, sampleCoords).g,
                            texture(tex, sampleCoords - caOffset).b
                        );
                    #else
                        dof += texture(tex, sampleCoords).rgb;
                    #endif
                }
            }
        }
        color = dof * (1.0 / pow2(quality));
    }
#endif

void main() {
    color = texture(colortex0, texCoords);
    
    #if DOF == 1
        float coc = getCoC(linearizeDepth(texture(depthtex0, texCoords).r), linearizeDepth(centerDepthSmooth));
        depthOfField(color.rgb, texCoords, colortex0, 8, DOF_RADIUS, coc);
    #endif

    #if BLOOM == 1
        bloomBuffer = writeBloom();
    #endif

    #if VL == 1
        #if VL_FILTER == 1
            color.rgb += gaussianBlur(texCoords, colortex7, 1.5, 2.0, 4).rgb;
        #else
            color.rgb += texture(colortex7, texCoords).rgb;
        #endif
    #endif
}
