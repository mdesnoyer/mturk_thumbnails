// A script to profile the Imageservingplatform 
// Sends a request to image on page load and then sends the image load time to
// the tracker 

function getRequestId() {
    return Math.floor((1 + Math.random()) * 0x10000).toString(16).substring(1); 
}

var docReadyId = setInterval(checkWindowReady, 100); //100ms
var counter = 0;
var profileId = null;
var uid = getRequestId() + getRequestId();

// Wait for doc ready and then fetch the image
function checkWindowReady(){
    if(document.readyState === "complete" || document.readyState === "interactive"){
        clearInterval(docReadyId);  
        profileId = setInterval(profileISP, 10000);
    }

}

function profileISP(){
    var isp = "http://isp-test-149188743.us-east-1.elb.amazonaws.com";
    var xmlhttp = new XMLHttpRequest(); 
    var pid = getRequestId() + getRequestId();
    if(xmlhttp)  
    {  
        var start = (new Date()).getTime();
        xmlhttp.onreadystatechange=function()  
        {  
            if (xmlhttp.readyState==4){
                if(xmlhttp.status == 200) { 
                    var diff = (new Date()).getTime() - start;
                    var url = isp + "/?roundtrip=" + diff + "&pid=" + pid + "&uid=" + uid;
                    var xmlhttp2 = new XMLHttpRequest();
                    xmlhttp2.open("GET", url, false);
                    xmlhttp2.send();
                } 
            }  
        } 
        //var cURL = "http://neon-image-cdn.s3.amazonaws.com/pixel.jpg?x=1";
        var cURL = isp + "/v1/server/pub1/vid1/?height=500&width=600&pid=" + pid + "&uid=" + uid;
        xmlhttp.open("GET", cURL, false);  //cURL is the URL of image   
        xmlhttp.send();  
        if (counter ++ >= 5)
            clearInterval(profileId);   
    }
}