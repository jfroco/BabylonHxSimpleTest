package com.babylonhx.materials.lib.pbr;

import com.babylonhx.Engine;
import com.babylonhx.lights.shadows.ShadowGenerator;
import com.babylonhx.lights.IShadowLight;
import com.babylonhx.lights.Light;
import com.babylonhx.materials.EffectFallbacks;
import com.babylonhx.materials.textures.BaseTexture;
import com.babylonhx.materials.textures.RenderTargetTexture;
import com.babylonhx.materials.textures.Texture;
import com.babylonhx.math.Color3;
import com.babylonhx.math.Vector4;
import com.babylonhx.math.Vector3;
import com.babylonhx.math.Matrix;
import com.babylonhx.mesh.AbstractMesh;
import com.babylonhx.mesh.Mesh;
import com.babylonhx.mesh.VertexBuffer;
import com.babylonhx.tools.SmartArray;
import com.babylonhx.lights.SpotLight;
import com.babylonhx.lights.DirectionalLight;
import com.babylonhx.lights.HemisphericLight;
import com.babylonhx.lights.PointLight;
import com.babylonhx.tools.Tools;
import com.babylonhx.animations.IAnimatable;


/**
 * ...
 * @author Krtolica Vujadin
 */

typedef PBRM = PBRMaterialDefines
 
class PBRMaterial extends Material {
	
