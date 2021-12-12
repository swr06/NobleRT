/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec3 viewToShadowClip(vec3 viewPos) {
	vec4 shadowPos = gbufferModelViewInverse * vec4(viewPos, 1.0);
	     shadowPos = shadowModelView  * shadowPos;
         shadowPos = shadowProjection * shadowPos;
	return vec3(distort(shadowPos.xy), shadowPos.z);
}

vec3 viewToShadowView(vec3 viewPos) {
	vec4 shadowPos = gbufferModelViewInverse * vec4(viewPos, 1.0);
	     shadowPos = shadowModelView  * shadowPos;
	return vec3(distort(shadowPos.xy), shadowPos.z);
}

float visibility(sampler2D tex, vec3 sampleCoords) {
    return step(sampleCoords.z - 1e-3, texture(tex, sampleCoords.xy).r);
}

vec3 sampleShadowColor(vec3 sampleCoords) {
    if(clamp01(sampleCoords) != sampleCoords) return vec3(1.0);
    float shadowVisibility0 = visibility(shadowtex0, sampleCoords);
    float shadowVisibility1 = visibility(shadowtex1, sampleCoords);

    /*
    float currDepth   = getViewPos0(texCoords).z;
    float shadowDepth = getViewPos0(sampleCoords.xy).z;

    float sss           = unpack2x8(texture(colortex2, sampleCoords.xy).y).y;
    float dist          = abs(currDepth - shadowDepth);
    float transmittance = exp(-(1.0 / sss) * dist);
    */
    
    vec4 shadowColor0     = texture(shadowcolor0, sampleCoords.xy);
    vec3 transmittedColor = shadowColor0.rgb * (1.0 - shadowColor0.a);
    return mix(transmittedColor * shadowVisibility1, vec3(1.0), shadowVisibility0);
}

#if SOFT_SHADOWS == 0

    vec3 PCF(vec3 sampleCoords, mat2 rotation) {
	    vec3 shadowResult = vec3(0.0); int SAMPLES;

        for(int x = 0; x < SHADOW_SAMPLES; x++) {
            for(int y = 0; y < SHADOW_SAMPLES; y++) {
                vec3 currSampleCoords = vec3(sampleCoords.xy + (rotation * vec2(x, y)), sampleCoords.z);

                shadowResult += sampleShadowColor(currSampleCoords);
                SAMPLES++;
            }
        }
        return shadowResult / float(SAMPLES);
    }
#else

    float findBlockerDepth(vec3 sampleCoords, mat2 rotation, float phi) {
        float avgBlockerDepth = 0.0;
        int BLOCKERS = 0;

        for(int i = 0; i < BLOCKER_SEARCH_SAMPLES; i++) {
            vec2 offset = BLOCKER_SEARCH_RADIUS * vogelDisk(i, BLOCKER_SEARCH_SAMPLES, phi) * pixelSize;
            float z     = texture(shadowtex0, sampleCoords.xy + offset).r;

            if(sampleCoords.z - 1e-3 > z) {
                avgBlockerDepth += z;
                BLOCKERS++;
            }
        }
        return BLOCKERS > 0 ? avgBlockerDepth / BLOCKERS : -1.0;
    }

    vec3 PCSS(vec3 sampleCoords, mat2 rotation, float phi) {
        float avgBlockerDepth = findBlockerDepth(sampleCoords, rotation, phi);
        if(avgBlockerDepth < 0.0) return vec3(1.0);

        float penumbraSize = (max0(sampleCoords.z - avgBlockerDepth) * LIGHT_SIZE) / avgBlockerDepth;

        vec3 shadowResult = vec3(0.0);
        for(int i = 0; i < PCSS_SAMPLES; i++) {
            vec2 offset           = rotation * (penumbraSize * vogelDisk(i, PCSS_SAMPLES, phi));
            vec3 currSampleCoords = vec3(sampleCoords.xy + offset, sampleCoords.z);

            shadowResult += sampleShadowColor(currSampleCoords);
        }
        return shadowResult / float(PCSS_SAMPLES);
    }
#endif

vec3 shadowMap(vec3 viewPos) {
    vec3 sampleCoords = viewToShadowClip(viewPos) * 0.5 + 0.5;
    if(clamp01(sampleCoords) != sampleCoords) return vec3(1.0);
    
    float theta    = (TAA == 1 ? randF(rngState) : uniformNoise(1, blueNoise).x) * TAU;
    float cosTheta = cos(theta), sinTheta = sin(theta);
    mat2 rotation  = mat2(cosTheta, -sinTheta, sinTheta, cosTheta) / shadowMapResolution;

    #if SOFT_SHADOWS == 0
        return PCF(sampleCoords, rotation);
    #else
        return PCSS(sampleCoords, rotation, theta / TAU);
    #endif
}
