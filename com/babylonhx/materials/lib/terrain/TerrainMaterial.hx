package com.babylonhx.materials.lib.terrain;

import com.babylonhx.math.Matrix;
import com.babylonhx.math.Color3;
import com.babylonhx.materials.textures.Texture;
import com.babylonhx.materials.textures.BaseTexture;
import com.babylonhx.mesh.VertexBuffer;
import com.babylonhx.mesh.Mesh;
import com.babylonhx.mesh.AbstractMesh;
import com.babylonhx.lights.DirectionalLight;
import com.babylonhx.lights.HemisphericLight;
import com.babylonhx.lights.SpotLight;
import com.babylonhx.lights.PointLight;
import com.babylonhx.animations.IAnimatable;

/**
 * ...
 * @author Krtolica Vujadin
 */

typedef TMD = TerrainMaterialDefines
 
class TerrainMaterial extends Material {
	
	public static var fragmentShader:String = "precision highp float;\n\n// Constants\nuniform vec3 vEyePosition;\nuniform vec4 vDiffuseColor;\n\n#ifdef SPECULARTERM\nuniform vec4 vSpecularColor;\n#endif\n\n// Input\nvarying vec3 vPositionW;\n\n#ifdef NORMAL\nvarying vec3 vNormalW;\n#endif\n\n#ifdef VERTEXCOLOR\nvarying vec4 vColor;\n#endif\n\n// Lights\n#ifdef LIGHT0\nuniform vec4 vLightData0;\nuniform vec4 vLightDiffuse0;\n#ifdef SPECULARTERM\nuniform vec3 vLightSpecular0;\n#endif\n#ifdef SHADOW0\n#if defined(SPOTLIGHT0) || defined(DIRLIGHT0)\nvarying vec4 vPositionFromLight0;\nuniform sampler2D shadowSampler0;\n#else\nuniform samplerCube shadowSampler0;\n#endif\nuniform vec3 shadowsInfo0;\n#endif\n#ifdef SPOTLIGHT0\nuniform vec4 vLightDirection0;\n#endif\n#ifdef HEMILIGHT0\nuniform vec3 vLightGround0;\n#endif\n#endif\n\n#ifdef LIGHT1\nuniform vec4 vLightData1;\nuniform vec4 vLightDiffuse1;\n#ifdef SPECULARTERM\nuniform vec3 vLightSpecular1;\n#endif\n#ifdef SHADOW1\n#if defined(SPOTLIGHT1) || defined(DIRLIGHT1)\nvarying vec4 vPositionFromLight1;\nuniform sampler2D shadowSampler1;\n#else\nuniform samplerCube shadowSampler1;\n#endif\nuniform vec3 shadowsInfo1;\n#endif\n#ifdef SPOTLIGHT1\nuniform vec4 vLightDirection1;\n#endif\n#ifdef HEMILIGHT1\nuniform vec3 vLightGround1;\n#endif\n#endif\n\n#ifdef LIGHT2\nuniform vec4 vLightData2;\nuniform vec4 vLightDiffuse2;\n#ifdef SPECULARTERM\nuniform vec3 vLightSpecular2;\n#endif\n#ifdef SHADOW2\n#if defined(SPOTLIGHT2) || defined(DIRLIGHT2)\nvarying vec4 vPositionFromLight2;\nuniform sampler2D shadowSampler2;\n#else\nuniform samplerCube shadowSampler2;\n#endif\nuniform vec3 shadowsInfo2;\n#endif\n#ifdef SPOTLIGHT2\nuniform vec4 vLightDirection2;\n#endif\n#ifdef HEMILIGHT2\nuniform vec3 vLightGround2;\n#endif\n#endif\n\n#ifdef LIGHT3\nuniform vec4 vLightData3;\nuniform vec4 vLightDiffuse3;\n#ifdef SPECULARTERM\nuniform vec3 vLightSpecular3;\n#endif\n#ifdef SHADOW3\n#if defined(SPOTLIGHT3) || defined(DIRLIGHT3)\nvarying vec4 vPositionFromLight3;\nuniform sampler2D shadowSampler3;\n#else\nuniform samplerCube shadowSampler3;\n#endif\nuniform vec3 shadowsInfo3;\n#endif\n#ifdef SPOTLIGHT3\nuniform vec4 vLightDirection3;\n#endif\n#ifdef HEMILIGHT3\nuniform vec3 vLightGround3;\n#endif\n#endif\n\n// Samplers\n#ifdef DIFFUSE\nvarying vec2 vTextureUV;\nuniform sampler2D textureSampler;\nuniform vec2 vTextureInfos;\n\nuniform sampler2D diffuse1Sampler;\nuniform sampler2D diffuse2Sampler;\nuniform sampler2D diffuse3Sampler;\n\nuniform vec2 diffuse1Infos;\nuniform vec2 diffuse2Infos;\nuniform vec2 diffuse3Infos;\n\n#endif\n\n#ifdef BUMP\nuniform sampler2D bump1Sampler;\nuniform sampler2D bump2Sampler;\nuniform sampler2D bump3Sampler;\n#endif\n\n// Shadows\n#ifdef SHADOWS\n\nfloat unpack(vec4 color)\n{\n	const vec4 bit_shift = vec4(1.0 / (255.0 * 255.0 * 255.0), 1.0 / (255.0 * 255.0), 1.0 / 255.0, 1.0);\n	return dot(color, bit_shift);\n}\n\n#if defined(POINTLIGHT0) || defined(POINTLIGHT1) || defined(POINTLIGHT2) || defined(POINTLIGHT3)\nfloat computeShadowCube(vec3 lightPosition, samplerCube shadowSampler, float darkness, float bias)\n{\n	vec3 directionToLight = vPositionW - lightPosition;\n	float depth = length(directionToLight);\n\n	depth = clamp(depth, 0., 1.);\n\n	directionToLight.y = 1.0 - directionToLight.y;\n\n	float shadow = unpack(textureCube(shadowSampler, directionToLight)) + bias;\n\n	if (depth > shadow)\n	{\n		return darkness;\n	}\n	return 1.0;\n}\n\nfloat computeShadowWithPCFCube(vec3 lightPosition, samplerCube shadowSampler, float mapSize, float bias, float darkness)\n{\n	vec3 directionToLight = vPositionW - lightPosition;\n	float depth = length(directionToLight);\n	float diskScale = (1.0 - (1.0 + depth * 3.0)) / mapSize;\n\n	depth = clamp(depth, 0., 1.);\n\n	directionToLight.y = 1.0 - directionToLight.y;\n\n	float visibility = 1.;\n\n	vec3 poissonDisk[4];\n	poissonDisk[0] = vec3(-1.0, 1.0, -1.0);\n	poissonDisk[1] = vec3(1.0, -1.0, -1.0);\n	poissonDisk[2] = vec3(-1.0, -1.0, -1.0);\n	poissonDisk[3] = vec3(1.0, -1.0, 1.0);\n\n	// Poisson Sampling\n	float biasedDepth = depth - bias;\n\n	if (unpack(textureCube(shadowSampler, directionToLight + poissonDisk[0] * diskScale)) < biasedDepth) visibility -= 0.25;\n	if (unpack(textureCube(shadowSampler, directionToLight + poissonDisk[1] * diskScale)) < biasedDepth) visibility -= 0.25;\n	if (unpack(textureCube(shadowSampler, directionToLight + poissonDisk[2] * diskScale)) < biasedDepth) visibility -= 0.25;\n	if (unpack(textureCube(shadowSampler, directionToLight + poissonDisk[3] * diskScale)) < biasedDepth) visibility -= 0.25;\n\n	return  min(1.0, visibility + darkness);\n}\n#endif\n\n#if defined(SPOTLIGHT0) || defined(SPOTLIGHT1) || defined(SPOTLIGHT2) || defined(SPOTLIGHT3) ||  defined(DIRLIGHT0) || defined(DIRLIGHT1) || defined(DIRLIGHT2) || defined(DIRLIGHT3)\nfloat computeShadow(vec4 vPositionFromLight, sampler2D shadowSampler, float darkness, float bias)\n{\n	vec3 depth = vPositionFromLight.xyz / vPositionFromLight.w;\n	depth = 0.5 * depth + vec3(0.5);\n	vec2 uv = depth.xy;\n\n	if (uv.x < 0. || uv.x > 1.0 || uv.y < 0. || uv.y > 1.0)\n	{\n		return 1.0;\n	}\n\n	float shadow = unpack(texture2D(shadowSampler, uv)) + bias;\n\n	if (depth.z > shadow)\n	{\n		return darkness;\n	}\n	return 1.;\n}\n\nfloat computeShadowWithPCF(vec4 vPositionFromLight, sampler2D shadowSampler, float mapSize, float bias, float darkness)\n{\n	vec3 depth = vPositionFromLight.xyz / vPositionFromLight.w;\n	depth = 0.5 * depth + vec3(0.5);\n	vec2 uv = depth.xy;\n\n	if (uv.x < 0. || uv.x > 1.0 || uv.y < 0. || uv.y > 1.0)\n	{\n		return 1.0;\n	}\n\n	float visibility = 1.;\n\n	vec2 poissonDisk[4];\n	poissonDisk[0] = vec2(-0.94201624, -0.39906216);\n	poissonDisk[1] = vec2(0.94558609, -0.76890725);\n	poissonDisk[2] = vec2(-0.094184101, -0.92938870);\n	poissonDisk[3] = vec2(0.34495938, 0.29387760);\n\n	// Poisson Sampling\n	float biasedDepth = depth.z - bias;\n\n	if (unpack(texture2D(shadowSampler, uv + poissonDisk[0] / mapSize)) < biasedDepth) visibility -= 0.25;\n	if (unpack(texture2D(shadowSampler, uv + poissonDisk[1] / mapSize)) < biasedDepth) visibility -= 0.25;\n	if (unpack(texture2D(shadowSampler, uv + poissonDisk[2] / mapSize)) < biasedDepth) visibility -= 0.25;\n	if (unpack(texture2D(shadowSampler, uv + poissonDisk[3] / mapSize)) < biasedDepth) visibility -= 0.25;\n\n	return  min(1.0, visibility + darkness);\n}\n\n// Thanks to http://devmaster.net/\nfloat unpackHalf(vec2 color)\n{\n	return color.x + (color.y / 255.0);\n}\n\nfloat linstep(float low, float high, float v) {\n	return clamp((v - low) / (high - low), 0.0, 1.0);\n}\n\nfloat ChebychevInequality(vec2 moments, float compare, float bias)\n{\n	float p = smoothstep(compare - bias, compare, moments.x);\n	float variance = max(moments.y - moments.x * moments.x, 0.02);\n	float d = compare - moments.x;\n	float p_max = linstep(0.2, 1.0, variance / (variance + d * d));\n\n	return clamp(max(p, p_max), 0.0, 1.0);\n}\n\nfloat computeShadowWithVSM(vec4 vPositionFromLight, sampler2D shadowSampler, float bias, float darkness)\n{\n	vec3 depth = vPositionFromLight.xyz / vPositionFromLight.w;\n	depth = 0.5 * depth + vec3(0.5);\n	vec2 uv = depth.xy;\n\n	if (uv.x < 0. || uv.x > 1.0 || uv.y < 0. || uv.y > 1.0 || depth.z >= 1.0)\n	{\n		return 1.0;\n	}\n\n	vec4 texel = texture2D(shadowSampler, uv);\n\n	vec2 moments = vec2(unpackHalf(texel.xy), unpackHalf(texel.zw));\n	return min(1.0, 1.0 - ChebychevInequality(moments, depth.z, bias) + darkness);\n}\n#endif\n#endif\n\n\n#ifdef CLIPPLANE\nvarying float fClipDistance;\n#endif\n\n// Fog\n#ifdef FOG\n\n#define FOGMODE_NONE    0.\n#define FOGMODE_EXP     1.\n#define FOGMODE_EXP2    2.\n#define FOGMODE_LINEAR  3.\n#define E 2.71828\n\nuniform vec4 vFogInfos;\nuniform vec3 vFogColor;\nvarying float fFogDistance;\n\nfloat CalcFogFactor()\n{\n	float fogCoeff = 1.0;\n	float fogStart = vFogInfos.y;\n	float fogEnd = vFogInfos.z;\n	float fogDensity = vFogInfos.w;\n\n	if (FOGMODE_LINEAR == vFogInfos.x)\n	{\n		fogCoeff = (fogEnd - fFogDistance) / (fogEnd - fogStart);\n	}\n	else if (FOGMODE_EXP == vFogInfos.x)\n	{\n		fogCoeff = 1.0 / pow(E, fFogDistance * fogDensity);\n	}\n	else if (FOGMODE_EXP2 == vFogInfos.x)\n	{\n		fogCoeff = 1.0 / pow(E, fFogDistance * fFogDistance * fogDensity * fogDensity);\n	}\n\n	return clamp(fogCoeff, 0.0, 1.0);\n}\n#endif\n\n// Bump\n#ifdef BUMP\n#extension GL_OES_standard_derivatives : enable\n// Thanks to http://www.thetenthplanet.de/archives/1180\nmat3 cotangent_frame(vec3 normal, vec3 p, vec2 uv)\n{\n	// get edge vectors of the pixel triangle\n	vec3 dp1 = dFdx(p);\n	vec3 dp2 = dFdy(p);\n	vec2 duv1 = dFdx(uv);\n	vec2 duv2 = dFdy(uv);\n\n	// solve the linear system\n	vec3 dp2perp = cross(dp2, normal);\n	vec3 dp1perp = cross(normal, dp1);\n	vec3 tangent = dp2perp * duv1.x + dp1perp * duv2.x;\n	vec3 binormal = dp2perp * duv1.y + dp1perp * duv2.y;\n\n	// construct a scale-invariant frame \n	float invmax = inversesqrt(max(dot(tangent, tangent), dot(binormal, binormal)));\n	return mat3(tangent * invmax, binormal * invmax, normal);\n}\n\nvec3 perturbNormal(vec3 viewDir, vec3 mixColor)\n{	\n	vec3 bump1Color = texture2D(bump1Sampler, vTextureUV * diffuse1Infos).xyz;\n	vec3 bump2Color = texture2D(bump2Sampler, vTextureUV * diffuse2Infos).xyz;\n	vec3 bump3Color = texture2D(bump3Sampler, vTextureUV * diffuse3Infos).xyz;\n	\n	bump1Color.rgb *= mixColor.r;\n   	bump2Color.rgb = mix(bump1Color.rgb, bump2Color.rgb, mixColor.g);\n   	vec3 map = mix(bump2Color.rgb, bump3Color.rgb, mixColor.b);\n	\n	map = map * 255. / 127. - 128. / 127.;\n	mat3 TBN = cotangent_frame(vNormalW * vTextureInfos.y, -viewDir, vTextureUV);\n	return normalize(TBN * map);\n}\n#endif\n\n// Light Computing\nstruct lightingInfo\n{\n	vec3 diffuse;\n#ifdef SPECULARTERM\n	vec3 specular;\n#endif\n};\n\nlightingInfo computeLighting(vec3 viewDirectionW, vec3 vNormal, vec4 lightData, vec3 diffuseColor, vec3 specularColor, float range, float glossiness) {\n	lightingInfo result;\n\n	vec3 lightVectorW;\n	float attenuation = 1.0;\n	if (lightData.w == 0.)\n	{\n		vec3 direction = lightData.xyz - vPositionW;\n\n		attenuation = max(0., 1.0 - length(direction) / range);\n		lightVectorW = normalize(direction);\n	}\n	else\n	{\n		lightVectorW = normalize(-lightData.xyz);\n	}\n\n	// diffuse\n	float ndl = max(0., dot(vNormal, lightVectorW));\n	result.diffuse = ndl * diffuseColor * attenuation;\n\n#ifdef SPECULARTERM\n	// Specular\n	vec3 angleW = normalize(viewDirectionW + lightVectorW);\n	float specComp = max(0., dot(vNormal, angleW));\n	specComp = pow(specComp, max(1., glossiness));\n\n	result.specular = specComp * specularColor * attenuation;\n#endif\n	return result;\n}\n\nlightingInfo computeSpotLighting(vec3 viewDirectionW, vec3 vNormal, vec4 lightData, vec4 lightDirection, vec3 diffuseColor, vec3 specularColor, float range, float glossiness) {\n	lightingInfo result;\n\n	vec3 direction = lightData.xyz - vPositionW;\n	vec3 lightVectorW = normalize(direction);\n	float attenuation = max(0., 1.0 - length(direction) / range);\n\n	// diffuse\n	float cosAngle = max(0., dot(-lightDirection.xyz, lightVectorW));\n	float spotAtten = 0.0;\n\n	if (cosAngle >= lightDirection.w)\n	{\n		cosAngle = max(0., pow(cosAngle, lightData.w));\n		spotAtten = clamp((cosAngle - lightDirection.w) / (1. - cosAngle), 0.0, 1.0);\n\n		// Diffuse\n		float ndl = max(0., dot(vNormal, -lightDirection.xyz));\n		result.diffuse = ndl * spotAtten * diffuseColor * attenuation;\n\n#ifdef SPECULARTERM\n		// Specular\n		vec3 angleW = normalize(viewDirectionW - lightDirection.xyz);\n		float specComp = max(0., dot(vNormal, angleW));\n		specComp = pow(specComp, max(1., glossiness));\n\n		result.specular = specComp * specularColor * spotAtten * attenuation;\n#endif\n\n		return result;\n	}\n\n	result.diffuse = vec3(0.);\n#ifdef SPECULARTERM\n	result.specular = vec3(0.);\n#endif\n\n	return result;\n}\n\nlightingInfo computeHemisphericLighting(vec3 viewDirectionW, vec3 vNormal, vec4 lightData, vec3 diffuseColor, vec3 specularColor, vec3 groundColor, float glossiness) {\n	lightingInfo result;\n\n	// Diffuse\n	float ndl = dot(vNormal, lightData.xyz) * 0.5 + 0.5;\n	result.diffuse = mix(groundColor, diffuseColor, ndl);\n\n#ifdef SPECULARTERM\n	// Specular\n	vec3 angleW = normalize(viewDirectionW + lightData.xyz);\n	float specComp = max(0., dot(vNormal, angleW));\n	specComp = pow(specComp, max(1., glossiness));\n\n	result.specular = specComp * specularColor;\n#endif\n\n	return result;\n}\n\nvoid main(void) {\n	// Clip plane\n#ifdef CLIPPLANE\n	if (fClipDistance > 0.0)\n		discard;\n#endif\n\n	vec3 viewDirectionW = normalize(vEyePosition - vPositionW);\n\n	// Base color\n	vec4 baseColor = vec4(1., 1., 1., 1.);\n	vec3 diffuseColor = vDiffuseColor.rgb;\n	\n#ifdef SPECULARTERM\n	float glossiness = vSpecularColor.a;\n	vec3 specularColor = vSpecularColor.rgb;\n#else\n	float glossiness = 0.;\n#endif\n\n	// Alpha\n	float alpha = vDiffuseColor.a;\n	\n	// Bump\n#ifdef NORMAL\n	vec3 normalW = normalize(vNormalW);\n#else\n	vec3 normalW = vec3(1.0, 1.0, 1.0);\n#endif\n\n#ifdef DIFFUSE\n	baseColor = texture2D(textureSampler, vTextureUV);\n\n#if defined(BUMP) && defined(DIFFUSE)\n	normalW = perturbNormal(viewDirectionW, baseColor.rgb);\n#endif\n\n#ifdef ALPHATEST\n	if (baseColor.a < 0.4)\n		discard;\n#endif\n\n	baseColor.rgb *= vTextureInfos.y;\n	\n	vec4 diffuse1Color = texture2D(diffuse1Sampler, vTextureUV * diffuse1Infos);\n	vec4 diffuse2Color = texture2D(diffuse2Sampler, vTextureUV * diffuse2Infos);\n	vec4 diffuse3Color = texture2D(diffuse3Sampler, vTextureUV * diffuse3Infos);\n	\n	diffuse1Color.rgb *= baseColor.r;\n   	diffuse2Color.rgb = mix(diffuse1Color.rgb, diffuse2Color.rgb, baseColor.g);\n   	baseColor.rgb = mix(diffuse2Color.rgb, diffuse3Color.rgb, baseColor.b);\n	\n#endif\n\n#ifdef VERTEXCOLOR\n	baseColor.rgb *= vColor.rgb;\n#endif\n\n	// Lighting\n	vec3 diffuseBase = vec3(0., 0., 0.);\n#ifdef SPECULARTERM\n	vec3 specularBase = vec3(0., 0., 0.);\n#endif\n	float shadow = 1.;\n\n#ifdef LIGHT0\n#ifndef SPECULARTERM\n	vec3 vLightSpecular0 = vec3(0.0);\n#endif\n#ifdef SPOTLIGHT0\n	lightingInfo info = computeSpotLighting(viewDirectionW, normalW, vLightData0, vLightDirection0, vLightDiffuse0.rgb, vLightSpecular0, vLightDiffuse0.a, glossiness);\n#endif\n#ifdef HEMILIGHT0\n	lightingInfo info = computeHemisphericLighting(viewDirectionW, normalW, vLightData0, vLightDiffuse0.rgb, vLightSpecular0, vLightGround0, glossiness);\n#endif\n#if defined(POINTLIGHT0) || defined(DIRLIGHT0)\n	lightingInfo info = computeLighting(viewDirectionW, normalW, vLightData0, vLightDiffuse0.rgb, vLightSpecular0, vLightDiffuse0.a, glossiness);\n#endif\n#ifdef SHADOW0\n#ifdef SHADOWVSM0\n	shadow = computeShadowWithVSM(vPositionFromLight0, shadowSampler0, shadowsInfo0.z, shadowsInfo0.x);\n#else\n#ifdef SHADOWPCF0\n#if defined(POINTLIGHT0)\n	shadow = computeShadowWithPCFCube(vLightData0.xyz, shadowSampler0, shadowsInfo0.y, shadowsInfo0.z, shadowsInfo0.x);\n#else\n	shadow = computeShadowWithPCF(vPositionFromLight0, shadowSampler0, shadowsInfo0.y, shadowsInfo0.z, shadowsInfo0.x);\n#endif\n#else\n#if defined(POINTLIGHT0)\n	shadow = computeShadowCube(vLightData0.xyz, shadowSampler0, shadowsInfo0.x, shadowsInfo0.z);\n#else\n	shadow = computeShadow(vPositionFromLight0, shadowSampler0, shadowsInfo0.x, shadowsInfo0.z);\n#endif\n#endif\n#endif\n#else\n	shadow = 1.;\n#endif\n	diffuseBase += info.diffuse * shadow;\n#ifdef SPECULARTERM\n	specularBase += info.specular * shadow;\n#endif\n#endif\n\n#ifdef LIGHT1\n#ifndef SPECULARTERM\n	vec3 vLightSpecular1 = vec3(0.0);\n#endif\n#ifdef SPOTLIGHT1\n	info = computeSpotLighting(viewDirectionW, normalW, vLightData1, vLightDirection1, vLightDiffuse1.rgb, vLightSpecular1, vLightDiffuse1.a, glossiness);\n#endif\n#ifdef HEMILIGHT1\n	info = computeHemisphericLighting(viewDirectionW, normalW, vLightData1, vLightDiffuse1.rgb, vLightSpecular1, vLightGround1, glossiness);\n#endif\n#if defined(POINTLIGHT1) || defined(DIRLIGHT1)\n	info = computeLighting(viewDirectionW, normalW, vLightData1, vLightDiffuse1.rgb, vLightSpecular1, vLightDiffuse1.a, glossiness);\n#endif\n#ifdef SHADOW1\n#ifdef SHADOWVSM1\n	shadow = computeShadowWithVSM(vPositionFromLight1, shadowSampler1, shadowsInfo1.z, shadowsInfo1.x);\n#else\n#ifdef SHADOWPCF1\n#if defined(POINTLIGHT1)\n	shadow = computeShadowWithPCFCube(vLightData1.xyz, shadowSampler1, shadowsInfo1.y, shadowsInfo1.z, shadowsInfo1.x);\n#else\n	shadow = computeShadowWithPCF(vPositionFromLight1, shadowSampler1, shadowsInfo1.y, shadowsInfo1.z, shadowsInfo1.x);\n#endif\n#else\n#if defined(POINTLIGHT1)\n	shadow = computeShadowCube(vLightData1.xyz, shadowSampler1, shadowsInfo1.x, shadowsInfo1.z);\n#else\n	shadow = computeShadow(vPositionFromLight1, shadowSampler1, shadowsInfo1.x, shadowsInfo1.z);\n#endif\n#endif\n#endif\n#else\n	shadow = 1.;\n#endif\n	diffuseBase += info.diffuse * shadow;\n#ifdef SPECULARTERM\n	specularBase += info.specular * shadow;\n#endif\n#endif\n\n#ifdef LIGHT2\n#ifndef SPECULARTERM\n	vec3 vLightSpecular2 = vec3(0.0);\n#endif\n#ifdef SPOTLIGHT2\n	info = computeSpotLighting(viewDirectionW, normalW, vLightData2, vLightDirection2, vLightDiffuse2.rgb, vLightSpecular2, vLightDiffuse2.a, glossiness);\n#endif\n#ifdef HEMILIGHT2\n	info = computeHemisphericLighting(viewDirectionW, normalW, vLightData2, vLightDiffuse2.rgb, vLightSpecular2, vLightGround2, glossiness);\n#endif\n#if defined(POINTLIGHT2) || defined(DIRLIGHT2)\n	info = computeLighting(viewDirectionW, normalW, vLightData2, vLightDiffuse2.rgb, vLightSpecular2, vLightDiffuse2.a, glossiness);\n#endif\n#ifdef SHADOW2\n#ifdef SHADOWVSM2\n	shadow = computeShadowWithVSM(vPositionFromLight2, shadowSampler2, shadowsInfo2.z, shadowsInfo2.x);\n#else\n#ifdef SHADOWPCF2\n#if defined(POINTLIGHT2)\n	shadow = computeShadowWithPCFCube(vLightData2.xyz, shadowSampler2, shadowsInfo2.y, shadowsInfo2.z, shadowsInfo2.x);\n#else\n	shadow = computeShadowWithPCF(vPositionFromLight2, shadowSampler2, shadowsInfo2.y, shadowsInfo2.z, shadowsInfo2.x);\n#endif\n#else\n#if defined(POINTLIGHT2)\n	shadow = computeShadowCube(vLightData2.xyz, shadowSampler2, shadowsInfo2.x, shadowsInfo2.z);\n#else\n	shadow = computeShadow(vPositionFromLight2, shadowSampler2, shadowsInfo2.x, shadowsInfo2.z);\n#endif\n#endif	\n#endif	\n#else\n	shadow = 1.;\n#endif\n	diffuseBase += info.diffuse * shadow;\n#ifdef SPECULARTERM\n	specularBase += info.specular * shadow;\n#endif\n#endif\n\n#ifdef LIGHT3\n#ifndef SPECULARTERM\n	vec3 vLightSpecular3 = vec3(0.0);\n#endif\n#ifdef SPOTLIGHT3\n	info = computeSpotLighting(viewDirectionW, normalW, vLightData3, vLightDirection3, vLightDiffuse3.rgb, vLightSpecular3, vLightDiffuse3.a, glossiness);\n#endif\n#ifdef HEMILIGHT3\n	info = computeHemisphericLighting(viewDirectionW, normalW, vLightData3, vLightDiffuse3.rgb, vLightSpecular3, vLightGround3, glossiness);\n#endif\n#if defined(POINTLIGHT3) || defined(DIRLIGHT3)\n	info = computeLighting(viewDirectionW, normalW, vLightData3, vLightDiffuse3.rgb, vLightSpecular3, vLightDiffuse3.a, glossiness);\n#endif\n#ifdef SHADOW3\n#ifdef SHADOWVSM3\n	shadow = computeShadowWithVSM(vPositionFromLight3, shadowSampler3, shadowsInfo3.z, shadowsInfo3.x);\n#else\n#ifdef SHADOWPCF3\n#if defined(POINTLIGHT3)\n	shadow = computeShadowWithPCFCube(vLightData3.xyz, shadowSampler3, shadowsInfo3.y, shadowsInfo3.z, shadowsInfo3.x);\n#else\n	shadow = computeShadowWithPCF(vPositionFromLight3, shadowSampler3, shadowsInfo3.y, shadowsInfo3.z, shadowsInfo3.x);\n#endif\n#else\n#if defined(POINTLIGHT3)\n	shadow = computeShadowCube(vLightData3.xyz, shadowSampler3, shadowsInfo3.x, shadowsInfo3.z);\n#else\n	shadow = computeShadow(vPositionFromLight3, shadowSampler3, shadowsInfo3.x, shadowsInfo3.z);\n#endif\n#endif	\n#endif	\n#else\n	shadow = 1.;\n#endif\n	diffuseBase += info.diffuse * shadow;\n#ifdef SPECULARTERM\n	specularBase += info.specular * shadow;\n#endif\n#endif\n\n#ifdef VERTEXALPHA\n	alpha *= vColor.a;\n#endif\n\n#ifdef SPECULARTERM\n	vec3 finalSpecular = specularBase * specularColor;\n#else\n	vec3 finalSpecular = vec3(0.0);\n#endif\n\n	vec3 finalDiffuse = clamp(diffuseBase * diffuseColor, 0.0, 1.0) * baseColor.rgb;\n\n	// Composition\n	vec4 color = vec4(finalDiffuse + finalSpecular, alpha);\n\n#ifdef FOG\n	float fog = CalcFogFactor();\n	color.rgb = fog * color.rgb + (1.0 - fog) * vFogColor;\n#endif\n\n	gl_FragColor = color;\n}";
	