	public static var fragmentShader:String = "precision highp float;\n\n// Constants\n#define RECIPROCAL_PI2 0.15915494\n#define FRESNEL_MAXIMUM_ON_ROUGH 0.25\n\nuniform vec3 vEyePosition;\nuniform vec3 vAmbientColor;\nuniform vec4 vDiffuseColor;\n\n// PBR CUSTOM CONTROLS\nuniform vec4 vPBRLightingIntensity;\nuniform vec4 vPBRShadowIntensity;\nuniform vec4 vPBRCameraInfos;\n\nuniform vec4 vPBROverloadedIntensity;\nuniform vec3 vPBROverloadedAmbient;\nuniform vec3 vPBROverloadedDiffuse;\nuniform vec3 vPBROverloadedSpecular;\nuniform vec3 vPBROverloadedEmissive;\nuniform vec3 vPBROverloadedSmoothness;\n\n// PBR CUSTOM CONSTANTS\nconst float kPi = 3.1415926535897932384626433832795;\n\n// PBR HELPER METHODS\nfloat Square(float value)\n{\n    return value * value;\n}\n\nfloat getLuminance(vec3 color)\n{\n    return clamp(dot(color, vec3(0.2126, 0.7152, 0.0722)), 0., 1.);\n}\n\nfloat convertRoughnessToAverageSlope(float roughness)\n{\n    // Calculate AlphaG as square of roughness; add epsilon to avoid numerical issues\n    const float kMinimumVariance = 0.0005;\n    float alphaG = Square(roughness) + kMinimumVariance;\n    return alphaG;\n}\n\n// From Microfacet Models for Refraction through Rough Surfaces, Walter et al. 2007\nfloat smithVisibilityG1_TrowbridgeReitzGGX(float dot, float alphaG)\n{\n    float tanSquared = (1.0 - dot * dot) / (dot * dot);\n    return 2.0 / (1.0 + sqrt(1.0 + alphaG * alphaG * tanSquared));\n}\n\nfloat smithVisibilityG_TrowbridgeReitzGGX_Walter(float NdotL, float NdotV, float alphaG)\n{\n    return smithVisibilityG1_TrowbridgeReitzGGX(NdotL, alphaG) * smithVisibilityG1_TrowbridgeReitzGGX(NdotV, alphaG);\n}\n\n// Trowbridge-Reitz (GGX)\n// Generalised Trowbridge-Reitz with gamma power=2.0\nfloat normalDistributionFunction_TrowbridgeReitzGGX(float NdotH, float alphaG)\n{\n    // Note: alphaG is average slope (gradient) of the normals in slope-space.\n    // It is also the (trigonometric) tangent of the median distribution value, i.e. 50% of normals have\n    // a tangent (gradient) closer to the macrosurface than this slope.\n    float a2 = Square(alphaG);\n    float d = NdotH * NdotH * (a2 - 1.0) + 1.0;\n    return a2 / (kPi * d * d);\n}\n\nvec3 fresnelSchlickGGX(float VdotH, vec3 reflectance0, vec3 reflectance90)\n{\n    return reflectance0 + (reflectance90 - reflectance0) * pow(clamp(1.0 - VdotH, 0., 1.), 5.0);\n}\n\nvec3 FresnelSchlickEnvironmentGGX(float VdotN, vec3 reflectance0, vec3 reflectance90, float smoothness)\n{\n    // Schlick fresnel approximation, extended with basic smoothness term so that rough surfaces do not approach reflectance90 at grazing angle\n    float weight = mix(FRESNEL_MAXIMUM_ON_ROUGH, 1.0, smoothness);\n    return reflectance0 + weight * (reflectance90 - reflectance0) * pow(clamp(1.0 - VdotN, 0., 1.), 5.0);\n}\n\n// Cook Torance Specular computation.\nvec3 computeSpecularTerm(float NdotH, float NdotL, float NdotV, float VdotH, float roughness, vec3 specularColor)\n{\n    float alphaG = convertRoughnessToAverageSlope(roughness);\n    float distribution = normalDistributionFunction_TrowbridgeReitzGGX(NdotH, alphaG);\n    float visibility = smithVisibilityG_TrowbridgeReitzGGX_Walter(NdotL, NdotV, alphaG);\n    visibility /= (4.0 * NdotL * NdotV); // Cook Torance Denominator  integated in viibility to avoid issues when visibility function changes.\n\n    vec3 fresnel = fresnelSchlickGGX(VdotH, specularColor, vec3(1., 1., 1.));\n\n    float specTerm = max(0., visibility * distribution) * NdotL;\n    return fresnel * specTerm * kPi; // TODO: audit pi constants\n}\n\nfloat computeDiffuseTerm(float NdotL, float NdotV, float VdotH, float roughness)\n{\n    // Diffuse fresnel falloff as per Disney principled BRDF, and in the spirit of\n    // of general coupled diffuse/specular models e.g. Ashikhmin Shirley.\n    float diffuseFresnelNV = pow(clamp(1.0 - NdotL, 0.000001, 1.), 5.0);\n    float diffuseFresnelNL = pow(clamp(1.0 - NdotV, 0.000001, 1.), 5.0);\n    float diffuseFresnel90 = 0.5 + 2.0 * VdotH * VdotH * roughness;\n    float diffuseFresnelTerm =\n        (1.0 + (diffuseFresnel90 - 1.0) * diffuseFresnelNL) *\n        (1.0 + (diffuseFresnel90 - 1.0) * diffuseFresnelNV);\n\n\n    return diffuseFresnelTerm * NdotL;\n    // PI Test\n    // diffuseFresnelTerm /= kPi;\n}\n\nfloat computeDefaultGlossiness(float glossiness, vec3 specularColor)\n{\n    float kSpecularNoAlphaWorkflow_SmoothnessMax = 0.95;\n\n    float specularLuminance = getLuminance(specularColor);\n    float specularLuma = sqrt(specularLuminance);\n    glossiness = specularLuma * kSpecularNoAlphaWorkflow_SmoothnessMax;\n\n    return glossiness;\n}\n\nvec3 toLinearSpace(vec3 color)\n{\n    return vec3(pow(color.r, 2.2), pow(color.g, 2.2), pow(color.b, 2.2));\n}\n\nvec3 toGammaSpace(vec3 color)\n{\n    return vec3(pow(color.r, 1.0 / 2.2), pow(color.g, 1.0 / 2.2), pow(color.b, 1.0 / 2.2));\n}\n\nvec3 toneMaps(vec3 color)\n{\n    color = max(color, 0.0);\n\n    // TONE MAPPING / EXPOSURE\n    color.rgb = color.rgb * vPBRCameraInfos.x;\n\n    float tuning = 1.5; // TODO: sync up so e.g. 18% greys are matched to exposure appropriately\n    // PI Test\n    // tuning *=  kPi;\n    vec3 tonemapped = 1.0 - exp2(-color.rgb * tuning); // simple local photographic tonemapper\n    color.rgb = mix(color.rgb, tonemapped, 1.0);\n    return color;\n}\n\nvec4 contrasts(vec4 color)\n{\n    color = clamp(color, 0.0, 1.0);\n\n    vec3 resultHighContrast = color.rgb * color.rgb * (3.0 - 2.0 * color.rgb);\n    float contrast = vPBRCameraInfos.y;\n    if (contrast < 1.0)\n    {\n        // Decrease contrast: interpolate towards zero-contrast image (flat grey)\n        color.rgb = mix(vec3(0.5, 0.5, 0.5), color.rgb, contrast);\n    }\n    else\n    {\n        // Increase contrast: apply simple shoulder-toe high contrast curve\n        color.rgb = mix(color.rgb, resultHighContrast, contrast - 1.0);\n    }\n\n    return color;\n}\n// END PBR HELPER METHODS\n\n#ifdef SPECULARTERM\nuniform vec4 vSpecularColor;\n#endif\nuniform vec3 vEmissiveColor;\n\n// Input\nvarying vec3 vPositionW;\n\n#ifdef NORMAL\nvarying vec3 vNormalW;\n#endif\n\n#ifdef VERTEXCOLOR\nvarying vec4 vColor;\n#endif\n\n// Lights\n#ifdef LIGHT0\nuniform vec4 vLightData0;\nuniform vec4 vLightDiffuse0;\n#ifdef SPECULARTERM\nuniform vec3 vLightSpecular0;\n#endif\n#ifdef SHADOW0\n#if defined(SPOTLIGHT0) || defined(DIRLIGHT0)\nvarying vec4 vPositionFromLight0;\nuniform sampler2D shadowSampler0;\n#else\nuniform samplerCube shadowSampler0;\n#endif\nuniform vec3 shadowsInfo0;\n#endif\n#ifdef SPOTLIGHT0\nuniform vec4 vLightDirection0;\n#endif\n#ifdef HEMILIGHT0\nuniform vec3 vLightGround0;\n#endif\n#endif\n\n#ifdef LIGHT1\nuniform vec4 vLightData1;\nuniform vec4 vLightDiffuse1;\n#ifdef SPECULARTERM\nuniform vec3 vLightSpecular1;\n#endif\n#ifdef SHADOW1\n#if defined(SPOTLIGHT1) || defined(DIRLIGHT1)\nvarying vec4 vPositionFromLight1;\nuniform sampler2D shadowSampler1;\n#else\nuniform samplerCube shadowSampler1;\n#endif\nuniform vec3 shadowsInfo1;\n#endif\n#ifdef SPOTLIGHT1\nuniform vec4 vLightDirection1;\n#endif\n#ifdef HEMILIGHT1\nuniform vec3 vLightGround1;\n#endif\n#endif\n\n#ifdef LIGHT2\nuniform vec4 vLightData2;\nuniform vec4 vLightDiffuse2;\n#ifdef SPECULARTERM\nuniform vec3 vLightSpecular2;\n#endif\n#ifdef SHADOW2\n#if defined(SPOTLIGHT2) || defined(DIRLIGHT2)\nvarying vec4 vPositionFromLight2;\nuniform sampler2D shadowSampler2;\n#else\nuniform samplerCube shadowSampler2;\n#endif\nuniform vec3 shadowsInfo2;\n#endif\n#ifdef SPOTLIGHT2\nuniform vec4 vLightDirection2;\n#endif\n#ifdef HEMILIGHT2\nuniform vec3 vLightGround2;\n#endif\n#endif\n\n#ifdef LIGHT3\nuniform vec4 vLightData3;\nuniform vec4 vLightDiffuse3;\n#ifdef SPECULARTERM\nuniform vec3 vLightSpecular3;\n#endif\n#ifdef SHADOW3\n#if defined(SPOTLIGHT3) || defined(DIRLIGHT3)\nvarying vec4 vPositionFromLight3;\nuniform sampler2D shadowSampler3;\n#else\nuniform samplerCube shadowSampler3;\n#endif\nuniform vec3 shadowsInfo3;\n#endif\n#ifdef SPOTLIGHT3\nuniform vec4 vLightDirection3;\n#endif\n#ifdef HEMILIGHT3\nuniform vec3 vLightGround3;\n#endif\n#endif\n\n// Samplers\n#ifdef DIFFUSE\nvarying vec2 vDiffuseUV;\nuniform sampler2D diffuseSampler;\nuniform vec2 vDiffuseInfos;\n#endif\n\n#ifdef AMBIENT\nvarying vec2 vAmbientUV;\nuniform sampler2D ambientSampler;\nuniform vec2 vAmbientInfos;\n#endif\n\n#ifdef OPACITY	\nvarying vec2 vOpacityUV;\nuniform sampler2D opacitySampler;\nuniform vec2 vOpacityInfos;\n#endif\n\n#ifdef EMISSIVE\nvarying vec2 vEmissiveUV;\nuniform vec2 vEmissiveInfos;\nuniform sampler2D emissiveSampler;\n#endif\n\n#ifdef LIGHTMAP\nvarying vec2 vLightmapUV;\nuniform vec2 vLightmapInfos;\nuniform sampler2D lightmapSampler;\n#endif\n\n#if defined(SPECULAR) && defined(SPECULARTERM)\nvarying vec2 vSpecularUV;\nuniform vec2 vSpecularInfos;\nuniform sampler2D specularSampler;\n#endif\n\n// Fresnel\n#ifdef FRESNEL\nfloat computeFresnelTerm(vec3 viewDirection, vec3 worldNormal, float bias, float power)\n{\n    float fresnelTerm = pow(bias + abs(dot(viewDirection, worldNormal)), power);\n    return clamp(fresnelTerm, 0., 1.);\n}\n#endif\n\n#ifdef DIFFUSEFRESNEL\nuniform vec4 diffuseLeftColor;\nuniform vec4 diffuseRightColor;\n#endif\n\n#ifdef OPACITYFRESNEL\nuniform vec4 opacityParts;\n#endif\n\n#ifdef EMISSIVEFRESNEL\nuniform vec4 emissiveLeftColor;\nuniform vec4 emissiveRightColor;\n#endif\n\n// Reflection\n#ifdef REFLECTION\nuniform vec2 vReflectionInfos;\n\n#ifdef REFLECTIONMAP_3D\nuniform samplerCube reflectionCubeSampler;\n#else\nuniform sampler2D reflection2DSampler;\n#endif\n\n#ifdef REFLECTIONMAP_SKYBOX\nvarying vec3 vPositionUVW;\n#else\n#ifdef REFLECTIONMAP_EQUIRECTANGULAR\nvarying vec3 vDirectionW;\n#endif\n\n#if defined(REFLECTIONMAP_PLANAR) || defined(REFLECTIONMAP_CUBIC) || defined(REFLECTIONMAP_PROJECTION)\nuniform mat4 reflectionMatrix;\n#endif\n#if defined(REFLECTIONMAP_SPHERICAL) || defined(REFLECTIONMAP_PROJECTION)\nuniform mat4 view;\n#endif\n#endif\n\nvec3 computeReflectionCoords(vec4 worldPos, vec3 worldNormal)\n{\n#ifdef REFLECTIONMAP_EQUIRECTANGULAR\n    vec3 direction = normalize(vDirectionW);\n\n    float t = clamp(direction.y * -0.5 + 0.5, 0., 1.0);\n    float s = atan(direction.z, direction.x) * RECIPROCAL_PI2 + 0.5;\n\n    return vec3(s, t, 0);\n#endif\n\n#ifdef REFLECTIONMAP_SPHERICAL\n    vec3 viewDir = normalize(vec3(view * worldPos));\n    vec3 viewNormal = normalize(vec3(view * vec4(worldNormal, 0.0)));\n\n    vec3 r = reflect(viewDir, viewNormal);\n    r.z = r.z - 1.0;\n\n    float m = 2.0 * length(r);\n\n    return vec3(r.x / m + 0.5, 1.0 - r.y / m - 0.5, 0);\n#endif\n\n#ifdef REFLECTIONMAP_PLANAR\n    vec3 viewDir = worldPos.xyz - vEyePosition;\n    vec3 coords = normalize(reflect(viewDir, worldNormal));\n\n    return vec3(reflectionMatrix * vec4(coords, 1));\n#endif\n\n#ifdef REFLECTIONMAP_CUBIC\n    vec3 viewDir = worldPos.xyz - vEyePosition;\n    vec3 coords = reflect(viewDir, worldNormal);\n#ifdef INVERTCUBICMAP\n    coords.y = 1.0 - coords.y;\n#endif\n    return vec3(reflectionMatrix * vec4(coords, 0));\n#endif\n\n#ifdef REFLECTIONMAP_PROJECTION\n    return vec3(reflectionMatrix * (view * worldPos));\n#endif\n\n#ifdef REFLECTIONMAP_SKYBOX\n    return vPositionUVW;\n#endif\n\n#ifdef REFLECTIONMAP_EXPLICIT\n    return vec3(0, 0, 0);\n#endif\n}\n\n#ifdef REFLECTIONFRESNEL\nuniform vec4 reflectionLeftColor;\nuniform vec4 reflectionRightColor;\n#endif\n\n#endif\n\n// Shadows\n#ifdef SHADOWS\n\nfloat unpack(vec4 color)\n{\n    const vec4 bit_shift = vec4(1.0 / (255.0 * 255.0 * 255.0), 1.0 / (255.0 * 255.0), 1.0 / 255.0, 1.0);\n    return dot(color, bit_shift);\n}\n\n#if defined(POINTLIGHT0) || defined(POINTLIGHT1) || defined(POINTLIGHT2) || defined(POINTLIGHT3)\nfloat computeShadowCube(vec3 lightPosition, samplerCube shadowSampler, float darkness, float bias)\n{\n    vec3 directionToLight = vPositionW - lightPosition;\n    float depth = length(directionToLight);\n\n    depth = clamp(depth, 0., 1.);\n\n    directionToLight.y = 1.0 - directionToLight.y;\n\n    float shadow = unpack(textureCube(shadowSampler, directionToLight)) + bias;\n\n    if (depth > shadow)\n    {\n        return mix(1.0, darkness, vPBRShadowIntensity.x);\n    }\n    return 1.0;\n}\n\nfloat computeShadowWithPCFCube(vec3 lightPosition, samplerCube shadowSampler, float mapSize, float bias, float darkness)\n{\n    vec3 directionToLight = vPositionW - lightPosition;\n    float depth = length(directionToLight);\n    float diskScale = (1.0 - (1.0 + depth * 3.0)) / mapSize;\n\n    depth = clamp(depth, 0., 1.);\n\n    directionToLight.y = 1.0 - directionToLight.y;\n\n    float visibility = 1.;\n\n    vec3 poissonDisk[4];\n    poissonDisk[0] = vec3(-1.0, 1.0, -1.0);\n    poissonDisk[1] = vec3(1.0, -1.0, -1.0);\n    poissonDisk[2] = vec3(-1.0, -1.0, -1.0);\n    poissonDisk[3] = vec3(1.0, -1.0, 1.0);\n\n    // Poisson Sampling\n    float biasedDepth = depth - bias;\n\n    if (unpack(textureCube(shadowSampler, directionToLight + poissonDisk[0] * diskScale)) < biasedDepth) visibility -= 0.25;\n    if (unpack(textureCube(shadowSampler, directionToLight + poissonDisk[1] * diskScale)) < biasedDepth) visibility -= 0.25;\n    if (unpack(textureCube(shadowSampler, directionToLight + poissonDisk[2] * diskScale)) < biasedDepth) visibility -= 0.25;\n    if (unpack(textureCube(shadowSampler, directionToLight + poissonDisk[3] * diskScale)) < biasedDepth) visibility -= 0.25;\n\n    return  min(1.0, mix(1.0, visibility + darkness, vPBRShadowIntensity.x));\n}\n#endif\n\n#if defined(SPOTLIGHT0) || defined(SPOTLIGHT1) || defined(SPOTLIGHT2) || defined(SPOTLIGHT3) ||  defined(DIRLIGHT0) || defined(DIRLIGHT1) || defined(DIRLIGHT2) || defined(DIRLIGHT3)\nfloat computeShadow(vec4 vPositionFromLight, sampler2D shadowSampler, float darkness, float bias)\n{\n    vec3 depth = vPositionFromLight.xyz / vPositionFromLight.w;\n    depth = 0.5 * depth + vec3(0.5);\n    vec2 uv = depth.xy;\n\n    if (uv.x < 0. || uv.x > 1.0 || uv.y < 0. || uv.y > 1.0)\n    {\n        return 1.0;\n    }\n\n    float shadow = unpack(texture2D(shadowSampler, uv)) + bias;\n\n    if (depth.z > shadow)\n    {\n        return mix(1.0, darkness, vPBRShadowIntensity.x);\n    }\n    return 1.;\n}\n\nfloat computeShadowWithPCF(vec4 vPositionFromLight, sampler2D shadowSampler, float mapSize, float bias, float darkness)\n{\n    vec3 depth = vPositionFromLight.xyz / vPositionFromLight.w;\n    depth = 0.5 * depth + vec3(0.5);\n    vec2 uv = depth.xy;\n\n    if (uv.x < 0. || uv.x > 1.0 || uv.y < 0. || uv.y > 1.0)\n    {\n        return 1.0;\n    }\n\n    float visibility = 1.;\n\n    vec2 poissonDisk[4];\n    poissonDisk[0] = vec2(-0.94201624, -0.39906216);\n    poissonDisk[1] = vec2(0.94558609, -0.76890725);\n    poissonDisk[2] = vec2(-0.094184101, -0.92938870);\n    poissonDisk[3] = vec2(0.34495938, 0.29387760);\n\n    // Poisson Sampling\n    float biasedDepth = depth.z - bias;\n\n    if (unpack(texture2D(shadowSampler, uv + poissonDisk[0] / mapSize)) < biasedDepth) visibility -= 0.25;\n    if (unpack(texture2D(shadowSampler, uv + poissonDisk[1] / mapSize)) < biasedDepth) visibility -= 0.25;\n    if (unpack(texture2D(shadowSampler, uv + poissonDisk[2] / mapSize)) < biasedDepth) visibility -= 0.25;\n    if (unpack(texture2D(shadowSampler, uv + poissonDisk[3] / mapSize)) < biasedDepth) visibility -= 0.25;\n\n    return  min(1.0, mix(1.0, visibility + darkness, vPBRShadowIntensity.x));\n}\n\n// Thanks to http://devmaster.net/\nfloat unpackHalf(vec2 color)\n{\n    return color.x + (color.y / 255.0);\n}\n\nfloat linstep(float low, float high, float v) {\n    return clamp((v - low) / (high - low), 0.0, 1.0);\n}\n\nfloat ChebychevInequality(vec2 moments, float compare, float bias)\n{\n    float p = smoothstep(compare - bias, compare, moments.x);\n    float variance = max(moments.y - moments.x * moments.x, 0.02);\n    float d = compare - moments.x;\n    float p_max = linstep(0.2, 1.0, variance / (variance + d * d));\n\n    return clamp(max(p, p_max), 0.0, 1.0);\n}\n\nfloat computeShadowWithVSM(vec4 vPositionFromLight, sampler2D shadowSampler, float bias, float darkness)\n{\n    vec3 depth = vPositionFromLight.xyz / vPositionFromLight.w;\n    depth = 0.5 * depth + vec3(0.5);\n    vec2 uv = depth.xy;\n\n    if (uv.x < 0. || uv.x > 1.0 || uv.y < 0. || uv.y > 1.0 || depth.z >= 1.0)\n    {\n        return 1.0;\n    }\n\n    vec4 texel = texture2D(shadowSampler, uv);\n\n    vec2 moments = vec2(unpackHalf(texel.xy), unpackHalf(texel.zw));\n    return min(1.0, mix(1.0, 1.0 - ChebychevInequality(moments, depth.z, bias) + darkness, vPBRShadowIntensity.x));\n}\n#endif\n\n#endif\n\n// Bump\n#ifdef BUMP\n#extension GL_OES_standard_derivatives : enable\nvarying vec2 vBumpUV;\nuniform vec2 vBumpInfos;\nuniform sampler2D bumpSampler;\n\n// Thanks to http://www.thetenthplanet.de/archives/1180\nmat3 cotangent_frame(vec3 normal, vec3 p, vec2 uv)\n{\n    // get edge vectors of the pixel triangle\n    vec3 dp1 = dFdx(p);\n    vec3 dp2 = dFdy(p);\n    vec2 duv1 = dFdx(uv);\n    vec2 duv2 = dFdy(uv);\n\n    // solve the linear system\n    vec3 dp2perp = cross(dp2, normal);\n    vec3 dp1perp = cross(normal, dp1);\n    vec3 tangent = dp2perp * duv1.x + dp1perp * duv2.x;\n    vec3 binormal = dp2perp * duv1.y + dp1perp * duv2.y;\n\n    // construct a scale-invariant frame \n    float invmax = inversesqrt(max(dot(tangent, tangent), dot(binormal, binormal)));\n    return mat3(tangent * invmax, binormal * invmax, normal);\n}\n\nvec3 perturbNormal(vec3 viewDir)\n{\n    vec3 map = texture2D(bumpSampler, vBumpUV).xyz;\n    map = map * 255. / 127. - 128. / 127.;\n    mat3 TBN = cotangent_frame(vNormalW * vBumpInfos.y, -viewDir, vBumpUV);\n    return normalize(TBN * map);\n}\n#endif\n\n#ifdef CLIPPLANE\nvarying float fClipDistance;\n#endif\n\n// Fog\n#ifdef FOG\n\n#define FOGMODE_NONE    0.\n#define FOGMODE_EXP     1.\n#define FOGMODE_EXP2    2.\n#define FOGMODE_LINEAR  3.\n#define E 2.71828\n\nuniform vec4 vFogInfos;\nuniform vec3 vFogColor;\nvarying float fFogDistance;\n\nfloat CalcFogFactor()\n{\n    float fogCoeff = 1.0;\n    float fogStart = vFogInfos.y;\n    float fogEnd = vFogInfos.z;\n    float fogDensity = vFogInfos.w;\n\n    if (FOGMODE_LINEAR == vFogInfos.x)\n    {\n        fogCoeff = (fogEnd - fFogDistance) / (fogEnd - fogStart);\n    }\n    else if (FOGMODE_EXP == vFogInfos.x)\n    {\n        fogCoeff = 1.0 / pow(E, fFogDistance * fogDensity);\n    }\n    else if (FOGMODE_EXP2 == vFogInfos.x)\n    {\n        fogCoeff = 1.0 / pow(E, fFogDistance * fFogDistance * fogDensity * fogDensity);\n    }\n\n    return clamp(fogCoeff, 0.0, 1.0);\n}\n#endif\n\n// Light Computing\nstruct lightingInfo\n{\n    vec3 diffuse;\n#ifdef SPECULARTERM\n    vec3 specular;\n#endif\n};\n\nlightingInfo computeLighting(vec3 viewDirectionW, vec3 vNormal, vec4 lightData, vec3 diffuseColor, vec3 specularColor, float range, float roughness, float NdotV) {\n    lightingInfo result;\n\n    vec3 lightVectorW;\n    float attenuation = 1.0;\n    if (lightData.w == 0.)\n    {\n        vec3 direction = lightData.xyz - vPositionW;\n\n        attenuation = max(0., 1.0 - length(direction) / range);\n        lightVectorW = normalize(direction);\n    }\n    else\n    {\n        lightVectorW = normalize(-lightData.xyz);\n    }\n\n    // diffuse\n    vec3 H = normalize(viewDirectionW + lightVectorW);\n    float NdotL = max(0.00000000001, dot(vNormal, lightVectorW));\n    float VdotH = clamp(0.00000000001, 1.0, dot(viewDirectionW, H));\n\n    float diffuseTerm = computeDiffuseTerm(NdotL, NdotV, VdotH, roughness);\n    result.diffuse = diffuseTerm * diffuseColor * attenuation;\n\n#ifdef SPECULARTERM\n    // Specular\n    float NdotH = max(0.00000000001, dot(vNormal, H));\n\n    vec3 specTerm = computeSpecularTerm(NdotH, NdotL, NdotV, VdotH, roughness, specularColor);\n    result.specular = specTerm * attenuation;\n#endif\n\n    return result;\n}\n\nlightingInfo computeSpotLighting(vec3 viewDirectionW, vec3 vNormal, vec4 lightData, vec4 lightDirection, vec3 diffuseColor, vec3 specularColor, float range, float roughness, float NdotV) {\n    lightingInfo result;\n\n    vec3 direction = lightData.xyz - vPositionW;\n    vec3 lightVectorW = normalize(direction);\n    float attenuation = max(0., 1.0 - length(direction) / range);\n\n    // diffuse\n    float cosAngle = max(0.0000001, dot(-lightDirection.xyz, lightVectorW));\n    float spotAtten = 0.0;\n\n    if (cosAngle >= lightDirection.w)\n    {\n        cosAngle = max(0., pow(cosAngle, lightData.w));\n        spotAtten = clamp((cosAngle - lightDirection.w) / (1. - cosAngle), 0.0, 1.0);\n\n        // Diffuse\n        vec3 H = normalize(viewDirectionW - lightDirection.xyz);\n        float NdotL = max(0.00000000001, dot(vNormal, -lightDirection.xyz));\n        float VdotH = clamp(dot(viewDirectionW, H), 0.00000000001, 1.0);\n\n        float diffuseTerm = computeDiffuseTerm(NdotL, NdotV, VdotH, roughness);\n        result.diffuse = diffuseTerm * diffuseColor * attenuation * spotAtten;\n\n#ifdef SPECULARTERM\n        // Specular\n        float NdotH = max(0.00000000001, dot(vNormal, H));\n\n        vec3 specTerm = computeSpecularTerm(NdotH, NdotL, NdotV, VdotH, roughness, specularColor);\n        result.specular = specTerm  * attenuation * spotAtten;\n#endif\n\n        return result;\n    }\n\n    result.diffuse = vec3(0.);\n#ifdef SPECULARTERM\n    result.specular = vec3(0.);\n#endif\n\n    return result;\n}\n\nlightingInfo computeHemisphericLighting(vec3 viewDirectionW, vec3 vNormal, vec4 lightData, vec3 diffuseColor, vec3 specularColor, vec3 groundColor, float roughness, float NdotV) {\n    lightingInfo result;\n\n    vec3 lightVectorW = normalize(lightData.xyz);\n\n    // Diffuse\n    float ndl = dot(vNormal, lightData.xyz) * 0.5 + 0.5;\n    result.diffuse = mix(groundColor, diffuseColor, ndl);\n\n#ifdef SPECULARTERM\n    // Specular\n    vec3 H = normalize(viewDirectionW + lightVectorW);\n    float NdotH = max(0.00000000001, dot(vNormal, H));\n    float NdotL = max(0.00000000001, ndl);\n    float VdotH = clamp(0.00000000001, 1.0, dot(viewDirectionW, H));\n\n    vec3 specTerm = computeSpecularTerm(NdotH, NdotL, NdotV, VdotH, roughness, specularColor);\n    result.specular = specTerm;\n#endif\n\n    return result;\n}\n\nvoid main(void) {\n    // Clip plane\n#ifdef CLIPPLANE\n    if (fClipDistance > 0.0)\n        discard;\n#endif\n\n    vec3 viewDirectionW = normalize(vEyePosition - vPositionW);\n\n    // Base color\n    vec4 baseColor = vec4(1., 1., 1., 1.);\n    vec3 diffuseColor = vDiffuseColor.rgb;\n    \n    // Alpha\n    float alpha = vDiffuseColor.a;\n\n#ifdef DIFFUSE\n    baseColor = texture2D(diffuseSampler, vDiffuseUV);\n    baseColor = vec4(toLinearSpace(baseColor.rgb), baseColor.a);\n\n#ifdef ALPHATEST\n    if (baseColor.a < 0.4)\n        discard;\n#endif\n\n#ifdef ALPHAFROMDIFFUSE\n    alpha *= baseColor.a;\n#endif\n\n    baseColor.rgb *= vDiffuseInfos.y;\n#endif\n\n    baseColor.rgb = mix(baseColor.rgb, vPBROverloadedDiffuse, vPBROverloadedIntensity.y);\n\n\n#ifdef VERTEXCOLOR\n    baseColor.rgb *= vColor.rgb;\n#endif\n\n    // Bump\n#ifdef NORMAL\n    vec3 normalW = normalize(vNormalW);\n#else\n    vec3 normalW = vec3(1.0, 1.0, 1.0);\n#endif\n\n\n#ifdef BUMP\n    normalW = perturbNormal(viewDirectionW);\n#endif\n\n    // Ambient color\n    vec3 baseAmbientColor = vec3(1., 1., 1.);\n\n#ifdef AMBIENT\n    baseAmbientColor = texture2D(ambientSampler, vAmbientUV).rgb * vAmbientInfos.y;\n    baseAmbientColor.rgb = mix(baseAmbientColor.rgb, vPBROverloadedAmbient, vPBROverloadedIntensity.x);\n#endif\n\n    // Specular map\n#ifdef SPECULARTERM\n    float glossiness = vSpecularColor.a;\n    vec3 specularColor = vSpecularColor.rgb;\n    specularColor.rgb = mix(specularColor.rgb, vPBROverloadedSpecular, vPBROverloadedIntensity.z);\n\n    #ifdef SPECULAR\n        vec4 specularMapColor = texture2D(specularSampler, vSpecularUV);\n        specularColor = toLinearSpace(specularMapColor.rgb);\n        specularColor.rgb = mix(specularColor.rgb, vPBROverloadedSpecular, vPBROverloadedIntensity.z);\n\n        #ifdef GLOSSINESS\n            glossiness = specularMapColor.a;\n        #else\n            glossiness = computeDefaultGlossiness(glossiness, specularColor);\n        #endif\n    #endif\n\n    glossiness = mix(glossiness, vPBROverloadedSmoothness.x, vPBROverloadedSmoothness.y);\n#else\n    float glossiness = 0.;\n    glossiness = mix(glossiness, vPBROverloadedSmoothness.x, vPBROverloadedSmoothness.y);\n    vec3 specularColor = vec3(0., 0., 0);\n    specularColor.rgb = mix(specularColor.rgb, vPBROverloadedSpecular, vPBROverloadedIntensity.z);\n#endif\n\n    // Apply Energy Conservation.\n    float reflectance = max(max(specularColor.r, specularColor.g), specularColor.b);\n    baseColor.rgb = (1. - reflectance) * baseColor.rgb;\n\n    // Compute Specular Fresnel + Reflectance.\n    float NdotV = max(0.00000000001, dot(normalW, viewDirectionW));\n\n    // Adapt glossiness.\n    glossiness = clamp(glossiness, 0., 1.) * 0.98;\n\n    // Call rough to not conflict with previous one.\n    float rough = clamp(1. - glossiness, 0.000001, 1.0);\n\n    // Lighting\n    vec3 diffuseBase = vec3(0., 0., 0.);\n    vec3 shadowedOnly = vPBROverloadedDiffuse;\n\n#ifdef SPECULARTERM\n    vec3 specularBase = vec3(0., 0., 0.);\n#endif\n    float shadow = 1.;\n\n#ifdef LIGHT0\n#ifndef SPECULARTERM\n    vec3 vLightSpecular0 = vec3(0.0);\n#endif\n#ifdef SPOTLIGHT0\n    lightingInfo info = computeSpotLighting(viewDirectionW, normalW, vLightData0, vLightDirection0, vLightDiffuse0.rgb, vLightSpecular0, vLightDiffuse0.a, rough, NdotV);\n#endif\n#ifdef HEMILIGHT0\n    lightingInfo info = computeHemisphericLighting(viewDirectionW, normalW, vLightData0, vLightDiffuse0.rgb, vLightSpecular0, vLightGround0, rough, NdotV);\n#endif\n#if defined(POINTLIGHT0) || defined(DIRLIGHT0)\n    lightingInfo info = computeLighting(viewDirectionW, normalW, vLightData0, vLightDiffuse0.rgb, vLightSpecular0, vLightDiffuse0.a, rough, NdotV);\n#endif\n#ifdef SHADOW0\n#ifdef SHADOWVSM0\n    shadow = computeShadowWithVSM(vPositionFromLight0, shadowSampler0, shadowsInfo0.z, shadowsInfo0.x);\n#else\n#ifdef SHADOWPCF0\n#if defined(POINTLIGHT0)\n    shadow = computeShadowWithPCFCube(vLightData0.xyz, shadowSampler0, shadowsInfo0.y, shadowsInfo0.z, shadowsInfo0.x);\n#else\n    shadow = computeShadowWithPCF(vPositionFromLight0, shadowSampler0, shadowsInfo0.y, shadowsInfo0.z, shadowsInfo0.x);\n#endif\n#else\n#if defined(POINTLIGHT0)\n    shadow = computeShadowCube(vLightData0.xyz, shadowSampler0, shadowsInfo0.x, shadowsInfo0.z);\n#else\n    shadow = computeShadow(vPositionFromLight0, shadowSampler0, shadowsInfo0.x, shadowsInfo0.z);\n#endif\n#endif\n#endif\n#else\n    shadow = 1.;\n#endif\n    diffuseBase += info.diffuse * shadow;\n    shadowedOnly *= shadow;\n\n#ifdef SPECULARTERM\n    specularBase += info.specular * shadow;\n#endif\n#endif\n\n#ifdef LIGHT1\n#ifndef SPECULARTERM\n    vec3 vLightSpecular1 = vec3(0.0);\n#endif\n#ifdef SPOTLIGHT1\n    info = computeSpotLighting(viewDirectionW, normalW, vLightData1, vLightDirection1, vLightDiffuse1.rgb, vLightSpecular1, vLightDiffuse1.a, rough, NdotV);\n#endif\n#ifdef HEMILIGHT1\n    info = computeHemisphericLighting(viewDirectionW, normalW, vLightData1, vLightDiffuse1.rgb, vLightSpecular1, vLightGround1, rough, NdotV);\n#endif\n#if defined(POINTLIGHT1) || defined(DIRLIGHT1)\n    info = computeLighting(viewDirectionW, normalW, vLightData1, vLightDiffuse1.rgb, vLightSpecular1, vLightDiffuse1.a, rough, NdotV);\n#endif\n#ifdef SHADOW1\n#ifdef SHADOWVSM1\n    shadow = computeShadowWithVSM(vPositionFromLight1, shadowSampler1, shadowsInfo1.z, shadowsInfo1.x);\n#else\n#ifdef SHADOWPCF1\n#if defined(POINTLIGHT1)\n    shadow = computeShadowWithPCFCube(vLightData1.xyz, shadowSampler1, shadowsInfo1.y, shadowsInfo1.z, shadowsInfo1.x);\n#else\n    shadow = computeShadowWithPCF(vPositionFromLight1, shadowSampler1, shadowsInfo1.y, shadowsInfo1.z, shadowsInfo1.x);\n#endif\n#else\n#if defined(POINTLIGHT1)\n    shadow = computeShadowCube(vLightData1.xyz, shadowSampler1, shadowsInfo1.x, shadowsInfo1.z);\n#else\n    shadow = computeShadow(vPositionFromLight1, shadowSampler1, shadowsInfo1.x, shadowsInfo1.z);\n#endif\n#endif\n#endif\n#else\n    shadow = 1.;\n#endif\n\n    diffuseBase += info.diffuse * shadow;\n    shadowedOnly *= shadow;\n\n#ifdef SPECULARTERM\n    specularBase += info.specular * shadow;\n#endif\n#endif\n\n#ifdef LIGHT2\n#ifndef SPECULARTERM\n    vec3 vLightSpecular2 = vec3(0.0);\n#endif\n#ifdef SPOTLIGHT2\n    info = computeSpotLighting(viewDirectionW, normalW, vLightData2, vLightDirection2, vLightDiffuse2.rgb, vLightSpecular2, vLightDiffuse2.a, rough, NdotV);\n#endif\n#ifdef HEMILIGHT2\n    info = computeHemisphericLighting(viewDirectionW, normalW, vLightData2, vLightDiffuse2.rgb, vLightSpecular2, vLightGround2, rough, NdotV);\n#endif\n#if defined(POINTLIGHT2) || defined(DIRLIGHT2)\n    info = computeLighting(viewDirectionW, normalW, vLightData2, vLightDiffuse2.rgb, vLightSpecular2, vLightDiffuse2.a, rough, NdotV);\n#endif\n#ifdef SHADOW2\n#ifdef SHADOWVSM2\n    shadow = computeShadowWithVSM(vPositionFromLight2, shadowSampler2, shadowsInfo2.z, shadowsInfo2.x);\n#else\n#ifdef SHADOWPCF2\n#if defined(POINTLIGHT2)\n    shadow = computeShadowWithPCFCube(vLightData2.xyz, shadowSampler2, shadowsInfo2.y, shadowsInfo2.z, shadowsInfo2.x);\n#else\n    shadow = computeShadowWithPCF(vPositionFromLight2, shadowSampler2, shadowsInfo2.y, shadowsInfo2.z, shadowsInfo2.x);\n#endif\n#else\n#if defined(POINTLIGHT2)\n    shadow = computeShadowCube(vLightData2.xyz, shadowSampler2, shadowsInfo2.x, shadowsInfo2.z);\n#else\n    shadow = computeShadow(vPositionFromLight2, shadowSampler2, shadowsInfo2.x, shadowsInfo2.z);\n#endif\n#endif	\n#endif	\n#else\n    shadow = 1.;\n#endif\n\n    diffuseBase += info.diffuse * shadow;\n    shadowedOnly *= shadow;\n\n#ifdef SPECULARTERM\n    specularBase += info.specular * shadow;\n#endif\n#endif\n\n#ifdef LIGHT3\n#ifndef SPECULARTERM\n    vec3 vLightSpecular3 = vec3(0.0);\n#endif\n#ifdef SPOTLIGHT3\n    info = computeSpotLighting(viewDirectionW, normalW, vLightData3, vLightDirection3, vLightDiffuse3.rgb, vLightSpecular3, vLightDiffuse3.a, rough, NdotV);\n#endif\n#ifdef HEMILIGHT3\n    info = computeHemisphericLighting(viewDirectionW, normalW, vLightData3, vLightDiffuse3.rgb, vLightSpecular3, vLightGround3, rough, NdotV);\n#endif\n#if defined(POINTLIGHT3) || defined(DIRLIGHT3)\n    info = computeLighting(viewDirectionW, normalW, vLightData3, vLightDiffuse3.rgb, vLightSpecular3, vLightDiffuse3.a, rough, NdotV);\n#endif\n#ifdef SHADOW3\n#ifdef SHADOWVSM3\n    shadow = computeShadowWithVSM(vPositionFromLight3, shadowSampler3, shadowsInfo3.z, shadowsInfo3.x);\n#else\n#ifdef SHADOWPCF3\n#if defined(POINTLIGHT3)\n    shadow = computeShadowWithPCFCube(vLightData3.xyz, shadowSampler3, shadowsInfo3.y, shadowsInfo3.z, shadowsInfo3.x);\n#else\n    shadow = computeShadowWithPCF(vPositionFromLight3, shadowSampler3, shadowsInfo3.y, shadowsInfo3.z, shadowsInfo3.x);\n#endif\n#else\n#if defined(POINTLIGHT3)\n    shadow = computeShadowCube(vLightData3.xyz, shadowSampler3, shadowsInfo3.x, shadowsInfo3.z);\n#else\n    shadow = computeShadow(vPositionFromLight3, shadowSampler3, shadowsInfo3.x, shadowsInfo3.z);\n#endif\n#endif	\n#endif	\n#else\n    shadow = 1.;\n#endif\n\n\n    diffuseBase += info.diffuse * shadow;\n    shadowedOnly *= shadow;\n\n#ifdef SPECULARTERM\n    specularBase += info.specular * shadow;\n#endif\n#endif\n\n    // Reflection\n    vec3 reflectionColor = vec3(0., 0., 0.);\n\n#ifdef REFLECTION\n    vec3 vReflectionUVW = computeReflectionCoords(vec4(vPositionW, 1.0), normalW);\n    vec3 ambientReflectionColor = vec3(0.1, 0.1, 0.1);\n\n    #ifdef REFLECTIONMAP_3D\n        float bias = 0.;\n\n        #ifdef ROUGHNESS\n            bias = 20.;\n            \n            #ifdef SPECULARTERM\n                bias *= (1.0 - glossiness);\n            #endif\n        #endif\n\n            reflectionColor = textureCube(reflectionCubeSampler, vReflectionUVW, bias).rgb * vReflectionInfos.x;\n            reflectionColor = toLinearSpace(reflectionColor.rgb);\n\n            ambientReflectionColor = textureCube(reflectionCubeSampler, normalW, 20.).rgb;\n            ambientReflectionColor = toLinearSpace(ambientReflectionColor.rgb);\n\n            reflectionColor = reflectionColor * vReflectionInfos.y;\n            //reflectionColor = reflectionColor * vReflectionInfos.y * shadow;\n    #else\n            vec2 coords = vReflectionUVW.xy;\n\n        #ifdef REFLECTIONMAP_PROJECTION\n            coords /= vReflectionUVW.z;\n        #endif\n\n        coords.y = 1.0 - coords.y;\n\n        reflectionColor = texture2D(reflection2DSampler, coords).rgb * vReflectionInfos.x;\n        reflectionColor = toLinearSpace(reflectionColor.rgb);\n\n        ambientReflectionColor = texture2D(reflection2DSampler, coords, 10.).rgb;\n        ambientReflectionColor = toLinearSpace(ambientReflectionColor.rgb);\n    #endif\n\n    #ifdef REFLECTIONFRESNEL\n        #ifdef REFLECTIONFRESNELFROMSPECULAR\n            // Compute reflection specular fresnel\n            vec3 specularEnvironmentR0 = specularColor.rgb;\n            vec3 specularEnvironmentR90 = reflectionLeftColor.rgb;\n            vec3 specularEnvironmentReflectanceViewer = FresnelSchlickEnvironmentGGX(clamp(NdotV, 0., 1.), specularEnvironmentR0, specularEnvironmentR90, sqrt(glossiness));\n            reflectionColor *= specularEnvironmentReflectanceViewer;\n        #else\n            float reflectionFresnelTerm = computeFresnelTerm(viewDirectionW, normalW, reflectionRightColor.a, reflectionLeftColor.a);\n            reflectionColor *= reflectionLeftColor.rgb * (1.0 - reflectionFresnelTerm) + reflectionFresnelTerm * reflectionRightColor.rgb;\n        #endif\n    #endif\n#endif\n\n#ifdef OPACITY\n    vec4 opacityMap = texture2D(opacitySampler, vOpacityUV);\n\n#ifdef OPACITYRGB\n    opacityMap.rgb = opacityMap.rgb * vec3(0.3, 0.59, 0.11);\n    alpha *= (opacityMap.x + opacityMap.y + opacityMap.z)* vOpacityInfos.y;\n#else\n    alpha *= opacityMap.a * vOpacityInfos.y;\n#endif\n\n#endif\n\n#ifdef VERTEXALPHA\n    alpha *= vColor.a;\n#endif\n\n#ifdef OPACITYFRESNEL\n    float opacityFresnelTerm = computeFresnelTerm(viewDirectionW, normalW, opacityParts.z, opacityParts.w);\n\n    alpha += opacityParts.x * (1.0 - opacityFresnelTerm) + opacityFresnelTerm * opacityParts.y;\n#endif\n\n    // Emissive\n    vec3 emissiveColor = vEmissiveColor;\n#ifdef EMISSIVE\n    vec3 emissiveColorTex = texture2D(emissiveSampler, vEmissiveUV).rgb;\n    emissiveColor = toLinearSpace(emissiveColorTex.rgb) * emissiveColor * vEmissiveInfos.y;\n    emissiveColor = mix(emissiveColor, vPBROverloadedEmissive, vPBROverloadedIntensity.w);\n#endif\n\n#ifdef EMISSIVEFRESNEL\n    float emissiveFresnelTerm = computeFresnelTerm(viewDirectionW, normalW, emissiveRightColor.a, emissiveLeftColor.a);\n\n    emissiveColor *= emissiveLeftColor.rgb * (1.0 - emissiveFresnelTerm) + emissiveFresnelTerm * emissiveRightColor.rgb;\n#endif\n\n    // Fresnel\n#ifdef DIFFUSEFRESNEL\n    float diffuseFresnelTerm = computeFresnelTerm(viewDirectionW, normalW, diffuseRightColor.a, diffuseLeftColor.a);\n\n    diffuseBase *= diffuseLeftColor.rgb * (1.0 - diffuseFresnelTerm) + diffuseFresnelTerm * diffuseRightColor.rgb;\n#endif\n\n    // Composition\n#ifdef EMISSIVEASILLUMINATION\n    vec3 finalDiffuse = max(diffuseBase * diffuseColor + vAmbientColor, 0.0) * baseColor.rgb;\n#else\n    #ifdef LINKEMISSIVEWITHDIFFUSE\n        vec3 finalDiffuse = clamp((diffuseBase + emissiveColor) * diffuseColor + vAmbientColor, 0.0, 1.0) * baseColor.rgb;\n    #else\n        vec3 finalDiffuse = clamp(diffuseBase * diffuseColor + emissiveColor + vAmbientColor, 0.0, 1.0) * baseColor.rgb;\n    #endif\n#endif\n\n#ifdef REFLECTION\n    // diffuse lighting from environment\n    finalDiffuse += baseColor.rgb * ambientReflectionColor * 0.2 * vPBRLightingIntensity.z;\n#endif\n\n#ifdef SPECULARTERM\n    vec3 finalSpecular = specularBase * specularColor;\n#else\n    vec3 finalSpecular = vec3(0.0);\n#endif\n\n#ifdef SPECULAROVERALPHA\n    alpha = clamp(alpha + dot(finalSpecular, vec3(0.3, 0.59, 0.11)), 0., 1.);\n#endif\n\n    // Composition\n#ifdef EMISSIVEASILLUMINATION\n    vec4 color = vec4(finalDiffuse * baseAmbientColor * vPBRLightingIntensity.x + finalSpecular * vPBRLightingIntensity.x + reflectionColor * vPBRLightingIntensity.z + emissiveColor * vPBRLightingIntensity.y, alpha);\n#else\n    vec4 color = vec4(finalDiffuse * baseAmbientColor + finalSpecular + reflectionColor, alpha);\n#endif\n\n#ifdef LIGHTMAP\n    vec3 lightmapColor = texture2D(lightmapSampler, vLightmapUV).rgb * vLightmapInfos.y;\n\n#ifdef USELIGHTMAPASSHADOWMAP\n    color.rgb *= lightmapColor;\n#else\n    color.rgb += lightmapColor;\n#endif\n#endif\n\n#ifdef FOG\n    float fog = CalcFogFactor();\n    color.rgb = fog * color.rgb + (1.0 - fog) * vFogColor;\n#endif\n    color = max(color, 0.0);\n\n    color.rgb = toneMaps(color.rgb);\n    color.rgb = toGammaSpace(color.rgb);\n    color = contrasts(color);\n\n    color.rgb = mix(color.rgb, shadowedOnly, (1.0 - vPBRShadowIntensity.y));\n\n    // Normal Display.\n    // gl_FragColor = vec4(normalW * 0.5 + 0.5, 1.0);\n\n    // Ambient reflection color.\n    // gl_FragColor = vec4(ambientReflectionColor, 1.0);\n\n    // Reflection color.\n    // gl_FragColor = vec4(reflectionColor, 1.0);\n\n    // Base color.\n    // gl_FragColor = vec4(baseColor.rgb, 1.0);\n\n    // Specular color.\n    // gl_FragColor = vec4(specularColor.rgb, 1.0);\n\n    // Glossiness color.\n    // gl_FragColor = vec4(glossiness, glossiness, glossiness, 1.0);\n\n    // Specular Map\n    // gl_FragColor = vec4(specularMapColor.rgb, 1.0);\n\n    //// Emissive Color\n    //vec2 test = vEmissiveUV * 0.5 + 0.5;\n    //gl_FragColor = vec4(test.x, test.y, 1.0, 1.0);\n\n    gl_FragColor = color;\n}";
	
