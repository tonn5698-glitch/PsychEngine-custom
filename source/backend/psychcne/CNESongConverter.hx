package backend.psychcne;

import backend.Song.SwagSong;
import backend.Song.SwagSection;
import haxe.Json;

class CNESongConverter
{
	static function value(data:Dynamic, field:String, fallback:Dynamic):Dynamic
	{
		if (data == null || !Reflect.hasField(data, field)) return fallback;
		var result = Reflect.field(data, field);
		return result == null ? fallback : result;
	}

	static function number(data:Dynamic, field:String, fallback:Float):Float
	{
		var raw = value(data, field, fallback);
		var parsed = Std.parseFloat(Std.string(raw));
		return Math.isNaN(parsed) ? fallback : parsed;
	}

	static function text(data:Dynamic, field:String, fallback:String):String
		return Std.string(value(data, field, fallback));

	static function array(data:Dynamic, field:String):Array<Dynamic>
	{
		var result:Dynamic = value(data, field, []);
		return result == null ? [] : cast result;
	}

	static function eventParam(event:Dynamic, index:Int, fallback:Dynamic = null):Dynamic
	{
		var params = array(event, "params");
		return index >= 0 && index < params.length ? params[index] : fallback;
	}

	static function toBool(value:Dynamic):Bool
	{
		if (value == true) return true;
		var str = Std.string(value).toLowerCase();
		return str == "true" || str == "1";
	}

	static function toPsychEvent(event:Dynamic, scrollSpeed:Float, strumLines:Array<Dynamic>):Array<Dynamic>
	{
		var name = text(event, "name", "");
		var params = array(event, "params");
		if (name == "Camera Movement")
		{
			var lineIndex = Std.int(eventParam(event, 0, 0));
			var lineType = lineIndex >= 0 && lineIndex < strumLines.length
				? Std.int(value(strumLines[lineIndex], "type", 0)) : 0;
			var lineCharacters = lineIndex >= 0 && lineIndex < strumLines.length
				? array(strumLines[lineIndex], "characters") : [];
			var targetCharacter = lineCharacters.length > 0 ? Std.string(lineCharacters[0]) : "";
			var cameraParams = [
				lineType,
				targetCharacter,
				toBool(eventParam(event, 1, true)),
				number({value: eventParam(event, 2, 4)}, "value", 4),
				Std.string(eventParam(event, 3, "CLASSIC")),
				Std.string(eventParam(event, 4, "In")),
				number({value: eventParam(event, 5, 0)}, "value", 0),
				number({value: eventParam(event, 6, 0)}, "value", 0)
			];
			return ["__CNE Camera Movement", Json.stringify(cameraParams), ""];
		}
		if (name == "Camera Position")
		{
			var cameraParams = [
				number({value: eventParam(event, 0, 0)}, "value", 0),
				number({value: eventParam(event, 1, 0)}, "value", 0),
				toBool(eventParam(event, 2, true)),
				number({value: eventParam(event, 3, 4)}, "value", 4),
				Std.string(eventParam(event, 4, "CLASSIC")),
				Std.string(eventParam(event, 5, "In")),
				toBool(eventParam(event, 6, false))
			];
			return ["__CNE Camera Position", Json.stringify(cameraParams), ""];
		}
		if (name == "Alt Animation Toggle" || name == "BPM Change"
			|| name == "Time Signature Change") return null;

		switch (name)
		{
			case "Add Camera Zoom":
				var zoom = eventParam(event, 0, 0);
				var camera = Std.string(eventParam(event, 1, "camGame"));
				return [name, camera == "camGame" ? Std.string(zoom) : "0", camera == "camHUD" ? Std.string(zoom) : "0"];
			case "Play Animation":
				var lineIndex = Std.int(eventParam(event, 0, 0));
				var lineType = lineIndex >= 0 && lineIndex < strumLines.length ? Std.int(value(strumLines[lineIndex], "type", 0)) : 0;
				var character = lineType == 1 ? "bf" : (lineType == 2 ? "gf" : "dad");
				return [name, Std.string(eventParam(event, 1, "")), character];
			case "Scroll Speed Change":
				var tweened = toBool(eventParam(event, 0, false));
				var target = scrollSpeed;
				var rawTarget = eventParam(event, 1, scrollSpeed);
				var parsedTarget = Std.parseFloat(Std.string(rawTarget));
				if (!Math.isNaN(parsedTarget)) target = parsedTarget;
				var duration = tweened ? eventParam(event, 2, 0) : 0;
				return ["Change Scroll Speed", Std.string(FlxMath.roundDecimal(target / (scrollSpeed == 0 ? 1 : scrollSpeed), 2)), Std.string(duration)];
			default:
				// Preserve the complete CNE parameter array for the CNE event-script adapter.
				return [name, Json.stringify(params), ""];
		}
	}