	public static var vertexShader:String = "precision highp float;\n\n// Attributes\nattribute vec3 position;\n#ifdef NORMAL\nattribute vec3 normal;\n#endif\n#ifdef UV1\nattribute vec2 uv;\n#endif\n#ifdef UV2\nattribute vec2 uv2;\n#endif\n#ifdef VERTEXCOLOR\nattribute vec4 color;\n#endif\n#if NUM_BONE_INFLUENCERS > 0\n	uniform mat4 mBones[BonesPerMesh];\n\n	attribute vec4 matricesIndices;\n	attribute vec4 matricesWeights;\n	#if NUM_BONE_INFLUENCERS > 4\n		attribute vec4 matricesIndicesExtra;\n		attribute vec4 matricesWeightsExtra;\n	#endif\n#endif\n\n// Uniforms\n\n#ifdef INSTANCES\nattribute vec4 world0;\nattribute vec4 world1;\nattribute vec4 world2;\nattribute vec4 world3;\n#else\nuniform mat4 world;\n#endif\n\nuniform mat4 view;\nuniform mat4 viewProjection;\n\n#ifdef DIFFUSE\nvarying vec2 vTextureUV;\nuniform mat4 textureMatrix;\nuniform vec2 vTextureInfos;\n#endif\n\n#ifdef POINTSIZE\nuniform float pointSize;\n#endif\n\n// Output\nvarying vec3 vPositionW;\n#ifdef NORMAL\nvarying vec3 vNormalW;\n#endif\n\n#ifdef VERTEXCOLOR\nvarying vec4 vColor;\n#endif\n\n#ifdef CLIPPLANE\nuniform vec4 vClipPlane;\nvarying float fClipDistance;\n#endif\n\n#ifdef FOG\nvarying float fFogDistance;\n#endif\n\n#ifdef SHADOWS\n#if defined(SPOTLIGHT0) || defined(DIRLIGHT0)\nuniform mat4 lightMatrix0;\nvarying vec4 vPositionFromLight0;\n#endif\n#if defined(SPOTLIGHT1) || defined(DIRLIGHT1)\nuniform mat4 lightMatrix1;\nvarying vec4 vPositionFromLight1;\n#endif\n#if defined(SPOTLIGHT2) || defined(DIRLIGHT2)\nuniform mat4 lightMatrix2;\nvarying vec4 vPositionFromLight2;\n#endif\n#if defined(SPOTLIGHT3) || defined(DIRLIGHT3)\nuniform mat4 lightMatrix3;\nvarying vec4 vPositionFromLight3;\n#endif\n#endif\n\nvoid main(void) {\n	mat4 finalWorld;\n\n#ifdef INSTANCES\n	finalWorld = mat4(world0, world1, world2, world3);\n#else\n	finalWorld = world;\n#endif\n\n#if NUM_BONE_INFLUENCERS > 0\n	mat4 influence;\n	influence = mBones[int(matricesIndices[0])] * matricesWeights[0];\n\n	#if NUM_BONE_INFLUENCERS > 1\n		influence += mBones[int(matricesIndices[1])] * matricesWeights[1];\n	#endif \n	#if NUM_BONE_INFLUENCERS > 2\n		influence += mBones[int(matricesIndices[2])] * matricesWeights[2];\n	#endif	\n	#if NUM_BONE_INFLUENCERS > 3\n		influence += mBones[int(matricesIndices[3])] * matricesWeights[3];\n	#endif	\n\n	#if NUM_BONE_INFLUENCERS > 4\n		influence += mBones[int(matricesIndicesExtra[0])] * matricesWeightsExtra[0];\n	#endif\n	#if NUM_BONE_INFLUENCERS > 5\n		influence += mBones[int(matricesIndicesExtra[1])] * matricesWeightsExtra[1];\n	#endif	\n	#if NUM_BONE_INFLUENCERS > 6\n		influence += mBones[int(matricesIndicesExtra[2])] * matricesWeightsExtra[2];\n	#endif	\n	#if NUM_BONE_INFLUENCERS > 7\n		influence += mBones[int(matricesIndicesExtra[3])] * matricesWeightsExtra[3];\n	#endif	\n\n	finalWorld = finalWorld * influence;\n#endif\n\n	gl_Position = viewProjection * finalWorld * vec4(position, 1.0);\n\n	vec4 worldPos = finalWorld * vec4(position, 1.0);\n	vPositionW = vec3(worldPos);\n\n#ifdef NORMAL\n	vNormalW = normalize(vec3(finalWorld * vec4(normal, 0.0)));\n#endif\n\n	// Texture coordinates\n#ifndef UV1\n	vec2 uv = vec2(0., 0.);\n#endif\n#ifndef UV2\n	vec2 uv2 = vec2(0., 0.);\n#endif\n\n#ifdef DIFFUSE\n	if (vTextureInfos.x == 0.)\n	{\n		vTextureUV = vec2(textureMatrix * vec4(uv, 1.0, 0.0));\n	}\n	else\n	{\n		vTextureUV = vec2(textureMatrix * vec4(uv2, 1.0, 0.0));\n	}\n#endif\n\n	// Clip plane\n#ifdef CLIPPLANE\n	fClipDistance = dot(worldPos, vClipPlane);\n#endif\n\n	// Fog\n#ifdef FOG\n	fFogDistance = (view * worldPos).z;\n#endif\n\n	// Shadows\n#ifdef SHADOWS\n#if defined(SPOTLIGHT0) || defined(DIRLIGHT0)\n	vPositionFromLight0 = lightMatrix0 * worldPos;\n#endif\n#if defined(SPOTLIGHT1) || defined(DIRLIGHT1)\n	vPositionFromLight1 = lightMatrix1 * worldPos;\n#endif\n#if defined(SPOTLIGHT2) || defined(DIRLIGHT2)\n	vPositionFromLight2 = lightMatrix2 * worldPos;\n#endif\n#if defined(SPOTLIGHT3) || defined(DIRLIGHT3)\n	vPositionFromLight3 = lightMatrix3 * worldPos;\n#endif\n#endif\n\n	// Vertex color\n#ifdef VERTEXCOLOR\n	vColor = color;\n#endif\n\n	// Point size\n#ifdef POINTSIZE\n	gl_PointSize = pointSize;\n#endif\n}";
	

