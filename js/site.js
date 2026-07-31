// Replaces rmarkdown.js, which was written against jQuery. Bootstrap 5 does not
// ship jQuery, so that file threw "$ is not defined" on every page and the
// mobile menu button had never worked on the Quarto site: it rendered, it was
// tappable, and nothing happened.
//
// Its other behaviour, shrinking the header on scroll, is not ported. The
// header carries `alwaysShrunk`, so there was nothing to shrink.
document.addEventListener("DOMContentLoaded", function () {
  var toggler = document.getElementById("menuToggler");
  var items = document.getElementById("menuItems");
  if (!toggler || !items) return;
  toggler.addEventListener("click", function () {
    items.classList.toggle("showMenu");
  });
});
