function doIt() {
    request.open("GET", "http://localhost/upgrade61.log", false);
    request.send(null);
    var lines = request.responseText.split("\n");
    var lastLog = "";
    for (i=Math.max(0,lines.length-30) ; i < lines.length-1; i++) {
	lastLog += lines[i] + "<br>";
    }
    document.getElementById("upgrade").innerHTML = lastLog;
}

request = new XMLHttpRequest();
setInterval("doIt()", 1000); // every second
