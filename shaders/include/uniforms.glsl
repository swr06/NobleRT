/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

uniform vec3 shadowLightPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 cameraPosition;
uniform vec3 upPosition;
uniform vec3 skyColor;

uniform vec2 viewResolution;
uniform vec2 pixelSize;

uniform float rainStrength;
uniform int framemod;
uniform int frameCounter;
uniform float frameTime;
uniform float frameTimeCounter;
uniform float centerDepthSmooth;
uniform float near;
uniform float far;
uniform float aspectRatio;
uniform float viewWidth;
uniform float viewHeight;
uniform int worldTime;
uniform int isEyeInWater;

uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
uniform sampler2D colortex8;
uniform sampler2D colortex9;
uniform sampler2D colortex10;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;
uniform sampler2D noisetex;

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 previousCameraPosition;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

const int noiseRes = 256;
const float airIOR = 1.00029;

vec3 shadowDir     = shadowLightPosition * 0.01;
vec3 playerSunDir  = normalize(mat3(gbufferModelViewInverse) * sunPosition);
vec3 playerMoonDir = normalize(mat3(gbufferModelViewInverse) * moonPosition);

/* ATMOSPHERIC SCATTERING CONSTANTS */

const float g  = 0.76;
const float gg = g*g;

const float earthRad = 6371e3;
const float atmosRad = 6481e3;

const float hR = 8.0e3;
const float hM = 1.2e3;

// Coefficients
const vec3 kRlh   = vec3(5.8e-6, 13.3e-6, 33.31e-6);        // Provided by Jessie#7257
const mat2x3 kMie = mat2x3(vec3(21e-6), vec3(21e-6) * 1.1); // Provided by LVutner#5199
const vec3 kOzo   = vec3(3.426e-7, 8.298e-7, 0.356e-7);     // Provided by LVutner#5199

const mat2x3 kScattering = mat2x3(kRlh, kMie[0]);
const mat3x3 kExtinction = mat3x3(kRlh, kMie[0] + kMie[1], kOzo);

const vec3 atmosRayPos = vec3(0.0, earthRad, 0.0);
