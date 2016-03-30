package com.babylonhx.mesh;

/**
 * ...
 * @author Krtolica Vujadin
 */

@:expose('BABYLON._VisibleInstances') class _VisibleInstances {
	
	public var map:Map<Int, Array<InstancedMesh>> = new Map<Int, Array<InstancedMesh>>();
	public var defaultRenderId:Int;
	public var selfDefaultRenderId:Int;
	

	public function new(defaultRenderId:Int, selfDefaultRenderId:Int) {		
		this.defaultRenderId = defaultRenderId;
		this.selfDefaultRenderId = selfDefaultRenderId;
	}
	
}
