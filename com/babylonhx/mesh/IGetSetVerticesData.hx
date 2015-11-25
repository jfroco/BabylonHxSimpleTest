package com.babylonhx.mesh;

/**
 * @author Krtolica Vujadin
 */

@:expose('BABYLON.IGetSetVerticesData') interface IGetSetVerticesData {
	
	function isVerticesDataPresent(kind:String):Bool;
	function getVerticesData(kind:String, copyWhenShared:Bool = false):Array<Float>;
	function getIndices(copyWhenShared:Bool = false):Array<Int>;
	function setVerticesData(kind:String, data:Array<Float>, updatable:Bool = false, ?stride:Int):Void;
	function updateVerticesData(kind:String, data:Array<Float>, updateExtends:Bool = false, makeItUnique:Bool = false):Void;
	function setIndices(indices:Array<Int>, totalVertices:Int = -1):Void;
	
}