	public var mixTexture:BaseTexture;
        
	public var diffuseTexture1:Texture;
	public var diffuseTexture2:Texture;
	public var diffuseTexture3:Texture;
	
	public var bumpTexture1:Texture;
	public var bumpTexture2:Texture;
	public var bumpTexture3:Texture;
	
	public var diffuseColor:Color3 = new Color3(1, 1, 1);
	public var specularColor:Color3 = new Color3(0, 0, 0);
	public var specularPower:Int = 64;
	public var disableLighting:Bool = false;

	private var _worldViewProjectionMatrix:Matrix = Matrix.Zero();
	private var _scaledDiffuse:Color3 = new Color3();
	private var _scaledSpecular:Color3 = new Color3();
	private var _renderId:Int;

	private var _defines:TerrainMaterialDefines = new TerrainMaterialDefines();
	private var _cachedDefines:TerrainMaterialDefines = new TerrainMaterialDefines();

	
	public function new(name:String, scene:Scene) {
		super(name, scene);
		
		if (!ShadersStore.Shaders.exists("terrainmat.fragment")) {
			ShadersStore.Shaders.set("terrainmat.fragment", fragmentShader);
			ShadersStore.Shaders.set("terrainmat.vertex", vertexShader);
		}
		
		this._cachedDefines.BonesPerMesh = -1;
	}

