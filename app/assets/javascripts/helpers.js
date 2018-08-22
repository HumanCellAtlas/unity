var OPEN_MODAL = '';
var PAGE_RENDERED = false;
// default actions to execute on all page loads
function enableDefaultActions() {
    $('.dropdown-toggle').dropdown();
    $('body').tooltip({selector: '[data-toggle="tooltip"]', container: 'body', trigger: 'hover'});
    $('[data-toggle="popover"]').popover()

}

// set error state on blank text boxes or selects
function setErrorOnBlank(selector) {
    selector.map(function() {
        if ( $(this).val() === "" ) {
            $(this).parent().addClass('has-error has-feedback');
        } else {
            $(this).parent().removeClass('has-error has-feedback');
        }
    });
}

// callback function will execute after modal completes opening
function launchModalSpinner(spinnerTarget, modalTarget, callback) {

    // set listener to fire callback, and immediately clear listener to prevent multiple requests queueing
    $(modalTarget).on('shown.bs.modal', function() {
        $(modalTarget).off('shown.bs.modal');
        callback();
    });

    $(spinnerTarget).empty();
    var target = $(spinnerTarget)[0];
    var spinner = new Spinner(opts).spin(target);
    $(target).data('spinner', spinner);
    $(modalTarget).modal('show');
}

// function to close modals with spinners launched from launchModalSpinner
// callback function will execute after modal completes closing
function closeModalSpinner(spinnerTarget, modalTarget, callback) {
    // set listener to fire callback, and immediately clear listener to prevent multiple requests queueing
    $(modalTarget).on('hidden.bs.modal', function() {
        $(modalTarget).off('hidden.bs.modal');
        callback();
    });
    $(spinnerTarget).data('spinner').stop();
    $(modalTarget).modal('hide');
}

// options for Spin.js
var opts = {
    lines: 13, // The number of lines to draw
    length: 38, // The length of each line
    width: 17, // The line thickness
    radius: 45, // The radius of the inner circle
    scale: 1, // Scales overall size of the spinner
    corners: 1, // Corner roundness (0..1)
    color: '#000000', // CSS color or array of colors
    fadeColor: 'transparent', // CSS color or array of colors
    speed: 1, // Rounds per second
    rotate: 0, // The rotation offset
    animation: 'spinner-line-fade-quick', // The CSS animation name for the lines
    direction: 1, // 1: clockwise, -1: counterclockwise
    zIndex: 2e9, // The z-index (defaults to 2000000000)
    className: 'spinner', // The CSS class to assign to the spinner
    top: '100px', // Top position relative to parent
    left: '50%', // Left position relative to parent
    shadow: '0 0 1px transparent', // Box-shadow for the lines
    position: 'relative' // Element positioning
};

$(document).on('shown.bs.modal', function(e) {
    console.log("modal " + $(e.target).attr('id') + ' opened');
    OPEN_MODAL = $(e.target).attr('id');
});

$(document).on('hidden.bs.modal', function(e) {
    console.log("modal " + $(e.target).attr('id') + ' closed');
    OPEN_MODAL = '';
});