	public static var vertexShader:String = "﻿precision highp float;\n\n// Attributes\nattribute vec3 position;\n#ifdef NORMAL\nattribute vec3 normal;\n#endif\n#ifdef UV1\nattribute vec2 uv;\n#endif\n#ifdef UV2\nattribute vec2 uv2;\n#endif\n#ifdef VERTEXCOLOR\nattribute vec4 color;\n#endif\n\n#if NUM_BONE_INFLUENCERS > 0\n	uniform mat4 mBones[BonesPerMesh];\n\n	attribute vec4 matricesIndices;\n	attribute vec4 matricesWeights;\n	#if NUM_BONE_INFLUENCERS > 4\n		attribute vec4 matricesIndicesExtra;\n		attribute vec4 matricesWeightsExtra;\n	#endif\n#endif\n\n// Uniforms\n\n#ifdef INSTANCES\nattribute vec4 world0;\nattribute vec4 world1;\nattribute vec4 world2;\nattribute vec4 world3;\n#else\nuniform mat4 world;\n#endif\n\nuniform mat4 view;\nuniform mat4 viewProjection;\n\n#ifdef DIFFUSE\nvarying vec2 vDiffuseUV;\nuniform mat4 diffuseMatrix;\nuniform vec2 vDiffuseInfos;\n#endif\n\n#ifdef AMBIENT\nvarying vec2 vAmbientUV;\nuniform mat4 ambientMatrix;\nuniform vec2 vAmbientInfos;\n#endif\n\n#ifdef OPACITY\nvarying vec2 vOpacityUV;\nuniform mat4 opacityMatrix;\nuniform vec2 vOpacityInfos;\n#endif\n\n#ifdef EMISSIVE\nvarying vec2 vEmissiveUV;\nuniform vec2 vEmissiveInfos;\nuniform mat4 emissiveMatrix;\n#endif\n\n#ifdef LIGHTMAP\nvarying vec2 vLightmapUV;\nuniform vec2 vLightmapInfos;\nuniform mat4 lightmapMatrix;\n#endif\n\n#if defined(SPECULAR) && defined(SPECULARTERM)\nvarying vec2 vSpecularUV;\nuniform vec2 vSpecularInfos;\nuniform mat4 specularMatrix;\n#endif\n\n#ifdef BUMP\nvarying vec2 vBumpUV;\nuniform vec2 vBumpInfos;\nuniform mat4 bumpMatrix;\n#endif\n\n#ifdef POINTSIZE\nuniform float pointSize;\n#endif\n\n// Output\nvarying vec3 vPositionW;\n#ifdef NORMAL\nvarying vec3 vNormalW;\n#endif\n\n#ifdef VERTEXCOLOR\nvarying vec4 vColor;\n#endif\n\n#ifdef CLIPPLANE\nuniform vec4 vClipPlane;\nvarying float fClipDistance;\n#endif\n\n#ifdef FOG\nvarying float fFogDistance;\n#endif\n\n#ifdef SHADOWS\n#if defined(SPOTLIGHT0) || defined(DIRLIGHT0)\nuniform mat4 lightMatrix0;\nvarying vec4 vPositionFromLight0;\n#endif\n#if defined(SPOTLIGHT1) || defined(DIRLIGHT1)\nuniform mat4 lightMatrix1;\nvarying vec4 vPositionFromLight1;\n#endif\n#if defined(SPOTLIGHT2) || defined(DIRLIGHT2)\nuniform mat4 lightMatrix2;\nvarying vec4 vPositionFromLight2;\n#endif\n#if defined(SPOTLIGHT3) || defined(DIRLIGHT3)\nuniform mat4 lightMatrix3;\nvarying vec4 vPositionFromLight3;\n#endif\n#endif\n\n#ifdef REFLECTIONMAP_SKYBOX\nvarying vec3 vPositionUVW;\n#endif\n\n#ifdef REFLECTIONMAP_EQUIRECTANGULAR\nvarying vec3 vDirectionW;\n#endif\n\nvoid main(void) {\n    mat4 finalWorld;\n\n#ifdef REFLECTIONMAP_SKYBOX\n    vPositionUVW = position;\n#endif \n\n#ifdef INSTANCES\n    finalWorld = mat4(world0, world1, world2, world3);\n#else\n    finalWorld = world;\n#endif\n\n#if NUM_BONE_INFLUENCERS > 0\n	mat4 influence;\n	influence = mBones[int(matricesIndices[0])] * matricesWeights[0];\n\n	#if NUM_BONE_INFLUENCERS > 1\n		influence += mBones[int(matricesIndices[1])] * matricesWeights[1];\n	#endif \n	#if NUM_BONE_INFLUENCERS > 2\n		influence += mBones[int(matricesIndices[2])] * matricesWeights[2];\n	#endif	\n	#if NUM_BONE_INFLUENCERS > 3\n		influence += mBones[int(matricesIndices[3])] * matricesWeights[3];\n	#endif	\n\n	#if NUM_BONE_INFLUENCERS > 4\n		influence += mBones[int(matricesIndicesExtra[0])] * matricesWeightsExtra[0];\n	#endif\n	#if NUM_BONE_INFLUENCERS > 5\n		influence += mBones[int(matricesIndicesExtra[1])] * matricesWeightsExtra[1];\n	#endif	\n	#if NUM_BONE_INFLUENCERS > 6\n		influence += mBones[int(matricesIndicesExtra[2])] * matricesWeightsExtra[2];\n	#endif	\n	#if NUM_BONE_INFLUENCERS > 7\n		influence += mBones[int(matricesIndicesExtra[3])] * matricesWeightsExtra[3];\n	#endif	\n\n	finalWorld = finalWorld * influence;\n#endif\n\n\n    gl_Position = viewProjection * finalWorld * vec4(position, 1.0);\n\n    vec4 worldPos = finalWorld * vec4(position, 1.0);\n    vPositionW = vec3(worldPos);\n\n#ifdef NORMAL\n    vNormalW = normalize(vec3(finalWorld * vec4(normal, 0.0)));\n#endif\n\n#ifdef REFLECTIONMAP_EQUIRECTANGULAR\n    vDirectionW = normalize(vec3(finalWorld * vec4(position, 0.0)));\n#endif\n\n    // Texture coordinates\n#ifndef UV1\n    vec2 uv = vec2(0., 0.);\n#endif\n#ifndef UV2\n    vec2 uv2 = vec2(0., 0.);\n#endif\n\n#ifdef DIFFUSE\n    if (vDiffuseInfos.x == 0.)\n    {\n        vDiffuseUV = vec2(diffuseMatrix * vec4(uv, 1.0, 0.0));\n    }\n    else\n    {\n        vDiffuseUV = vec2(diffuseMatrix * vec4(uv2, 1.0, 0.0));\n    }\n#endif\n\n#ifdef AMBIENT\n    if (vAmbientInfos.x == 0.)\n    {\n        vAmbientUV = vec2(ambientMatrix * vec4(uv, 1.0, 0.0));\n    }\n    else\n    {\n        vAmbientUV = vec2(ambientMatrix * vec4(uv2, 1.0, 0.0));\n    }\n#endif\n\n#ifdef OPACITY\n    if (vOpacityInfos.x == 0.)\n    {\n        vOpacityUV = vec2(opacityMatrix * vec4(uv, 1.0, 0.0));\n    }\n    else\n    {\n        vOpacityUV = vec2(opacityMatrix * vec4(uv2, 1.0, 0.0));\n    }\n#endif\n\n#ifdef EMISSIVE\n    if (vEmissiveInfos.x == 0.)\n    {\n        vEmissiveUV = vec2(emissiveMatrix * vec4(uv, 1.0, 0.0));\n    }\n    else\n    {\n        vEmissiveUV = vec2(emissiveMatrix * vec4(uv2, 1.0, 0.0));\n    }\n#endif\n\n#ifdef LIGHTMAP\n    if (vLightmapInfos.x == 0.)\n    {\n        vLightmapUV = vec2(lightmapMatrix * vec4(uv, 1.0, 0.0));\n    }\n    else\n    {\n        vLightmapUV = vec2(lightmapMatrix * vec4(uv2, 1.0, 0.0));\n    }\n#endif\n\n#if defined(SPECULAR) && defined(SPECULARTERM)\n    if (vSpecularInfos.x == 0.)\n    {\n        vSpecularUV = vec2(specularMatrix * vec4(uv, 1.0, 0.0));\n    }\n    else\n    {\n        vSpecularUV = vec2(specularMatrix * vec4(uv2, 1.0, 0.0));\n    }\n#endif\n\n#ifdef BUMP\n    if (vBumpInfos.x == 0.)\n    {\n        vBumpUV = vec2(bumpMatrix * vec4(uv, 1.0, 0.0));\n    }\n    else\n    {\n        vBumpUV = vec2(bumpMatrix * vec4(uv2, 1.0, 0.0));\n    }\n#endif\n\n    // Clip plane\n#ifdef CLIPPLANE\n    fClipDistance = dot(worldPos, vClipPlane);\n#endif\n\n    // Fog\n#ifdef FOG\n    fFogDistance = (view * worldPos).z;\n#endif\n\n    // Shadows\n#ifdef SHADOWS\n#if defined(SPOTLIGHT0) || defined(DIRLIGHT0)\n    vPositionFromLight0 = lightMatrix0 * worldPos;\n#endif\n#if defined(SPOTLIGHT1) || defined(DIRLIGHT1)\n    vPositionFromLight1 = lightMatrix1 * worldPos;\n#endif\n#if defined(SPOTLIGHT2) || defined(DIRLIGHT2)\n    vPositionFromLight2 = lightMatrix2 * worldPos;\n#endif\n#if defined(SPOTLIGHT3) || defined(DIRLIGHT3)\n    vPositionFromLight3 = lightMatrix3 * worldPos;\n#endif\n#endif\n\n    // Vertex color\n#ifdef VERTEXCOLOR\n    vColor = color;\n#endif\n\n    // Point size\n#ifdef POINTSIZE\n    gl_PointSize = pointSize;\n#endif\n}";
	

