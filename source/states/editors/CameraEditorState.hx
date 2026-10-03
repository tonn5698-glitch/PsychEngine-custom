package states.editors;

import haxe.Json;
import backend.Song;
import backend.StageData;
import objects.Character;
import states.editors.content.FileDialogHandler;
import states.editors.content.PsychJsonPrinter;

class CameraEditorState extends MusicBeatState
{
    static inline var HEADER:Int = 48;
    static inline var TIMELINE:Int = 190;
    static inline var PANEL:Int = 300;
    static inline var DURATION:Float = 250;

    var song:SwagSong;
    var preview:FlxCamera;
    var stage:FlxTypedGroup<FlxSprite>;
    var vcam:FlxSprite;
    var mask:FlxSprite;
    var events:Array<Dynamic> = [];
    var meta:Array<Dynamic> = [];
    var layers:Array<String> = ['Default'];
    var layer:Int = 0;
    var selected:Int = -1;
    var selectedMany:Array<Int> = [];
    var copied:Array<Dynamic> = [];
    var time:Float = 0;
    var timelineZoom:Float = 0.12;
    var timelinePan:Float = 0;
    var snap:Bool = true;
    var playing:Bool = false;
    var relative:Bool = false;
    var extended:Bool = false;
    var pass:Bool = true;
    var passAlpha:Float = 0.65;
    var undoStack:Array<String> = [];
    var redoStack:Array<String> = [];
    var dragIndex:Int = -1;
    var dragging:Bool = false;
    var resizing:Bool = false;
    var dragStartX:Float = 0;
    var dragStartTime:Float = 0;
    var dragStartDuration:Float = 0;
    var panPreview:Bool = false;
    var panStartX:Float = 0;
    var panStartY:Float = 0;
    var panStartScrollX:Float = 0;
    var panStartScrollY:Float = 0;
    #if FLX_TOUCH
    var touchPinchDist:Float = 0;
    #end

    var blocks:Array<FlxSprite> = [];
    var labels:Array<FlxText> = [];
    var head:FlxSprite;
    var info:FlxText;
    var xBox:PsychUINumericStepper;
    var yBox:PsychUINumericStepper;
    var zoomBox:PsychUINumericStepper;
    var durBox:PsychUINumericStepper;
    var timeBox:PsychUINumericStepper;
    var zoomSlider:PsychUISlider;
    var passSlider:PsychUISlider;
    var fileDialog:FileDialogHandler;

    public function new(?s:SwagSong)
    {
        super();
        song = s != null ? s : PlayState.SONG;
    }

