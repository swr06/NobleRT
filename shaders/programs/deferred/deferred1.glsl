/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/include/atmospherics/atmosphere.glsl"

#ifdef STAGE_VERTEX

    out mat3[2] skyIlluminanceMat;
    out vec3 skyMultScatterIllum;
    out vec3 directIlluminance;

    void main() {
        gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
        texCoords   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

        skyIlluminanceMat = sampleSkyIlluminance(skyMultScatterIllum);

        #if CLOUDS == 1
            directIlluminance = sampleDirectIlluminance();
        #else
            directIlluminance = vec3(0.0);
        #endif
    }

#elif defined STAGE_FRAGMENT

    #if GI == 1
        /* RENDERTARGETS: 3,0,6,12 */

        layout (location = 0) out vec4 shadowmap;
        layout (location = 1) out vec3 sky;
        layout (location = 2) out vec3 skyIlluminance;
        layout (location = 3) out vec4 clouds;
    #else
        /* RENDERTARGETS: 3,0,6,10,12 */

        layout (location = 0) out vec4 shadowmap;
        layout (location = 1) out vec3 sky;
        layout (location = 2) out vec3 skyIlluminance;
        layout (location = 3) out vec4 aoHistory;
        layout (location = 4) out vec4 clouds;
    #endif

    #if CLOUDS == 1
        #include "/include/atmospherics/clouds.glsl"
    #endif
    
    #include "/include/fragment/shadows.glsl"

    in mat3[2] skyIlluminanceMat;
    in vec3 skyMultScatterIllum;
    in vec3 directIlluminance;

    #if GI == 0 && AO == 1 && AO_FILTER == 1
        float filterAO(sampler2D tex, vec2 coords, Material mat, float scale, float radius, float sigma, int steps) {
            float ao = 0.0, totalWeight = 0.0;

            for(int x = -steps; x <= steps; x++) {
                for(int y = -steps; y <= steps; y++) {
                    vec2 offset         = vec2(x, y) * radius * pixelSize;
                    vec2 sampleCoords   = (coords * scale) + offset;
                    if(clamp01(sampleCoords) != sampleCoords) continue;

                    Material sampleMat = getMaterial(coords + offset);

                    float weight  = gaussianDistrib2D(vec2(x, y), sigma);
                          weight *= getDepthWeight(mat.depth0, sampleMat.depth0, 2.0);
                          weight *= getNormalWeight(mat.normal, sampleMat.normal, 8.0);
                          weight  = clamp01(weight);

                    ao          += texture(tex, sampleCoords).a * weight;
                    totalWeight += weight;
                }
            }
            return clamp01(ao * (1.0 / totalWeight));
        }
    #endif

    void main() {
        vec3 viewPos  = getViewPos0(texCoords);
        Material mat  = getMaterial(texCoords);
        bool skyCheck = isSky(texCoords);

        vec3 bentNormal = mat.normal;

        //////////////////////////////////////////////////////////
        /*-------- AMBIENT OCCLUSION / BENT NORMALS ------------*/
        //////////////////////////////////////////////////////////

        #if GI == 0 && AO == 1
            if(!skyCheck) {
                vec4 ao = texture(colortex10, texCoords * AO_RESOLUTION);
                if(any(greaterThan(ao.rgb, vec3(0.0)))) bentNormal = clamp01(ao.rgb);

                aoHistory = ao;

                #if AO_FILTER == 1
                    aoHistory.a = filterAO(colortex10, texCoords, mat, AO_RESOLUTION, 0.3, 2.0, 2);
                #endif
            }
        #endif

        #ifdef WORLD_OVERWORLD
            //////////////////////////////////////////////////////////
            /*----------------- SHADOW MAPPING ---------------------*/
            //////////////////////////////////////////////////////////
            vec4 tmp = texture(colortex2, texCoords);

            shadowmap.a    = 0.0;
            shadowmap.rgb  = !skyCheck ? shadowMap(viewToScene(viewPos), tmp.rgb, shadowmap.a) : vec3(1.0);
            shadowmap.rgb *= tmp.a;

            //////////////////////////////////////////////////////////
            /*------------- ATMOSPHERIC SCATTERING -----------------*/
            //////////////////////////////////////////////////////////
            skyIlluminance = mat.lightmap.y > EPS ? getSkyLight(bentNormal, skyIlluminanceMat) : vec3(0.0);

            if(clamp(texCoords, vec2(0.0), vec2(ATMOSPHERE_RESOLUTION)) == texCoords) {
                vec3 skyRay = normalize(unprojectSphere(texCoords * rcp(ATMOSPHERE_RESOLUTION)));
                     sky    = atmosphericScattering(skyRay, skyMultScatterIllum);
            }

            //////////////////////////////////////////////////////////
            /*---------------- VOLUMETRIC CLOUDS -------------------*/
            //////////////////////////////////////////////////////////
            #if CLOUDS == 1
                
                clouds = vec4(0.0, 0.0, 0.0, 1.0);

                if(clamp(texCoords, vec2(0.0), vec2(CLOUDS_RESOLUTION)) == texCoords) {
                    vec3 scaledViewDir = normalize(getViewPos1(texCoords * rcp(CLOUDS_RESOLUTION)));

                    float distToCloud;
                    vec3 cloudsRay = mat3(gbufferModelViewInverse) * scaledViewDir;
                         clouds    = cloudsScattering(cloudsRay, distToCloud, directIlluminance, skyMultScatterIllum);

                    /* Aerial Perspective */
                    clouds = mix(vec4(0.0, 0.0, 0.0, 1.0), clouds, exp(-1e-4 * distToCloud));

                    /* Reprojection */
                    vec3 prevPos    = reprojectClouds(viewPos, 1e8 * distToCloud);
                    vec4 prevClouds = texture(colortex12, prevPos.xy);

                    // Offcenter rejection from Zombye#7365 (Spectrum - https://github.com/zombye/spectrum)
                    vec2 pixelCenterDist = 1.0 - abs(2.0 * fract(prevPos.xy * viewSize) - 1.0);
                    float centerWeight   = sqrt(pixelCenterDist.x * pixelCenterDist.y) * 0.5 + 0.5;

                    vec2  velocity       = (texCoords - prevPos.xy) * viewSize;
                    float velocityWeight = exp(-length(velocity)) * 0.8 + 0.2;

                    float weight = clamp01(centerWeight * velocityWeight * float(clamp01(prevPos.xy) == prevPos.xy));

                    clouds = mix(clouds, prevClouds, 0.9 * weight);
                }
            #endif
        #endif
    }
#endif
