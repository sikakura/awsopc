
var COLOR_START = "#ffdddd";
var COLOR_STOP = "transparent";
var COLOR_BACKUP = "#ffff00";

var startCell = null;
var bitstr = "1";
var color = COLOR_START;
var map = [
	["0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0"],
	["0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0"],
	["0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0"],
	["0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0"],
	["0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0"],
	["0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0"],
	["0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0"]
];

//Tableロード時
function load(){

	var ret = document.getElementById("server_schedule").value;
	if(ret.length == 0){
//		alert("null");
		return;
	}
	var table = document.getElementById("time_table");
	//色を変更してmapにも反映させる
	var x, y, cells, count;
	count = 0;
	for(y=1; y<table.rows.length; y++){
		row = table.rows.item(y);
		for(x=1; x<row.cells.length; x++){
			//alert(ret.substring(count,count+1));
			if( ret.substring(count,count+1) == "0" ){
				row.cells.item(x).style.backgroundColor = COLOR_STOP;
				map[y-1][x-1] = "0";
			}
			else if( ret.substring(count,count+1) == "1" ){
				row.cells.item(x).style.backgroundColor = COLOR_START;
				map[y-1][x-1] = "1";
			}
			else if( ret.substring(count,count+1) == "2" ){
				row.cells.item(x).style.backgroundColor = COLOR_BACKUP;
				map[y-1][x-1] = "2";
			}
			count = count + 1;
		}
	}
}


//モードの変更
function modechange(){

	var mode = document.getElementsByName("mode");
	var sample = document.getElementById("sample-color");
	if( mode[0].checked ){
		bitstr = "1";
		color = COLOR_START;
		sample.style.background = color;
	}else if(mode[1].checked){
		bitstr = "0";
		color = COLOR_STOP;
		sample.style.background = color;
	}else if(mode[2].checked){
		bitstr = "2";
		color = COLOR_BACKUP;
		sample.style.background = color;
	}
}

//マウスダウンのイベント処理
function mouseDown(table, e){
	if (!e) var e = window.event;
	
	startCell = e.srcElement? e.srcElement: e.target;
	if(startCell.tagName != "TD"){
		startCell = null;
		return;
	}
	mouseMove(table, e);
}
//マウスアップのイベント処理
function mouseUp(table, e){
	if (!e) var e = window.event;
	
	var endCell = e.srcElement?e.srcElement:e.target;
	if(!(endCell.tagName=="TD" && startCell))
		return false;
	
	//セルの位置を取得
	var from = getCellPos(table, startCell);
	var to = getCellPos(table, endCell);
	if(!from || !to)
		return false;
	
	//mouseMoveで選択状態表示の更新をさせないようにする
	startCell = null;
	
	//ここに選択後の処理を書く
	//alert("("+from.col+", "+from.row+") -> ("+to.col+", "+to.row+")");
	var ret = "";
	for(y=0; y<7; y++){
		for(x=0; x<24; x++){
			ret = ret + map[y][x];
		}
	}
	//alert(ret);
	document.getElementById("server_schedule").value = ret;
}
//マウス移動のイベント処理
function mouseMove(table, e){
	if (!e) var e = window.event;
	
	var endCell = e.srcElement?e.srcElement:e.target;
	if(!(endCell.tagName=="TD" && startCell))
		return false;
	
	//セルの位置を取得
	var from = getCellPos(table, startCell);
	var to = getCellPos(table, endCell);
	if(!from || !to)
		return false;

	//色を変更
	var x, y, cells;
	for(y=1; y<table.rows.length; y++){
		row = table.rows.item(y);
		for(x=1; x<row.cells.length; x++){
			if((from.row-y)*(y-to.row)>=0 && (from.col-x)*(x-to.col)>=0){
				row.cells.item(x).style.backgroundColor = color;
				map[y-1][x-1] = bitstr;
			}
		}
	}
}
//tableの中のcellの位置を取得する
function getCellPos(table, cell){
	var pos = new Object();
	if(cell.nodeName == "TD"){
		var x, y, cells;
		for(y=0; y<table.rows.length; y++){
			row = table.rows.item(y);
			for(x=0; x<row.cells.length; x++){
				if(row.cells.item(x) == cell){
					pos.row = y;
					pos.col = x;
					return pos;
				}
			}
		}
	}
	return null;
}
