require("./helpers")
{ vows: vows, assert: assert, zombie: zombie, brains: brains } = require("vows")

brains.get "/cookies", (req, res)->
  res.cookie "_name", "value"
  res.cookie "_expires1", "3s", "Expires": new Date(Date.now() + 3000)
  res.cookie "_expires2", "5s", "Max-Age": 5000
  res.cookie "_expires3", "0s", "Expires": new Date(Date.now() - 100)
  res.cookie "_expires4", "0s", "Max-Age": 0
  res.cookie "_path1", "yummy", "Path": "/cookies"
  res.cookie "_path2", "yummy", "Path": "/cookies/sub"
  res.cookie "_path3", "wrong", "Path": "/wrong"
  res.cookie "_path4", "yummy", "Path": "/"
  res.cookie "_domain1", "here", "Domain": ".localhost"
  res.cookie "_domain2", "not here", "Domain": "not.localhost"
  res.cookie "_domain3", "wrong", "Domain": "notlocalhost"
  res.send "<html></html>"

brains.get "/cookies/echo", (req,res)->
  cookies = ("#{k}=#{v}" for k,v of req.cookies).join("; ")
  res.send "<html>#{cookies}</html>"

brains.get "/cookies_redirect", (req, res)->
  res.cookie "_expires5", "3s", "Expires": new Date(Date.now() + 3000), "Path": "/"
  res.redirect "/"

vows.describe("Cookies").addBatch(
  "get cookies":
    zombie.wants "http://localhost:3003/cookies"
      "cookies":
        topic: (browser)->
          browser.cookies("localhost", "/cookies")
        "should have access to session cookie": (cookies)->
          assert.equal cookies.get("_name"), "value"
        "should have access to persistent cookie": (cookies)->
          assert.equal cookies.get("_expires1"), "3s"
          assert.equal cookies.get("_expires2"), "5s"
        "should not have access to expired cookies": (cookies)->
          assert.isUndefined cookies.get("_expires3")
          assert.isUndefined cookies.get("_expires4")
        "should have access to cookies for the path /cookies": (cookies)->
          assert.equal cookies.get("_path1"), "yummy"
        "should have access to cookies for paths which are ancestors of /cookies": (cookies)->
          assert.equal cookies.get("_path4"), "yummy"
        "should not have access to other paths": (cookies)->
          assert.isUndefined cookies.get("_path2")
          assert.isUndefined cookies.get("_path3")
        "should not have access to .domain": (cookies)->
          assert.equal cookies.get("_domain1"), "here"
        "should not have access to other domains": (cookies)->
          assert.isUndefined cookies.get("_domain2")
          assert.isUndefined cookies.get("_domain3")
      "document.cookie":
        topic: (browser)->
          browser.document.cookie
        "should return name/value pairs": (cookie)-> assert.match cookie, /^(\w+=\w+; )+\w+=\w+$/
        "pairs":
          topic: (serialized)->
            pairs = serialized.split("; ").reduce (map, pair)->
              [name, value] = pair.split("=")
              map[name] = value
              map
            , {}
          "should include only visible cookies": (pairs)->
            keys = (key for key, value of pairs).sort()
            assert.deepEqual keys, "_domain1 _expires1 _expires2 _name _path1 _path4".split(" ")
          "should match name to value": (pairs)->
           assert.equal pairs._name, "value"
           assert.equal pairs._path1, "yummy"

  "get cookies and redirect":
    zombie.wants "http://localhost:3003/cookies_redirect"
      "cookies":
        topic: (browser)->
          browser.cookies("localhost", "/")
        "should have access to persistent cookie": (cookies)->
          assert.equal cookies.get("_expires5"), "3s"

  "send cookies":
    topic: ->
      browser = new zombie.Browser()
      browser.cookies("localhost").set "_name", "value"
      browser.cookies("localhost").set "_expires1", "3s", "max-age": 3000
      browser.cookies("localhost").set "_expires2", "0s", "max-age": 0
      browser.cookies("localhost", "/cookies").set "_path1", "here"
      browser.cookies("localhost", "/cookies/echo").set "_path2", "here"
      browser.cookies("localhost", "/jars").set "_path3", "there", "path": "/jars"
      browser.cookies("localhost", "/cookies/fido").set "_path4", "there", "path": "/cookies/fido"
      browser.cookies("localhost", "/jars").set "_path5", "here", "path": "/cookies"
      browser.cookies("localhost", "/jars").set "_path6", "here"
      browser.cookies(".localhost").set "_domain1", "here"
      browser.cookies("not.localhost").set "_domain2", "there"
      browser.cookies("notlocalhost").set "_domain3", "there"
      browser.wants "http://localhost:3003/cookies/echo", =>
        cookies = browser.text("html").split(/;\s*/).reduce (all, cookie)->
          [name, value] = cookie.split("=")
          all[name] = value.replace(/^"(.*)"$/, "$1")
          all
        , {}
        @callback null, cookies
    "should send session cookie": (cookies)-> assert.equal cookies._name, "value"
    "should pass persistent cookie to server": (cookies)-> assert.equal cookies._expires1, "3s"
    "should not pass expired cookie to server": (cookies)-> assert.isUndefined cookies._expires2
    "should pass path cookies to server": (cookies)->
      assert.equal cookies._path1, "here"
      assert.equal cookies._path2, "here"
    "should pass cookies that specified a different path when they were assigned": (cookies)-> assert.equal cookies._path5, "here" 
    "should pass cookies that didn't specify a path when they were assigned": (cookies)-> assert.equal cookies._path6, "here" 
    "should not pass unrelated path cookies to server": (cookies)->
      assert.isUndefined cookies._path3
      assert.isUndefined cookies._path4
    "should pass sub-domain cookies to server": (cookies)-> assert.equal cookies._domain1, "here"
    "should not pass other domain cookies to server": (cookies)->
      assert.isUndefined cookies._domain2
      assert.isUndefined cookies._domain3

  "setting cookies from subdomains":
    topic: (browser)->
      browser = new zombie.Browser()
      browser.cookies("www.localhost").update("foo=bar; domain=.localhost")
      @callback null, browser
    "should be accessible": (browser)->
      assert.equal "bar", browser.cookies("localhost").get("foo")
      assert.equal "bar", browser.cookies("www.localhost").get("foo")

).export(module)
