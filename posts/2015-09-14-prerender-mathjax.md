---
title: Prerendering MathJax
---

I use MathJax on this blog. It's a great tool, but it's really slow, and worse, it's slow in a way that draws attention to itself. A page with even a bit of MathJax will go through these stages:

1. Unrendered MathJax markup
2. Initial render with incorrect font
3. Render with correct font, but with incorrect spacing and alignment
3. Render correctly

The entire process can take a few seconds, and it's rather jarring to watch text reflow at each stage as MathJax renders.

Khan Academy has noticed this problem, so it's developed an alternative called [KaTeX](https://github.com/Khan/KaTeX), which can render at many times the speed of MathJax. Unfortunately, it only implements a [small subset](https://github.com/Khan/KaTeX/wiki/Function-Support-in-KaTeX) of MathJax's functionality, and I wanted to draw commutative diagrams, which weren't supported. Even quite basic things like `\begin{split}` [aren't yet supported](https://github.com/Khan/KaTeX/issues/208), so I'm stuck with MathJax for the time being.

<!--more-->

## Prerendering
Fortunately, there's a tool called [mathjax-node](https://github.com/mathjax/MathJax-node) that allows you to render MathJax markup to a string, and even works on entire files. This seemed perfect for me, since I just use MathJax on this blog, which is a static site. I should be able to build the pages in Hakyll as normal, and then write a simple node script to batch prerender the MathJax. Here's what I ended up with:

```javascript
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
      var HTML = "<!DOCTYPE html>\n" 
        + document.documentElement.outerHTML
                  .replace(/^(\n|\s)*/, "");
      fs.writeFileSync(fullPath, HTML);
      callback();
    });
  });
};


var postDir = "./_site/posts/";
var pageDir = "./_site/blog";

var posts = fs.readdirSync(postDir);
var pages = fs.readdirSync(pageDir);

// Wait for all of these and the homepage
var pending = posts.length + pages.length + 1;

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
```

It uses a rather hacky method to "wait" for all the posts to be done, but it worked well enough to not justify a dependency on more robust concurrency packages. 

## Speed
I was pleasantly surprised by how much it sped up the rendering.

Rendering was extraordinarily quick compared to client-side MathJax. Prerendered pages also didn't go through all the intermediate rendering stages that caused text to jostle around for a few seconds before MathJax settled down. The speedup was even more noticeable on mobile devices, especially slower ones.

## Size
The price paid for this speed was page size. A HTML page that was previously 31kb had ballooned to 243kb! I decided to take a look at the rendered HTML, and I saw some plainly ridiculous markup like this:

```HTML
<span id="MathJax-Element-9-Frame" class="mjx-chtml">
  <span id="MJXc-Node-984" class="mjx-math" role="math">
    <span id="MJXc-Node-985" class="mjx-mrow">
      <span id="MJXc-Node-986" class="mjx-texatom">
        <span id="MJXc-Node-987" class="mjx-mrow">
          <span id="MJXc-Node-988" class="mjx-mi">
            <span class="mjx-char MJXc-TeX-main-I" style="padding-top: 0.519em; padding-bottom: 0.298em;">
            A
            </span>
          </span>
        </span>
      </span>
    </span>
  </span>
</span>
```

It didn't look like the most efficient method of encoding an \\(A\\), but it also looked like the amount of entropy the prerendering added might not be as large as the filesize delta suggested. I decided to see how much the rendered markup compressed:

```bash
gzip -c _site/posts/prerenderedPost.html | wc -c
```

and I found that the 243kb could be compressed down to 24kb. This was a compression ratio of 10%; the original file only compressed at 26%. I decided that the file size wasn't as big an issue as I'd initially supposed:


- The prerendered markup gzips well
- Prerendered pages wouldn't have to download the 60kb MathJax Javascript file, which only gzips down to about 20kb
- At these filesizes, [TTFB](https://en.wikipedia.org/wiki/Time_To_First_Byte)/ latency tends to be a larger factor
- Devices with slower connections would tend to have a harder time rendering MathJax too
- The webfonts need to be downloaded in either case, they can be over 60kb gzipped
