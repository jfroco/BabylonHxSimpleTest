package;

import lime.app.Application;
import lime.Assets;
import lime.ui.KeyCode;
import lime.ui.KeyModifier;
import lime.graphics.RenderContext;
import lime.ui.Touch;
import lime.ui.Window;

import com.babylonhx.Engine;
import com.babylonhx.Scene;

import com.babylonhx.cameras.FreeCamera;
import com.babylonhx.lights.HemisphericLight;
import com.babylonhx.materials.StandardMaterial;
import com.babylonhx.materials.textures.Texture;
import com.babylonhx.layer.Layer;
import com.babylonhx.math.Color3;
import com.babylonhx.math.Vector3;
import com.babylonhx.mesh.Mesh;


/**
 * ...
 * @author jfroco
 */

class MainLime extends Application {
	
	var scene:Scene;
	var engine:Engine;
	
	
	public function new() {
		super();
	}
		
	public override function onWindowCreate(window:Window):Void {
		engine = new Engine(window, false);	
		scene = new Scene(engine);

		var camera = new FreeCamera("camera1", new Vector3(0, 1, -10), scene);
        camera.setTarget(Vector3.Zero());
        camera.attachControl();

        var background = new Layer("background", "assets/fondo.png", scene, true);

		var light = new HemisphericLight("light1", new Vector3(0, 1, 0), scene);
        light.diffuse = new Color3(1, 1, 1);
        light.groundColor = new Color3(0.3, 0.3, 0.3);
        light.specular = new Color3(1, 1, 1);


        var texture_wood = new StandardMaterial("texture_wood", scene);
        texture_wood.diffuseTexture = new Texture("assets/wood.jpg", scene);

        var sphere = Mesh.CreateSphere("sphere1", 16, 1, scene);
        sphere.position.y = 1;
        sphere.material = texture_wood;

        var texture_ground = new StandardMaterial("texture_ground", scene);
        texture_ground.diffuseColor = new Color3(0.8, 0.2, 0.2); 
        var ground = Mesh.CreateGround("ground1", 6, 6, 2, scene);
        ground.material = texture_ground;
        
        scene.getEngine().runRenderLoop(function () {
            scene.render();
        });

				
		engine.width = this.window.width;
		engine.height = this.window.height;
	}
	
	override function onMouseDown(window:Window, x:Float, y:Float, button:Int) {
		for(f in Engine.mouseDown) {
			f(x, y, button);
		}
	}
	
	override function onMouseUp(window:Window, x:Float, y:Float, button:Int) {
		for(f in Engine.mouseUp) {
			f();
		}
	}
	
	override function onMouseMove(window:Window, x:Float, y:Float) {
		for(f in Engine.mouseMove) {
			f(x, y);
		}
	}
	
	override function onMouseWheel(window:Window, deltaX:Float, deltaY:Float) {
		for (f in Engine.mouseWheel) {
			f(deltaY / 2);
		}
	}
	
	override function onTouchStart(touch:Touch) {
		for (f in Engine.touchDown) {
			f(touch.x, touch.y, touch.id);
		}
	}
	
	override function onTouchEnd(touch:Touch) {
		for (f in Engine.touchUp) {
			f(touch.x, touch.y, touch.id);
		}
	}
	
	override function onTouchMove(touch:Touch) {
		for (f in Engine.touchMove) {
			f(touch.x, touch.y, touch.id);
		}
	}

	override function onKeyUp(window:Window, keycode:Int, modifier:KeyModifier) {
		for(f in Engine.keyUp) {
			f(keycode);
		}
	}
	
	override function onKeyDown(window:Window, keycode:Int, modifier:KeyModifier) {
		for(f in Engine.keyDown) {
			f(keycode);
		}
	}
	
	override public function onWindowResize(window:Window, width:Int, height:Int) {
		engine.width = this.window.width;
		engine.height = this.window.height;
	}
	
	override function update(deltaTime:Int) {
		if(engine != null) {
			engine._renderLoop();		
		}
	}
	
}