	public var directIntensity:Float = 1.0;
	public var emissiveIntensity:Float = 1.0;
	public var environmentIntensity:Float = 1.0;
	public var _lightingInfos:Vector4;

	public var shadowIntensity:Float = 1.0;
	public var shadeIntensity:Float = 1.0;
	private var _shadowInfos:Vector4;

	public var cameraExposure:Float = 1.0;
	public var cameraContrast:Float = 1.0;
	private var _cameraInfos:Vector4 = new Vector4(1.0, 1.0, 0.0, 0.0);

	public var overloadedAmbientIntensity:Float = 0.0;
	public var overloadedDiffuseIntensity:Float = 0.0;
	public var overloadedSpecularIntensity:Float = 0.0;
	public var overloadedEmissiveIntensity:Float = 0.0;
	private var _overloadedIntensity:Vector4;
	public var overloadedAmbient:Color3 = Color3.White();
	public var overloadedDiffuse:Color3 = Color3.White();
	public var overloadedSpecular:Color3 = Color3.White();
	public var overloadedEmissive:Color3 = Color3.White();

	public var overloadedSmoothness:Float = 0.0;
	public var overloadedSmoothnessIntensity:Float = 0.0;
	private var _overloadedSmoothness:Vector3;
   
	public var disableBumpMap:Bool = false;