	public static function parse(rawData:String, songName:String, basePath:String):SwagSong
	{
		var chart:Dynamic = Json.parse(rawData);
		if (Reflect.hasField(chart, "song") && Reflect.field(chart, "song") != null) chart = Reflect.field(chart, "song");

		var meta:Dynamic = value(chart, "meta", null);
		#if sys
		if (meta == null)
		{
			var metaPath = basePath + "songs/" + songName + "/meta.json";
			if (sys.FileSystem.exists(metaPath))
				try meta = Json.parse(sys.io.File.getContent(metaPath)) catch (e:Dynamic) trace('[PsychCNE] Meta parse failed: ' + Std.string(e));
		}
		#end

		var bpm = number(meta, "bpm", 100);
		var beatsPerMeasure = number(meta, "beatsPerMeasure", 4);
		if (beatsPerMeasure <= 0) beatsPerMeasure = 4;
		var speed = number(chart, "scrollSpeed", 1);
		var needsVoices = toBool(value(meta, "needsVoices", true));
		var stage = text(chart, "stage", "stage");

		var strumLines = array(chart, "strumLines");
		var noteTypes:Array<String> = [for (noteType in array(chart, "noteTypes")) Std.string(noteType)];
		var player1 = "bf";
		var player2 = "dad";
		var gfVersion = "gf";
		var playerFound = false;
		var opponentFound = false;
		var gfFound = false;
		var keyCount = 4;
		var notes:Array<Dynamic> = [];
		var maxTime:Float = 0;

		for (line in strumLines)
		{
			var lineType = Std.int(value(line, "type", 0));
			var chars = array(line, "characters");
			if (lineType == 1 && !playerFound && chars.length > 0) { player1 = Std.string(chars[0]); playerFound = true; }
			if (lineType == 0 && !opponentFound && chars.length > 0) { player2 = Std.string(chars[0]); opponentFound = true; }
			if (lineType == 2 && !gfFound && chars.length > 0) { gfVersion = Std.string(chars[0]); gfFound = true; }
			var lineKeys = Std.int(value(line, "keyCount", 4));
			if (lineKeys > keyCount) keyCount = lineKeys;

			for (note in array(line, "notes"))
			{
				var time = number(note, "time", 0);
				var id = Std.int(value(note, "id", 0));
				var sustain = number(note, "sLen", 0);
				var typeIndex = Std.int(value(note, "type", 0));
				var noteType = typeIndex > 0 && typeIndex <= noteTypes.length ? noteTypes[typeIndex - 1] : "";
				notes.push({time: time, id: id, sustain: sustain, noteType: noteType, lineType: lineType});
				if (time + sustain > maxTime) maxTime = time + sustain;
			}
		}
		if (keyCount < 4) keyCount = 4;
		if (keyCount > 18) keyCount = 18;
		notes.sort(function(a, b) return Reflect.compare(a.time, b.time));

		var chartEvents = array(chart, "events");
		chartEvents.sort(function(a, b) return Reflect.compare(number(a, "time", 0), number(b, "time", 0)));
		for (event in chartEvents)
		{
			var time = number(event, "time", 0);
			if (time > maxTime) maxTime = time;
		}

		var sections:Array<SwagSection> = [];
		var currentBpm = bpm;
		var currentBeats = beatsPerMeasure;
		var pendingBpm:Null<Float> = null;
		var pendingBeats:Null<Float> = null;
		var sectionStart:Float = 0;
		var noteIndex = 0;
		var eventIndex = 0;
		var loops = 0;
		while (sectionStart <= maxTime || sections.length == 0)
		{
			if (pendingBpm != null) { currentBpm = pendingBpm; pendingBpm = null; }
			if (pendingBeats != null) { currentBeats = pendingBeats; pendingBeats = null; }
			var section:SwagSection = {
				sectionNotes: [],
				sectionBeats: currentBeats,
				mustHitSection: false,
				altAnim: false,
				changeBPM: false,
				bpm: currentBpm
			};

			while (eventIndex < chartEvents.length && number(chartEvents[eventIndex], "time", 0) <= sectionStart + 0.01)
			{
				var event = chartEvents[eventIndex++];
				var name = text(event, "name", "");
				switch (name)
				{
					case "Alt Animation Toggle":
						section.altAnim = toBool(eventParam(event, 0, false)) || toBool(eventParam(event, 1, false));
					case "BPM Change":
						currentBpm = number({value: eventParam(event, 0, currentBpm)}, "value", currentBpm);
						section.bpm = currentBpm;
						section.changeBPM = true;
					case "Time Signature Change":
						currentBeats = number({value: eventParam(event, 0, currentBeats)}, "value", currentBeats);
						section.sectionBeats = currentBeats;
				}
			}
			section.bpm = currentBpm;
			section.sectionBeats = currentBeats;
			var sectionEnd = sectionStart + (60000 / (currentBpm <= 0 ? 100 : currentBpm)) * currentBeats;

			while (eventIndex < chartEvents.length && number(chartEvents[eventIndex], "time", 0) < sectionEnd)
			{
				var event = chartEvents[eventIndex++];
				var name = text(event, "name", "");
				switch (name)
				{
					case "Alt Animation Toggle":
						section.altAnim = toBool(eventParam(event, 0, false)) || toBool(eventParam(event, 1, false));
					case "BPM Change":
						var nextBpm = Std.parseFloat(Std.string(eventParam(event, 0, currentBpm)));
						if (!Math.isNaN(nextBpm) && nextBpm > 0)
						{
							section.changeBPM = true;
							section.bpm = nextBpm;
							pendingBpm = nextBpm;
						}
					case "Time Signature Change":
						var nextBeats = Std.parseFloat(Std.string(eventParam(event, 0, currentBeats)));
						if (!Math.isNaN(nextBeats) && nextBeats > 0)
						{
							section.sectionBeats = nextBeats;
							pendingBeats = nextBeats;
						}
				}
			}

			while (noteIndex < notes.length && notes[noteIndex].time < sectionEnd)
			{
				var note = notes[noteIndex++];
				var data = Std.int(note.id);
				// CNE assigns ownership per strumLine; camera movement never changes note ownership.
				if (note.lineType == 1) data += keyCount;
				section.sectionNotes.push([note.time, data, note.sustain, note.noteType]);
			}
			section.sectionNotes.sort(function(a, b) return Reflect.compare(a[0], b[0]));
			sections.push(section);
			sectionStart = sectionEnd;
			loops++;
			if (loops > 10000) break;
		}

		var convertedEvents:Array<Dynamic> = [];
		for (event in chartEvents)
		{
			var converted = toPsychEvent(event, speed, strumLines);
			if (converted != null) convertedEvents.push([number(event, "time", 0), converted]);
		}
		convertedEvents.sort(function(a, b) return Reflect.compare(a[0], b[0]));
		var groupedEvents:Array<Dynamic> = [];
		for (entry in convertedEvents)
		{
			var last = groupedEvents.length > 0 ? groupedEvents[groupedEvents.length - 1] : null;
			if (last != null && last[0] == entry[0]) last[1].push(entry[1]);
			else groupedEvents.push([entry[0], [entry[1]]]);
		}

		return {
			song: text(meta, "name", songName),
			notes: sections,
			events: groupedEvents,
			bpm: bpm,
			needsVoices: needsVoices,
			speed: speed,
			offset: 0,
			player1: player1,
			player2: player2,
			gfVersion: gfVersion,
			stage: stage,
			format: "psych_v1",
			mania: keyCount > 4 ? keyCount - 1 : 0
		};
	}
}
