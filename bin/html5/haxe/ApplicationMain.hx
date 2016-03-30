import BasicScene;
import lime.Assets;


@:access(lime.app.Application)


class ApplicationMain {
	
	
	public static var config:lime.app.Config;
	public static var preloader:lime.app.Preloader;
	
	private static var app:lime.app.Application;
	
	
	public static function create ():Void {
		
		preloader = new lime.app.Preloader ();
		
		#if !munit
		app = new BasicScene ();
		app.setPreloader (preloader);
		app.create (config);
		#end
		
		preloader.onComplete.add (start);
		preloader.create (config);
		
		#if (js && html5)
		var urls = [];
		var types = [];
		
		
		urls.push ("assets/img/flare.png");
		types.push (AssetType.IMAGE);
		
		
		urls.push ("assets/img/lens4.png");
		types.push (AssetType.IMAGE);
		
		
		urls.push ("assets/img/lens5.png");
		types.push (AssetType.IMAGE);
		
		
		urls.push ("assets/img/skybox/skybox_nx.jpg");
		types.push (AssetType.IMAGE);
		
		
		urls.push ("assets/img/skybox/skybox_ny.jpg");
		types.push (AssetType.IMAGE);
		
		
		urls.push ("assets/img/skybox/skybox_nz.jpg");
		types.push (AssetType.IMAGE);
		
		
		urls.push ("assets/img/skybox/skybox_px.jpg");
		types.push (AssetType.IMAGE);
		
		
		urls.push ("assets/img/skybox/skybox_py.jpg");
		types.push (AssetType.IMAGE);
		
		
		urls.push ("assets/img/skybox/skybox_pz.jpg");
		types.push (AssetType.IMAGE);
		
		
		urls.push ("assets/skybox/Sky_FantasySky_Fire_Cam_px.jpg");
		types.push (AssetType.IMAGE);
		
		
		
		if (config.assetsPrefix != null) {
			
			for (i in 0...urls.length) {
				
				if (types[i] != AssetType.FONT) {
					
					urls[i] = config.assetsPrefix + urls[i];
					
				}
				
			}
			
		}
		
		preloader.load (urls, types);
		#end
		
	}
	
	
	public static function main () {
		
		config = {
			
			build: "13",
			company: "Mingga Labs",
			file: "BabylonHx_Lime",
			fps: 60,
			name: "BabylonHx Example",
			orientation: "",
			packageName: "com.minggalabs.babylonhx.example",
			version: "1.0.0",
			windows: [
				
				{
					antialiasing: 0,
					background: 16777215,
					borderless: false,
					depthBuffer: true,
					display: 0,
					fullscreen: false,
					hardware: true,
					height: 0,
					parameters: "{}",
					resizable: true,
					stencilBuffer: true,
					title: "BabylonHx Example",
					vsync: false,
					width: 0,
					x: null,
					y: null
				},
			]
			
		};
		
		#if (!html5 || munit)
		create ();
		#end
		
	}
	
	
	public static function start ():Void {
		
		#if !munit
		
		var result = app.exec ();
		
		#if (sys && !nodejs && !emscripten)
		Sys.exit (result);
		#end
		
		#else
		
		new BasicScene ();
		
		#end
		
	}
	
	
	#if neko
	@:noCompletion @:dox(hide) public static function __init__ () {
		
		var loader = new neko.vm.Loader (untyped $loader);
		loader.addPath (haxe.io.Path.directory (Sys.executablePath ()));
		loader.addPath ("./");
		loader.addPath ("@executable_path/");
		
	}
	#end
	
	
}
