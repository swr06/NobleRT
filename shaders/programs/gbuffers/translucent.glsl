/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/include/common.glsl"
#include "/include/atmospherics/atmosphere.glsl"
#include "/include/fragment/water.glsl"

#ifdef STAGE_VERTEX

	#define attribute in
	attribute vec4 at_tangent;
	attribute vec3 mc_Entity;

	flat out int blockId;
	out vec2 texCoords;
	out vec2 lmCoords;
	out vec3 viewPos;
	out vec3 geoNormal;
	out vec3 skyIlluminance;
	out vec3 directIlluminance;
	out vec4 vertexColor;
	out mat3 TBN;

	void main() {
		texCoords   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
		lmCoords    = gl_MultiTexCoord1.xy * rcp(240.0);
		vertexColor = gl_Color;

    	geoNormal = mat3(gbufferModelViewInverse) * (gl_NormalMatrix * gl_Normal);
    	viewPos   = transMAD(gl_ModelViewMatrix, gl_Vertex.xyz);

    	vec3 tangent = mat3(gbufferModelViewInverse) * (gl_NormalMatrix * (at_tangent.xyz / at_tangent.w));
		TBN 		 = mat3(tangent, cross(tangent, geoNormal), geoNormal);

		blockId 	= int((mc_Entity.x - 1000.0) + 0.25);
		gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;

		directIlluminance = sampleDirectIlluminance();

		#if TAA == 1
			gl_Position.xy += taaJitter(gl_Position);
    	#endif
	}

#elif defined STAGE_FRAGMENT

	/* RENDERTARGETS: 1,4 */

	layout (location = 0) out uvec4 data;
	layout (location = 1) out vec3 sceneColor;

	flat in int blockId;
	in vec2 texCoords;
	in vec2 lmCoords;
	in vec3 viewPos;
	in vec3 geoNormal;
	in vec3 skyIlluminance;
	in vec3 directIlluminance;
	in vec4 vertexColor;
	in mat3 TBN;

	#include "/include/fragment/brdf.glsl"
	#include "/include/fragment/shadows.glsl"

	void main() {
		vec4 albedoTex   = texture(colortex0, texCoords);
		vec4 normalTex   = texture(normals,   texCoords);
		vec4 specularTex = texture(specular,  texCoords);

		if(albedoTex.a < 0.102) discard;

		albedoTex *= vertexColor;

		Material mat;

		#if WHITE_WORLD == 1
	    	mat.albedo = vec3(1.0);
    	#endif

		// WOTAH
		if(blockId == 1) { 
			albedoTex  = vec4(0.0);
			mat.F0 	   = waterF0;
			mat.rough  = 0.0;
			mat.normal = TBN * getWaterNormals(viewToWorld(viewPos), WATER_OCTAVES);
		
		} else {
			mat.F0         = specularTex.y;
    		mat.rough      = clamp01(hardCodedRoughness != 0.0 ? hardCodedRoughness : 1.0 - specularTex.x);
    		mat.ao         = normalTex.z;
			mat.emission   = specularTex.w * maxVal8 < 254.5 ? specularTex.w : 0.0;
    		mat.subsurface = (specularTex.z * maxVal8) < 65.0 ? 0.0 : specularTex.z;

    		mat.albedo = albedoTex.rgb;

			if(all(greaterThan(normalTex, vec4(EPS)))) {
				mat.normal.xy = normalTex.xy * 2.0 - 1.0;
				mat.normal.z  = sqrt(1.0 - dot(mat.normal.xy, mat.normal.xy));
				mat.normal    = TBN * mat.normal;
			}

			#if GI == 0
				if(mat.F0 * maxVal8 <= 229.5) {
					vec3 scenePos = viewToScene(viewPos);

					#if TONEMAP == 0
       					mat.albedo = sRGBToAP1Albedo(mat.albedo);
    				#endif

					vec3 skyLight  = vec3(0.0);
					vec4 shadowmap = vec4(1.0, 1.0, 1.0, 0.0);

					#ifdef WORLD_OVERWORLD
						if(mat.lightmap.y > EPS) {
							vec3 tmp = vec3(0.0);
							skyLight = getSkyLight(mat.normal, sampleSkyIlluminance(tmp));
						}
						shadowmap.rgb = shadowMap(scenePos, geoNormal, shadowmap.a);
					#endif

					sceneColor = computeDiffuse(scenePos, shadowLightVector, mat, shadowmap, directIlluminance, skyLight, 1.0);
				}
			#endif
		}
	
		vec2 encNormal = encodeUnitVector(mat.normal);

		vec3 labPbrData0 = vec3(mat.rough, lmCoords);
		vec4 labPbrData1 = vec4(mat.ao, mat.emission, mat.F0, mat.subsurface);
	
		uvec4 shiftedData0  = uvec4(round(labPbrData0   * vec3(maxVal8, 511.0, 511.0)), blockId) << uvec4(0, 8, 17, 26);
		uvec4 shiftedData1  = uvec4(round(labPbrData1   * maxVal8))                              << uvec4(0, 8, 17, 26);
		uvec3 shiftedAlbedo = uvec3(round(albedoTex.rgb * vec3(2047.0, 1023.0, 2047.0)))         << uvec3(0, 11, 21);
		uvec2 shiftedNormal = uvec2(round(encNormal     * maxVal16))                             << uvec2(0, 16);

		data.x = shiftedData0.x  | shiftedData0.y  | shiftedData0.z | shiftedData0.w;
		data.y = shiftedData1.x  | shiftedData1.y  | shiftedData1.z | shiftedData1.w;
		data.z = shiftedAlbedo.x | shiftedAlbedo.y | shiftedAlbedo.z;
		data.w = shiftedNormal.x | shiftedNormal.y;
	}
#endif
