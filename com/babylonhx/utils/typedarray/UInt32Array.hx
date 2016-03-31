package com.babylonhx.utils.typedarray;

/**
 * @author Krtolica Vujadin
 */

#if purejs

	typedef UInt32Array = js.html.UInt32Array;

#elseif snow
 
	typedef UInt32Array = snow.api.buffers.UInt32Array;
	
#elseif openfl

	typedef UInt32Array = openfl.utils.UInt32Array;
	
#elseif lime

	typedef UInt32Array = lime.utils.UInt32Array;	
	
#elseif nme

	typedef UInt32Array = nme.utils.UInt32Array;

#elseif kha



#end
