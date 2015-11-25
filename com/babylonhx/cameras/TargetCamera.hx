package com.babylonhx.cameras;

import com.babylonhx.math.Matrix;
import com.babylonhx.math.Vector2;
import com.babylonhx.math.Vector3;
import com.babylonhx.tools.Tools;

/**
* ...
* @author Krtolica Vujadin
*/

@:expose('BABYLON.TargetCamera') class TargetCamera extends Camera {

	public var cameraDirection:Vector3 = new Vector3(0, 0, 0);
	public var cameraRotation:Vector2 = new Vector2(0, 0);
	public var rotation:Vector3 = new Vector3(0, 0, 0);

	public var speed:Float = 2.0;
	public var noRotationConstraint:Bool = false;
	public var lockedTarget:Dynamic = null;

	public var _currentTarget:Vector3 = Vector3.Zero();
	public var _viewMatrix:Matrix = Matrix.Zero();
	public var _camMatrix:Matrix = Matrix.Zero();
	public var _cameraTransformMatrix:Matrix = Matrix.Zero();
	public var _cameraRotationMatrix:Matrix = Matrix.Zero();
	private var _rigCamTransformMatrix:Matrix;
	
	public var _referencePoint:Vector3 = new Vector3(0, 0, 1);
	public var _transformedReferencePoint:Vector3 = Vector3.Zero();
	public var _lookAtTemp:Matrix = Matrix.Zero();
	public var _tempMatrix:Matrix = Matrix.Zero();

	public var _reset:Void->Void;

	public var _waitingLockedTargetId:String;
	

	public function new(name:String, position:Vector3, scene:Scene) {
		super(name, position, scene);
	}
	
	inline public function getFrontPosition(distance:Float):Vector3 {
		var direction = this.getTarget().subtract(this.position);
		direction.normalize();
		direction.scaleInPlace(distance);
		
		return this.globalPosition.add(direction);
	}

	public function _getLockedTargetPosition():Vector3 {
		if (this.lockedTarget == null) {
			return null;
		}
		
		return this.lockedTarget.position != null ? this.lockedTarget.position : this.lockedTarget;
	}

	// Cache
	override public function _initCache() {
		super._initCache();
		this._cache.lockedTarget = new Vector3(Math.POSITIVE_INFINITY, Math.POSITIVE_INFINITY, Math.POSITIVE_INFINITY);
		this._cache.rotation = new Vector3(Math.POSITIVE_INFINITY, Math.POSITIVE_INFINITY, Math.POSITIVE_INFINITY);
	}

	override public function _updateCache(ignoreParentClass:Bool = false):Void {
		if (!ignoreParentClass) {
			super._updateCache();
		}
		
		var lockedTargetPosition = this._getLockedTargetPosition();
		if (lockedTargetPosition == null) {
			this._cache.lockedTarget = null;
		}
		else {
			if (this._cache.lockedTarget == null) {
				this._cache.lockedTarget = lockedTargetPosition.clone();
			}
			else {
				this._cache.lockedTarget.copyFrom(lockedTargetPosition);
			}
		}
		
		this._cache.rotation.copyFrom(this.rotation);
	}

	// Synchronized
	override public function _isSynchronizedViewMatrix():Bool {
		if (!super._isSynchronizedViewMatrix()) {
			return false;
		}
		
		var lockedTargetPosition:Vector3 = this._getLockedTargetPosition();
		
		return (this._cache.lockedTarget != null ? this._cache.lockedTarget.equals(lockedTargetPosition) : lockedTargetPosition == null)
			&& this._cache.rotation.equals(this.rotation);
	}

	// Methods
	inline public function _computeLocalCameraSpeed():Float {
		var engine = this.getEngine();
		return this.speed * ((engine.getDeltaTime() / (engine.getFps() * 10.0)));
	}

	// Target
	static var zUpVector:Vector3 = new Vector3(0, 1.0, 0);
	static var vDir:Vector3 = Vector3.Zero();
	inline public function setTarget(target:Vector3) {
		this.upVector.normalize();
		
		Matrix.LookAtLHToRef(this.position, target, this.upVector, this._camMatrix);
		this._camMatrix.invert();
		
		this.rotation.x = Math.atan(this._camMatrix.m[6] / this._camMatrix.m[10]);
		
		vDir = target.subtract(this.position);
		
		if (vDir.x >= 0.0) {
			this.rotation.y = (-Math.atan(vDir.z / vDir.x) + Math.PI / 2.0);
		} 
		else {
			this.rotation.y = (-Math.atan(vDir.z / vDir.x) - Math.PI / 2.0);
		}
		
		this.rotation.z = -Math.acos(Vector3.Dot(zUpVector, this.upVector));
		
		/*if (Math.isNaN(this.rotation.x)) {
			this.rotation.x = 0;
		}
		
		if (Math.isNaN(this.rotation.y)) {
			this.rotation.y = 0;
		}
		
		if (Math.isNaN(this.rotation.z)) {
			this.rotation.z = 0;
		}*/
	}

	public function getTarget():Vector3 {
		return this._currentTarget;
	}

	public function _decideIfNeedsToMove():Bool {
		return Math.abs(this.cameraDirection.x) > 0 || Math.abs(this.cameraDirection.y) > 0 || Math.abs(this.cameraDirection.z) > 0;
	}

	public function _updatePosition() {
		this.position.addInPlace(this.cameraDirection);
	}
	
	override public function _checkInputs() {
		var needToMove = this._decideIfNeedsToMove();
		var needToRotate = Math.abs(this.cameraRotation.x) > 0 || Math.abs(this.cameraRotation.y) > 0;
		
		// Move
		if (needToMove) {
			this._updatePosition();
		}
		
		// Rotate
		if (needToRotate) {
			this.rotation.x += this.cameraRotation.x;
			this.rotation.y += this.cameraRotation.y;
			
			if (!this.noRotationConstraint) {
				var limit = (Math.PI / 2) * 0.95;
				if (this.rotation.x > limit) {
					this.rotation.x = limit;
				}
				if (this.rotation.x < -limit) {
					this.rotation.x = -limit;
				}
			}
		}
		
		// Inertia
		if (needToMove) {
			if (Math.abs(this.cameraDirection.x) < Engine.Epsilon) {
				this.cameraDirection.x = 0;
			}
			
			if (Math.abs(this.cameraDirection.y) < Engine.Epsilon) {
				this.cameraDirection.y = 0;
			}
			
			if (Math.abs(this.cameraDirection.z) < Engine.Epsilon) {
				this.cameraDirection.z = 0;
			}
			
			this.cameraDirection.scaleInPlace(this.inertia);
		}
		if (needToRotate) {
			if (Math.abs(this.cameraRotation.x) < Engine.Epsilon) {
				this.cameraRotation.x = 0;
			}
			
			if (Math.abs(this.cameraRotation.y) < Engine.Epsilon) {
				this.cameraRotation.y = 0;
			}
			this.cameraRotation.scaleInPlace(this.inertia);
		}
		
		super._checkInputs();
	}
	
	override public function _getViewMatrix_default():Matrix {
		if (this.lockedTarget == null) {
			// Compute
			if (this.upVector.x != 0 || this.upVector.y != 1.0 || this.upVector.z != 0) {
				Matrix.LookAtLHToRef(Vector3.Zero(), this._referencePoint, this.upVector, this._lookAtTemp);
				Matrix.RotationYawPitchRollToRef(this.rotation.y, this.rotation.x, this.rotation.z, this._cameraRotationMatrix);
				
				this._lookAtTemp.multiplyToRef(this._cameraRotationMatrix, this._tempMatrix);
				this._lookAtTemp.invert();
				this._tempMatrix.multiplyToRef(this._lookAtTemp, this._cameraRotationMatrix);
			} 
			else {
				Matrix.RotationYawPitchRollToRef(this.rotation.y, this.rotation.x, this.rotation.z, this._cameraRotationMatrix);
			}
			
			Vector3.TransformCoordinatesToRef(this._referencePoint, this._cameraRotationMatrix, this._transformedReferencePoint);
			
			// Computing target and final matrix
			this.position.addToRef(this._transformedReferencePoint, this._currentTarget);
		} 
		else {
			this._currentTarget.copyFrom(this._getLockedTargetPosition());
		}
		
		Matrix.LookAtLHToRef(this.position, this._currentTarget, this.upVector, this._viewMatrix);
		return this._viewMatrix;
	}
	
	public function _getVRViewMatrix():Matrix {
		Matrix.RotationYawPitchRollToRef(this.rotation.y, this.rotation.x, this.rotation.z, this._cameraRotationMatrix);
		
		Vector3.TransformCoordinatesToRef(this._referencePoint, this._cameraRotationMatrix, this._transformedReferencePoint);
		Vector3.TransformNormalToRef(this.upVector, this._cameraRotationMatrix, this._cameraRigParams.vrActualUp);
		
		// Computing target and final matrix
		this.position.addToRef(this._transformedReferencePoint, this._currentTarget);
		
		Matrix.LookAtLHToRef(this.position, this._currentTarget, this._cameraRigParams.vrActualUp, this._cameraRigParams.vrWorkMatrix);
		
		this._cameraRigParams.vrWorkMatrix.multiplyToRef(this._cameraRigParams.vrPreViewMatrix, this._viewMatrix);
		return this._viewMatrix;
	}
	
	/**
	 * @override
	 * Override Camera.createRigCamera
	 */
	override public function createRigCamera(name:String, cameraIndex:Int):Camera {
		if (this.cameraRigMode != Camera.RIG_MODE_NONE) {
			var rigCamera = new TargetCamera(name, this.position.clone(), this.getScene());
			if (this.cameraRigMode == Camera.RIG_MODE_VR) {
				rigCamera._cameraRigParams = { };
				rigCamera._cameraRigParams.vrActualUp = new Vector3(0, 0, 0);
				rigCamera._getViewMatrix = rigCamera._getVRViewMatrix;
			}
			
			return rigCamera;
		}
		
		return null;
	}
	
	/**
	 * @override
	 * Override Camera._updateRigCameras
	 */
	override public function _updateRigCameras() {
		switch (this.cameraRigMode) {
			case Camera.RIG_MODE_STEREOSCOPIC_ANAGLYPH,
				 Camera.RIG_MODE_STEREOSCOPIC_SIDEBYSIDE_PARALLEL,
				 Camera.RIG_MODE_STEREOSCOPIC_SIDEBYSIDE_CROSSEYED,
				 Camera.RIG_MODE_STEREOSCOPIC_OVERUNDER,
				 Camera.RIG_MODE_VR:
				var camLeft:TargetCamera = cast this._rigCameras[0];
				var camRight:TargetCamera = cast this._rigCameras[1];
				
				if (this.cameraRigMode == Camera.RIG_MODE_VR) {
					camLeft.rotation.x = camRight.rotation.x = this.rotation.x;
					camLeft.rotation.y = camRight.rotation.y = this.rotation.y;
					camLeft.rotation.z = camRight.rotation.z = this.rotation.z;
					
					camLeft.position.copyFrom(this.position);
					camRight.position.copyFrom(this.position);
				} 
				else {
					//provisionnaly using _cameraRigParams.stereoHalfAngle instead of calculations based on _cameraRigParams.interaxialDistance:
					this._getRigCamPosition(-this._cameraRigParams.stereoHalfAngle, camLeft.position);
					this._getRigCamPosition(this._cameraRigParams.stereoHalfAngle, camRight.position);
					
					camLeft.setTarget(this.getTarget());
					camRight.setTarget(this.getTarget());
				}
		}
		
		super._updateRigCameras();
	}

	private function _getRigCamPosition(halfSpace:Float, result:Vector3) {
		if (this._rigCamTransformMatrix == null) {
			this._rigCamTransformMatrix = new Matrix();
		}
		var target = this.getTarget();
		Matrix.Translation( -target.x, -target.y, -target.z).multiplyToRef(Matrix.RotationY(halfSpace), this._rigCamTransformMatrix);
		
		this._rigCamTransformMatrix = this._rigCamTransformMatrix.multiply(Matrix.Translation(target.x, target.y, target.z));
		
		Vector3.TransformCoordinatesToRef(this.position, this._rigCamTransformMatrix, result);
	}
	
}
