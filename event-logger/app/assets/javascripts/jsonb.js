$(function() {
  let $elements = $("body.show .b-json__show");
  $elements.each(function(index, element) {
    let $element= $(element);
    let data = $element.data('json');
    $element.jsonViewer(data, {collapsed: true, withQuotes: true});
  })
});