	public var diffuseTexture:BaseTexture;
	public var ambientTexture:BaseTexture;
	public var opacityTexture:BaseTexture;
	public var reflectionTexture:BaseTexture;
	public var emissiveTexture:BaseTexture;
	public var specularTexture:BaseTexture;
	public var bumpTexture:BaseTexture;
	public var lightmapTexture:BaseTexture;

	public var ambientColor:Color3 = new Color3(0, 0, 0);
	public var diffuseColor:Color3 = new Color3(1, 1, 1);
	public var specularColor:Color3 = new Color3(1, 1, 1);
	public var specularPower:Int = 64;
	public var emissiveColor:Color3 = new Color3(0, 0, 0);
	public var useAlphaFromDiffuseTexture:Bool = false;
	public var useEmissiveAsIllumination:Bool = false;
	public var linkEmissiveWithDiffuse:Bool = false;
	public var useReflectionFresnelFromSpecular:Bool = false;
	public var useSpecularOverAlpha:Bool = true;
	public var disableLighting:Bool = false;

	public var roughness:Float = 0;

	public var useLightmapAsShadowmap:Bool = false;

	public var diffuseFresnelParameters:FresnelParameters;
	public var opacityFresnelParameters:FresnelParameters;
	public var reflectionFresnelParameters:FresnelParameters;
	public var emissiveFresnelParameters:FresnelParameters;

	public var useGlossinessFromSpecularMapAlpha:Bool = false;