	override public function needAlphaBlending():Bool {
		return (this.alpha < 1.0);
	}

	override public function needAlphaTesting():Bool {
		return false;
	}

	override public function getAlphaTestTexture():BaseTexture {
		return null;
	}

	// Methods   
	private function _checkCache(scene:Scene, ?mesh:AbstractMesh, useInstances:Bool):Bool {
		if (mesh == null) {
			return true;
		}
		
		if (this._defines.defines[TMD.INSTANCES] != useInstances) {
			return false;
		}
		
		if (mesh._materialDefines != null && mesh._materialDefines.isEqual(this._defines)) {
			return true;
		}
		
		return false;
	}

	override public function isReady(?mesh:AbstractMesh, useInstances:Bool = false):Bool {
		if (this.checkReadyOnlyOnce) {
			if (this._wasPreviouslyReady) {
				return true;
			}
		}
		
		var scene = this.getScene();
		
		if (!this.checkReadyOnEveryCall) {
			if (this._renderId == scene.getRenderId()) {
				if (this._checkCache(scene, mesh, useInstances)) {
					return true;
				}
			}
		}
		
		var engine:Engine = scene.getEngine();
		var needNormals:Bool = false;
		var needUVs:Bool = false;
		
		this._defines.reset();
		
		// Textures
		if (scene.texturesEnabled) {
			if (this.mixTexture != null && StandardMaterial.DiffuseTextureEnabled) {
				if (!this.mixTexture.isReady()) {
					return false;
				} 
				else {
					needUVs = true;
					this._defines.defines[TMD.DIFFUSE] = true;
				}
			}
			if ((this.bumpTexture1 != null || this.bumpTexture2 != null || this.bumpTexture3 != null) && StandardMaterial.BumpTextureEnabled) {
				needUVs = true;
				needNormals = true;
				this._defines.defines[TMD.BUMP] = true;
			}
		}
		
		// Effect
		if (scene.clipPlane != null) {
			this._defines.defines[TMD.CLIPPLANE] = true;
		}
		
		if (engine.getAlphaTesting()) {
			this._defines.defines[TMD.ALPHATEST] = true;
		}
		
		// Point size
		if (this.pointsCloud || scene.forcePointsCloud) {
			this._defines.defines[TMD.POINTSIZE] = true;
		}
		
		// Fog
		if (scene.fogEnabled && mesh != null && mesh.applyFog && scene.fogMode != Scene.FOGMODE_NONE && this.fogEnabled) {
			this._defines.defines[TMD.FOG] = true;
		}
		
		var lightIndex:Int = 0;
		if (scene.lightsEnabled && !this.disableLighting) {
			for (index in 0...scene.lights.length) {
				var light = scene.lights[index];
				
				if (!light.isEnabled()) {
					continue;
				}
				
				// Excluded check
				if (light._excludedMeshesIds.length > 0) {
					for (excludedIndex in 0...light._excludedMeshesIds.length) {
						var excludedMesh = scene.getMeshByID(light._excludedMeshesIds[excludedIndex]);
						
						if (excludedMesh != null) {
							light.excludedMeshes.push(excludedMesh);
						}
					}
					
					light._excludedMeshesIds = [];
				}
				
				// Included check
				if (light._includedOnlyMeshesIds.length > 0) {
					for (includedOnlyIndex in 0...light._includedOnlyMeshesIds.length) {
						var includedOnlyMesh = scene.getMeshByID(light._includedOnlyMeshesIds[includedOnlyIndex]);
						
						if (includedOnlyMesh != null) {
							light.includedOnlyMeshes.push(includedOnlyMesh);
						}
					}
					
					light._includedOnlyMeshesIds = [];
				}
				
				if (!light.canAffectMesh(mesh)) {
					continue;
				}
				needNormals = true;
				this._defines.defines[TMD.LIGHT0 + lightIndex] = true;
				
				var type:Int = this._defines.getLight(light.type, lightIndex);			
				this._defines.defines[type] = true;
				
				// Specular
				if (!light.specular.equalsFloats(0, 0, 0)) {
					this._defines.defines[TMD.SPECULARTERM] = true;
				}
				
				// Shadows
				if (scene.shadowsEnabled) {
					var shadowGenerator = light.getShadowGenerator();
					if (mesh != null && mesh.receiveShadows && shadowGenerator != null) {
						this._defines.defines[TMD.SHADOW0 + lightIndex] = true;
						
						this._defines.defines[TMD.SHADOWS] = true;
						
						if (shadowGenerator.useVarianceShadowMap || shadowGenerator.useBlurVarianceShadowMap) {
							this._defines.defines[TMD.SHADOWVSM0 + lightIndex] = true;
						}
						
						if (shadowGenerator.usePoissonSampling) {
							this._defines.defines[TMD.SHADOWPCF0 + lightIndex] = true;
						}
					}
				}
				
				lightIndex++;
				if (lightIndex == Material.maxSimultaneousLights) {
					break;
				}
			}
		}
		
		// Attribs
		if (mesh != null) {
			if (needNormals && mesh.isVerticesDataPresent(VertexBuffer.NormalKind)) {
				this._defines.defines[TMD.NORMAL] = true;
			}
			if (needUVs) {
				if (mesh.isVerticesDataPresent(VertexBuffer.UVKind)) {
					this._defines.defines[TMD.UV1] = true;
				}
				if (mesh.isVerticesDataPresent(VertexBuffer.UV2Kind)) {
					this._defines.defines[TMD.UV2] = true;
				}
			}
			if (mesh.useVertexColors && mesh.isVerticesDataPresent(VertexBuffer.ColorKind)) {
				this._defines.defines[TMD.VERTEXCOLOR] = true;
				
				if (mesh.hasVertexAlpha) {
					this._defines.defines[TMD.VERTEXALPHA] = true;
				}
			}
			if (mesh.useBones && mesh.computeBonesUsingShaders) {
				this._defines.NUM_BONE_INFLUENCERS = mesh.numBoneInfluencers;
				this._defines.BonesPerMesh = (mesh.skeleton.bones.length + 1);
			}
			
			// Instances
			if (useInstances) {
				this._defines.defines[TMD.INSTANCES] = true;
			}
		}
		
		// Get correct effect      
		if (!this._defines.isEqual(this._cachedDefines) || this._effect == null) {
			this._defines.cloneTo(this._cachedDefines);
			
			scene.resetCachedMaterial();
			
			// Fallbacks
			var fallbacks:EffectFallbacks = new EffectFallbacks();             
			if (this._defines.defines[TMD.FOG]) {
				fallbacks.addFallback(1, "FOG");
			}
			
			for (lightIndex in 0...Material.maxSimultaneousLights) {
				if (!this._defines.defines[TMD.LIGHT0 + lightIndex]) {
					continue;
				}
				
				if (lightIndex > 0) {
					fallbacks.addFallback(lightIndex, "LIGHT" + lightIndex);
				}
				
				if (this._defines.defines[TMD.SHADOW0 + lightIndex]) {
					fallbacks.addFallback(0, "SHADOW" + lightIndex);
				}
				
				if (this._defines.defines[TMD.SHADOWPCF0 + lightIndex]) {
					fallbacks.addFallback(0, "SHADOWPCF" + lightIndex);
				}
				
				if (this._defines.defines[TMD.SHADOWVSM0 + lightIndex]) {
					fallbacks.addFallback(0, "SHADOWVSM" + lightIndex);
				}
			}
		 
			if (this._defines.NUM_BONE_INFLUENCERS > 0){
                fallbacks.addCPUSkinningFallback(0, mesh);    
            }
			
			//Attributes
			var attribs:Array<String> = [VertexBuffer.PositionKind];
			
			if (this._defines.defines[TMD.NORMAL]) {
				attribs.push(VertexBuffer.NormalKind);
			}
			
			if (this._defines.defines[TMD.UV1]) {
				attribs.push(VertexBuffer.UVKind);
			}
			
			if (this._defines.defines[TMD.UV2]) {
				attribs.push(VertexBuffer.UV2Kind);
			}
			
			if (this._defines.defines[TMD.VERTEXCOLOR]) {
				attribs.push(VertexBuffer.ColorKind);
			}
			
			if (this._defines.NUM_BONE_INFLUENCERS > 0) {
				attribs.push(VertexBuffer.MatricesIndicesKind);
				attribs.push(VertexBuffer.MatricesWeightsKind);
				if (this._defines.NUM_BONE_INFLUENCERS > 4) {
                    attribs.push(VertexBuffer.MatricesIndicesExtraKind);
                    attribs.push(VertexBuffer.MatricesWeightsExtraKind);
                }
			}
			
			if (this._defines.defines[TMD.INSTANCES]) {
				attribs.push("world0");
				attribs.push("world1");
				attribs.push("world2");
				attribs.push("world3");
			}
			
			// Legacy browser patch
			var shaderName:String = "terrainmat";
			var join = this._defines.toString();
			this._effect = scene.getEngine().createEffect(shaderName,
				attribs,
				["world", "view", "viewProjection", "vEyePosition", "vLightsType", "vDiffuseColor", "vSpecularColor",
					"vLightData0", "vLightDiffuse0", "vLightSpecular0", "vLightDirection0", "vLightGround0", "lightMatrix0",
					"vLightData1", "vLightDiffuse1", "vLightSpecular1", "vLightDirection1", "vLightGround1", "lightMatrix1",
					"vLightData2", "vLightDiffuse2", "vLightSpecular2", "vLightDirection2", "vLightGround2", "lightMatrix2",
					"vLightData3", "vLightDiffuse3", "vLightSpecular3", "vLightDirection3", "vLightGround3", "lightMatrix3",
					"vFogInfos", "vFogColor", "pointSize",
					"vTextureInfos", 
					"mBones",
					"vClipPlane", "textureMatrix",
					"shadowsInfo0", "shadowsInfo1", "shadowsInfo2", "shadowsInfo3",
					
					"diffuse1Infos", "diffuse2Infos", "diffuse3Infos"
				],
				["textureSampler", "diffuse1Sampler", "diffuse2Sampler", "diffuse3Sampler",
					"bump1Sampler", "bump2Sampler", "bump3Sampler",
					"shadowSampler0", "shadowSampler1", "shadowSampler2", "shadowSampler3"
				],
				join, fallbacks, this.onCompiled, this.onError);
		}
		if (!this._effect.isReady()) {
			return false;
		}
		
		this._renderId = scene.getRenderId();
		this._wasPreviouslyReady = true;
		
		if (mesh != null) {
			if (mesh._materialDefines == null) {
				mesh._materialDefines = new TerrainMaterialDefines();
			}
			
			this._defines.cloneTo(mesh._materialDefines);
		}
		
		return true;
	}

