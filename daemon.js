var follow = require("follow"),
  async = require("async"),
  request = require("./json-client"),
  rawRequest = require("request"),
  docstate = require("docstate").control();

var adminDb = "http://localhost:4985/linkedin";


// download company data visible to different users
// var linkedInUserProfileUrl = "/v1/people/~:(id,email-address,first-name,last-name,headline,current-share,summary,picture-url,public-profile-url,specialties,positions)?format=json&oauth2_access_token="+accessToken;


var feed = new follow.Feed({db:adminDb, include_docs:true, filter : "sync_gateway/bychannel", query_params : {channels : "user-new,contact-new,message-new,company-new"}});

// handle new users
docstate.safe("user", "new", function(doc){
  console.log("new user", doc)
  var userID = doc._id.substr(2);
  // fetch the users contacts
  var connectionsURL = "https://api.linkedin.com/v1/people/~/connections:(id,email-address,first-name,last-name,headline,location,picture-url,positions)?format=json&oauth2_access_token="+doc.accessToken
  request.get(connectionsURL, function(err, res, body){
    if (err) {
      console.error("error with user", doc._id, err)
    } else {
      console.log(body.values.length)
      var contactIDs = body.values.map(function(v){return v.id;});
      insertProfiles(doc, body.values, function(err) {
        if (err) {
          console.error("error insertProfiles", err)
        } else {

          grantAccessToContacts(userID, contactIDs, function(err){
            if (err) {
              throw err;
            }
              delete doc.state;
              console.log("doc", doc)
              request.put(adminDb+"/"+doc._id, {json:doc}, function(err) {
                if (err) {
                  throw err;
                }
                console.log("imported user's contacts")
              })
          });
        }
      })
    }
  })
})

// fetch avatar images for contacts
var avatarFetch = async.queue(function(info, done) {
  var doc = info.doc;
  var field = info.field;
  var docURL= adminDb+"/"+doc._id;
  console.log("fetch avatar for", docURL)
  var picURL = doc[field];
  if (!picURL) {
    delete doc.state;
    return request.put(docURL, {json:doc}, function(err) {
      if (err) {
        console.error("doc put error", err, doc);
        throw(err)
      }
      done()
    })
  }

  var getPic = rawRequest(picURL)
  getPic.on("error", function(err) {
    throw err;
  })
  getPic.on("response", function(res) {
    var image = new Buffer(0);
    res.on("data", function(data) {
      image = Buffer.concat([image, data]);
    })
    res.on("end", function() {
      doc._attachments = {};
      doc._attachments[info.target] = {
        data : image.toString("base64"),
        content_type : res.headers["content-type"]
      }
      delete doc.state;
      request.put(docURL, {json:doc}, function(err) {
        if (err) {
          console.error("attach put error", err, doc);
          throw(err)
        }
        done()
      })
    })
  })
}, 4)

var companyFetch = async.queue(function(info, done) {

  var companyInfoURL = "https://api.linkedin.com/v1/companies/"+info.id+":(id,name,square-logo-url,description)?format=json&oauth2_access_token="+info.accessToken
  request.get(companyInfoURL, function(err, res, body) {
    if (err) {
      console.error("err company", err, body)
    } else {
      console.log("company", body)
      body.type = "company";
      body.state = 'new';
      var companyURL = adminDb + "/com:" + body.id
      request.put(companyURL, {json: body}, function(err, res, body){
        done()
      })
    }
  })

}, 4)


docstate.safe("contact", "new", function(doc){
  var docURL= adminDb+"/"+doc._id;
  if (!doc.pictureUrl) {
    delete doc.state;
    request.put(docURL, {json:doc}, function(err) {
      if (err) {
        console.error("contact put error", err, doc);
        throw(err)
      }
    })
  } else {
    avatarFetch.push({doc:doc, field : "pictureUrl", target : "avatar"});
  }
});


docstate.safe("company", "new", function(doc){
  console.log("company", doc);
  avatarFetch.push({doc:doc, field : "squareLogoUrl", target : "logo"});
})



function grantAccessToContacts(userID, contactIDs, done) {
  request.get(adminDb+"/_user/"+userID, function(err, res, body) {
    if (err) {return done(err)}
    body.admin_channels = body.admin_channels || [];
    var chans = {};
    for (var i = 0; i < body.admin_channels.length; i++) {
      chans[body.admin_channels[i]] = true;
    }
    for (i = 0; i < contactIDs.length; i++) {
      if (contactIDs[i] != "private") chans["c-"+contactIDs[i]] = true;
    }
    body.admin_channels = Object.keys(chans);
    // console.log("grantAccessToContacts", contactIDs, body)
    body.admin_channels.push("all")
    request.put(adminDb+"/_user/"+userID, {json : body}, done)
  });
}

function insertProfiles(user, profiles, done) {
  var p = profiles.pop();
  if (!p) {return done()}
  if (p.id == "private") {return insertProfiles(user, profiles, done)}
  delete p.apiStandardProfileRequest;
  p.type = "contact"
  p.state = "new"

  var pos = p.positions && p.positions.values && p.positions.values[0]
  if (pos && pos.company && pos.company.id) {
    companyFetch.push({id : pos.company.id, accessToken : user.accessToken})
  }

  var docURL= adminDb+"/c:"+p.id;
  request.get(docURL, function(err, res, doc) {
    if (err == 404) {
      request.put(docURL, {json:p}, function(err) {
        if (err) {return done(err)}
        insertProfiles(user, profiles, done);
      })
    } else if (err) {
      done(err)
    } else {
      // todo merge any new info into the doc and save back
      // for now skip it
      insertProfiles(user, profiles, done);
    }

  })
}


// handle new messages
docstate.safe("message", "new", function(doc){
  console.log("new message", doc)
  var userURL= adminDb+"/u:"+doc.sender_id;
  request.get(userURL, function(err, res, sender) {
    var sendURL = "https://api.linkedin.com/v1/people/~/mailbox?format=json&oauth2_access_token="+sender.accessToken
    var sendBody = {
      recipients: {
        values : [{
          person : {
            _path : "/people/"+doc.recipient.substr(2)
          }
        }]
      },
      subject : doc.subject,
      body : doc.message
    }
    request.post(sendURL, {json : sendBody}, function(err, res, body){
      console.log("sent message", err, body)
      if (!err) {
        delete doc.state;
        request.put(adminDb+"/"+doc._id, {json:doc}, function(err, res, body) {
          console.log("done message", err, body)
        })
      }
    })
  });
// get user doc for access token
// user access token to send message
// remove state = new


})

docstate.start()

feed.on('change', function(change) {
  if (change.doc) docstate.handle(change.doc);
})

feed.on('error', function(err) {
  console.error('Since Follow always retries on errors, this must be serious');
  throw err;
})

feed.follow();