	private var _renderTargets:SmartArray<RenderTargetTexture> = new SmartArray<RenderTargetTexture>(16);
	private var _worldViewProjectionMatrix:Matrix = Matrix.Zero();
	private var _globalAmbientColor:Color3 = new Color3(0, 0, 0);
	private var _tempColor:Color3 = new Color3();

	private var _renderId:Int;

	private var _defines:PBRMaterialDefines = new PBRMaterialDefines();
	private var _cachedDefines:PBRMaterialDefines = new PBRMaterialDefines();
	

	public function new(name:String, scene:Scene) {
		super(name, scene);
		
		if (!ShadersStore.Shaders.exists("pbrmat.fragment")) {
			ShadersStore.Shaders.set("pbrmat.fragment", fragmentShader);
			ShadersStore.Shaders.set("pbrmat.vertex", vertexShader);
		}
		
		this._cachedDefines.BonesPerMesh = -1;
		
		this._lightingInfos = new Vector4(this.directIntensity, this.emissiveIntensity, this.environmentIntensity, 0.0);
		this._shadowInfos = new Vector4(this.shadowIntensity, this.shadeIntensity, 0.0, 0.0);
		this._overloadedIntensity = new Vector4(this.overloadedAmbientIntensity, this.overloadedDiffuseIntensity, this.overloadedSpecularIntensity, this.overloadedEmissiveIntensity);
		this._overloadedSmoothness = new Vector3(this.overloadedSmoothness, this.overloadedSmoothnessIntensity, 0.0);
		
		this.getRenderTargetTextures = function():SmartArray<RenderTargetTexture> {
			this._renderTargets.reset();
			
			if (this.reflectionTexture != null && this.reflectionTexture.isRenderTarget) {
				this._renderTargets.push(cast this.reflectionTexture);
			}
			
			return this._renderTargets;
		};
	}

	override public function needAlphaBlending():Bool {
		return (this.alpha < 1.0) || (this.opacityTexture != null) || this._shouldUseAlphaFromDiffuseTexture() || this.opacityFresnelParameters != null && this.opacityFresnelParameters.isEnabled;
	}

	override public function needAlphaTesting():Bool {
		return this.diffuseTexture != null && this.diffuseTexture.hasAlpha;
	}

	private function _shouldUseAlphaFromDiffuseTexture():Bool {
		return this.diffuseTexture != null && this.diffuseTexture.hasAlpha && this.useAlphaFromDiffuseTexture;
	}

	override public function getAlphaTestTexture():BaseTexture {
		return this.diffuseTexture;
	}

	private function _checkCache(scene:Scene, ?mesh:AbstractMesh, useInstances:Bool):Bool {
		if (mesh == null) {
			return true;
		}
		
		if (this._defines.defines[PBRM.INSTANCES] != useInstances) {
			return false;
		}
		
		if (mesh._materialDefines != null && mesh._materialDefines.isEqual(this._defines)) {
			return true;
		}
		
		return false;
	}

	public static function PrepareDefinesForLights(scene:Scene, mesh:AbstractMesh, defines:PBRMaterialDefines):Bool {
		var lightIndex:Int = 0;
		var needNormals:Bool = false;
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
			defines.defines[PBRM.LIGHT0 + lightIndex] = true;
			
			var type:Int = defines.getLight(light.type, lightIndex);			
			defines.defines[type] = true;
			
			// Specular
			if (!light.specular.equalsFloats(0, 0, 0)) {
				defines.defines[PBRM.SPECULARTERM] = true;
			}
			
			// Shadows
			if (scene.shadowsEnabled) {
				var shadowGenerator = light.getShadowGenerator();
				if (mesh != null && mesh.receiveShadows && shadowGenerator != null) {
					defines.defines[PBRM.SHADOW0 + lightIndex] = true;
					
					defines.defines[PBRM.SHADOWS] = true;
					
					if (shadowGenerator.useVarianceShadowMap || shadowGenerator.useBlurVarianceShadowMap) {
						defines.defines[PBRM.SHADOWVSM0 + lightIndex] = true;
					}
					
					if (shadowGenerator.usePoissonSampling) {
						defines.defines[PBRM.SHADOWPCF0 + lightIndex] = true;
					}
				}
			}
			
			lightIndex++;
			if (lightIndex == Material.maxSimultaneousLights) {
				break;
			}
		}
		
