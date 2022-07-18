float amount1 = mix(VC_AMOUNT * (1.0 + moonPhase / 21.0), 2.0, rainStrength);
const float distanceThreshold = VC_SAMPLES * 32.0;

float get3DNoise(vec3 pos) {
	pos *= 0.4 + moonPhase / 21.0;
	pos.xz *= 0.4;

	vec3 floorPos = floor(pos);
	vec3 fractPos = fract(pos);

	vec2 noiseCoord = (floorPos.xz + fractPos.xz + floorPos.y * 16.0) * 0.015625;

	float planeA = texture2D(noisetex, noiseCoord).r;
	float planeB = texture2D(noisetex, noiseCoord + 0.25).r;

	return mix(planeA, planeB, fractPos.y);
}

vec2 getCloudSample(vec3 pos, in float firstLayer, float secondLayer) {
	float noise = get3DNoise(pos * 0.625 + frameTimeCounter * 0.4) * 1.0;
		  noise+= get3DNoise(pos * 0.250 + frameTimeCounter * 0.3) * 1.5;
		  noise+= get3DNoise(pos * 0.125 + frameTimeCounter * 0.2) * 3.0;
		  noise+= get3DNoise(pos * 0.025 + frameTimeCounter * 0.1) * 9.0;

	#ifdef VL
	float result0 = noise * VL_AMOUNT - (10.0 + firstLayer * 5.0);
	#else
	float result0 = 0.0;
	#endif

	float result1 = noise * amount1 - (10.0 + secondLayer * 5.0);

	return clamp(vec2(result0, result1), vec2(0.0), vec2(1.0));
}

void computeVolumetricEffects(vec4 translucent, vec3 viewPos, vec2 newTexCoord, float depth0, float depth1, float dither, inout vec4 vlOut1, inout vec4 vlOut2) {
	if (clamp(texCoord, vec2(0.0), vec2(VOLUMETRICS_RESOLUTION + 1e-3)) == texCoord) {
		#ifdef VL
		vec4 firstCloudLayer = vec4(0.0);
		#endif

		vec4 secondCloudLayer = vec4(0.0);

		#ifdef VL
		vec3 shadowCol = vec3(0.0);

		float shadowBrightness = 10.0 * (1.0 + float(isEyeInWater == 1) * 4.0);
		float lViewPos = length(viewPos.xz) * 0.000125;
		float firstLayerVisibility = clamp(VL_OPACITY, cameraPosition.y * 0.005, 1.0) * (1.0 - dfade * 0.75) * VL_OPACITY;
		#endif

		vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);
		float VoL = clamp(dot(normalize(viewPos), lightVec), 0.0, 1.0) * 0.5;
		lightCol *= 1.0 + VoL + pow6(VoL);

		float currentDistanceFactor = 200.0 / VC_SAMPLES * (far / 250.0) * (1.0 - float(isEyeInWater == 1) * 0.5);

		for(int i = 0; i < VC_SAMPLES; i++) {
			float currentDistance = (i + dither) * currentDistanceFactor;

			if (depth1 < currentDistance || (depth0 < currentDistance && translucent == vec4(0.0))) {
				break;
			}

			vec3 worldPos = calculateWorldPos(getLogarithmicDepth(currentDistance), newTexCoord);
			vec3 shadowPos = calculateShadowPos(worldPos);
			vec3 playerPos = worldPos + cameraPosition;

			#ifdef VL
			float shadow0 = shadow2D(shadowtex0, shadowPos).z;
			#endif

			float shadow1 = shadow2D(shadowtex1, shadowPos).z;
			float lWorldPos = length(worldPos.xz);

			#ifdef VL
			float firstLayer = abs(VL_HEIGHT - playerPos.y) / VL_STRETCHING;
			#else
			float firstLayer = 5.0;
			#endif

			float secondLayer = abs(VC_HEIGHT - playerPos.y) / VC_STRETCHING;
			float cloudVisibility = (1.0 - float(shadow1 != 1.0) * float(eyeBrightnessSmooth.y <= 150.0)) * float(lWorldPos < distanceThreshold) * float(firstLayer < 4.0 || secondLayer < 2.0);

			if (cloudVisibility > 0.5) {
				vec2 noise = getCloudSample(playerPos, firstLayer, secondLayer);

				if (noise != vec2(0.0)) {
					#ifdef VL
					//Distant Fade for VL
					float vanillaFog = 1.0 - clamp(pow3(lViewPos) + pow6(lWorldPos / far), 0.0, 1.0);

					//Colored Shadows
					#ifdef SHADOW_COLOR
					if (shadow0 < 1.0) {
						if (shadow1 > 0.0) {
							shadowCol = texture2D(shadowcolor0, shadowPos.xy).rgb;
							shadowCol *= shadowCol * shadow1;
						}
					}

					vec3 shadow = clamp(shadowCol * shadowBrightness * (1.0 - shadow0) + shadow0, vec3(0.0), vec3(shadowBrightness));
					#endif

					//VL Fog
					firstLayerVisibility *= vanillaFog;

					float cloudLighting0 = clamp(smoothstep(VL_HEIGHT + VL_STRETCHING * noise.x, VL_HEIGHT - VL_STRETCHING * noise.x, playerPos.y) * 0.25 + noise.x * 0.75, 0.0, 1.0);
					vec4 cloudsColor0 = vec4(0.0);
					if (firstLayerVisibility > 0.0 && shadow1 != 0.0) {
						cloudsColor0 = vec4(lightCol, noise.x);
						#ifdef SHADOW_COLOR
						cloudsColor0.rgb *= shadow;
						#endif
						cloudsColor0.a *= firstLayerVisibility;
						cloudsColor0.rgb *= cloudsColor0.a;
					}
					#endif

					//Volumetric Clouds
					float cloudLighting1 = clamp(smoothstep(VC_HEIGHT + VC_STRETCHING * noise.y, VC_HEIGHT - VC_STRETCHING * noise.y, playerPos.y) * 0.5 + noise.y * 0.5, 0.0, 1.0);
					vec4 cloudsColor1 = vec4(mix(lightCol, ambientCol, cloudLighting1), noise.y);
						cloudsColor1.a *= VC_OPACITY;
						cloudsColor1.rgb *= cloudsColor1.a;

					//Trabslucency Blending
					if (depth0 < currentDistance) {
						#ifdef VL
						cloudsColor0.rgb *= translucent.rgb * translucent.rgb;
						#endif

						cloudsColor1.rgb *= translucent.rgb * translucent.rgb;
					}

					#ifdef VL
					firstCloudLayer += cloudsColor0 * (1.0 - firstCloudLayer.a) * (1.0 - secondCloudLayer.a);
					#endif

					secondCloudLayer += cloudsColor1 * (1.0 - secondCloudLayer.a);
				}
			}
		}

		#ifdef VL
		vlOut1 = firstCloudLayer;
		#endif

		vlOut2 = secondCloudLayer;
	}
}