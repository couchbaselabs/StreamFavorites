## How to build

* clone

* run [`pod`](http://beta.cocoapods.org/)

* upgrade the Couchbase Lite Cocoapod to Beta2 by swapping out the .framework files from `Pods/couchbase-lite-ios` with the ones from the Couchbase download.

* configure sync gateway
  * either use Couchbase Cloud
  * or run it on your machine based on the Beta2 download.
  * use the sync function

* configure the node.js authentication handler
* run the authentication handler (it's a proxy)

* update the app code with your app secret and sync gateway url

* launch the app and login
* if you launch the app on another device, you should see sync
