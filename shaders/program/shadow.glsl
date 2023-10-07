//Settings//
#include "/lib/common.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
#ifdef WATER_CAUSTICS
flat in int mat;
#endif

in vec2 texCoord;

#ifdef WATER_CAUSTICS
in vec3 worldPos;
#endif

in vec4 color;

//Uniforms//
#ifdef WATER_CAUSTICS
uniform int isEyeInWater;

uniform float frameTimeCounter;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 fogColor;
uniform vec3 cameraPosition;

uniform sampler2D noisetex;
#endif

uniform sampler2D tex;

//Common Variables//
#ifdef WATER_CAUSTICS
float eBS = eyeBrightnessSmooth.y / 240.0;
#endif

//Includes//
#ifdef WATER_CAUSTICS
#include "/lib/water/waterCaustics.glsl"
#endif

//Program//
void main() {
    vec4 albedo = texture2D(tex, texCoord) * color;

	float glass = float(mat == 3);

	if (albedo.a < 0.01) discard;

    #ifdef SHADOW_COLOR
	albedo.rgb = mix(vec3(1.0), albedo.rgb, 1.0 - pow(1.0 - albedo.a, 1.5));
	albedo.rgb *= albedo.rgb;

	#ifdef WATER_CAUSTICS
	if (mat == 1){
		float caustics = getWaterCaustics(worldPos + cameraPosition);
		albedo.rgb = vec3(0.5, 0.9, 1.7) * caustics * WATER_CAUSTICS_STRENGTH;
	}
	#endif

	albedo.rgb *= 1.0 - pow32(albedo.a);

	if (glass > 0.5 && albedo.a < 0.35) discard;
	#endif
	
	gl_FragData[0] = albedo;
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
flat out int mat;

out vec2 texCoord;

#ifdef WATER_CAUSTICS
out vec3 worldPos;
#endif

out vec4 color;

//Uniforms//
#ifdef WAVING_BLOCKS
uniform float frameTimeCounter;

uniform vec3 cameraPosition;
#endif

uniform mat4 shadowProjection, shadowProjectionInverse;
uniform mat4 shadowModelView, shadowModelViewInverse;

//Attributes//
attribute vec4 mc_Entity;

#ifdef WAVING_BLOCKS
attribute vec4 mc_midTexCoord;
#endif

//Includes//
#ifdef WAVING_BLOCKS
#include "/lib/util/waving.glsl"
#endif

//Program//
void main() {
	//Coord
	texCoord = gl_MultiTexCoord0.xy;

	#ifdef WAVING_BLOCKS
	vec2 lightMapCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	lightMapCoord = clamp(lightMapCoord, vec2(0.0), vec2(0.9333, 1.0));
	#endif

	//Materials
	mat = int(mc_Entity.x);
	
	//Color & Position
	color = gl_Color;

	vec4 position = shadowModelViewInverse * shadowProjectionInverse * ftransform();

	#ifdef WAVING_BLOCKS
	float istopv = gl_MultiTexCoord0.t < mc_midTexCoord.t ? 1.0 : 0.0;
	position.xyz = getWavingBlocks(position.xyz, istopv, lightMapCoord.y);
	#endif

	#ifdef WATER_CAUSTICS
	worldPos = position.xyz;
	#endif

	gl_Position = shadowProjection * shadowModelView * position;

	float dist = sqrt(gl_Position.x * gl_Position.x + gl_Position.y * gl_Position.y);
	float distortFactor = dist * shadowMapBias + (1.0 - shadowMapBias);
	
	gl_Position.xy *= 1.0 / distortFactor;
	gl_Position.z = gl_Position.z * 0.2;
}

#endif