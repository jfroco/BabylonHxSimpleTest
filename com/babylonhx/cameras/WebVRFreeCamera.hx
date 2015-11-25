package com.babylonhx.cameras;

import com.babylonhx.math.Matrix;
import com.babylonhx.math.Vector3;
import com.babylonhx.math.Quaternion;
import com.babylonhx.cameras.VRCameraMetrics;


//declare var HMDVRDevice;
//declare var PositionSensorVRDevice;

@:expose('BABYLON.WebVRFreeCamera') class WebVRFreeCamera extends FreeCamera {
	
	public var _hmdDevice:Dynamic = null;
	public var _sensorDevice:Dynamic = null;
	public var _cacheState:Dynamic = null;
	public var _cacheQuaternion:Quaternion = new Quaternion();
	public var _cacheRotation:Vector3 = Vector3.Zero();
	public var _vrEnabled:Bool = false;
	
	
	public function new(name:String, position:Vector3, scene:Scene, compensateDistortion:Bool = true) {
		super(name, position, scene);            
		
		var metrics = VRCameraMetrics.GetDefault();
		metrics.compensateDistortion = compensateDistortion;
		this.setCameraRigMode(Camera.RIG_MODE_VR, { vrCameraMetrics: metrics });
	}
	
	private function _getWebVRDevices(devices:Array<Dynamic>) {
		var size = devices.length;
		var i = 0;
		
		// Reset devices.
		this._sensorDevice = null;
		this._hmdDevice = null;
		
		// Search for a HmdDevice.
		while (i < size && this._hmdDevice == null) {
			if (Type.getClassName(Type.getClass(devices[i])) == 'HMDVRDevice') {
				this._hmdDevice = devices[i];
			}
			i++;
		}
		
		i = 0;
		
		while (i < size && this._sensorDevice == null) {
			if (Type.getClassName(Type.getClass(devices[i])) == 'PositionSensorVRDevice' && (!this._hmdDevice || devices[i].hardwareUnitId == this._hmdDevice.hardwareUnitId)) {
				this._sensorDevice = devices[i];
			}
			i++;
		}
		
		this._vrEnabled = this._sensorDevice && this._hmdDevice ? true : false;
	}
	
	override public function _checkInputs() {
		if (this._vrEnabled) {
			this._cacheState = this._sensorDevice.getState();
			this._cacheQuaternion.copyFromFloats(this._cacheState.orientation.x, this._cacheState.orientation.y, this._cacheState.orientation.z, this._cacheState.orientation.w);
			this._cacheQuaternion.toEulerAnglesToRef(this._cacheRotation);
			
			this.rotation.x = -this._cacheRotation.z;
			this.rotation.y = -this._cacheRotation.y;
			this.rotation.z = this._cacheRotation.x;
		}
		
		super._checkInputs();
	}
	
	override public function attachControl(?element:Dynamic, noPreventDefault:Bool = false, useCtrlForPanning:Bool = false) {
		super.attachControl(element, noPreventDefault);
		var nav:Dynamic = untyped window.navigator;
		if (nav.getVRDevices) {
			nav.getVRDevices().then(this._getWebVRDevices);
		}
		else if (nav.mozGetVRDevices) {
			nav.mozGetVRDevices(this._getWebVRDevices);
		}
	}
	
	override public function detachControl(?element:Dynamic) {
		super.detachControl(element);
		this._vrEnabled = false;
	}
		
}
