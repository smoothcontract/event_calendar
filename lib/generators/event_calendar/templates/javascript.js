/*
 * Smart event highlighting
 * Handles for when events span rows, or don't have a background color
 */
Event.observe(window, "load", function() {
  // highlight events that have a background color
  $$(".ec-event-bg").each(function(ele) {
    ele.observe("mouseover", function(evt) {
      event_id = ele.readAttribute("data-event-id");
      event_class_name = ele.readAttribute("data-event-class");
      $(".ec-"+event_class_name+"-"+event_id).addClassName("ec-hover");
    });
    ele.observe("mouseout", function(evt) {
      event_id = ele.readAttribute("data-event-id");
      event_class_name = ele.readAttribute("data-event-class");
      event_color = ele.readAttribute("data-color");
      $(".ec-"+event_class_name+"-"+event_id).removeClassName("ec-hover");
    });
  });
});