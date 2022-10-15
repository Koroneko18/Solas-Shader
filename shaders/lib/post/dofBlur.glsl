const vec2 blurOffsets16[24] = vec2[24](
   vec2(0.1460926159456175, 0.020787547167935988),
   vec2(-0.1825871708713689, 0.18966012073331695),
   vec2(0.029971579969786034, -0.3007252737690296),
   vec2(0.23410647666390696, 0.3238488400319377),
   vec2(-0.424638398217927, -0.05463544978666622),
   vec2(0.4056721444313761, -0.23615144637091998),
   vec2(-0.13334731505890593, 0.5233616060429274),
   vec2(-0.25589981099335624, -0.4753112064115146),
   vec2(0.5607630327402762, 0.22493636638566347),
   vec2(-0.5797996105033465, 0.2608448564764615),
   vec2(0.28210282292008254, -0.5782993626046011),
   vec2(0.20892492283022107, 0.6812777514087536),
   vec2(-0.6226573574229254, -0.3410722053298899),
   vec2(0.7342618788693432, -0.1402520246130074),
   vec2(-0.44528246719953335, 0.6566524118139899),
   vec2(-0.10152096897477153, -0.7761863529801623),
   vec2(0.6357685022106778, 0.5551347570434946),
   vec2(-0.8514283199697419, 0.05606935806801772),
   vec2(0.6240868218930599, -0.5985156882048945),
   vec2(-0.03988135805823967, 0.9212132296296122),
   vec2(-0.5903956315359723, -0.6888068712318116),
   vec2(0.9397871085211658, 0.14699843411448665),
   vec2(-0.793037618517887, 0.5737835835181074),
   vec2(0.21893812032846297, -0.9446129811322083)
);

vec3 getDepthOfField(vec3 color, vec3 viewPos, float z1) {
	vec3 blur = vec3(0.0);

	float fovScale = gbufferProjection[1][1] / 1.37;
	float coc = 0.0;

	#ifdef DOF
	coc = max(abs(z1 - centerDepthSmooth) * DOF_STRENGTH - 0.01, 0.0);
	coc /= sqrt(coc * coc + 0.1);
	#endif

	//#ifdef DISTANT_BLUR
	//coc = min(length(viewPos) * DISTANT_BLUR_RANGE * 0.00025, DISTANT_BLUR_STRENGTH * 0.025) * DISTANT_BLUR_STRENGTH;
	//#endif

    float lod = log2(viewHeight * aspectRatio * coc * fovScale / 320.0);
	
	if (coc > 0.0 && z1 > 0.56) {
		for(int i = 0; i < 24; i++) {
			vec2 offset = blurOffsets16[i] * coc * 0.025 * fovScale * vec2(1.0 / aspectRatio, 1.0);
			blur += texture2DLod(colortex1, texCoord + offset, lod).rgb;
		}
		blur /= 24.0;
	}

	else blur = color;
	return blur;
}