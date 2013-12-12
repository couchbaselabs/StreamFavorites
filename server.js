var request = require("./json-client"),
  httpProxy = require('http-proxy');

var syncGatewayInfo = {
      host: 'localhost',
      port: 4984,
      admin: 4985,
      dbname: "listream"
    };

syncGatewayInfo.url ='http://'+syncGatewayInfo.host+":"+syncGatewayInfo.port;
var adminURL ='http://'+syncGatewayInfo.host+":"+syncGatewayInfo.admin;


httpProxy.createServer(function (req, res, proxy) {
  //
  // Create a proxy server and add a login handler
  //
  if (/_access_token\/.*/.test(req.url)) {
    console.log("token",req.method, req.url, req.headers)
    handleAccessToken(req.url.split('/').pop(), function(err, userID, session){
      if (err) {
        console.log("error", err)
        res.writeHead(500, {'Content-Type': 'application/json'});
        res.end(JSON.stringify(err));
      } else {
        console.log("session info", session)
        res.writeHead(200, {
          'Content-Type': 'application/json',
          "Set-Cookie" : session.cookie_name+"="+session.session_id+"; Path=/; Expires="+(new Date(session.expires)).toUTCString()
        });
        res.end(JSON.stringify({userID: userID}));
      }
    })
  } else {
    console.log("proxy",req.method, req.url, req.headers)
    proxy.proxyRequest(req, res, syncGatewayInfo);
  }

}).listen(8080);


function handleAccessToken(accessToken, done) {
  console.log("handleAccessToken", accessToken);
  var linkedInUserProfileUrl = "https://api.linkedin.com/v1/people/~:(id,email-address)?format=json&oauth2_access_token="+accessToken;
  request.get(linkedInUserProfileUrl, function(err, res, userData){
    if (err) {return done(err)}
    var userID = userData.id;
    console.log("got userID", userID)
    getSessionForUser(userID, function(err, session) {
      if (err) {return done(err)}
      doApplicationSetup(userID, accessToken, function(err){
        if (err) {return done(err)}
        done(false, userID, session);
      })
    });
  })
}

// APPLICTION logic
// create profile doc that can kick off contacts bot
function doApplicationSetup(userID, accessToken, done){
  var userSetupDocURL = adminURL+"/"+syncGatewayInfo.dbname+"/u:" + userID;
  request.get(userSetupDocURL, function(err, res, setupDoc) {
    // console.log("get doc", err, res.statusCode, setupDoc._id)

    if (err == 404) {
      var newSetupDoc = {
        type : "user",
        state : "new",
        accessToken : accessToken
      };
      request.put(userSetupDocURL, {json:newSetupDoc}, done);
    } else if (err) {
      done(err)
    } else {
      // console.log("existing setupDoc", setupDoc);
      if (setupDoc.accessToken !== accessToken) {
        setupDoc.accessToken = accessToken;
        request.put(userSetupDocURL, {json:setupDoc}, done);
      } else {
        done()
      }
    }
  })
}


function getSessionForUser(userID, done) {
  ensureUserDocExists(userID, function(err) {
    if (err) {return done(err)}
    request.post(adminURL+"/"+syncGatewayInfo.dbname+"/_session", {json:{name : userID}}, function(err, res, body){
      // console.log("session", err, res.statusCode, body)
      if (err) {return done(err)}
      done(false, body)
    })
  });
}


function ensureUserDocExists(userID, done) {
  var userDocURL = adminURL+"/"+syncGatewayInfo.dbname+"/_user/" + userID;
  request.get(userDocURL, function(err, res) {
    // console.log("userDocURL", err, res.statusCode, userDocURL)
    if (err == 404) {
      // create a user doc
      request.put(userDocURL, {json:{email: userID, password : Math.random().toString(36).substr(2)}}, function(err, res, body){
        // console.log("put userDocURL", err, res.statusCode, body)
        done(err)
      })
    } else {
      done(err)
    }
  })
}
