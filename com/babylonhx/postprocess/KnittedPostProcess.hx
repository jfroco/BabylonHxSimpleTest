package com.babylonhx.postprocess;

import com.babylonhx.cameras.Camera;
import com.babylonhx.materials.Effect;
import com.babylonhx.math.Vector2;
import com.babylonhx.materials.ShadersStore;

/**
 * ...
 * @author Krtolica Vujadin
 */
@:expose('BABYLON.KnittedPostProcess') class KnittedPostProcess extends PostProcess {

	// https://www.shadertoy.com/view/4ts3zM
	public static var fragmentShader:String = "#ifdef GL_ES\nprecision highp float;\n#endif\n varying vec2 vUV; uniform sampler2D textureSampler; uniform vec2 screenSize; uniform vec2 tileSize; uniform float threads; void main(void) { vec2 posInTile = mod(vec2(gl_FragCoord), tileSize); vec2 tileNum = floor(vec2(gl_FragCoord) / tileSize); vec2 nrmPosInTile = posInTile / tileSize; tileNum.y += floor(abs(nrmPosInTile.x - 0.5) + nrmPosInTile.y); vec2 texCoord = tileNum * tileSize / screenSize.xy; vec3 color = texture2D(textureSampler, texCoord).rgb; color *= fract((nrmPosInTile.y + abs(nrmPosInTile.x - 0.5)) * floor(threads)); gl_FragColor = vec4(color, 1.0); }";
	
	public var screenSize:Vector2 = new Vector2(1, 1);
	public var tileSize:Vector2 = new Vector2(12, 16);
	public var threads:Float = 4.0;
	

	public function new(name:String, ratio:Float, camera:Camera, ?samplingMode:Int, ?engine:Engine, reusable:Bool = false) {
		if (!ShadersStore.Shaders.exists("knitted.fragment")) {			
			ShadersStore.Shaders.set("knitted.fragment", fragmentShader);
		}
		
		super(name, "knitted", ["screenSize", "tileSize", "threads"], null, ratio, camera, samplingMode, engine, reusable);
		
		this.onSizeChanged = function() {
			this.screenSize.x = camera.getScene().getEngine().getRenderWidth();
			this.screenSize.y = camera.getScene().getEngine().getRenderHeight();
		};
		
		this.onApply = function(effect:Effect) {
			effect.setVector2("screenSize", this.screenSize);
			effect.setVector2("tileSize", this.tileSize);
			effect.setFloat("threads", this.threads);
		};
		
		this.onSizeChanged();
	}
	
}
