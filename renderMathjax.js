var mjAPI = require("mathjax-node/lib/mj-page.js");
var jsdom = require("jsdom").jsdom;
var fs = require("fs");
var path = require("path");

mjAPI.start();

var renderMathjaxForFile = (dir, fileName, callback) => {
    var fullPath = path.join(dir, fileName);
    var html = fs.readFile(fullPath, (err, data) => {
    var document = jsdom(data);
    console.log("Rendering:", fileName);

    mjAPI.typeset({
      html: document.body.innerHTML,
      renderer: "CommonHTML",
      inputs: ["TeX"],
      xmlns:"svg",
      svg:true
    }, function(result) {
      "use strict";
      document.body.innerHTML = result.html;
      var HTML = "<!DOCTYPE html>\n" + document.documentElement.outerHTML.replace(/^(\n|\s)*/, "");
      fs.writeFileSync(fullPath, HTML);
      callback();
    });
  });
};


var postDir = "./_site/posts/";
var pageDir = "./_site/blog";
var projectDir = "./_site/projects";

var posts = fs.readdirSync(postDir);
var pages = fs.readdirSync(pageDir);
var projects = fs.readdirSync(projectDir);

// Wait for all of these and the homepage
var pending = posts.length + pages.length + projects.length + 1;

var closeWhenDone = () => {
  pending -= 1;
  if (pending === 0) process.exit();
};

renderMathjaxForFile("./_site/", "index.html", closeWhenDone);

posts.forEach(post => {
  renderMathjaxForFile(postDir, post, closeWhenDone);
});

pages.forEach(page => {
  renderMathjaxForFile(pageDir, page, closeWhenDone);
});

projects.forEach(page => {
  renderMathjaxForFile(pageDir, page, closeWhenDone);
});