    override function create()
    {
        FlxG.mouse.visible = true;
        if(song == null)
        {
            var msg=new FlxText(20,20,FlxG.width-40,'Open a Psych Engine chart to edit camera events.',24);
            add(msg);
            fileDialog=new FileDialogHandler();
            fileDialog.open('song.json','Open Psych Engine Chart',null,function()
            {
                try
                {
                    song=Song.parseJSON(fileDialog.data,fileDialog.path);
                    PlayState.SONG=song; StageData.loadDirectory(song); loadData();
                    makePreview(); makeHeader(); makeTimeline(); makePanel(); refresh(); seek(0);
                    msg.destroy();
                }
                catch(e:Dynamic) msg.text='Failed to load chart: '+Std.string(e);
            });
            super.create();
            return;
        }
        PlayState.SONG = song;
        StageData.loadDirectory(song);
        loadData();

        var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF202020); add(bg);
        makePreview();
        makeHeader();
        makeTimeline();
        makePanel();
        refresh();
        seek(0);
        super.create();
    }

    function makeHeader()
    {
        var bar = new FlxSprite(0,0).makeGraphic(FlxG.width,HEADER,0xFF101010); add(bar);
        add(new FlxText(12,9,500,'Camera Editor  •  '+song.song,22));
        var save = new PsychUIButton(FlxG.width-185,9,'Save',saveChart,80,28); add(save);
        var back = new PsychUIButton(FlxG.width-95,9,'Back',closeEditor,80,28); add(back);
        info = new FlxText(12,HEADER+3,FlxG.width-PANEL-24,'',11); add(info);
    }

    function makePreview()
    {
        preview = new FlxCamera(0,HEADER,FlxG.width-PANEL,FlxG.height-HEADER-TIMELINE);
        preview.bgColor = 0xFF303030; FlxG.cameras.add(preview,false);
        stage = new FlxTypedGroup<FlxSprite>(); stage.cameras=[preview]; add(stage);

        var name = song.stage;
        if(name == null || name.length==0) name = StageData.vanillaSongStage(song.song);
        var sf = StageData.getStageFile(name);
        var gf:Character = sf.hide_girlfriend ? null : new Character(sf.girlfriend[0],sf.girlfriend[1],song.gfVersion==null?'gf':song.gfVersion);
        var dad = new Character(sf.opponent[0],sf.opponent[1],song.player2==null?'dad':song.player2);
        var bf = new Character(sf.boyfriend[0],sf.boyfriend[1],song.player1==null?'bf':song.player1);
        if(gf!=null) stage.add(gf); stage.add(dad); stage.add(bf);
        if(sf.objects!=null) StageData.addObjectsToState(sf.objects,gf,dad,bf,stage);
        add(new FlxText(12,HEADER+25,250,'Stage: '+name,12));

        mask = new FlxSprite(0,HEADER).makeGraphic(1,1,FlxColor.BLACK); add(mask);
        vcam = new FlxSprite().makeGraphic(1,1,FlxColor.TRANSPARENT); add(vcam);
        vcam.scrollFactor.set(); mask.scrollFactor.set();
    }

    function makeTimeline()
    {
        var y=FlxG.height-TIMELINE;
        var bg=new FlxSprite(0,y).makeGraphic(FlxG.width-PANEL,TIMELINE,0xFF111111); add(bg);
        add(new FlxText(8,y+6,160,'Timeline',16));
        var play=new PsychUIButton(175,y+5,'Play',function() playing=!playing,55,24); add(play);
        var focus=new PsychUIButton(235,y+5,'+ Focus',function() addEvent('Focus Camera'),75,24); add(focus);
        var zoom=new PsychUIButton(315,y+5,'+ Zoom',function() addEvent('Zoom Camera'),75,24); add(zoom);
        var lay=new PsychUIButton(395,y+5,'+ Layer',addLayer,75,24); add(lay);
        var sb=new PsychUICheckBox(475,y+9,'Snap',55); sb.checked=true; sb.onClick=function() snap=sb.checked; add(sb);
        add(new FlxText(535,y+10,FlxG.width-PANEL-545,'LMB select/seek • RMB Focus • Shift+RMB Zoom • Ctrl+Wheel layer • Shift+Wheel zoom',10));
        head=new FlxSprite(0,y).makeGraphic(2,TIMELINE,FlxColor.WHITE); add(head);
    }

    function makePanel()
    {
        var x=FlxG.width-PANEL;
        add(new FlxSprite(x,HEADER).makeGraphic(PANEL,FlxG.height-HEADER,0xFF181818));
        add(new FlxText(x+12,HEADER+12,PANEL-24,'Properties',20));

        xBox=new PsychUINumericStepper(x+12,HEADER+58,1,0,-99999,99999,1,120);
        yBox=new PsychUINumericStepper(x+150,HEADER+58,1,0,-99999,99999,1,120);
        zoomBox=new PsychUINumericStepper(x+12,HEADER+110,.01,1,.05,4,2,120);
        durBox=new PsychUINumericStepper(x+150,HEADER+110,10,DURATION,0,60000,0,120);
        timeBox=new PsychUINumericStepper(x+12,HEADER+162,1,0,0,99999999,1,120);
        for(c in [xBox,yBox,zoomBox,durBox,timeBox]) add(c);
        add(new FlxText(x+12,HEADER+43,120,'Position X')); add(new FlxText(x+150,HEADER+43,120,'Position Y'));
        add(new FlxText(x+12,HEADER+95,120,'Zoom')); add(new FlxText(x+150,HEADER+95,120,'Duration'));
        add(new FlxText(x+12,HEADER+147,120,'Start Time'));
        xBox.onValueChange=propertyChanged; yBox.onValueChange=propertyChanged; zoomBox.onValueChange=propertyChanged;
        durBox.onValueChange=propertyChanged; timeBox.onValueChange=propertyChanged;

        zoomSlider=new PsychUISlider(x+12,HEADER+220,function(v){if(selected>=0){zoomBox.value=v;propertyChanged();}},1,.05,4,250);
        zoomSlider.label='Zoom'; add(zoomSlider);

        var r=new PsychUICheckBox(x+12,HEADER+275,'Relative View',150); r.onClick=function(){relative=r.checked;evaluate();}; add(r);
        var e=new PsychUICheckBox(x+12,HEADER+305,'Show Extended Bounds',180); e.onClick=function(){extended=e.checked;overlay();}; add(e);
        var p=new PsychUICheckBox(x+12,HEADER+335,'Passepartout',130); p.checked=true; p.onClick=function(){pass=p.checked;overlay();}; add(p);
        passSlider=new PsychUISlider(x+12,HEADER+385,function(v){passAlpha=v;overlay();},.65,0,1,250); passSlider.label='Passepartout Opacity'; passSlider.decimals=2; add(passSlider);
        add(new FlxText(x+12,HEADER+445,PANEL-24,'Focus Camera → Camera Follow Pos\nZoom Camera → Add Camera Zoom\nCtrl+C/V copy/paste\nDelete remove\nCtrl+Z/Y undo/redo',12));
    }

    function loadData()
    {
        events=song.events==null?[]:song.events;
        meta=Reflect.hasField(song,'cameraEditor')?cast Reflect.field(song,'cameraEditor'):[];
        if(meta==null) meta=[];
        for(i in 0...events.length) if(isCam(events[i]) && metaFor(i)==null) meta.push({index:i,duration:DURATION,layer:'Default'});
        for(m in meta) if(m!=null && m.layer!=null && !layers.contains(m.layer)) layers.push(m.layer);
    }

    function isCam(e:Dynamic):Bool
    {
        return e!=null && e.length>1 && e[1]!=null && e[1].length>0 &&
            (e[1][0][0]=='Camera Follow Pos'||e[1][0][0]=='Add Camera Zoom'||e[1][0][0]=='Focus Camera'||e[1][0][0]=='Zoom Camera');
    }
    function metaFor(i:Int):Dynamic { for(m in meta) if(m!=null && Reflect.field(m,'index')==i) return m; return null; }
    function duration(i:Int):Float { var m=metaFor(i); return m==null?DURATION:Std.parseFloat(Std.string(m.duration)); }
    function layerOf(i:Int):String { var m=metaFor(i); return m==null?'Default':m.layer; }
    function nameOf(e:Dynamic):String { var n=e[1][0][0]; return n=='Camera Follow Pos'?'Focus Camera':n=='Add Camera Zoom'?'Zoom Camera':n; }

    function eventX(t:Float):Float return (t-timelinePan)*timelineZoom+110;
    function mouseTime():Float return Math.max(0,(FlxG.mouse.x-110)/timelineZoom+timelinePan);
    function snapTime(t:Float):Float return snap&&Conductor.stepCrochet>0?Math.round(t/Conductor.stepCrochet)*Conductor.stepCrochet:t;

    function refresh()
    {
        for(s in blocks) remove(s); for(t in labels) remove(t); blocks=[]; labels=[];
        var y=FlxG.height-TIMELINE+72;
        for(i in 0...events.length) if(isCam(events[i])&&layerOf(i)==layers[layer])
        {
            var x=eventX(events[i][0]), w=Math.max(20,duration(i)*timelineZoom);
            if(x+w<105||x>FlxG.width-PANEL) continue;
            var b=new FlxSprite(x,y).makeGraphic(1,1,nameOf(events[i])=='Focus Camera'?0xFF4B75FF:0xFFFF9A3D);
            b.scale.set(Math.min(w,FlxG.width-PANEL-x),34); b.updateHitbox(); b.ID=i; add(b); blocks.push(b);
            var t=new FlxText(x+3,y+8,Math.max(20,w-6),nameOf(events[i]),10); t.ID=i; add(t); labels.push(t);
        }
        head.x=Math.max(110,Math.min(FlxG.width-PANEL-2,eventX(time)));
        info.text='Time '+FlxMath.roundDecimal(time/1000,3)+'s  •  Beat '+FlxMath.roundDecimal(Conductor.getBeat(time),2)+'  •  Step '+FlxMath.roundDecimal(Conductor.getStep(time),2)+'  •  Layer '+layers[layer];
    }

    function addEvent(kind:String)
    {
        pushUndo();
        var t=snapTime(time);
        var e:Dynamic=kind=='Focus Camera'?[t,[['Camera Follow Pos','640','360']]]:[t,[['Add Camera Zoom','0.1','0.03']]];
        var i=events.length; events.push(e); meta.push({index:i,duration:DURATION,layer:layers[layer],ease:'linear',easeDir:'out'});
        selected=i; selectedMany=[i]; refresh(); seek(t); updateProperties();
    }
    function snapshot():String return Json.stringify({events:events,meta:meta,layers:layers});
    function restoreSnapshot(s:String)
    {
        var d:Dynamic=Json.parse(s); events=cast d.events; meta=cast d.meta; layers=cast d.layers;
        if(layers==null||layers.length==0)layers=['Default'];
        selected=-1;selectedMany=[];refresh();evaluate();
    }
    function pushUndo(){undoStack.push(snapshot());if(undoStack.length>80)undoStack.shift();redoStack=[];}
    function undo(){if(undoStack.length==0)return;redoStack.push(snapshot());restoreSnapshot(undoStack.pop());}
    function redo(){if(redoStack.length==0)return;undoStack.push(snapshot());restoreSnapshot(redoStack.pop());}
    function addLayer(){layers.push('Layer '+(layers.length+1));layer=layers.length-1;refresh();}

    function seek(t:Float)
    {
        time=Math.max(0,t); Conductor.songPosition=time; Conductor.mapBPMChanges(song); evaluate(); refresh(); updateProperties();
    }

    function easeValue(t:Float,name:String,dir:String):Float
    {
        var x=Math.max(0,Math.min(1,t)),v=x;
        switch(name){case 'sine':v=1-Math.cos(x*Math.PI/2);case 'quad':v=x*x;case 'cube':v=x*x*x;case 'quart':v=x*x*x*x;case 'quint':v=x*x*x*x*x;case 'expo':v=x==0?0:Math.pow(2,10*(x-1));case 'circ':v=1-Math.sqrt(1-x*x);case 'back':v=x*x*(2.70158*x-1.70158);case 'bounce':if(x<1/2.75)v=7.5625*x*x;else if(x<2/2.75){x-=1.5/2.75;v=7.5625*x*x+.75;}else if(x<2.5/2.75){x-=2.25/2.75;v=7.5625*x*x+.9375;}else{x-=2.625/2.75;v=7.5625*x*x+.984375;}}
        if(dir=='in')return v;if(dir=='out')return 1-easeValue(1-v,name,'in');return x<.5?easeValue(x*2,name,'out')/2:easeValue(x*2-1,name,'in')/2+.5;
    }
    function evaluate()
    {
        var sf=StageData.getStageFile(song.stage==null?StageData.vanillaSongStage(song.song):song.stage);
        var sx:Float=640,sy:Float=360,z:Float=sf.defaultZoom;
        var focus:Array<Int>=[],zooms:Array<Int>=[];
        for(i in 0...events.length)if(isCam(events[i])){var n=Std.string(events[i][1][0][0]);if(n=='Camera Follow Pos'||n=='Focus Camera')focus.push(i);if(n=='Add Camera Zoom'||n=='Zoom Camera')zooms.push(i);}
        focus.sort(function(a,b)return events[a][0]<events[b][0]?-1:1);zooms.sort(function(a,b)return events[a][0]<events[b][0]?-1:1);
        for(k in 0...focus.length)
        {
            var i=focus[k],e:Array<Dynamic>=cast events[i],et=Std.parseFloat(Std.string(e[0]));if(time<et)break;
            sx=Std.parseFloat(Std.string(e[1][0][1]));sy=Std.parseFloat(Std.string(e[1][0][2]));
            if(k+1<focus.length){var ni=focus[k+1],ne:Array<Dynamic>=cast events[ni],nt=Std.parseFloat(Std.string(ne[0]));if(time<nt&&nt>et){var m=metaFor(i),dur=m==null?DURATION:Std.parseFloat(Std.string(Reflect.field(m,'duration'))),p=Math.max(0,Math.min(1,(time-et)/Math.max(1,Math.min(dur,nt-et)))),en=m!=null&&Reflect.hasField(m,'ease')?Std.string(Reflect.field(m,'ease')):'linear',ed=m!=null&&Reflect.hasField(m,'easeDir')?Std.string(Reflect.field(m,'easeDir')):'out';p=easeValue(p,en,ed);sx+=(Std.parseFloat(Std.string(ne[1][0][1]))-sx)*p;sy+=(Std.parseFloat(Std.string(ne[1][0][2]))-sy)*p;}}
        }
        for(i in zooms)if(Std.parseFloat(Std.string(events[i][0]))<=time){var a=Std.parseFloat(Std.string(events[i][1][0][1]));if(!Math.isNaN(a))z+=a;}
        if(!relative){preview.zoom=Math.max(.1,z);preview.scroll.set(sx-preview.width/(2*preview.zoom),sy-preview.height/(2*preview.zoom));}
        overlay();
    }
    function overlay()
    {
        if(vcam==null)return;
        var w=FlxG.width-PANEL,h=FlxG.height-HEADER-TIMELINE,cx=w/2,cy=HEADER+h/2;
        var aspect=extended?20/9:16/9; var vh=Math.min(h*.78,w/aspect*.78),vw=vh*aspect;
        vcam.makeGraphic(Std.int(vw),Std.int(vh),FlxColor.WHITE); vcam.alpha=0.08;
        vcam.x=cx-vw/2;vcam.y=cy-vh/2;vcam.visible=true;
        mask.makeGraphic(w,h,FlxColor.BLACK);mask.x=0;mask.y=HEADER;mask.alpha=pass?passAlpha:0;
    }

    function updateProperties()
    {
        if(selected<0||selected>=events.length){return;}
        var e:Array<Dynamic>=cast events[selected];
        var row:Array<Dynamic>=cast e[1][0];
        var n:String=Std.string(row[0]),a=Std.parseFloat(Std.string(row.length>1?row[1]:'0')),b=Std.parseFloat(Std.string(row.length>2?row[2]:'0'));
        if(n=='Camera Follow Pos'||n=='Focus Camera'){xBox.value=a;yBox.value=b;zoomBox.value=1;}else{xBox.value=0;yBox.value=0;zoomBox.value=1+a;}
        durBox.value=duration(selected);timeBox.value=Std.parseFloat(Std.string(e[0]));zoomSlider.value=zoomBox.value;
    }

    function propertyChanged()
    {
        if(selected<0||selected>=events.length)return;
        var e:Array<Dynamic>=cast events[selected];
        var row:Array<Dynamic>=cast e[1][0];
        var n:String=Std.string(row[0]);
        if(n=='Camera Follow Pos'||n=='Focus Camera'){row[1]=Std.string(xBox.value);row[2]=Std.string(yBox.value);}
        else row[1]=Std.string(zoomBox.value-1);
        e[0]=snapTime(timeBox.value);
        var m=metaFor(selected);if(m==null){m={index:selected,duration:DURATION,layer:'Default'};meta.push(m);}m.duration=durBox.value;
        refresh();evaluate();
    }

    function copySelected()
    {
        copied=[];if(selectedMany.length==0&&selected>=0)selectedMany=[selected];if(selectedMany.length==0)return;
        var base:Float=Std.parseFloat(Std.string((cast events[selectedMany[0]]:Array<Dynamic>)[0]));
        for(i in selectedMany)
        {
            var e:Array<Dynamic>=cast events[i];
            var row:Array<Dynamic>=cast e[1][0];
            copied.push([Std.parseFloat(Std.string(e[0]))-base,[[row[0],row.length>1?row[1]:'',row.length>2?row[2]:'']],duration(i)]);
        }
    }
    function pasteSelected()
    {
        var base=snapTime(time);selectedMany=[];for(c in copied){var i=events.length;events.push([base+c[0],c[1]]);meta.push({index:i,duration:c[2],layer:layers[layer]});selectedMany.push(i);}selected=selectedMany.length>0?selectedMany[0]:-1;refresh();
    }
    function deleteSelected()
    {
        if(selectedMany.length==0&&selected>=0)selectedMany=[selected];
        if(selectedMany.length>0)pushUndo();selectedMany.sort(function(a,b)return b-a);
        for(i in selectedMany)if(i>=0&&i<events.length)events.splice(i,1);
        selected=-1;selectedMany=[];refresh();
    }

    override function update(elapsed:Float)
    {
        if(song==null){super.update(elapsed);return;}
        if(controls.BACK||FlxG.keys.justPressed.ESCAPE){closeEditor();return;}
        if(playing){seek(time+elapsed*1000);if(time>chartLength())seek(0);}
        #if FLX_TOUCH
        if(FlxG.touches != null && FlxG.touches.list.length >= 2)
        {
            var ta=FlxG.touches.list[0];
            var tb=FlxG.touches.list[1];
            var dx=ta.x-tb.x;
            var dy=ta.y-tb.y;
            var dist=Math.sqrt(dx*dx+dy*dy);
            if(touchPinchDist>0 && dist>1)
            {
                preview.zoom=Math.max(.25,Math.min(4,preview.zoom*(dist/touchPinchDist)));
                overlay();
            }
            touchPinchDist=dist;
        }
        else touchPinchDist=0;
        #end
        if(FlxG.mouse.wheel!=0)
        {
            if(FlxG.mouse.y>=FlxG.height-TIMELINE){if(FlxG.keys.pressed.SHIFT)timelineZoom=Math.max(.02,Math.min(2,timelineZoom+FlxG.mouse.wheel*.01));else timelinePan=Math.max(0,timelinePan-FlxG.mouse.wheel*500/timelineZoom);refresh();}
            else if(FlxG.mouse.x<FlxG.width-PANEL){preview.zoom=Math.max(.25,Math.min(4,preview.zoom+FlxG.mouse.wheel*.1));overlay();}
        }
        if(FlxG.mouse.justPressed)
        {
            if(FlxG.mouse.y>=FlxG.height-TIMELINE&&FlxG.mouse.x<FlxG.width-PANEL)
            {
                var hit=-1;var resize=false;for(b in blocks)if(FlxG.mouse.overlaps(b,FlxG.camera)){hit=b.ID;if(Math.abs(FlxG.mouse.x-(b.x+b.width))<16)resize=true;break;}
                if(hit>=0){pushUndo();selected=hit;if(FlxG.keys.pressed.SHIFT){if(selectedMany.contains(hit))selectedMany.remove(hit);else selectedMany.push(hit);}else selectedMany=[hit];updateProperties();dragIndex=hit;dragStartX=FlxG.mouse.x;dragStartTime=Std.parseFloat(Std.string(events[hit][0]));dragStartDuration=duration(hit);dragging=!resize;resizing=resize;}
                else seek(mouseTime());
            }
            else if(FlxG.mouse.y>=HEADER&&FlxG.mouse.y<FlxG.height-TIMELINE&&FlxG.mouse.x<FlxG.width-PANEL){panPreview=true;panStartX=FlxG.mouse.x;panStartY=FlxG.mouse.y;panStartScrollX=preview.scroll.x;panStartScrollY=preview.scroll.y;}
        }
        if(FlxG.mouse.pressed)
        {
            if(dragIndex>=0){var dx=FlxG.mouse.x-dragStartX;var ev:Array<Dynamic>=cast events[dragIndex];if(dragging)ev[0]=Math.max(0,snapTime(dragStartTime+dx/timelineZoom));if(resizing){var m=metaFor(dragIndex);if(m!=null)m.duration=Math.max(0,dragStartDuration+dx/timelineZoom);}refresh();evaluate();}
            else if(panPreview){preview.scroll.x=panStartScrollX-(FlxG.mouse.x-panStartX)/preview.zoom;preview.scroll.y=panStartScrollY-(FlxG.mouse.y-panStartY)/preview.zoom;}
        }
        if(FlxG.mouse.justReleased){dragIndex=-1;dragging=false;resizing=false;panPreview=false;}
        if(FlxG.mouse.justPressedRight&&FlxG.mouse.y>=FlxG.height-TIMELINE&&FlxG.mouse.x<FlxG.width-PANEL)addEvent(FlxG.keys.pressed.SHIFT?'Zoom Camera':'Focus Camera');
        if(FlxG.keys.justPressed.DELETE||FlxG.keys.justPressed.BACKSPACE)deleteSelected();
        if(FlxG.keys.justPressed.C&&FlxG.keys.pressed.CONTROL)copySelected();
        if(FlxG.keys.justPressed.V&&FlxG.keys.pressed.CONTROL)pasteSelected();
        if(FlxG.keys.justPressed.Z&&FlxG.keys.pressed.CONTROL){if(FlxG.keys.pressed.SHIFT)redo();else undo();}
        if(FlxG.keys.justPressed.Y&&FlxG.keys.pressed.CONTROL)redo();
        super.update(elapsed);
    }

    function chartLength():Float{var m:Float=0;for(e in events)if(e!=null)m=Math.max(m,Std.parseFloat(Std.string((cast e:Array<Dynamic>)[0]))+duration(events.indexOf(e)));return m+1000;}

    function saveChart()
    {
        var savedMeta:Array<Dynamic>=[];
        for(i in 0...events.length)
        {
            var m=metaFor(i);
            savedMeta.push({index:i,duration:m==null?DURATION:m.duration,layer:m==null?'Default':m.layer,
                ease:m!=null&&Reflect.hasField(m,'ease')?m.ease:'linear',
                easeDir:m!=null&&Reflect.hasField(m,'easeDir')?m.easeDir:'out'});
        }
        Reflect.setField(song,'cameraEditor',savedMeta);song.events=events;
        var data=PsychJsonPrinter.print(song,['sectionNotes','events']);
        #if mobile
        if(Song.chartPath!=null)StorageUtil.saveContent(Song.chartPath.substr(Song.chartPath.lastIndexOf('/')+1),data);
        #else
        if(Song.chartPath!=null)File.saveContent(Song.chartPath,data);else{if(fileDialog==null)fileDialog=new FileDialogHandler();if(fileDialog.completed)fileDialog.save(Paths.formatToSongPath(song.song)+'.json',data);}
        #end
        if(info!=null)info.text='Saved camera events.';
    }

    function closeEditor(){if(preview!=null)FlxG.cameras.remove(preview);MusicBeatState.switchState(new MasterEditorMenu());}
}