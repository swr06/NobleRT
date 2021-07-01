/***********************************************/
/*       Copyright (C) Noble SSRT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

float distanceSquared(vec3 v1, vec3 v2) {
	vec3 u = v2 - v1;
	return dot(u, u);
}

float sdSphere(vec3 rayPos, vec3 spherePos, float radius)  {
    return length(rayPos - spherePos) - radius;
}

float cdist(vec2 coord) {
	return max(abs(coord.x - 0.5), abs(coord.y - 0.5)) * 1.85;
}

float distx(float dist) {
    return (far * (dist - near)) / (dist * (far - near));
}

float saturate(float x) {
	return clamp(x, 0.0, 1.0);
}

/*
	Thanks to the 2 people who gave me
	their hemisphere sampling functions! <3
*/

// Written by n_r4h33m#7259
vec3 hemisphereSample(float u, float v) {
    float phi = v * 2.0 * PI;
    float cosTheta = 1.0 - u;
    float sinTheta = sqrt(1.0 - cosTheta * cosTheta);
    return vec3(cos(phi) * sinTheta, sin(phi) * sinTheta, cosTheta);
}

// Written by xirreal#0281
vec3 randomHemisphereDirection(vec3 n, vec2 r) {
    vec3 uu = normalize(cross(n, vec3(0.0, 1.0, 1.0)));
    vec3 vv = cross(uu, n);

    float ra = sqrt(r.y);
    float rx = ra * cos(PI2 * r.x);
    float ry = ra * sin(PI2 * r.x);
    float rz = sqrt(1.0 - r.y);
    vec3 rr = vec3(rx * uu + ry * vv + rz * n);

    return normalize(rr);
}