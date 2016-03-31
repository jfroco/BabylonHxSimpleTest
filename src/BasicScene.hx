package;

import com.babylonhx.*;
import com.babylonhx.cameras.*;
import com.babylonhx.lights.*;
import com.babylonhx.lensflare.*;
import com.babylonhx.materials.*;
import com.babylonhx.materials.textures.*;
import com.babylonhx.math.*;
import com.babylonhx.mesh.*;
import lime.app.*;
import lime.ui.*;




/**
 * ...
 * @author jfroco
 */

class BasicScene extends Application {
	
	var scene:Scene;
	var engine:Engine;
	
	
	public function new() {
		super();
	}
		
	public override function onWindowCreate(window:Window):Void {
		engine = new Engine(window, false);	
		scene = new Scene(engine);
		engine.width = this.window.width;
		engine.height = this.window.height;
		initGame();
		addKeys();
	}
	
	function addKeys()
	{
		
	}
	
	function initGame()
	{
		var light0 = new PointLight("Omni", new Vector3(10, 50, 50), scene);
        
        var camera = new ArcRotateCamera("Camera", 0.4, 1.2, 20, new Vector3(-10, 0, 0), scene);
        camera.attachControl(this, true);
        
        var material1 = new StandardMaterial("mat1", scene);
        material1.diffuseColor = new Color3(1, 1, 0);
        
        for (i in 0...10) {
            var box = Mesh.CreateBox("Box", 1.0, scene);
            box.material = material1;
            box.position = new Vector3(-i * 5, 0, 0);
        }
        
        // Fog
        scene.fogMode = Scene.FOGMODE_EXP;
        //Scene.FOGMODE_NONE;
        //Scene.FOGMODE_EXP;
        //Scene.FOGMODE_EXP2;
        //Scene.FOGMODE_LINEAR;
        
        scene.fogColor = new Color3(0.9, 0.9, 0.85);
        scene.fogDensity = 0.01;
        
        //Only if LINEAR
        //scene.fogStart = 20.0;
        //scene.fogEnd = 60.0;
		
		// Creating light sphere
        var lightSphere0 = Mesh.CreateSphere("Sphere0", 16, 0.5, scene);
        
        lightSphere0.material = new StandardMaterial("white", scene);
        cast(lightSphere0.material, StandardMaterial).diffuseColor = new Color3(0, 0, 0);
        cast(lightSphere0.material, StandardMaterial).specularColor = new Color3(0, 0, 0);
        cast(lightSphere0.material, StandardMaterial).emissiveColor = new Color3(1, 1, 1);
        
        lightSphere0.position = light0.position;
        
        var lensFlareSystem = new LensFlareSystem("lensFlareSystem", light0, scene);
        var flare00 = new LensFlare(0.2, 0, new Color3(1, 1, 1), "assets/img/lens5.png", lensFlareSystem);
        var flare01 = new LensFlare(0.5, 0.2, new Color3(0.5, 0.5, 1), "assets/img/lens4.png", lensFlareSystem);
        var flare02 = new LensFlare(0.2, 1.0, new Color3(1, 1, 1), "assets/img/lens4.png", lensFlareSystem);
        var flare03 = new LensFlare(0.4, 0.4, new Color3(1, 0.5, 1), "assets/img/flare.png", lensFlareSystem);
        var flare04 = new LensFlare(0.1, 0.6, new Color3(1, 1, 1), "assets/img/lens5.png", lensFlareSystem);
        var flare05 = new LensFlare(0.3, 0.8, new Color3(1, 1, 1), "assets/img/lens4.png", lensFlareSystem);
        
        // Skybox
        var skybox = Mesh.CreateBox("skyBox", 100.0, scene);
        var skyboxMaterial = new StandardMaterial("skyBox", scene);
        skyboxMaterial.backFaceCulling = false;
        skyboxMaterial.reflectionTexture = new CubeTexture("assets/img/skybox/skybox", scene);
        skyboxMaterial.reflectionTexture.coordinatesMode = Texture.SKYBOX_MODE;
        skyboxMaterial.diffuseColor = new Color3(0, 0, 0);
        skyboxMaterial.specularColor = new Color3(0, 0, 0);
        skybox.material = skyboxMaterial;
        
        var alpha = 0.0;
        scene.registerBeforeRender(function () {
            scene.fogDensity = Math.cos(alpha) / 10;
            alpha += 0.02;
        });
        
        scene.getEngine().runRenderLoop(function () {
            scene.render();
        });
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