		return needNormals;
	}

	private static var _scaledDiffuse:Color3 = new Color3();
	private static var _scaledSpecular:Color3 = new Color3();
	private static var _scaledEmissive:Color3 = new Color3();

	public static function BindLights(scene:Scene, mesh:AbstractMesh, effect:Effect, defines:MaterialDefines) {
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
					light.transferToEffect(effect, "vLightData" + lightIndex);
					
				case "DIRLIGHT":
					light.transferToEffect(effect, "vLightData" + lightIndex);
					
				case "SPOTLIGHT":
					light.transferToEffect(effect, "vLightData" + lightIndex, "vLightDirection" + lightIndex);
					
				case "HEMILIGHT":
					light.transferToEffect(effect, "vLightData" + lightIndex, "vLightGround" + lightIndex);			
			}
			
			// GAMMA CORRECTION.
			light.diffuse.toLinearSpaceToRef(PBRMaterial._scaledDiffuse);
			PBRMaterial._scaledDiffuse.scaleToRef(light.intensity, PBRMaterial._scaledDiffuse);
			
			light.diffuse.scaleToRef(light.intensity, PBRMaterial._scaledDiffuse);
			effect.setColor4("vLightDiffuse" + lightIndex, PBRMaterial._scaledDiffuse, light.range);
			if (defines.defines[PBRM.SPECULARTERM]) {
				light.specular.toLinearSpaceToRef(PBRMaterial._scaledSpecular);
				PBRMaterial._scaledSpecular.scaleToRef(light.intensity, PBRMaterial._scaledSpecular);
				effect.setColor3("vLightSpecular" + lightIndex, PBRMaterial._scaledSpecular);
			}
			
			// Shadows
			if (scene.shadowsEnabled) {
				var shadowGenerator = light.getShadowGenerator();
				if (mesh.receiveShadows && shadowGenerator != null) {
					if (!cast(light, IShadowLight).needCube()) {
						effect.setMatrix("lightMatrix" + lightIndex, shadowGenerator.getTransformMatrix());
					}
					effect.setTexture("shadowSampler" + lightIndex, shadowGenerator.getShadowMapForRendering());
					effect.setFloat3("shadowsInfo" + lightIndex, shadowGenerator.getDarkness(), shadowGenerator.getShadowMap().getSize().width, shadowGenerator.bias);
				}
			}
			
			lightIndex++;
			
			if (lightIndex == Material.maxSimultaneousLights) {
				break;
			}
		}
	}

	override public function isReady(?mesh:AbstractMesh, useInstances:Bool = false):Bool {
		if (this.checkReadyOnlyOnce) {
			if (this._wasPreviouslyReady) {
				return true;
			}
		}
		
		var scene:Scene = this.getScene();
		
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
			if (this.diffuseTexture != null && StandardMaterial.DiffuseTextureEnabled) {
				if (!this.diffuseTexture.isReady()) {
					return false;
				} 
				else {
					needUVs = true;
					this._defines.defines[PBRM.DIFFUSE] = true;
				}
			}
			
			if (this.ambientTexture != null && StandardMaterial.AmbientTextureEnabled) {
				if (!this.ambientTexture.isReady()) {
					return false;
				} 
				else {
					needUVs = true;
					this._defines.defines[PBRM.AMBIENT] = true;
				}
			}
			
			if (this.opacityTexture != null && StandardMaterial.OpacityTextureEnabled) {
				if (!this.opacityTexture.isReady()) {
					return false;
				} 
				else {
					needUVs = true;
					this._defines.defines[PBRM.OPACITY] = true;
					
					if (this.opacityTexture.getAlphaFromRGB) {
						this._defines.defines[PBRM.OPACITYRGB] = true;
					}
				}
			}
			
			if (this.reflectionTexture != null && StandardMaterial.ReflectionTextureEnabled) {
				if (!this.reflectionTexture.isReady()) {
					return false;
				} 
				else {
					needNormals = true;
					this._defines.defines[PBRM.REFLECTION] = true;
					
					if (this.roughness > 0) {
						this._defines.defines[PBRM.ROUGHNESS] = true;
					}
					
					if (this.reflectionTexture.coordinatesMode == Texture.INVCUBIC_MODE) {
						this._defines.defines[PBRM.INVERTCUBICMAP] = true;
					}
					
					this._defines.defines[PBRM.REFLECTIONMAP_3D] = this.reflectionTexture.isCube;
					
					switch (this.reflectionTexture.coordinatesMode) {
						case Texture.CUBIC_MODE, Texture.INVCUBIC_MODE:
							this._defines.defines[PBRM.REFLECTIONMAP_CUBIC] = true;
							
						case Texture.EXPLICIT_MODE:
							this._defines.defines[PBRM.REFLECTIONMAP_EXPLICIT] = true;
							
						case Texture.PLANAR_MODE:
							this._defines.defines[PBRM.REFLECTIONMAP_PLANAR] = true;
							
						case Texture.PROJECTION_MODE:
							this._defines.defines[PBRM.REFLECTIONMAP_PROJECTION] = true;
							
						case Texture.SKYBOX_MODE:
							this._defines.defines[PBRM.REFLECTIONMAP_SKYBOX] = true;
							
						case Texture.SPHERICAL_MODE:
							this._defines.defines[PBRM.REFLECTIONMAP_SPHERICAL] = true;
							
						case Texture.EQUIRECTANGULAR_MODE:
							this._defines.defines[PBRM.REFLECTIONMAP_EQUIRECTANGULAR] = true;							
					}
				}
			}
			
			if (this.lightmapTexture != null && StandardMaterial.LightmapEnabled) {
				if (!this.lightmapTexture.isReady()) {
					return false;
				} 
				else {
					needUVs = true;
					this._defines.defines[PBRM.LIGHTMAP] = true;
					this._defines.defines[PBRM.USELIGHTMAPASSHADOWMAP] = this.useLightmapAsShadowmap;
				}
			}
			
			if (this.emissiveTexture != null && StandardMaterial.EmissiveTextureEnabled) {
				if (!this.emissiveTexture.isReady()) {
					return false;
				} 
				else {
					needUVs = true;
					this._defines.defines[PBRM.EMISSIVE] = true;
				}
			}
			
			if (this.specularTexture != null && StandardMaterial.SpecularTextureEnabled) {
				if (!this.specularTexture.isReady()) {
					return false;
				} 
				else {
					needUVs = true;
					this._defines.defines[PBRM.SPECULAR] = true;
					this._defines.defines[PBRM.GLOSSINESS] = this.useGlossinessFromSpecularMapAlpha;
				}
			}
		}
		
		if (scene.getEngine().getCaps().standardDerivatives == null && this.bumpTexture != null && StandardMaterial.BumpTextureEnabled && !this.disableBumpMap) {
			if (!this.bumpTexture.isReady()) {
				return false;
			} 
			else {
				needUVs = true;
				this._defines.defines[PBRM.BUMP] = true;
			}
		}
		
		// Effect
		if (scene.clipPlane != null) {
			this._defines.defines[PBRM.CLIPPLANE] = true;
		}
		
		if (engine.getAlphaTesting()) {
			this._defines.defines[PBRM.ALPHATEST] = true;
		}
		
		if (this._shouldUseAlphaFromDiffuseTexture()) {
			this._defines.defines[PBRM.ALPHAFROMDIFFUSE] = true;
		}
		
		if (this.useEmissiveAsIllumination) {
			this._defines.defines[PBRM.EMISSIVEASILLUMINATION] = true;
		}
		
		if (this.linkEmissiveWithDiffuse) {
			this._defines.defines[PBRM.LINKEMISSIVEWITHDIFFUSE] = true;
		}
		
		if (this.useReflectionFresnelFromSpecular) {
			this._defines.defines[PBRM.REFLECTIONFRESNELFROMSPECULAR] = true;
		}
		
		// Point size
		if (this.pointsCloud || scene.forcePointsCloud) {
			this._defines.defines[PBRM.POINTSIZE] = true;
		}
		
		// Fog
		if (scene.fogEnabled && mesh != null && mesh.applyFog && scene.fogMode != Scene.FOGMODE_NONE && this.fogEnabled) {
			this._defines.defines[PBRM.FOG] = true;
		}
		
		if (scene.lightsEnabled && !this.disableLighting) {
			needNormals = PBRMaterial.PrepareDefinesForLights(scene, mesh, this._defines);
		}
		
		if (StandardMaterial.FresnelEnabled) {
			// Fresnel
			if (this.diffuseFresnelParameters != null && this.diffuseFresnelParameters.isEnabled) {
				this._defines.defines[PBRM.DIFFUSEFRESNEL] = true;
			}
			
			if (this.opacityFresnelParameters != null && this.opacityFresnelParameters.isEnabled) {
				this._defines.defines[PBRM.OPACITYFRESNEL] = true;
			}
			
			if (this.reflectionFresnelParameters != null && this.reflectionFresnelParameters.isEnabled) {
				this._defines.defines[PBRM.REFLECTIONFRESNEL] = true;
			}
			
			if (this.emissiveFresnelParameters != null && this.emissiveFresnelParameters.isEnabled) {
				this._defines.defines[PBRM.EMISSIVEFRESNEL] = true;
			}
			
			if (this._defines.defines[PBRM.DIFFUSEFRESNEL] ||
				this._defines.defines[PBRM.OPACITYFRESNEL] ||
				this._defines.defines[PBRM.REFLECTIONFRESNEL] ||
				this._defines.defines[PBRM.EMISSIVEFRESNEL]) {	
				
				needNormals = true;
				this._defines.defines[PBRM.FRESNEL] = true;
			}
		}
		/*if (StandardMaterial.FresnelEnabled) {
			// Fresnel
			if (this.diffuseFresnelParameters != null && this.diffuseFresnelParameters.isEnabled ||
				this.opacityFresnelParameters != null && this.opacityFresnelParameters.isEnabled ||
				this.emissiveFresnelParameters != null && this.emissiveFresnelParameters.isEnabled ||
				this.reflectionFresnelParameters != null && this.reflectionFresnelParameters.isEnabled) {
					
				if (this.diffuseFresnelParameters != null && this.diffuseFresnelParameters.isEnabled) {
					this._defines.defines[PBRM.DIFFUSEFRESNEL] = true;
				}
				
				if (this.opacityFresnelParameters != null && this.opacityFresnelParameters.isEnabled) {
					this._defines.defines[PBRM.OPACITYFRESNEL] = true;
				}
				
				if (this.reflectionFresnelParameters != null && this.reflectionFresnelParameters.isEnabled) {
					this._defines.defines[PBRM.REFLECTIONFRESNEL] = true;
				}
				
				if (this.emissiveFresnelParameters != null && this.emissiveFresnelParameters.isEnabled) {
					this._defines.defines[PBRM.EMISSIVEFRESNEL] = true;
				}
				
				needNormals = true;
				this._defines.defines[PBRM.FRESNEL] = true;
			}
		}*/
		
		if (this._defines.defines[PBRM.SPECULARTERM] && this.useSpecularOverAlpha) {
			this._defines.defines[PBRM.SPECULAROVERALPHA] = true;
		}
		
		// Attribs
		if (mesh != null) {
			if (needNormals && mesh.isVerticesDataPresent(VertexBuffer.NormalKind)) {
				this._defines.defines[PBRM.NORMAL] = true;
			}
			if (needUVs) {
				if (mesh.isVerticesDataPresent(VertexBuffer.UVKind)) {
					this._defines.defines[PBRM.UV1] = true;
				}
				if (mesh.isVerticesDataPresent(VertexBuffer.UV2Kind)) {
					this._defines.defines[PBRM.UV2] = true;
				}
			}
			if (mesh.useVertexColors && mesh.isVerticesDataPresent(VertexBuffer.ColorKind)) {
				this._defines.defines[PBRM.VERTEXCOLOR] = true;
				
				if (mesh.hasVertexAlpha) {
					this._defines.defines[PBRM.VERTEXALPHA] = true;
				}
			}
			if (mesh.useBones && mesh.computeBonesUsingShaders) {
				this._defines.NUM_BONE_INFLUENCERS = mesh.numBoneInfluencers;
				this._defines.BonesPerMesh = (mesh.skeleton.bones.length + 1);
			}
			
			// Instances
			if (useInstances) {
				this._defines.defines[PBRM.INSTANCES] = true;
			}
		}
		
		// Get correct effect      
		if (!this._defines.isEqual(this._cachedDefines) || this._effect == null) {
			this._defines.cloneTo(this._cachedDefines);
			
			scene.resetCachedMaterial();
			
			// Fallbacks
			var fallbacks:EffectFallbacks = new EffectFallbacks();
			if (this._defines.defines[PBRM.REFLECTION]) {
				fallbacks.addFallback(0, "REFLECTION");
			}
			
			if (this._defines.defines[PBRM.SPECULAR]) {
				fallbacks.addFallback(0, "SPECULAR");
			}
			
			if (this._defines.defines[PBRM.BUMP]) {
				fallbacks.addFallback(0, "BUMP");
			}
			
			if (this._defines.defines[PBRM.SPECULAROVERALPHA]) {
				fallbacks.addFallback(0, "SPECULAROVERALPHA");
			}
			
			if (this._defines.defines[PBRM.FOG]) {
				fallbacks.addFallback(1, "FOG");
			}
			
			for (lightIndex in 0...Material.maxSimultaneousLights) {
				if (!this._defines.defines[PBRM.LIGHT0 + lightIndex]) {
					continue;
				}
				
				if (lightIndex > 0) {
					fallbacks.addFallback(lightIndex, "LIGHT" + lightIndex);
				}
				
				if (this._defines.defines[PBRM.SHADOW0 + lightIndex]) {
					fallbacks.addFallback(0, "SHADOW" + lightIndex);
				}
				
				if (this._defines.defines[PBRM.SHADOWPCF0 + lightIndex]) {
					fallbacks.addFallback(0, "SHADOWPCF" + lightIndex);
				}
				
				if (this._defines.defines[PBRM.SHADOWVSM0 + lightIndex]) {
					fallbacks.addFallback(0, "SHADOWVSM" + lightIndex);
				}
			}
			
			if (this._defines.defines[PBRM.SPECULARTERM]) {
				fallbacks.addFallback(0, "SPECULARTERM");
			}
			
			if (this._defines.defines[PBRM.DIFFUSEFRESNEL]) {
				fallbacks.addFallback(1, "DIFFUSEFRESNEL");
			}
			
			if (this._defines.defines[PBRM.OPACITYFRESNEL]) {
				fallbacks.addFallback(2, "OPACITYFRESNEL");
			}
			
			if (this._defines.defines[PBRM.REFLECTIONFRESNEL]) {
				fallbacks.addFallback(3, "REFLECTIONFRESNEL");
			}
			
			if (this._defines.defines[PBRM.EMISSIVEFRESNEL]) {
				fallbacks.addFallback(4, "EMISSIVEFRESNEL");
			}
			
			if (this._defines.defines[PBRM.FRESNEL]) {
				fallbacks.addFallback(4, "FRESNEL");
			}
			
			if (this._defines.NUM_BONE_INFLUENCERS > 0){
				fallbacks.addCPUSkinningFallback(0, mesh);    
			}
			
			//Attributes
			var attribs:Array<String> = [VertexBuffer.PositionKind];
			
			if (this._defines.defines[PBRM.NORMAL]) {
				attribs.push(VertexBuffer.NormalKind);
			}
			
			if (this._defines.defines[PBRM.UV1]) {
				attribs.push(VertexBuffer.UVKind);
			}
			
			if (this._defines.defines[PBRM.UV2]) {
				attribs.push(VertexBuffer.UV2Kind);
			}
			
			if (this._defines.defines[PBRM.VERTEXCOLOR]) {
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
			
			if (this._defines.defines[PBRM.INSTANCES]) {
				attribs.push("world0");
				attribs.push("world1");
				attribs.push("world2");
				attribs.push("world3");
			}
			
			// Legacy browser patch
			var shaderName:String = "pbrmat";
			if (scene.getEngine().getCaps().standardDerivatives != true) {
				shaderName = "legacypbrmat";
			}
			var join:String = this._defines.toString();
			this._effect = scene.getEngine().createEffect(shaderName,
				attribs,
				["world", "view", "viewProjection", "vEyePosition", "vLightsType", "vAmbientColor", "vDiffuseColor", "vSpecularColor", "vEmissiveColor",
					"vLightData0", "vLightDiffuse0", "vLightSpecular0", "vLightDirection0", "vLightGround0", "lightMatrix0",
					"vLightData1", "vLightDiffuse1", "vLightSpecular1", "vLightDirection1", "vLightGround1", "lightMatrix1",
					"vLightData2", "vLightDiffuse2", "vLightSpecular2", "vLightDirection2", "vLightGround2", "lightMatrix2",
					"vLightData3", "vLightDiffuse3", "vLightSpecular3", "vLightDirection3", "vLightGround3", "lightMatrix3",
					"vFogInfos", "vFogColor", "pointSize",
					"vDiffuseInfos", "vAmbientInfos", "vOpacityInfos", "vReflectionInfos", "vEmissiveInfos", "vSpecularInfos", "vBumpInfos", "vLightmapInfos",
					"mBones",
					"vClipPlane", "diffuseMatrix", "ambientMatrix", "opacityMatrix", "reflectionMatrix", "emissiveMatrix", "specularMatrix", "bumpMatrix", "lightmapMatrix",
					"shadowsInfo0", "shadowsInfo1", "shadowsInfo2", "shadowsInfo3",
					"diffuseLeftColor", "diffuseRightColor", "opacityParts", "reflectionLeftColor", "reflectionRightColor", "emissiveLeftColor", "emissiveRightColor",
					"roughness",
					"vPBRLightingIntensity", "vPBRShadowIntensity", "vPBROverloadedIntensity", "vPBRCameraInfos", "vPBROverloadedDiffuse", "vPBROverloadedSpecular", "vPBROverloadedEmissive", "vPBROverloadedSmoothness"
				],
				["diffuseSampler", "ambientSampler", "opacitySampler", "reflectionCubeSampler", "reflection2DSampler", "emissiveSampler", "specularSampler", "bumpSampler", "lightmapSampler",
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
				mesh._materialDefines = new PBRMaterialDefines();
			}
			
			this._defines.cloneTo(mesh._materialDefines);
		}
		
		return true;
	}

	override public function unbind() {
		if (this.reflectionTexture != null && this.reflectionTexture.isRenderTarget) {
			this._effect.setTexture("reflection2DSampler", null);
		}
		
		super.unbind();
	}

	override public function bindOnlyWorldMatrix(world:Matrix) {
		this._effect.setMatrix("world", world);
	}
	
	private var _myScene:Scene = null;
	private var _myShadowGenerator:ShadowGenerator = null;

	override public function bind(world:Matrix, ?mesh:Mesh) {
		this._myScene = this.getScene();
		
		// Matrices        
		this.bindOnlyWorldMatrix(world);
		this._effect.setMatrix("viewProjection", this._myScene.getTransformMatrix());
		
		// Bones
		if (mesh != null && mesh.useBones && mesh.computeBonesUsingShaders) {
			this._effect.setMatrices("mBones", mesh.skeleton.getTransformMatrices());
		}
		
		if (this._myScene.getCachedMaterial() != this) {
			if (StandardMaterial.FresnelEnabled) {
				// Fresnel
				if (this.diffuseFresnelParameters != null && this.diffuseFresnelParameters.isEnabled) {
					this._effect.setColor4("diffuseLeftColor", this.diffuseFresnelParameters.leftColor, this.diffuseFresnelParameters.power);
					this._effect.setColor4("diffuseRightColor", this.diffuseFresnelParameters.rightColor, this.diffuseFresnelParameters.bias);
				}
				
				if (this.opacityFresnelParameters != null && this.opacityFresnelParameters.isEnabled) {
					this._effect.setColor4("opacityParts", new Color3(this.opacityFresnelParameters.leftColor.toLuminance(), this.opacityFresnelParameters.rightColor.toLuminance(), this.opacityFresnelParameters.bias), this.opacityFresnelParameters.power);
				}
				
				if (this.reflectionFresnelParameters != null && this.reflectionFresnelParameters.isEnabled) {
					this._effect.setColor4("reflectionLeftColor", this.reflectionFresnelParameters.leftColor, this.reflectionFresnelParameters.power);
					this._effect.setColor4("reflectionRightColor", this.reflectionFresnelParameters.rightColor, this.reflectionFresnelParameters.bias);
				}
				
				if (this.emissiveFresnelParameters != null && this.emissiveFresnelParameters.isEnabled) {
					this._effect.setColor4("emissiveLeftColor", this.emissiveFresnelParameters.leftColor, this.emissiveFresnelParameters.power);
					this._effect.setColor4("emissiveRightColor", this.emissiveFresnelParameters.rightColor, this.emissiveFresnelParameters.bias);
				}
			}
			
			// Textures        
			if (this.diffuseTexture != null && StandardMaterial.DiffuseTextureEnabled) {
				this._effect.setTexture("diffuseSampler", this.diffuseTexture);
				
				this._effect.setFloat2("vDiffuseInfos", this.diffuseTexture.coordinatesIndex, this.diffuseTexture.level);
				this._effect.setMatrix("diffuseMatrix", this.diffuseTexture.getTextureMatrix());
			}
			
			if (this.ambientTexture != null && StandardMaterial.AmbientTextureEnabled) {
				this._effect.setTexture("ambientSampler", this.ambientTexture);
				
				this._effect.setFloat2("vAmbientInfos", this.ambientTexture.coordinatesIndex, this.ambientTexture.level);
				this._effect.setMatrix("ambientMatrix", this.ambientTexture.getTextureMatrix());
			}
			
			if (this.opacityTexture != null && StandardMaterial.OpacityTextureEnabled) {
				this._effect.setTexture("opacitySampler", this.opacityTexture);
				
				this._effect.setFloat2("vOpacityInfos", this.opacityTexture.coordinatesIndex, this.opacityTexture.level);
				this._effect.setMatrix("opacityMatrix", this.opacityTexture.getTextureMatrix());
			}
			
			if (this.reflectionTexture != null && StandardMaterial.ReflectionTextureEnabled) {
				if (this.reflectionTexture.isCube) {
					this._effect.setTexture("reflectionCubeSampler", this.reflectionTexture);
				} 
				else {
					this._effect.setTexture("reflection2DSampler", this.reflectionTexture);
				}
				
				this._effect.setMatrix("reflectionMatrix", this.reflectionTexture.getReflectionTextureMatrix());
				this._effect.setFloat2("vReflectionInfos", this.reflectionTexture.level, this.roughness);
			}
			
			if (this.emissiveTexture != null && StandardMaterial.EmissiveTextureEnabled) {
				this._effect.setTexture("emissiveSampler", this.emissiveTexture);
				
				this._effect.setFloat2("vEmissiveInfos", this.emissiveTexture.coordinatesIndex, this.emissiveTexture.level);
				this._effect.setMatrix("emissiveMatrix", this.emissiveTexture.getTextureMatrix());
			}
			
			if (this.lightmapTexture != null && StandardMaterial.LightmapEnabled) {
				this._effect.setTexture("lightmapSampler", this.lightmapTexture);
				
				this._effect.setFloat2("vLightmapInfos", this.lightmapTexture.coordinatesIndex, this.lightmapTexture.level);
				this._effect.setMatrix("lightmapMatrix", this.lightmapTexture.getTextureMatrix());
			}
			
			if (this.specularTexture != null && StandardMaterial.SpecularTextureEnabled) {
				this._effect.setTexture("specularSampler", this.specularTexture);
				
				this._effect.setFloat2("vSpecularInfos", this.specularTexture.coordinatesIndex, this.specularTexture.level);
				this._effect.setMatrix("specularMatrix", this.specularTexture.getTextureMatrix());
			}
			
			if (this.bumpTexture != null && this._myScene.getEngine().getCaps().standardDerivatives == true && StandardMaterial.BumpTextureEnabled && !this.disableBumpMap) {
				this._effect.setTexture("bumpSampler", this.bumpTexture);
				
				this._effect.setFloat2("vBumpInfos", this.bumpTexture.coordinatesIndex, 1.0 / this.bumpTexture.level);
				this._effect.setMatrix("bumpMatrix", this.bumpTexture.getTextureMatrix());
			}
			
			// Clip plane
			if (this._myScene.clipPlane != null) {
				this._effect.setFloat4("vClipPlane", this._myScene.clipPlane.normal.x,
					this._myScene.clipPlane.normal.y,
					this._myScene.clipPlane.normal.z,
					this._myScene.clipPlane.d);
			}
			
			// Point size
			if (this.pointsCloud) {
				this._effect.setFloat("pointSize", this.pointSize);
			}
			
			// Colors
			this._myScene.ambientColor.multiplyToRef(this.ambientColor, this._globalAmbientColor);
			
			// GAMMA CORRECTION.
			this.specularColor.toLinearSpaceToRef(PBRMaterial._scaledSpecular);
			
			this._effect.setVector3("vEyePosition", this._myScene._mirroredCameraPosition != null ? this._myScene._mirroredCameraPosition : this._myScene.activeCamera.position);
			this._effect.setColor3("vAmbientColor", this._globalAmbientColor);
			
			if (this._defines.defines[PBRM.SPECULARTERM]) {
				this._effect.setColor4("vSpecularColor", PBRMaterial._scaledSpecular, this.specularPower);
			}
			
			// GAMMA CORRECTION.
			this.emissiveColor.toLinearSpaceToRef(PBRMaterial._scaledEmissive); 
			this._effect.setColor3("vEmissiveColor", PBRMaterial._scaledEmissive);
		}
		
		// GAMMA CORRECTION.
		this.diffuseColor.toLinearSpaceToRef(PBRMaterial._scaledDiffuse);
		this._effect.setColor4("vDiffuseColor", PBRMaterial._scaledDiffuse, this.alpha * mesh.visibility);
		
		// Lights
		if (this._myScene.lightsEnabled && !this.disableLighting) {
			PBRMaterial.BindLights(this._myScene, mesh, this._effect, this._defines);
		}
		
		// View
		if (this._myScene.fogEnabled && mesh.applyFog && this._myScene.fogMode != Scene.FOGMODE_NONE || this.reflectionTexture != null) {
			this._effect.setMatrix("view", this._myScene.getViewMatrix());
		}
		
		// Fog
		if (this._myScene.fogEnabled && mesh.applyFog && this._myScene.fogMode != Scene.FOGMODE_NONE) {
			this._effect.setFloat4("vFogInfos", this._myScene.fogMode, this._myScene.fogStart, this._myScene.fogEnd, this._myScene.fogDensity);
			this._effect.setColor3("vFogColor", this._myScene.fogColor);
		}
		
		this._lightingInfos.x = this.directIntensity;
		this._lightingInfos.y = this.emissiveIntensity;
		this._lightingInfos.z = this.environmentIntensity;
		this._effect.setVector4("vPBRLightingIntensity", this._lightingInfos);
		
		this._shadowInfos.x = this.shadowIntensity;
		this._shadowInfos.y = this.shadeIntensity;
		this._effect.setVector4("vPBRShadowIntensity", this._shadowInfos);
		
		this._cameraInfos.x = this.cameraExposure;
		this._cameraInfos.y = this.cameraContrast;
		this._effect.setVector4("vPBRCameraInfos", this._cameraInfos);
		
		this._overloadedIntensity.x = this.overloadedAmbientIntensity;
		this._overloadedIntensity.y = this.overloadedDiffuseIntensity;
		this._overloadedIntensity.z = this.overloadedSpecularIntensity;
		this._overloadedIntensity.w = this.overloadedEmissiveIntensity;
		this._effect.setVector4("vPBROverloadedIntensity", this._overloadedIntensity);
		
		this.overloadedAmbient.toLinearSpaceToRef(this._tempColor);
		this._effect.setColor3("vPBROverloadedAmbient", this._tempColor);
		this.overloadedDiffuse.toLinearSpaceToRef(this._tempColor);
		this._effect.setColor3("vPBROverloadedDiffuse", this._tempColor);
		this.overloadedSpecular.toLinearSpaceToRef(this._tempColor);
		this._effect.setColor3("vPBROverloadedSpecular", this._tempColor);
		this.overloadedEmissive.toLinearSpaceToRef(this._tempColor);
		this._effect.setColor3("vPBROverloadedEmissive", this._tempColor);
		
		this._overloadedSmoothness.x = this.overloadedSmoothness;
		this._overloadedSmoothness.y = this.overloadedSmoothnessIntensity;
		this._effect.setVector3("vPBROverloadedSmoothness", this._overloadedSmoothness);
		
		super.bind(world, mesh);
		
		this._myScene = null;
	}

	public function getAnimatables():Array<IAnimatable> {
		var results:Array<IAnimatable> = [];
		
		if (this.diffuseTexture != null && this.diffuseTexture.animations != null && this.diffuseTexture.animations.length > 0) {
			results.push(this.diffuseTexture);
		}
		
		if (this.ambientTexture != null && this.ambientTexture.animations != null && this.ambientTexture.animations.length > 0) {
			results.push(this.ambientTexture);
		}
		
		if (this.opacityTexture != null && this.opacityTexture.animations != null && this.opacityTexture.animations.length > 0) {
			results.push(this.opacityTexture);
		}
		
		if (this.reflectionTexture != null && this.reflectionTexture.animations != null && this.reflectionTexture.animations.length > 0) {
			results.push(this.reflectionTexture);
		}
		
		if (this.emissiveTexture != null && this.emissiveTexture.animations != null && this.emissiveTexture.animations.length > 0) {
			results.push(this.emissiveTexture);
		}
		
		if (this.specularTexture != null && this.specularTexture.animations != null && this.specularTexture.animations.length > 0) {
			results.push(this.specularTexture);
		}
		
		if (this.bumpTexture != null && this.bumpTexture.animations != null && this.bumpTexture.animations.length > 0) {
			results.push(this.bumpTexture);
		}
		
		return results;
	}

	override public function dispose(forceDisposeEffect:Bool = false) {
		if (this.diffuseTexture != null) {
			this.diffuseTexture.dispose();
		}
		
		if (this.ambientTexture != null) {
			this.ambientTexture.dispose();
		}
		
		if (this.opacityTexture != null) {
			this.opacityTexture.dispose();
		}
		
		if (this.reflectionTexture != null) {
			this.reflectionTexture.dispose();
		}
		
		if (this.emissiveTexture != null) {
			this.emissiveTexture.dispose();
		}
		
		if (this.specularTexture != null) {
			this.specularTexture.dispose();
		}
		
		if (this.bumpTexture != null) {
			this.bumpTexture.dispose();
		}
		
		super.dispose(forceDisposeEffect);
	}

	override public function clone(name:String):PBRMaterial {
		var newPBRMaterial = new PBRMaterial(name, this.getScene());
		
		// Base material
		this.copyTo(newPBRMaterial);
		
		// PBR material
		if (this.diffuseTexture != null) {
			newPBRMaterial.diffuseTexture = this.diffuseTexture.clone();
		}
		if (this.ambientTexture != null) {
			newPBRMaterial.ambientTexture = this.ambientTexture.clone();
		}
		if (this.opacityTexture != null) {
			newPBRMaterial.opacityTexture = this.opacityTexture.clone();
		}
		if (this.reflectionTexture != null) {
			newPBRMaterial.reflectionTexture = this.reflectionTexture.clone();
		}
		if (this.emissiveTexture != null) {
			newPBRMaterial.emissiveTexture = this.emissiveTexture.clone();
		}
		if (this.specularTexture != null) {
			newPBRMaterial.specularTexture = this.specularTexture.clone();
		}
		if (this.bumpTexture != null) {
			newPBRMaterial.bumpTexture = this.bumpTexture.clone();
		}
		if (this.lightmapTexture != null) {
			newPBRMaterial.lightmapTexture = this.lightmapTexture.clone();
			newPBRMaterial.useLightmapAsShadowmap = this.useLightmapAsShadowmap;
		}
		
		newPBRMaterial.ambientColor = this.ambientColor.clone();
		newPBRMaterial.diffuseColor = this.diffuseColor.clone();
		newPBRMaterial.specularColor = this.specularColor.clone();
		newPBRMaterial.specularPower = this.specularPower;
		newPBRMaterial.emissiveColor = this.emissiveColor.clone();
		newPBRMaterial.useAlphaFromDiffuseTexture = this.useAlphaFromDiffuseTexture;
		newPBRMaterial.useEmissiveAsIllumination = this.useEmissiveAsIllumination;
		newPBRMaterial.useGlossinessFromSpecularMapAlpha = this.useGlossinessFromSpecularMapAlpha;
		newPBRMaterial.useReflectionFresnelFromSpecular = this.useReflectionFresnelFromSpecular;
		newPBRMaterial.useSpecularOverAlpha = this.useSpecularOverAlpha;
		newPBRMaterial.roughness = this.roughness;
		
		newPBRMaterial.diffuseFresnelParameters = this.diffuseFresnelParameters.clone();
		newPBRMaterial.emissiveFresnelParameters = this.emissiveFresnelParameters.clone();
		newPBRMaterial.reflectionFresnelParameters = this.reflectionFresnelParameters.clone();
		newPBRMaterial.opacityFresnelParameters = this.opacityFresnelParameters.clone();
		
		newPBRMaterial.directIntensity = this.directIntensity;
		newPBRMaterial.emissiveIntensity = this.emissiveIntensity;
		newPBRMaterial.environmentIntensity = this.environmentIntensity;
		
		newPBRMaterial.shadowIntensity = this.shadowIntensity;
		newPBRMaterial.shadeIntensity = this.shadeIntensity;
		
		newPBRMaterial.cameraExposure = this.cameraExposure;
		newPBRMaterial.cameraContrast = this.cameraContrast;
		
		newPBRMaterial.overloadedAmbientIntensity = this.overloadedAmbientIntensity;
		newPBRMaterial.overloadedDiffuseIntensity = this.overloadedDiffuseIntensity;
		newPBRMaterial.overloadedSpecularIntensity = this.overloadedSpecularIntensity;
		newPBRMaterial.overloadedEmissiveIntensity = this.overloadedEmissiveIntensity;
		newPBRMaterial.overloadedAmbient = this.overloadedAmbient.clone();
		newPBRMaterial.overloadedDiffuse = this.overloadedDiffuse.clone();
		newPBRMaterial.overloadedSpecular = this.overloadedSpecular.clone();
		newPBRMaterial.overloadedEmissive = this.overloadedEmissive.clone();
		
		newPBRMaterial.overloadedSmoothness = this.overloadedSmoothness;
		newPBRMaterial.overloadedSmoothnessIntensity = this.overloadedSmoothnessIntensity;
		
		newPBRMaterial.disableBumpMap = this.disableBumpMap;
		
		return newPBRMaterial;
	}
	
}
