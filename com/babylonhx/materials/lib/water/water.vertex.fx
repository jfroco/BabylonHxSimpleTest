precision highp float;

// Attributes
attribute vec3 position;
#ifdef NORMAL
attribute vec3 normal;
#endif
#ifdef UV1
attribute vec2 uv;
#endif
#ifdef UV2
attribute vec2 uv2;
#endif
#ifdef VERTEXCOLOR
attribute vec4 color;
#endif
#if NUM_BONE_INFLUENCERS > 0
	uniform mat4 mBones[BonesPerMesh];

	attribute vec4 matricesIndices;
	attribute vec4 matricesWeights;
	#if NUM_BONE_INFLUENCERS > 4
		attribute vec4 matricesIndicesExtra;
		attribute vec4 matricesWeightsExtra;
	#endif
#endif

// Uniforms

#ifdef INSTANCES
attribute vec4 world0;
attribute vec4 world1;
attribute vec4 world2;
attribute vec4 world3;
#else
uniform mat4 world;
#endif

uniform mat4 view;
uniform mat4 viewProjection;

#ifdef BUMP
varying vec2 vNormalUV;
uniform mat4 normalMatrix;
uniform vec2 vNormalInfos;
#endif

#ifdef POINTSIZE
uniform float pointSize;
#endif

// Output
varying vec3 vPositionW;
#ifdef NORMAL
varying vec3 vNormalW;
#endif

#ifdef VERTEXCOLOR
varying vec4 vColor;
#endif

#ifdef CLIPPLANE
uniform vec4 vClipPlane;
varying float fClipDistance;
#endif

#ifdef FOG
varying float fFogDistance;
#endif

#ifdef SHADOWS
#if defined(SPOTLIGHT0) || defined(DIRLIGHT0)
uniform mat4 lightMatrix0;
varying vec4 vPositionFromLight0;
#endif
#if defined(SPOTLIGHT1) || defined(DIRLIGHT1)
uniform mat4 lightMatrix1;
varying vec4 vPositionFromLight1;
#endif
#if defined(SPOTLIGHT2) || defined(DIRLIGHT2)
uniform mat4 lightMatrix2;
varying vec4 vPositionFromLight2;
#endif
#if defined(SPOTLIGHT3) || defined(DIRLIGHT3)
uniform mat4 lightMatrix3;
varying vec4 vPositionFromLight3;
#endif
#endif

// Water uniforms
uniform mat4 worldReflectionViewProjection;
uniform vec2 windDirection;
uniform float waveLength;
uniform float time;
uniform float windForce;
uniform float waveHeight;
uniform float waveSpeed;

// Water varyings
varying vec3 vPosition;
varying vec3 vRefractionMapTexCoord;
varying vec3 vReflectionMapTexCoord;

void main(void) {
	mat4 finalWorld;

#ifdef INSTANCES
	finalWorld = mat4(world0, world1, world2, world3);
#else
	finalWorld = world;
#endif

#if NUM_BONE_INFLUENCERS > 0
	mat4 influence;
	influence = mBones[int(matricesIndices[0])] * matricesWeights[0];

	#if NUM_BONE_INFLUENCERS > 1
		influence += mBones[int(matricesIndices[1])] * matricesWeights[1];
	#endif 
	#if NUM_BONE_INFLUENCERS > 2
		influence += mBones[int(matricesIndices[2])] * matricesWeights[2];
	#endif	
	#if NUM_BONE_INFLUENCERS > 3
		influence += mBones[int(matricesIndices[3])] * matricesWeights[3];
	#endif	

	#if NUM_BONE_INFLUENCERS > 4
		influence += mBones[int(matricesIndicesExtra[0])] * matricesWeightsExtra[0];
	#endif
	#if NUM_BONE_INFLUENCERS > 5
		influence += mBones[int(matricesIndicesExtra[1])] * matricesWeightsExtra[1];
	#endif	
	#if NUM_BONE_INFLUENCERS > 6
		influence += mBones[int(matricesIndicesExtra[2])] * matricesWeightsExtra[2];
	#endif	
	#if NUM_BONE_INFLUENCERS > 7
		influence += mBones[int(matricesIndicesExtra[3])] * matricesWeightsExtra[3];
	#endif	

	finalWorld = finalWorld * influence;
#endif

	vec4 worldPos = finalWorld * vec4(position, 1.0);
	vPositionW = vec3(worldPos);

#ifdef NORMAL
	vNormalW = normalize(vec3(finalWorld * vec4(normal, 0.0)));
#endif

	// Texture coordinates
#ifndef UV1
	vec2 uv = vec2(0., 0.);
#endif
#ifndef UV2
	vec2 uv2 = vec2(0., 0.);
#endif

#ifdef BUMP
	if (vNormalInfos.x == 0.)
	{
		vNormalUV = vec2(normalMatrix * vec4((uv * 1.0) / waveLength + time * windForce * windDirection, 1.0, 0.0));
	}
	else
	{
		vNormalUV = vec2(normalMatrix * vec4((uv2 * 1.0) / waveLength + time * windForce * windDirection, 1.0, 0.0));
	}
#endif

	// Clip plane
#ifdef CLIPPLANE
	fClipDistance = dot(worldPos, vClipPlane);
#endif

	// Fog
#ifdef FOG
	fFogDistance = (view * worldPos).z;
#endif

	// Shadows
#ifdef SHADOWS
#if defined(SPOTLIGHT0) || defined(DIRLIGHT0)
	vPositionFromLight0 = lightMatrix0 * worldPos;
#endif
#if defined(SPOTLIGHT1) || defined(DIRLIGHT1)
	vPositionFromLight1 = lightMatrix1 * worldPos;
#endif
#if defined(SPOTLIGHT2) || defined(DIRLIGHT2)
	vPositionFromLight2 = lightMatrix2 * worldPos;
#endif
#if defined(SPOTLIGHT3) || defined(DIRLIGHT3)
	vPositionFromLight3 = lightMatrix3 * worldPos;
#endif
#endif

	// Vertex color
#ifdef VERTEXCOLOR
	vColor = color;
#endif

	// Point size
#ifdef POINTSIZE
	gl_PointSize = pointSize;
#endif

	vec3 p = position;
	float newY = (sin(((p.x / 0.05) + time * waveSpeed * windForce) * windDirection.x) * waveHeight * 5.0)
			   + (cos(((p.z / 0.05) + time * waveSpeed * windForce) * windDirection.y) * waveHeight * 5.0);
	p.y += abs(newY);
	
	gl_Position = viewProjection * finalWorld * vec4(p, 1.0);

#ifdef REFLECTION
	worldPos = viewProjection * finalWorld * vec4(p, 1.0);
	
	// Water
	vPosition = position;
	
	vRefractionMapTexCoord.x = 0.5 * (worldPos.w + worldPos.x);
	vRefractionMapTexCoord.y = 0.5 * (worldPos.w + worldPos.y);
	vRefractionMapTexCoord.z = worldPos.w;
	
	worldPos = worldReflectionViewProjection * vec4(position, 1.0);
	vReflectionMapTexCoord.x = 0.5 * (worldPos.w + worldPos.x);
	vReflectionMapTexCoord.y = 0.5 * (worldPos.w + worldPos.y);
	vReflectionMapTexCoord.z = worldPos.w;
#endif
}