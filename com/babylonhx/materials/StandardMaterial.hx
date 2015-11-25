package com.babylonhx.materials;

import com.babylonhx.Engine;
import com.babylonhx.lights.shadows.ShadowGenerator;
import com.babylonhx.lights.IShadowLight;
import com.babylonhx.materials.textures.BaseTexture;
import com.babylonhx.materials.textures.RenderTargetTexture;
import com.babylonhx.materials.textures.Texture;
import com.babylonhx.math.Color3;
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

typedef SMD = StandardMaterialDefines

@:expose('BABYLON.StandardMaterial') class StandardMaterial extends Material {
		
	// Flags used to enable or disable a type of texture for all Standard Materials
	public static var DiffuseTextureEnabled:Bool = true;
	public static var AmbientTextureEnabled:Bool = true;
	public static var OpacityTextureEnabled:Bool = true;
	public static var ReflectionTextureEnabled:Bool = true;
	public static var EmissiveTextureEnabled:Bool = true;
	public static var SpecularTextureEnabled:Bool = true;
	public static var BumpTextureEnabled:Bool = true;
	public static var FresnelEnabled:Bool = true;
	public static var LightmapEnabled:Bool = true;
	
	public var diffuseTexture:BaseTexture = null;
	public var ambientTexture:BaseTexture = null;
	public var opacityTexture:BaseTexture = null;
	public var reflectionTexture:BaseTexture = null;
	public var emissiveTexture:BaseTexture = null;
	public var specularTexture:BaseTexture = null;
	public var bumpTexture:BaseTexture = null;
	public var lightmapTexture:BaseTexture = null;

	public var ambientColor:Color3 = new Color3(0, 0, 0);
	public var diffuseColor:Color3 = new Color3(1, 1, 1);
	public var specularColor:Color3 = new Color3(1, 1, 1);
	public var specularPower:Float = 64;
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
	private var _renderId:Int = 0;
		
	private var _defines:StandardMaterialDefines = new StandardMaterialDefines();
	private var _cachedDefines:StandardMaterialDefines = new StandardMaterialDefines();
	
	private var _useLogarithmicDepth:Bool;
	public var useLogarithmicDepth(get, set):Bool;
	

	public function new(name:String, scene:Scene) {
		super(name, scene);
		
		this._cachedDefines.BonesPerMesh = -1;
		
		this.getRenderTargetTextures = function():SmartArray<RenderTargetTexture> {
			this._renderTargets.reset();
			
			if (this.reflectionTexture != null && this.reflectionTexture.isRenderTarget) {
				this._renderTargets.push(cast this.reflectionTexture);
			}
			
			return this._renderTargets;
		}
	}
	
	private function get_useLogarithmicDepth():Bool {
		return this._useLogarithmicDepth;
	}
	private function set_useLogarithmicDepth(value:Bool):Bool {
		this._useLogarithmicDepth = value && this.getScene().getEngine().getCaps().fragmentDepthSupported;
		return this._useLogarithmicDepth;
	}

	override public function needAlphaBlending():Bool {
		return (this.alpha < 1.0) || (this.opacityTexture != null) || this._shouldUseAlphaFromDiffuseTexture() || (this.opacityFresnelParameters != null) && this.opacityFresnelParameters.isEnabled;
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

	// Methods
	private function _checkCache(scene:Scene, ?mesh:AbstractMesh, useInstances:Bool = false):Bool {
		if (mesh == null) {
			return true;
		}
		
		if (this._defines.defines[SMD.INSTANCES] != useInstances) {
			return false;
		}
		
		if (mesh._materialDefines != null && mesh._materialDefines.isEqual(this._defines)) {
			return true;
		}
		
		return false;
	}

	public static function PrepareDefinesForLights(scene:Scene, mesh:AbstractMesh, defines:StandardMaterialDefines):Bool {
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
			defines.defines[SMD.LIGHT0 + lightIndex] = true;
			
			var type:Int = defines.getLight(light.type, lightIndex);			
			defines.defines[type] = true;
			
			// Specular
			if (!light.specular.equalsFloats(0, 0, 0)) {
				defines.defines[SMD.SPECULARTERM] = true;
			}
			
			// Shadows
			if (scene.shadowsEnabled) {
				var shadowGenerator = light.getShadowGenerator();
				if (mesh != null && mesh.receiveShadows && shadowGenerator != null) {
					defines.defines[SMD.SHADOW0 + lightIndex] = true; 
					
					defines.defines[SMD.SHADOWS] = true;
					
					if (shadowGenerator.useVarianceShadowMap || shadowGenerator.useBlurVarianceShadowMap) {
						defines.defines[SMD.SHADOWVSM0 + lightIndex] = true;
					}
					
					if (shadowGenerator.usePoissonSampling) {
						defines.defines[SMD.SHADOWPCF0 + lightIndex] = true;
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
			
			light.diffuse.scaleToRef(light.intensity, StandardMaterial._scaledDiffuse);
			effect.setColor4("vLightDiffuse" + lightIndex, StandardMaterial._scaledDiffuse, light.range);
			if (defines.defines[SMD.SPECULARTERM]) {
				light.specular.scaleToRef(light.intensity, StandardMaterial._scaledSpecular);
				effect.setColor3("vLightSpecular" + lightIndex, StandardMaterial._scaledSpecular);
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
		
		var scene = this.getScene();
		
		if (!this.checkReadyOnEveryCall) {
			if (this._renderId == scene.getRenderId()) {
				if (this._checkCache(scene, mesh, useInstances)) {
					return true;
				}
			}
		}
		
		var engine = scene.getEngine();
		var needNormals = false;
		var needUVs = false;
		
		this._defines.reset();
		
		// Textures
		if (scene.texturesEnabled) {
			if (this.diffuseTexture != null && StandardMaterial.DiffuseTextureEnabled) {
				if (!this.diffuseTexture.isReady()) {
					return false;
				} 
				else {
					needUVs = true;
					this._defines.defines[SMD.DIFFUSE] = true;
				}
			}
			
			if (this.ambientTexture != null && StandardMaterial.AmbientTextureEnabled) {
				if (!this.ambientTexture.isReady()) {
					return false;
				} 
				else {
					needUVs = true;
					this._defines.defines[SMD.AMBIENT] = true;
				}
			}
			
			if (this.opacityTexture != null && StandardMaterial.OpacityTextureEnabled) {
				if (!this.opacityTexture.isReady()) {
					return false;
				} 
				else {
					needUVs = true;
					this._defines.defines[SMD.OPACITY] = true;
					
					if (this.opacityTexture.getAlphaFromRGB) {
						this._defines.defines[SMD.OPACITYRGB] = true;
					}
				}
			}
			
			if (this.reflectionTexture != null && StandardMaterial.ReflectionTextureEnabled) {
				if (!this.reflectionTexture.isReady()) {
					return false;
				} 
				else {
					needNormals = true;
					this._defines.defines[SMD.REFLECTION] = true;
					
					if (this.roughness > 0) {
						this._defines.defines[SMD.ROUGHNESS] = true;
					}
					
					if (this.reflectionTexture.coordinatesMode == Texture.INVCUBIC_MODE) {
						this._defines.defines[SMD.INVERTCUBICMAP] = true;
					}
					
					this._defines.defines[SMD.REFLECTIONMAP_3D] = this.reflectionTexture.isCube;
					
					switch (this.reflectionTexture.coordinatesMode) {
						case Texture.CUBIC_MODE, Texture.INVCUBIC_MODE:
							this._defines.defines[SMD.REFLECTIONMAP_CUBIC] = true;
							
						case Texture.EXPLICIT_MODE:
							this._defines.defines[SMD.REFLECTIONMAP_EXPLICIT] = true;
							
						case Texture.PLANAR_MODE:
							this._defines.defines[SMD.REFLECTIONMAP_PLANAR] = true;
							
						case Texture.PROJECTION_MODE:
							this._defines.defines[SMD.REFLECTIONMAP_PROJECTION] = true;
							
						case Texture.SKYBOX_MODE:
							this._defines.defines[SMD.REFLECTIONMAP_SKYBOX] = true;
							
						case Texture.SPHERICAL_MODE:
							this._defines.defines[SMD.REFLECTIONMAP_SPHERICAL] = true;
							
						case Texture.EQUIRECTANGULAR_MODE:
							this._defines.defines[SMD.REFLECTIONMAP_EQUIRECTANGULAR] = true;							
					}
				}
			}
			
			if (this.emissiveTexture != null && StandardMaterial.EmissiveTextureEnabled) {
				if (!this.emissiveTexture.isReady()) {
					return false;
				} 
				else {
					needUVs = true;
					this._defines.defines[SMD.EMISSIVE] = true;
				}
			}
			
			if (this.lightmapTexture != null && StandardMaterial.LightmapEnabled) {
				if (!this.lightmapTexture.isReady()) {
					return false;
				} 
				else {
					needUVs = true;
					this._defines.defines[SMD.LIGHTMAP] = true;
					this._defines.defines[SMD.USELIGHTMAPASSHADOWMAP] = this.useLightmapAsShadowmap;
				}
			}
			
			if (this.specularTexture != null && StandardMaterial.SpecularTextureEnabled) {
				if (!this.specularTexture.isReady()) {
					return false;
				} 
				else {
					needUVs = true;
					this._defines.defines[SMD.SPECULAR] = true;
					this._defines.defines[SMD.GLOSSINESS] = this.useGlossinessFromSpecularMapAlpha;
				}
			}
		}
		
		if (scene.getEngine().getCaps().standardDerivatives == true && this.bumpTexture != null && StandardMaterial.BumpTextureEnabled) {
			if (!this.bumpTexture.isReady()) {
				return false;
			} 
			else {
				needUVs = true;
				this._defines.defines[SMD.BUMP] = true;
			}
		}
		
		// Effect
		if (scene.clipPlane != null) {
			this._defines.defines[SMD.CLIPPLANE] = true;
		}
		
		if (engine.getAlphaTesting()) {
			this._defines.defines[SMD.ALPHATEST] = true;
		}
		
		if (this._shouldUseAlphaFromDiffuseTexture()) {
			this._defines.defines[SMD.ALPHAFROMDIFFUSE] = true;
		}
		
		if (this.useEmissiveAsIllumination) {
			this._defines.defines[SMD.EMISSIVEASILLUMINATION] = true;
		}
		
		if (this.linkEmissiveWithDiffuse) {
			this._defines.defines[SMD.LINKEMISSIVEWITHDIFFUSE] = true;
		}
		
		if (this.useReflectionFresnelFromSpecular) {
			this._defines.defines[SMD.REFLECTIONFRESNELFROMSPECULAR] = true;
		}
		
		if (this.useLogarithmicDepth) {
            this._defines.defines[SMD.LOGARITHMICDEPTH] = true;
        }
		
		// Point size
		if (this.pointsCloud || scene.forcePointsCloud) {
			this._defines.defines[SMD.POINTSIZE] = true;
		}
		
		// Fog
		if (scene.fogEnabled && mesh != null && mesh.applyFog && scene.fogMode != Scene.FOGMODE_NONE && this.fogEnabled) {
			this._defines.defines[SMD.FOG] = true;
		}
		
		if (scene.lightsEnabled && !this.disableLighting) {
			needNormals = StandardMaterial.PrepareDefinesForLights(scene, mesh, this._defines);
		}
		
		if (StandardMaterial.FresnelEnabled) {
			// Fresnel
			if (this.diffuseFresnelParameters != null && this.diffuseFresnelParameters.isEnabled) {
				this._defines.defines[SMD.DIFFUSEFRESNEL] = true;
			}
			
			if (this.opacityFresnelParameters != null && this.opacityFresnelParameters.isEnabled) {
				this._defines.defines[SMD.OPACITYFRESNEL] = true;
			}
			
			if (this.reflectionFresnelParameters != null && this.reflectionFresnelParameters.isEnabled) {
				this._defines.defines[SMD.REFLECTIONFRESNEL] = true;
			}
			
			if (this.emissiveFresnelParameters != null && this.emissiveFresnelParameters.isEnabled) {
				this._defines.defines[SMD.EMISSIVEFRESNEL] = true;
			}
			
			if (this._defines.defines[SMD.DIFFUSEFRESNEL] ||
				this._defines.defines[SMD.OPACITYFRESNEL] ||
				this._defines.defines[SMD.REFLECTIONFRESNEL] ||
				this._defines.defines[SMD.EMISSIVEFRESNEL]) {	
				
				needNormals = true;
				this._defines.defines[SMD.FRESNEL] = true;
			}
		}
		
		if (this._defines.defines[SMD.SPECULARTERM] && this.useSpecularOverAlpha) {
			this._defines.defines[SMD.SPECULAROVERALPHA] = true;
		}
		
		// Attribs
		if (mesh != null) {
			if (needNormals && mesh.isVerticesDataPresent(VertexBuffer.NormalKind)) {
				this._defines.defines[SMD.NORMAL] = true;
			}
			if (needUVs) {
				if (mesh.isVerticesDataPresent(VertexBuffer.UVKind)) {
					this._defines.defines[SMD.UV1] = true;
				}
				if (mesh.isVerticesDataPresent(VertexBuffer.UV2Kind)) {
					this._defines.defines[SMD.UV2] = true;
				}
			}
			if (mesh.useVertexColors && mesh.isVerticesDataPresent(VertexBuffer.ColorKind)) {
				this._defines.defines[SMD.VERTEXCOLOR] = true;
				
				if (mesh.hasVertexAlpha) {
					this._defines.defines[SMD.VERTEXALPHA] = true;
				}
			}
			if (mesh.useBones && mesh.computeBonesUsingShaders) {
				this._defines.NUM_BONE_INFLUENCERS = mesh.numBoneInfluencers;
				this._defines.BonesPerMesh = (mesh.skeleton.bones.length + 1);
			}
			
			// Instances
			if (useInstances) {
				this._defines.defines[SMD.INSTANCES] = true;
			}
		}
		
		// Get correct effect      
		if (!this._defines.isEqual(this._cachedDefines) || this._effect == null) {
			this._defines.cloneTo(this._cachedDefines);
			
			scene.resetCachedMaterial();
			
			// Fallbacks
			var fallbacks = new EffectFallbacks();
			if (this._defines.defines[SMD.REFLECTION]) {
				fallbacks.addFallback(0, "REFLECTION");
			}
			
			if (this._defines.defines[SMD.SPECULAR]) {
				fallbacks.addFallback(0, "SPECULAR");
			}
			
			if (this._defines.defines[SMD.BUMP]) {
				fallbacks.addFallback(0, "BUMP");
			}
			
			if (this._defines.defines[SMD.SPECULAROVERALPHA]) {
				fallbacks.addFallback(0, "SPECULAROVERALPHA");
			}
			
			if (this._defines.defines[SMD.FOG]) {
				fallbacks.addFallback(1, "FOG");
			}
			
			if (this._defines.defines[SMD.POINTSIZE]) {
                fallbacks.addFallback(0, "POINTSIZE");
            }
			
			if (this._defines.defines[SMD.LOGARITHMICDEPTH]) {
                fallbacks.addFallback(0, "LOGARITHMICDEPTH");
            }
			
			for (lightIndex in 0...Material.maxSimultaneousLights) {
				if (!this._defines.defines[SMD.LIGHT0 + lightIndex]) {
					continue;
				}
				
				if (lightIndex > 0) {
					fallbacks.addFallback(lightIndex, "LIGHT" + lightIndex);
				}
				
				if (this._defines.defines[SMD.SHADOW0 + lightIndex]) {
					fallbacks.addFallback(0, "SHADOW" + lightIndex);
				}
				
				if (this._defines.defines[SMD.SHADOWPCF0 + lightIndex]) {
					fallbacks.addFallback(0, "SHADOWPCF" + lightIndex);
				}
				
				if (this._defines.defines[SMD.SHADOWVSM0 + lightIndex]) {
					fallbacks.addFallback(0, "SHADOWVSM" + lightIndex);
				}
			}
			
			if (this._defines.defines[SMD.SPECULARTERM]) {
				fallbacks.addFallback(0, "SPECULARTERM");
			}
			
			if (this._defines.defines[SMD.DIFFUSEFRESNEL]) {
				fallbacks.addFallback(1, "DIFFUSEFRESNEL");
			}
			
			if (this._defines.defines[SMD.OPACITYFRESNEL]) {
				fallbacks.addFallback(2, "OPACITYFRESNEL");
			}
			
			if (this._defines.defines[SMD.REFLECTIONFRESNEL]) {
				fallbacks.addFallback(3, "REFLECTIONFRESNEL");
			}
			
			if (this._defines.defines[SMD.EMISSIVEFRESNEL]) {
				fallbacks.addFallback(4, "EMISSIVEFRESNEL");
			}
			
			if (this._defines.defines[SMD.FRESNEL]) {
				fallbacks.addFallback(4, "FRESNEL");
			}
			
			if (this._defines.NUM_BONE_INFLUENCERS > 0){
				fallbacks.addCPUSkinningFallback(0, mesh);    
			}
			
			//Attributes
			var attribs:Array<String> = [VertexBuffer.PositionKind];
			
			if (this._defines.defines[SMD.NORMAL]) {
				attribs.push(VertexBuffer.NormalKind);
			}
			
			if (this._defines.defines[SMD.UV1]) {
				attribs.push(VertexBuffer.UVKind);
			}
			
			if (this._defines.defines[SMD.UV2]) {
				attribs.push(VertexBuffer.UV2Kind);
			}
			
			if (this._defines.defines[SMD.VERTEXCOLOR]) {
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
			
			if (this._defines.defines[SMD.INSTANCES]) {
				attribs.push("world0");
				attribs.push("world1");
				attribs.push("world2");
				attribs.push("world3");
			}
			
			// Legacy browser patch
			var shaderName = "default";
			if (scene.getEngine().getCaps().standardDerivatives != true) {
				shaderName = "legacydefault";
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
					"logarithmicDepthConstant"
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
				mesh._materialDefines = new StandardMaterialDefines();
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
			
			if (this.bumpTexture != null && scene.getEngine().getCaps().standardDerivatives == true && StandardMaterial.BumpTextureEnabled) {
				this._effect.setTexture("bumpSampler", this.bumpTexture);
				
				this._effect.setFloat2("vBumpInfos", this.bumpTexture.coordinatesIndex, 1.0 / this.bumpTexture.level);
				this._effect.setMatrix("bumpMatrix", this.bumpTexture.getTextureMatrix());
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
			
			// Colors
			scene.ambientColor.multiplyToRef(this.ambientColor, this._globalAmbientColor);
			
			this._effect.setVector3("vEyePosition", scene._mirroredCameraPosition != null ? scene._mirroredCameraPosition : scene.activeCamera.position);
			this._effect.setColor3("vAmbientColor", this._globalAmbientColor);
			
			if (this._defines.defines[SMD.SPECULARTERM]) {
				this._effect.setColor4("vSpecularColor", this.specularColor, this.specularPower);
			}
			this._effect.setColor3("vEmissiveColor", this.emissiveColor);
		}
		
		// Diffuse
		this._effect.setColor4("vDiffuseColor", this.diffuseColor, this.alpha * mesh.visibility);
		
		// Lights
		if (scene.lightsEnabled && !this.disableLighting) {
			StandardMaterial.BindLights(scene, mesh, this._effect, this._defines);
		}
		
		// View
		if (scene.fogEnabled && mesh.applyFog && scene.fogMode != Scene.FOGMODE_NONE || this.reflectionTexture != null) {
			this._effect.setMatrix("view", scene.getViewMatrix());
		}
		
		// Fog
		if (scene.fogEnabled && mesh.applyFog && scene.fogMode != Scene.FOGMODE_NONE) {
			this._effect.setFloat4("vFogInfos", scene.fogMode, scene.fogStart, scene.fogEnd, scene.fogDensity);
			this._effect.setColor3("vFogColor", scene.fogColor);
		}
		
		// Log. depth
        if (this._defines.defines[SMD.LOGARITHMICDEPTH]) {
            this._effect.setFloat("logarithmicDepthConstant", 2.0 / (Math.log(scene.activeCamera.maxZ + 1.0) / 0.6931471805599453));  // Math.LN2
        }
		
		super.bind(world, mesh);
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

	override public function clone(name:String):StandardMaterial {
		var newStandardMaterial = new StandardMaterial(name, this.getScene());
		
		// Base material
		this.copyTo(newStandardMaterial);
		
		// Standard material
		if (this.diffuseTexture != null) {
			newStandardMaterial.diffuseTexture = this.diffuseTexture.clone();
		}
		if (this.ambientTexture != null) {
			newStandardMaterial.ambientTexture = this.ambientTexture.clone();
		}
		if (this.opacityTexture != null) {
			newStandardMaterial.opacityTexture = this.opacityTexture.clone();
		}
		if (this.reflectionTexture != null) {
			newStandardMaterial.reflectionTexture = this.reflectionTexture.clone();
		}
		if (this.emissiveTexture != null) {
			newStandardMaterial.emissiveTexture = this.emissiveTexture.clone();
		}
		if (this.specularTexture != null) {
			newStandardMaterial.specularTexture = this.specularTexture.clone();
		}
		if (this.bumpTexture != null) {
			newStandardMaterial.bumpTexture = this.bumpTexture.clone();
		}
		if (this.lightmapTexture != null) {
			newStandardMaterial.lightmapTexture = this.lightmapTexture.clone();
			newStandardMaterial.useLightmapAsShadowmap = this.useLightmapAsShadowmap;
		}
		
		newStandardMaterial.ambientColor = this.ambientColor.clone();
		newStandardMaterial.diffuseColor = this.diffuseColor.clone();
		newStandardMaterial.specularColor = this.specularColor.clone();
		newStandardMaterial.specularPower = this.specularPower;
		newStandardMaterial.emissiveColor = this.emissiveColor.clone();
		newStandardMaterial.useAlphaFromDiffuseTexture = this.useAlphaFromDiffuseTexture;
		newStandardMaterial.useEmissiveAsIllumination = this.useEmissiveAsIllumination;
		newStandardMaterial.useGlossinessFromSpecularMapAlpha = this.useGlossinessFromSpecularMapAlpha;
		newStandardMaterial.useReflectionFresnelFromSpecular = this.useReflectionFresnelFromSpecular;
		newStandardMaterial.useSpecularOverAlpha = this.useSpecularOverAlpha;
		newStandardMaterial.roughness = this.roughness;
		
		if (this.diffuseFresnelParameters != null) {
			newStandardMaterial.diffuseFresnelParameters = this.diffuseFresnelParameters.clone();
		}
		if (this.emissiveFresnelParameters != null) {
			newStandardMaterial.emissiveFresnelParameters = this.emissiveFresnelParameters.clone();
		}
		if (this.reflectionFresnelParameters != null) {
			newStandardMaterial.reflectionFresnelParameters = this.reflectionFresnelParameters.clone();
		}
		if (this.opacityFresnelParameters != null) {
			newStandardMaterial.opacityFresnelParameters = this.opacityFresnelParameters.clone();
		}
		
		return newStandardMaterial;
	}

}