	override public function bindOnlyWorldMatrix(world:Matrix) {
		this._effect.setMatrix("world", world);
	}

	override public function bind(world:Matrix, ?mesh:Mesh) {
		var scene = this.getScene();
		
		// Matrices        
		this.bindOnlyWorldMatrix(world);
		this._effect.setMatrix("viewProjection", scene.getTransformMatrix());
		
		// Bones
		if (mesh != null && mesh.useBones && mesh.computeBonesUsingShaders) {
			this._effect.setMatrices("mBones", mesh.skeleton.getTransformMatrices());
		}
		
		if (scene.getCachedMaterial() != this) {
			// Textures        
			if (this.mixTexture != null) {
				this._effect.setTexture("textureSampler", this.mixTexture);
				this._effect.setFloat2("vTextureInfos", this.mixTexture.coordinatesIndex, this.mixTexture.level);
				this._effect.setMatrix("textureMatrix", this.mixTexture.getTextureMatrix());
				
				if (StandardMaterial.DiffuseTextureEnabled) {
					if (this.diffuseTexture1 != null) {
						this._effect.setTexture("diffuse1Sampler", this.diffuseTexture1);
						this._effect.setFloat2("diffuse1Infos", this.diffuseTexture1.uScale, this.diffuseTexture1.vScale);
					}
					if (this.diffuseTexture2 != null) {
						this._effect.setTexture("diffuse2Sampler", this.diffuseTexture2);
						this._effect.setFloat2("diffuse2Infos", this.diffuseTexture2.uScale, this.diffuseTexture2.vScale);
					}
					if (this.diffuseTexture3 != null) {
						this._effect.setTexture("diffuse3Sampler", this.diffuseTexture3);
						this._effect.setFloat2("diffuse3Infos", this.diffuseTexture3.uScale, this.diffuseTexture3.vScale);
					}
				}
				
				if (StandardMaterial.BumpTextureEnabled && scene.getEngine().getCaps().standardDerivatives == true) {
					if (this.bumpTexture1 != null) {
						this._effect.setTexture("bump1Sampler", this.bumpTexture1);
					}
					if (this.bumpTexture2 != null) {
						this._effect.setTexture("bump2Sampler", this.bumpTexture2);
					}
					if (this.bumpTexture3 != null) {
						this._effect.setTexture("bump3Sampler", this.bumpTexture3);
					}
				}
			}
			// Clip plane
			if (scene.clipPlane != null) {
				var clipPlane = scene.clipPlane;
				this._effect.setFloat4("vClipPlane", clipPlane.normal.x, clipPlane.normal.y, clipPlane.normal.z, clipPlane.d);
			}
			
			// Point size
			if (this.pointsCloud) {
				this._effect.setFloat("pointSize", this.pointSize);
			}
			
			this._effect.setVector3("vEyePosition", scene._mirroredCameraPosition != null ? scene._mirroredCameraPosition : scene.activeCamera.position);                
		}
		
		this._effect.setColor4("vDiffuseColor", this._scaledDiffuse, this.alpha * mesh.visibility);
				
		if (this._defines.defines[TMD.SPECULARTERM]) {
			this._effect.setColor4("vSpecularColor", this.specularColor, this.specularPower);
		}
		
		if (scene.lightsEnabled && !this.disableLighting) {
			var lightIndex:Int = 0;
			for (index in 0...scene.lights.length) {
				var light = scene.lights[index];
				
				if (!light.isEnabled()) {
					continue;
				}
				
				if (!light.canAffectMesh(mesh)) {
					continue;
				}
				
				switch (light.type) {
					case "POINTLIGHT":
						light.transferToEffect(this._effect, "vLightData" + lightIndex);
						
					case "DIRLIGHT":
						light.transferToEffect(this._effect, "vLightData" + lightIndex);
						
					case "SPOTLIGHT":
						light.transferToEffect(this._effect, "vLightData" + lightIndex, "vLightDirection" + lightIndex);
						
					case "HEMILIGHT":
						light.transferToEffect(this._effect, "vLightData" + lightIndex, "vLightGround" + lightIndex);			
				}
				
				light.diffuse.scaleToRef(light.intensity, this._scaledDiffuse);
				this._effect.setColor4("vLightDiffuse" + lightIndex, this._scaledDiffuse, light.range);
				
				if (this._defines.defines[TMD.SPECULARTERM]) {
					light.specular.scaleToRef(light.intensity, this._scaledSpecular);
					this._effect.setColor3("vLightSpecular" + lightIndex, this._scaledSpecular);
				}
				
				// Shadows
				if (scene.shadowsEnabled) {
					var shadowGenerator = light.getShadowGenerator();
					if (mesh.receiveShadows && shadowGenerator != null) {
						this._effect.setMatrix("lightMatrix" + lightIndex, shadowGenerator.getTransformMatrix());
						this._effect.setTexture("shadowSampler" + lightIndex, shadowGenerator.getShadowMapForRendering());
						this._effect.setFloat3("shadowsInfo" + lightIndex, shadowGenerator.getDarkness(), shadowGenerator.getShadowMap().getSize().width, shadowGenerator.bias);
					}
				}
				
				lightIndex++;
				
				if (lightIndex == Material.maxSimultaneousLights) {
					break;
				}
			}
		}
		
		// View && Fog
		if (scene.fogEnabled && mesh.applyFog && scene.fogMode != Scene.FOGMODE_NONE) {
			this._effect.setMatrix("view", scene.getViewMatrix());
			
			this._effect.setFloat4("vFogInfos", scene.fogMode, scene.fogStart, scene.fogEnd, scene.fogDensity);
			this._effect.setColor3("vFogColor", scene.fogColor);
		}
		
		super.bind(world, mesh);
	}

	public function getAnimatables():Array<IAnimatable> {
		var results:Array<IAnimatable> = [];
		
		if (this.mixTexture != null && this.mixTexture.animations != null && this.mixTexture.animations.length > 0) {
			results.push(this.mixTexture);
		}
		
		return results;
	}

	override public function dispose(forceDisposeEffect:Bool = false) {
		if (this.mixTexture != null) {
			this.mixTexture.dispose();
		}
		
		super.dispose(forceDisposeEffect);
	}

	override public function clone(name:String):TerrainMaterial {
		var newMaterial:TerrainMaterial = new TerrainMaterial(name, this.getScene());
		
		// Base material
		this.copyTo(newMaterial);
		
		// Simple material
		if (this.mixTexture != null) {
			newMaterial.mixTexture = this.mixTexture.clone();
		}
		
		newMaterial.diffuseColor = this.diffuseColor.clone();
		
		return newMaterial;
	}
	
}
