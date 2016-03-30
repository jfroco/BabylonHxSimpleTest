package com.babylonhx.postprocess;

import com.babylonhx.cameras.Camera;
import com.babylonhx.materials.Effect;

/**
 * ...
 * @author Krtolica Vujadin
 */

@:enum 
abstract TonemappingOperator(Int) {
    var Hable = 0;
    var Reinhard = 1;
    var HejiDawson = 2;
    var Photographic = 3;
}
 
class TonemapPostProcess extends PostProcess {

	private var _operator:TonemappingOperator;
	private var _exposureAdjustment:Float;

	
	public function new(name:String, operator:TonemappingOperator, exposureAdjustment:Float, camera:Camera, samplingMode:Int = Texture.BILINEAR_SAMPLINGMODE, ?engine:Engine, textureFormat:Int = Engine.TEXTURETYPE_UNSIGNED_INT) {
		this._operator = operator;
		this._exposureAdjustment = exposureAdjustment;
		
		var params:Array<String> = ["_ExposureAdjustment"];
		var defines:String = "#define ";

		if (operator == TonemappingOperator.Hable) {
			defines += "HABLE_TONEMAPPING";
		}
		else if (operator == TonemappingOperator.Reinhard) {
			defines += "REINHARD_TONEMAPPING";
		}
		else if (operator == TonemappingOperator.HejiDawson) {
			defines += "OPTIMIZED_HEJIDAWSON_TONEMAPPING";
		}
		else if (operator == TonemappingOperator.Photographic) {
			defines += "PHOTOGRAPHIC_TONEMAPPING";
		}
		
		super(name, "tonemap", params, null, 1.0, camera, samplingMode, engine, true, defines, textureFormat);
		
		this.onApply = function(effect:Effect) {
			effect.setFloat("_ExposureAdjustment", this._exposureAdjustment);
		};
	}
	
}
