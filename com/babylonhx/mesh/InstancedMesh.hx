package com.babylonhx.mesh;

import com.babylonhx.cameras.Camera;
import com.babylonhx.Node;
import com.babylonhx.math.Vector3;
import com.babylonhx.bones.Skeleton;
import com.babylonhx.materials.Material;
import com.babylonhx.culling.BoundingInfo;
import com.babylonhx.culling.BoundingSphere;
import com.babylonhx.tools.Tools;
import com.babylonhx.animations.IAnimatable;


/**
 * ...
 * @author Krtolica Vujadin
 */

/**
 * Creates an instance based on a source mesh.
 */
@:expose('BABYLON.InstancedMesh') class InstancedMesh extends AbstractMesh implements IAnimatable {
	
	private var _sourceMesh:Mesh;
	private var _currentLOD:Mesh;
	

	public function new(name:String, source:Mesh) {
		super(name, source.getScene());
		
		source.instances.push(this);
		
		this._sourceMesh = source;
		
		this.position.copyFrom(source.position);
		this.rotation.copyFrom(source.rotation);
		this.scaling.copyFrom(source.scaling);
		
		if (source.rotationQuaternion != null) {
			this.rotationQuaternion = source.rotationQuaternion.clone();
		}
		
		this.infiniteDistance = source.infiniteDistance;
		
		this.setPivotMatrix(source.getPivotMatrix());
		
		this.refreshBoundingInfo();
		this._syncSubMeshes();
	}

	// Methods
	override private function get_receiveShadows():Bool {
		return this._sourceMesh.receiveShadows;
	}

	override private function get_material():Material {
		return this._sourceMesh.material;
	}

	override private function get_visibility():Float {
		return this._sourceMesh.visibility;
	}

	override private function get_skeleton():Skeleton {
		return this._sourceMesh.skeleton;
	}

	override public function getTotalVertices():Int {
		return this._sourceMesh.getTotalVertices();
	}

	public var sourceMesh(get, null):Mesh;
	private function get_sourceMesh():Mesh {
		return this._sourceMesh;
	}

	override public function getVerticesData(kind:String, copyWhenShared:Bool = false):Array<Float> {
		return this._sourceMesh.getVerticesData(kind, copyWhenShared);
	}

	override public function isVerticesDataPresent(kind:String):Bool {
		return this._sourceMesh.isVerticesDataPresent(kind);
	}

	override public function getIndices(copyWhenShared:Bool = false):Array<Int> {
		return this._sourceMesh.getIndices(copyWhenShared);
	}

	override private function get_positions():Array<Vector3> {
		return this._sourceMesh._positions;
	}

	inline public function refreshBoundingInfo() {
		var meshBB = this._sourceMesh.getBoundingInfo();
		
		this._boundingInfo = new BoundingInfo(meshBB.minimum.clone(), meshBB.maximum.clone());
		
		this._updateBoundingInfo();
	}

	override public function _preActivate() {
		if (this._currentLOD != null) {
			this._currentLOD._preActivate();
		}
	}
	
	override public function _activate(renderId:Int) {
		if (this._currentLOD != null) {
			this.sourceMesh._registerInstanceForRenderId(this, renderId);
		}
	}
	
	override public function getLOD(camera:Camera, ?boundingSphere:BoundingSphere):AbstractMesh {
		this._currentLOD = cast this.sourceMesh.getLOD(this.getScene().activeCamera, this.getBoundingInfo().boundingSphere);
		
		if (this._currentLOD == this.sourceMesh) {
            return this;
        }
		
		return this._currentLOD;
	}

	inline public function _syncSubMeshes() {
		this.releaseSubMeshes();
		if(this._sourceMesh.subMeshes != null) {
			for (index in 0...this._sourceMesh.subMeshes.length) {
				this._sourceMesh.subMeshes[index].clone(this, this._sourceMesh);
			}
		}
	}

	override public function _generatePointsArray():Bool {
		return this._sourceMesh._generatePointsArray();
	}

	// Clone
	override public function clone(name:String, newParent:Node = null, doNotCloneChildren:Bool = false):InstancedMesh {
		var result = this._sourceMesh.createInstance(name);
		
		// TODO: Deep copy
		//Tools.DeepCopy(this, result, ["name"], []);
		
		// Bounding info
		this.refreshBoundingInfo();
		
		// Parent
		if (newParent != null) {
			result.parent = newParent;
		}
		
		if (!doNotCloneChildren) {
			// Children
			for (index in 0...this.getScene().meshes.length) {
				var mesh = this.getScene().meshes[index];
				
				if (mesh.parent == this) {
					mesh.clone(mesh.name, result);
				}
			}
		}
		
		result.computeWorldMatrix(true);
		
		return result;
	}

	// Dispose
	override public function dispose(doNotRecurse:Bool = false) {
		// Remove from mesh
		this._sourceMesh.instances.remove(this);
		
		super.dispose(doNotRecurse);
	}
	
}
