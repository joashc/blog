var $doc = $(document),$article = $('.post'),$markers = $('.post .footnoteRef'),$footnotes = $('.footnotes').find('ol');
function createSidenotes() {
  var $footnoteList = $footnotes.children();
  $markers.each(function (index, item) {
    var $item = $(item);
    $item.closest('p').wrap('<div class="post-subject"></div>');
    var paragraph = $item.closest('.post-subject');
    var offset = ($item.find('sup').offset().top - $(paragraph).offset().top) + 4;
    paragraph.append(
        "<div class='post-sidenote' role='complementary' style='margin-top: " + offset + "px'>"
        + $($footnoteList[index]).html()
        + "</div>"
    );
    paragraph.find('a').last().remove();
  });
}

function toggleNotes() {
  if ($footnotes.length > 0 && $markers.length > 0) {
    $article.addClass('has-sidenotes');
  }
}

$doc.ready(function() {
  createSidenotes();
  toggleNotes();
});
