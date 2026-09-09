package shaders.flixel.system;

import flixel.system.FlxAssets.FlxShader as OriginalFlxShader;

/**
 * A modded FlxShader that allows using GLSL Es 300 and GLSL 330
 * @author Mihai Alexandru (M.A. Jigsaw)
 */
class FlxShader extends OriginalFlxShader
{
	public var custom:Bool = false;
	public var save:Bool = true;

	public override function new(?save:Bool)
	{
		if (save != null)
			this.save = save;

		super();
	}

	@:noCompletion private override function __initGL():Void
	{
		if (__glSourceDirty || __paramBool == null)
		{
			__glSourceDirty = false;
			program = null;

			__inputBitmapData = new Array();
			__paramBool = new Array();
			__paramFloat = new Array();
			__paramInt = new Array();

			__processGLData(glVertexSource, "attribute");
			__processGLData(glVertexSource, "uniform");
			__processGLData(glFragmentSource, "uniform");
		}

		if (__context != null && program == null)
			initGLforce();
	}

	public function initGLforce()
	{
		if (!custom)
			initGood(glFragmentSource, glVertexSource);
	}

	public function initGood(glFragmentSource:String, glVertexSource:String)
	{
		@:privateAccess
		var gl = __context.gl;

		// Only use GLSL 300 if the shader explicitly declares it.
		// Shaders without a version directive default to GLSL 120 (compatible with most mods).
		var isGLSL300:Bool = glVertexSource.indexOf('#version 300') != -1
			|| glVertexSource.indexOf('#version 330') != -1
			|| glFragmentSource.indexOf('#version 300') != -1
			|| glFragmentSource.indexOf('#version 330') != -1;

		#if lime_opengles
		var prefix:String;
		if (isGLSL300)
			prefix = "#version 300 es\n";
		else
			prefix = "";
		#else
		var prefix:String = "";
		#end

		#if (js && html5)
		prefix += (precisionHint == FULL ? "precision mediump float;\n" : "precision lowp float;\n");
		#else
		prefix += "#ifdef GL_ES\n"
			+ (precisionHint == FULL ? "#ifdef GL_FRAGMENT_PRECISION_HIGH\n"
				+ "precision highp float;\n"
				+ "#else\n"
				+ "precision mediump float;\n"
				+ "#endif\n" : "precision lowp float;\n")
			+ "#endif\n\n";
		#end

		#if lime_opengles
		var vertex:String;
		var fragment:String;
		if (isGLSL300)
		{
			prefix += 'out vec4 output_FragColor;\n';
			vertex = prefix
				+ glVertexSource.replace("attribute", "in")
					.replace("varying", "out")
					.replace("texture2D", "texture")
					.replace("gl_FragColor", "output_FragColor");
			fragment = prefix + glFragmentSource.replace("varying", "in").replace("texture2D", "texture").replace("gl_FragColor", "output_FragColor");
		}
		else
		{
			vertex = prefix + glVertexSource;
			fragment = prefix + glFragmentSource;
		}
		#else
		var vertex = prefix + glVertexSource;
		var fragment = prefix + glFragmentSource;
		#end

		var id = vertex + fragment;

		@:privateAccess
		if (__context.__programs.exists(id) && save)
		{
			@:privateAccess
			program = __context.__programs.get(id);
		}
		else
		{
			program = __context.createProgram(GLSL);

			@:privateAccess
			program.__glProgram = __createGLProgram(vertex, fragment);

			@:privateAccess
			if (save)
				__context.__programs.set(id, program);
		}

		if (program != null)
		{
			@:privateAccess
			glProgram = program.__glProgram;

			for (input in __inputBitmapData)
			{
				@:privateAccess
				if (input.__isUniform)
				{
					@:privateAccess
					input.index = gl.getUniformLocation(glProgram, input.name);
				}
				else
				{
					@:privateAccess
					input.index = gl.getAttribLocation(glProgram, input.name);
				}
			}

			for (parameter in __paramBool)
			{
				@:privateAccess
				if (parameter.__isUniform)
				{
					@:privateAccess
					parameter.index = gl.getUniformLocation(glProgram, parameter.name);
				}
				else
				{
					@:privateAccess
					parameter.index = gl.getAttribLocation(glProgram, parameter.name);
				}
			}

			for (parameter in __paramFloat)
			{
				@:privateAccess
				if (parameter.__isUniform)
				{
					@:privateAccess
					parameter.index = gl.getUniformLocation(glProgram, parameter.name);
				}
				else
				{
					@:privateAccess
					parameter.index = gl.getAttribLocation(glProgram, parameter.name);
				}
			}

			for (parameter in __paramInt)
			{
				@:privateAccess
				if (parameter.__isUniform)
				{
					@:privateAccess
					parameter.index = gl.getUniformLocation(glProgram, parameter.name);
				}
				else
				{
					@:privateAccess
					parameter.index = gl.getAttribLocation(glProgram, parameter.name);
				}
			}
		}
	}
}
