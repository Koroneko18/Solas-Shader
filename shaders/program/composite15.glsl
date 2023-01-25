//Settings//
#include "/lib/common.glsl"

#ifdef FSH

//Varyings//
in vec2 texCoord;

//Uniforms//
#if defined TAA || defined FXAA || defined DOF
uniform float viewWidth, viewHeight;
#endif

#if defined DOF || defined FXAA
uniform float aspectRatio;
#endif

#ifdef DOF
uniform float centerDepthSmooth;
#endif

#ifdef TAA
uniform vec3 cameraPosition, previousCameraPosition;

uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferPreviousModelView, gbufferModelViewInverse;

#ifdef SSGI
uniform sampler2D colortex6;
#endif

uniform sampler2D colortex5;
#endif

uniform sampler2D colortex1;

#if defined TAA || defined DOF
uniform sampler2D depthtex1;

uniform mat4 gbufferProjectionInverse;

#ifdef DOF
uniform mat4 gbufferProjection;
#endif
#endif

//Optifine Constants//
#ifdef DOF
const bool colortex0MipmapEnabled = true;
#endif

//Common Functions//
#ifdef FXAA
float getLuminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}
#endif

//Includes//
#ifdef DOF
#include "/lib/post/dofBlur.glsl"
#include "/lib/util/ToView.glsl"
#endif

#ifdef FXAA
#include "/lib/antialiasing/fxaa.glsl"
#endif

#ifdef TAA
#include "/lib/util/reprojection.glsl"
#include "/lib/antialiasing/taa.glsl"
#endif

void main() {
	vec3 color = texture2D(colortex1, texCoord).rgb;

	#ifdef FXAA
	color = FXAA311(color);	
	#endif

	#if defined DOF || defined TAA
	float z1 = texture2D(depthtex1, texCoord).r;
	#endif

	#ifdef DOF
	vec3 viewPos = ToView(vec3(texCoord, z1));
	color = getDepthOfField(color, viewPos, z1);
	#endif

	#ifdef TAA
    vec4 tempData = vec4(texture2D(colortex5, texCoord).r, 0.0, 0.0, 0.0);
	tempData = TemporalAA(color, colortex1, colortex5, tempData.r, z1);
	#endif

	/* DRAWBUFFERS:1 */
	gl_FragData[0].rgb = color;

	#ifdef TAA
	/* DRAWBUFFERS:15 */
	gl_FragData[1] = tempData;
	#endif
}

#endif

/////////////////////////////////////////////////////////////////////////////////////

#ifdef VSH

//Varyings//
out vec2 texCoord;

void main() {
	//Coords
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	
	//Position
	gl_Position = ftransform();
}

#endif